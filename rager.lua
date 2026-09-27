--[[ Rivals Rager v3 ]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")

local lp     = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CONFIG_FILE = "rivals_rager_v3_config.json"
local MAX_DIST    = 1000

-- ============================================================
-- CONFIG
-- ============================================================
local DEFAULTS = {
	rageEnabled     = false,
	rageKey         = "F5",
	rageModeKey     = "G",
	rageHoldKey     = "E",
	rageMaxDist     = 1000,
	rageMode        = "Orbit",
	rageActivation  = "Normal",
	orbitSpeed      = 3,
	orbitDistance   = 6,

	espEnabled      = false,
	espKey          = "F",
	espTracers      = true,
	espHealthBars   = true,
	espRange        = 1000,
	espTeamCheck    = true,

	menuPosX        = 20,
	menuPosY        = 0.35,
}

local cfg = {}

-- Bind representation: { kind = "key"|"mouse", value = Enum.KeyCode | "Mouse1"|"Mouse2"|"Mouse3" }

local function bindLabel(b)
	if type(b) ~= "table" then return "?" end
	if b.kind == "key" then
		return b.value and b.value.Name or "?"
	else
		return b.value or "?"
	end
end

local function bindFromString(name, fallback)
	if type(name) ~= "string" then return fallback end
	if name == "Mouse1" or name == "Mouse2" or name == "Mouse3" then
		return { kind = "mouse", value = name }
	end
	local ok, kc = pcall(function() return Enum.KeyCode[name] end)
	if ok and kc then return { kind = "key", value = kc } end
	return fallback
end

local function loadConfig()
	local data = {}
	if readfile and isfile then
		local ok, exists = pcall(isfile, CONFIG_FILE)
		if ok and exists then
			local ok2, contents = pcall(readfile, CONFIG_FILE)
			if ok2 and contents and contents ~= "" then
				local ok3, decoded = pcall(function() return HttpService:JSONDecode(contents) end)
				if ok3 and type(decoded) == "table" then data = decoded end
			end
		end
	end

	for k, v in pairs(DEFAULTS) do
		if data[k] == nil then
			cfg[k] = v
		elseif type(v) == "string" then
			cfg[k] = (type(data[k]) == "string") and data[k] or v
		else
			cfg[k] = data[k]
		end
	end

	cfg.rageMaxDist = math.clamp(tonumber(cfg.rageMaxDist) or 1000, 100, MAX_DIST)
	cfg.espRange    = math.clamp(tonumber(cfg.espRange)    or 1000, 100, MAX_DIST)

	cfg.rageKey     = bindFromString(cfg.rageKey,     { kind = "key", value = Enum.KeyCode.F5 })
	cfg.rageModeKey = bindFromString(cfg.rageModeKey, { kind = "key", value = Enum.KeyCode.G })
	cfg.rageHoldKey = bindFromString(cfg.rageHoldKey, { kind = "key", value = Enum.KeyCode.E })
	cfg.espKey      = bindFromString(cfg.espKey,      { kind = "key", value = Enum.KeyCode.F })
end

local function saveConfig()
	if not writefile then return end
	local snapshot = {
		rageEnabled     = cfg.rageEnabled,
		rageKey         = bindLabel(cfg.rageKey),
		rageModeKey     = bindLabel(cfg.rageModeKey),
		rageHoldKey     = bindLabel(cfg.rageHoldKey),
		rageMaxDist     = cfg.rageMaxDist,
		rageMode        = cfg.rageMode,
		rageActivation  = cfg.rageActivation,
		orbitSpeed      = cfg.orbitSpeed,
		orbitDistance   = cfg.orbitDistance,
		espEnabled      = cfg.espEnabled,
		espKey          = bindLabel(cfg.espKey),
		espTracers      = cfg.espTracers,
		espHealthBars   = cfg.espHealthBars,
		espRange        = cfg.espRange,
		espTeamCheck    = cfg.espTeamCheck,
		menuPosX        = cfg.menuPosX,
		menuPosY        = cfg.menuPosY,
	}
	local ok, enc = pcall(function() return HttpService:JSONEncode(snapshot) end)
	if ok and enc then pcall(writefile, CONFIG_FILE, enc) end
end

loadConfig()

local state = { unloaded = false, menuOpen = true }

-- ============================================================
-- BIND HELPERS
-- ============================================================
-- Does this InputObject match the given bind?
local function inputMatches(input, bind)
	if type(bind) ~= "table" then return false end
	if bind.kind == "key" then
		return input.UserInputType == Enum.UserInputType.Keyboard
			and bind.value ~= nil
			and input.KeyCode == bind.value
	elseif bind.kind == "mouse" then
		if bind.value == "Mouse1" then return input.UserInputType == Enum.UserInputType.MouseButton1 end
		if bind.value == "Mouse2" then return input.UserInputType == Enum.UserInputType.MouseButton2 end
		if bind.value == "Mouse3" then return input.UserInputType == Enum.UserInputType.MouseButton3 end
	end
	return false
end

-- Convert an InputObject into a bind table (or nil if unsupported)
local function bindFromInput(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		return { kind = "key", value = input.KeyCode }
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		return { kind = "mouse", value = "Mouse1" }
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		return { kind = "mouse", value = "Mouse2" }
	elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
		return { kind = "mouse", value = "Mouse3" }
	end
	return nil
end

-- ============================================================
-- TEAM DETECTION
-- ============================================================
local function teamKey(plr)
	if not plr then return nil end
	local ok1, teamId = pcall(function() return plr:GetAttribute("TeamID") end)
	if ok1 and teamId ~= nil and teamId ~= "" then return "rivals_" .. tostring(teamId) end
	if plr.Team and plr.Team.Name ~= "" then return "team_" .. plr.Team.Name end
	local ok2, attr = pcall(function() return plr:GetAttribute("Team") end)
	if ok2 and attr ~= nil and attr ~= "" then return "attr_" .. tostring(attr) end
	local ls = plr:FindFirstChild("leaderstats")
	if ls then
		for _, child in ipairs(ls:GetChildren()) do
			local n = child.Name:lower()
			if n == "team" or n == "side" or n == "faction" then
				local ok3, v = pcall(function() return tostring(child.Value) end)
				if ok3 and v ~= "" and v ~= "nil" then return "ls_" .. v end
			end
		end
	end
	local cls = plr:FindFirstChild("CustomLeaderstats")
	if cls then
		for _, child in ipairs(cls:GetChildren()) do
			local n = child.Name:lower()
			if n == "team" or n == "teamid" or n == "side" or n == "faction" then
				local ok4, v = pcall(function() return tostring(child.Value) end)
				if ok4 and v ~= "" and v ~= "nil" then return "cls_" .. v end
			end
		end
	end
	return nil
end

local function sameTeam(a, b)
	if not a or not b then return false end
	if a == b then return true end
	local ka, kb = teamKey(a), teamKey(b)
	if not ka or not kb then return false end
	return ka == kb
end

-- ============================================================
-- ESP
-- ============================================================
local espCache = {}
local hasDrawing = pcall(function() return Drawing.new("Line") end)

local function destroyESP(plr)
	local data = espCache[plr]
	if not data then return end
	if data.highlight then
		pcall(function()
			data.highlight.Adornee = nil
			data.highlight:Destroy()
		end)
	end
	if data.tracer then pcall(function() data.tracer:Remove() end) end
	if data.hpBg then pcall(function() data.hpBg:Remove() end) end
	if data.hpFill then pcall(function() data.hpFill:Remove() end) end
	espCache[plr] = nil
end

local function espColorFor(plr)
	if cfg.espTeamCheck and sameTeam(lp, plr) then
		return Color3.fromRGB(60, 220, 60)
	end
	return Color3.fromRGB(255, 60, 60)
end

local function buildESP(plr)
	if plr == lp then return end
	if not cfg.espEnabled then
		destroyESP(plr)
		return
	end

	local char = plr.Character
	if not char or not char:FindFirstChildOfClass("Humanoid") then return end

	local myChar = lp.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	if myRoot then
		local tRoot = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
		if tRoot and (myRoot.Position - tRoot.Position).Magnitude > cfg.espRange then
			destroyESP(plr)
			return
		end
	end

	local data = espCache[plr]
	if data and data.highlight then
		if data.highlight.Adornee ~= char then
			data.highlight.Adornee = char
		end
		local col = espColorFor(plr)
		data.highlight.FillColor = col
		data.highlight.OutlineColor = col
		return
	end

	local hl = Instance.new("Highlight")
	hl.Name = "RivalsRagerESP"
	hl.FillTransparency = 0.5
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Adornee = char
	hl.Parent = (gethui and gethui()) or game:GetService("CoreGui")

	local col = espColorFor(plr)
	hl.FillColor = col
	hl.OutlineColor = col

	local entry = { highlight = hl }

	if cfg.espTracers and hasDrawing then
		local line = Drawing.new("Line")
		line.Thickness = 1.5
		line.Transparency = 1
		line.Visible = false
		line.Color = col
		entry.tracer = line
	end

	if cfg.espHealthBars and hasDrawing then
		local bg = Drawing.new("Line")
		bg.Thickness = 3
		bg.Color = Color3.fromRGB(180, 40, 40)
		bg.Transparency = 1
		bg.Visible = false

		local fill = Drawing.new("Line")
		fill.Thickness = 3
		fill.Color = Color3.fromRGB(40, 220, 40)
		fill.Transparency = 1
		fill.Visible = false

		entry.hpBg = bg
		entry.hpFill = fill
	end

	espCache[plr] = entry
end

local function refreshESP()
	if state.unloaded then return end
	if not cfg.espEnabled then
		for plr in pairs(espCache) do destroyESP(plr) end
		return
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		buildESP(plr)
	end
end

local function shouldSkip(plr)
	if plr == lp then return true end
	if cfg.espTeamCheck and sameTeam(lp, plr) then return true end
	local char = plr.Character
	if not char then return true end
	local myRoot = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	local tRoot = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
	if myRoot and tRoot then
		if (myRoot.Position - tRoot.Position).Magnitude > cfg.espRange then
			return true
		end
	end
	return false
end

local function updateTracers()
	if state.unloaded then return end
	if not (cfg.espEnabled and cfg.espTracers and hasDrawing) then
		for _, data in pairs(espCache) do
			if data.tracer then data.tracer.Visible = false end
		end
		return
	end

	local vp = camera.ViewportSize
	local startX = vp.X / 2
	local startY = vp.Y

	for plr, data in pairs(espCache) do
		local tracer = data.tracer
		if tracer then
			if shouldSkip(plr) then
				tracer.Visible = false
			else
				local char = plr.Character
				local targetPart = char and (char:FindFirstChild("HumanoidRootPart")
					or char:FindFirstChild("Head")
					or char:FindFirstChildWhichIsA("BasePart"))
				if not targetPart then
					tracer.Visible = false
				else
					local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
					if onScreen then
						tracer.From = Vector2.new(startX, startY)
						tracer.To = Vector2.new(screenPos.X, screenPos.Y)
						tracer.Color = espColorFor(plr)
						tracer.Visible = true
					else
						tracer.Visible = false
					end
				end
			end
		end
	end
end

local function updateHealthBars()
	if state.unloaded then return end
	if not (cfg.espEnabled and cfg.espHealthBars and hasDrawing) then
		for _, data in pairs(espCache) do
			if data.hpBg then data.hpBg.Visible = false end
			if data.hpFill then data.hpFill.Visible = false end
		end
		return
	end

	for plr, data in pairs(espCache) do
		if data.hpBg and data.hpFill then
			local skip = shouldSkip(plr)
			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head"))
			if not (hum and root and hum.Health > 0) then skip = true end

			if skip then
				data.hpBg.Visible = false
				data.hpFill.Visible = false
			else
				local screenPos, onScreen = camera:WorldToViewportPoint(root.Position)
				if onScreen then
					local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
					local barHeight = 26
					local barX = screenPos.X - 28
					local yTop = screenPos.Y - barHeight / 2
					local yBottom = yTop + barHeight
					local ySplit = yBottom - barHeight * pct

					data.hpBg.From = Vector2.new(barX, yTop)
					data.hpBg.To = Vector2.new(barX, yBottom)
					data.hpBg.Visible = true

					if pct > 0 then
						data.hpFill.From = Vector2.new(barX, ySplit)
						data.hpFill.To = Vector2.new(barX, yBottom)
						data.hpFill.Visible = true
					else
						data.hpFill.Visible = false
					end
				else
					data.hpBg.Visible = false
					data.hpFill.Visible = false
				end
			end
		end
	end
end

local function wirePlayer(plr)
	if plr == lp then return end
	plr.CharacterAdded:Connect(function()
		if cfg.espEnabled then
			task.defer(function() buildESP(plr) end)
		end
	end)
	plr.CharacterRemoving:Connect(function() destroyESP(plr) end)
end

for _, plr in ipairs(Players:GetPlayers()) do wirePlayer(plr) end
Players.PlayerAdded:Connect(wirePlayer)
Players.PlayerRemoving:Connect(function(plr) destroyESP(plr) end)

RunService.RenderStepped:Connect(function()
	if state.unloaded then return end
	updateTracers()
	updateHealthBars()
end)

RunService.Heartbeat:Connect(function()
	if state.unloaded or not cfg.espEnabled then return end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= lp then buildESP(plr) end
	end
end)

-- ============================================================
-- RAGEBOT
-- ============================================================
local rageCache = {
	target = nil,
	orbitAngle = 0,
	randomMode = "Orbit",
	randomTimer = 0,
	holdKeyDown = false,
	savedCFrame = nil,
	savedVelocity = nil,
}

local RANDOM_MODES = { "Orbit", "Above", "Behind", "Front" }
local RANDOM_INTERVAL = 0.1

local function isRageActive()
	if cfg.rageActivation == "Normal" then
		return cfg.rageEnabled
	else
		return rageCache.holdKeyDown
	end
end

local function findRageTarget()
	local myChar = lp.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	if not myRoot then return nil end

	local best, bestDist = nil, math.huge
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= lp then
			if not sameTeam(lp, plr) then
				local char = plr.Character
				if char then
					local hum = char:FindFirstChildOfClass("Humanoid")
					local head = char:FindFirstChild("Head")
					if hum and hum.Health > 0 and head then
						local d = (head.Position - myRoot.Position).Magnitude
						if d <= cfg.rageMaxDist and d < bestDist then
							bestDist = d
							best = char
						end
					end
				end
			end
		end
	end
	return best
end

local function savePosition()
	local char = lp.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		rageCache.savedCFrame = hrp.CFrame
		rageCache.savedVelocity = hrp.Velocity
	end
end

local function restorePosition()
	local char = lp.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and rageCache.savedCFrame then
		hrp.CFrame = rageCache.savedCFrame
		hrp.Velocity = rageCache.savedVelocity or Vector3.new(0, 0, 0)
	end
	rageCache.savedCFrame = nil
	rageCache.savedVelocity = nil
end

local function resetRageCamera()
	rageCache.target = nil
	rageCache.orbitAngle = 0
	rageCache.randomTimer = 0
	pcall(function()
		camera.CameraType = Enum.CameraType.Custom
		local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
		if hum then camera.CameraSubject = hum end
	end)
end

local function rageStep(dt)
	if state.unloaded then return end

	local active = isRageActive()

	if not active then
		if rageCache.target then
			rageCache.target = nil
			restorePosition()
			resetRageCamera()
		end
		return
	end

	if not rageCache.target and not rageCache.savedCFrame then
		savePosition()
	end

	local target = findRageTarget()
	rageCache.target = target
	if not target then return end

	local head = target:FindFirstChild("Head")
	if not head then return end

	local myChar = lp.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	if not myRoot then return end

	local headPos = head.Position
	local dist = math.clamp(cfg.orbitDistance, 1, 30)

	local activeMode = cfg.rageMode
	if activeMode == "Random" then
		rageCache.randomTimer = rageCache.randomTimer + dt
		if rageCache.randomTimer >= RANDOM_INTERVAL then
			rageCache.randomTimer = 0
			rageCache.randomMode = RANDOM_MODES[math.random(1, #RANDOM_MODES)]
		end
		activeMode = rageCache.randomMode
	end

	local desired

	if activeMode == "Orbit" then
		rageCache.orbitAngle = (rageCache.orbitAngle + dt * cfg.orbitSpeed * 2) % (math.pi * 2)
		local offset = Vector3.new(
			math.cos(rageCache.orbitAngle) * dist,
			dist * 0.5,
			math.sin(rageCache.orbitAngle) * dist
		)
		desired = headPos + offset
		myRoot.CFrame = CFrame.lookAt(desired, headPos)
		myRoot.Velocity = Vector3.new(0, 0, 0)

	elseif activeMode == "Behind" then
		local targetCFrame = target:GetPivot()
		local behindDir = targetCFrame.LookVector
		desired = headPos - behindDir * dist + Vector3.new(0, dist * 0.5, 0)
		myRoot.CFrame = CFrame.lookAt(desired, headPos)
		myRoot.Velocity = Vector3.new(0, 0, 0)

	elseif activeMode == "Front" then
		local targetCFrame = target:GetPivot()
		local frontDir = targetCFrame.LookVector
		desired = headPos + frontDir * dist + Vector3.new(0, dist * 0.5, 0)
		myRoot.CFrame = CFrame.lookAt(desired, headPos)
		myRoot.Velocity = Vector3.new(0, 0, 0)

	else -- Above
		desired = Vector3.new(headPos.X, headPos.Y + dist, headPos.Z)
		myRoot.CFrame = CFrame.lookAt(desired, headPos)
		myRoot.Velocity = Vector3.new(0, 0, 0)
	end

	local camPos = desired + Vector3.new(0, 2, 0)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(camPos, headPos)
	camera.Focus = CFrame.new(headPos)

	local screenPos, onScreen = camera:WorldToViewportPoint(headPos)
	if onScreen then
		local vp = camera.ViewportSize
		local dx = screenPos.X - vp.X / 2
		local dy = screenPos.Y - vp.Y / 2
		pcall(function() mousemoverel(dx, dy) end)
	end
end

local RAGE_BIND = "RivalsRagerStep"
pcall(function() RunService:UnbindFromRenderStep(RAGE_BIND) end)
RunService:BindToRenderStep(RAGE_BIND, Enum.RenderPriority.Camera.Value + 2, rageStep)

-- ============================================================
-- HOLD KEY / BUTTON INPUT
-- ============================================================
UserInputService.InputBegan:Connect(function(input, processed)
	if state.unloaded then return end
	if cfg.rageActivation ~= "Hold Key" then return end
	if inputMatches(input, cfg.rageHoldKey) then
		rageCache.holdKeyDown = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if state.unloaded then return end
	if inputMatches(input, cfg.rageHoldKey) then
		rageCache.holdKeyDown = false
	end
end)

-- ============================================================
-- GUI
-- ============================================================
local COL_BG       = Color3.fromRGB(20, 20, 20)
local COL_HEADER   = Color3.fromRGB(35, 35, 35)
local COL_BTN      = Color3.fromRGB(45, 45, 45)
local COL_BTN_ON   = Color3.fromRGB(200, 90, 0)
local COL_TEXT     = Color3.fromRGB(230, 230, 230)
local COL_ACCENT   = Color3.fromRGB(200, 90, 0)
local COL_TRACK    = Color3.fromRGB(50, 50, 50)
local FONT         = Enum.Font.Gotham
local FONT_B       = Enum.Font.GothamBold

local gui = Instance.new("ScreenGui")
gui.Name = "RivalsRagerV3"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = (gethui and gethui()) or lp:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 260, 0, 0)
main.AutomaticSize = Enum.AutomaticSize.Y
main.Position = UDim2.new(0, cfg.menuPosX, cfg.menuPosY, 0)
main.BackgroundColor3 = COL_BG
main.BorderSizePixel = 0
main.Active = false
main.Visible = state.menuOpen
main.Parent = gui

local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, 0, 0, 18)
header.BackgroundColor3 = COL_HEADER
header.BorderSizePixel = 0
header.Text = " RIVALS RAGER V3  [RShift]"
header.TextColor3 = COL_TEXT
header.Font = FONT_B
header.TextSize = 11
header.TextXAlignment = Enum.TextXAlignment.Left
header.Active = true
header.Parent = main

local list = Instance.new("Frame")
list.Size = UDim2.new(1, 0, 0, 0)
list.AutomaticSize = Enum.AutomaticSize.Y
list.Position = UDim2.new(0, 0, 0, 18)
list.BackgroundTransparency = 1
list.Parent = main

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 3)
layout.Parent = list

local pad = Instance.new("UIPadding")
pad.PaddingLeft   = UDim.new(0, 4)
pad.PaddingRight  = UDim.new(0, 4)
pad.PaddingTop    = UDim.new(0, 4)
pad.PaddingBottom = UDim.new(0, 5)
pad.Parent = list

-- Top-bar drag
do
	local dragging = false
	local dragStart, startPos

	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = main.Position
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			main.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			if dragging then
				dragging = false
				cfg.menuPosX = main.Position.X.Offset
				cfg.menuPosY = main.Position.Y.Scale
				saveConfig()
			end
		end
	end)
end

-- ============================================================
-- STATUS HUD
-- ============================================================
local hud = Instance.new("TextLabel")
hud.Size = UDim2.new(0, 560, 0, 18)
hud.AnchorPoint = Vector2.new(0.5, 1)
hud.Position = UDim2.new(0.5, 0, 1, -8)
hud.BackgroundColor3 = COL_BG
hud.BackgroundTransparency = 0.3
hud.BorderSizePixel = 0
hud.TextColor3 = COL_TEXT
hud.Font = FONT
hud.TextSize = 11
hud.TextXAlignment = Enum.TextXAlignment.Center
hud.Text = ""
hud.ZIndex = 10
hud.Parent = gui

local fpsCounter = 0
local fpsLast = tick()
local fps = 0

-- ============================================================
-- WIDGETS
-- ============================================================
local BTN_H = 16
local SLIDER_H = 22
local widgets = {}

local function refreshAll()
	for _, f in ipairs(widgets) do pcall(f) end
end

local function makeLabel(text)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, 12)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = COL_ACCENT
	l.TextSize = 10
	l.Font = FONT_B
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = list
	return l
end

local function makeToggle(label, getState, setState)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, BTN_H)
	btn.BackgroundColor3 = COL_BTN
	btn.BorderSizePixel = 0
	btn.TextColor3 = COL_TEXT
	btn.Font = FONT
	btn.TextSize = 10
	btn.AutoButtonColor = false
	btn.Parent = list

	local function refresh()
		local on = getState()
		btn.Text = label .. ": " .. (on and "ON" or "OFF")
		btn.BackgroundColor3 = on and COL_BTN_ON or COL_BTN
	end
	refresh()
	table.insert(widgets, refresh)

	btn.MouseButton1Click:Connect(function()
		setState(not getState())
		refreshAll()
		saveConfig()
	end)

	return btn
end

local function makeSlider(label, getVal, setVal, minV, maxV, step, isInt, suffix)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1, 0, 0, SLIDER_H)
	holder.BackgroundTransparency = 1
	holder.Parent = list

	local top = Instance.new("TextLabel")
	top.Size = UDim2.new(1, 0, 0, 12)
	top.BackgroundTransparency = 1
	top.TextColor3 = COL_TEXT
	top.Font = FONT
	top.TextSize = 10
	top.TextXAlignment = Enum.TextXAlignment.Left
	top.Parent = holder

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0, 6)
	bar.Position = UDim2.new(0, 0, 0, 14)
	bar.BackgroundColor3 = COL_TRACK
	bar.BorderSizePixel = 0
	bar.Parent = holder

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = COL_ACCENT
	fill.BorderSizePixel = 0
	fill.Parent = bar

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 8, 0, 10)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.BorderSizePixel = 0
	knob.Parent = bar

	local function refresh()
		local v = getVal()
		local t = math.clamp((v - minV) / (maxV - minV), 0, 1)
		fill.Size = UDim2.new(t, 0, 1, 0)
		knob.Position = UDim2.new(t, 0, 0.5, 0)
		top.Text = label .. ": " .. tostring(v) .. (suffix or "")
	end
	refresh()
	table.insert(widgets, refresh)

	local dragging = false

	local function move(x)
		local ratio = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		local raw = minV + (maxV - minV) * ratio
		if isInt then raw = math.floor(raw + 0.5) end
		if step and step > 0 then
			raw = math.floor(raw / step + 0.5) * step
			if isInt then raw = math.floor(raw) end
		end
		raw = math.clamp(raw, minV, maxV)
		setVal(raw)
		refresh()
	end

	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			move(input.Position.X)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch) then
			move(input.Position.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			if dragging then
				dragging = false
				saveConfig()
			end
		end
	end)

	return { refresh = refresh }
end

local function makeCycle(label, options, getVal, setVal)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, BTN_H)
	btn.BackgroundColor3 = COL_BTN
	btn.BorderSizePixel = 0
	btn.TextColor3 = COL_TEXT
	btn.Font = FONT
	btn.TextSize = 10
	btn.AutoButtonColor = false
	btn.Parent = list

	local function refresh()
		btn.Text = label .. ": " .. tostring(getVal())
		btn.BackgroundColor3 = COL_BTN
	end
	refresh()
	table.insert(widgets, refresh)

	btn.MouseButton1Click:Connect(function()
		local cur = getVal()
		local idx = 1
		for i, o in ipairs(options) do
			if o == cur then idx = i break end
		end
		idx = idx + 1
		if idx > #options then idx = 1 end
		setVal(options[idx])
		rageCache.randomTimer = 0
		rageCache.orbitAngle = 0
		refreshAll()
		saveConfig()
	end)

	return btn
end

local listeningFor = nil

local function makeBind(label, getBind, setBind)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, BTN_H)
	row.BackgroundTransparency = 1
	row.Parent = list

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.5, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = label
	lbl.TextColor3 = COL_TEXT
	lbl.Font = FONT
	lbl.TextSize = 10
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = row

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.5, 0, 1, 0)
	btn.Position = UDim2.new(0.5, 0, 0, 0)
	btn.BackgroundColor3 = COL_BTN
	btn.BorderSizePixel = 0
	btn.TextColor3 = COL_TEXT
	btn.Font = FONT_B
	btn.TextSize = 10
	btn.AutoButtonColor = false
	btn.Parent = row

	local function refresh()
		if listeningFor == label then
			btn.Text = "..."
			btn.BackgroundColor3 = COL_ACCENT
		else
			btn.Text = bindLabel(getBind())
			btn.BackgroundColor3 = COL_BTN
		end
	end
	refresh()
	table.insert(widgets, refresh)

	btn.MouseButton1Click:Connect(function()
		if listeningFor == label then
			listeningFor = nil
		else
			listeningFor = label
		end
		refreshAll()
	end)

	return { refresh = refresh }
end

-- ============================================================
-- BUILD MENU
-- ============================================================
makeLabel("Toggles")
makeToggle("Ragebot", function() return cfg.rageEnabled end, function(v)
	cfg.rageEnabled = v
	if not v then
		restorePosition()
		resetRageCamera()
	end
end)
makeToggle("ESP", function() return cfg.espEnabled end, function(v)
	cfg.espEnabled = v
	refreshESP()
end)
makeToggle("ESP Tracers", function() return cfg.espTracers end, function(v)
	cfg.espTracers = v
end)
makeToggle("ESP Health Bars", function() return cfg.espHealthBars end, function(v)
	cfg.espHealthBars = v
end)
makeToggle("ESP Team Check", function() return cfg.espTeamCheck end, function(v)
	cfg.espTeamCheck = v
	refreshESP()
end)

makeLabel("Rage Activation")
makeCycle("Trigger", { "Normal", "Hold Key" },
	function() return cfg.rageActivation end,
	function(v) cfg.rageActivation = v end)

makeLabel("Rage Mode")
makeCycle("Mode", { "Orbit", "Behind", "Front", "Above", "Random" },
	function() return cfg.rageMode end,
	function(v) cfg.rageMode = v end)

makeLabel("Rage Settings")
makeSlider("Distance",     function() return cfg.rageMaxDist end,   function(v) cfg.rageMaxDist = v end,   100, MAX_DIST, 50, true, " studs")
makeSlider("Spin Speed",   function() return cfg.orbitSpeed end,    function(v) cfg.orbitSpeed = v end,     1, 30,       1, true, "x")
makeSlider("Orbit Radius", function() return cfg.orbitDistance end, function(v) cfg.orbitDistance = v end, 1, 30,       1, true, " studs")

makeLabel("ESP Settings")
makeSlider("ESP Range",    function() return cfg.espRange end,      function(v) cfg.espRange = v end,      100, MAX_DIST, 50, true, " studs")

makeLabel("Hotkeys")
makeBind("Ragebot Key",   function() return cfg.rageKey     end, function(b) cfg.rageKey     = b end)
makeBind("Rage Mode Key", function() return cfg.rageModeKey end, function(b) cfg.rageModeKey = b end)
makeBind("Hold Key",      function() return cfg.rageHoldKey end, function(b) cfg.rageHoldKey = b end)
makeBind("ESP Key",       function() return cfg.espKey      end, function(b) cfg.espKey      = b end)

local unloadBtn = Instance.new("TextButton")
unloadBtn.Size = UDim2.new(1, 0, 0, 18)
unloadBtn.BackgroundColor3 = Color3.fromRGB(150, 30, 30)
unloadBtn.BorderSizePixel = 0
unloadBtn.Text = "Unload (click twice)"
unloadBtn.TextColor3 = Color3.fromRGB(255, 220, 220)
unloadBtn.Font = FONT_B
unloadBtn.TextSize = 10
unloadBtn.AutoButtonColor = false
unloadBtn.Parent = list

local unloadArmed = false
local unloadDeadline = 0
local unloadConn = nil

local function fullUnload()
	if state.unloaded then return end
	state.unloaded = true
	cfg.rageEnabled = false
	cfg.espEnabled = false
	restorePosition()
	resetRageCamera()
	for plr in pairs(espCache) do destroyESP(plr) end
	pcall(function() RunService:UnbindFromRenderStep(RAGE_BIND) end)
	pcall(function() gui:Destroy() end)
end

unloadBtn.MouseButton1Click:Connect(function()
	if not unloadArmed then
		unloadArmed = true
		unloadDeadline = tick() + 0.5
		unloadBtn.Text = "Confirm unload (0.5s)"
		unloadBtn.BackgroundColor3 = Color3.fromRGB(220, 40, 40)

		if unloadConn then unloadConn:Disconnect() end
		unloadConn = RunService.Heartbeat:Connect(function()
			if not unloadArmed then
				unloadConn:Disconnect()
				unloadConn = nil
				return
			end
			local remaining = unloadDeadline - tick()
			if remaining <= 0 then
				unloadArmed = false
				unloadBtn.Text = "Unload (click twice)"
				unloadBtn.BackgroundColor3 = Color3.fromRGB(150, 30, 30)
				unloadConn:Disconnect()
				unloadConn = nil
			else
				unloadBtn.Text = string.format("Confirm unload (%.1fs)", remaining)
			end
		end)
	else
		unloadArmed = false
		if unloadConn then unloadConn:Disconnect() unloadConn = nil end
		fullUnload()
	end
end)

-- ============================================================
-- GLOBAL HOTKEYS
-- ============================================================
UserInputService.InputBegan:Connect(function(input, processed)
	if state.unloaded then return end

	if listeningFor then
		-- Always allow Escape via keyboard to cancel
		if input.UserInputType == Enum.UserInputType.Keyboard
		and input.KeyCode == Enum.KeyCode.Escape then
			listeningFor = nil
			refreshAll()
			return
		end

		local bind = bindFromInput(input)
		if bind then
			if listeningFor == "Ragebot Key" then
				cfg.rageKey = bind
				listeningFor = nil
			elseif listeningFor == "Rage Mode Key" then
				cfg.rageModeKey = bind
				listeningFor = nil
			elseif listeningFor == "Hold Key" then
				cfg.rageHoldKey = bind
				listeningFor = nil
			elseif listeningFor == "ESP Key" then
				cfg.espKey = bind
				listeningFor = nil
			end
			refreshAll()
			saveConfig()
		end
		return
	end

	if processed then return end

	-- RightShift toggles menu (always keyboard)
	if input.UserInputType == Enum.UserInputType.Keyboard
	and input.KeyCode == Enum.KeyCode.RightShift then
		state.menuOpen = not state.menuOpen
		main.Visible = state.menuOpen
		return
	end

	-- Ragebot toggle (Normal mode only)
	if cfg.rageActivation == "Normal" and inputMatches(input, cfg.rageKey) then
		cfg.rageEnabled = not cfg.rageEnabled
		if not cfg.rageEnabled then
			restorePosition()
			resetRageCamera()
		end
		refreshAll()
		saveConfig()
		return
	end

	-- Rage mode cycle
	if inputMatches(input, cfg.rageModeKey) then
		local modes = { "Orbit", "Behind", "Front", "Above", "Random" }
		local idx = 1
		for i, m in ipairs(modes) do
			if m == cfg.rageMode then idx = i break end
		end
		idx = idx + 1
		if idx > #modes then idx = 1 end
		cfg.rageMode = modes[idx]
		rageCache.randomTimer = 0
		rageCache.orbitAngle = 0
		refreshAll()
		saveConfig()
		return
	end

	-- ESP toggle
	if inputMatches(input, cfg.espKey) then
		cfg.espEnabled = not cfg.espEnabled
		refreshESP()
		refreshAll()
		saveConfig()
		return
	end
end)

-- ============================================================
-- FPS COUNTER + HUD UPDATE
-- ============================================================
RunService.RenderStepped:Connect(function()
	fpsCounter = fpsCounter + 1
	local now = tick()
	if now - fpsLast >= 1 then
		fps = fpsCounter
		fpsCounter = 0
		fpsLast = now
	end
end)

task.spawn(function()
	while not state.unloaded do
		local activeTxt
		if cfg.rageActivation == "Normal" then
			activeTxt = cfg.rageEnabled and "On" or "Off"
		else
			activeTxt = rageCache.holdKeyDown and "Active" or "Idle"
		end

		local tgtTxt = "Target: None"
		if rageCache.target then
			local plr = Players:GetPlayerFromCharacter(rageCache.target)
			if plr then tgtTxt = "Target: " .. plr.Name end
		end

		hud.Text = string.format(
			"Rage: %s   Mode: %s   %s   Esp: %s   Fps: %d",
			activeTxt,
			cfg.rageMode,
			tgtTxt,
			cfg.espEnabled and "On" or "Off",
			fps
		)
		task.wait(0.1)
	end
end)

refreshAll()

print("[Rivals Rager v3] Loaded | Rage: " .. bindLabel(cfg.rageKey) .. " | Mode Key: " .. bindLabel(cfg.rageModeKey) .. " | Hold: " .. bindLabel(cfg.rageHoldKey) .. " | ESP: " .. bindLabel(cfg.espKey) .. " | Menu: RightShift")