--!nocheck
-- ============================================================
-- Aero — v7 (Image Perfect UI + Silent Aim + NPC Support)
-- ============================================================

print("[Aero] booting...")

local Svc = {}
do
    local function s(name) local ok, v = pcall(game.GetService, game, name); if ok then return v end end
    Svc.Players  = s("Players")
    Svc.RS       = s("RunService")
    Svc.UIS      = s("UserInputService")
    Svc.TS       = s("TweenService")
    Svc.WS       = s("Workspace")
    Svc.HS       = s("HttpService")
    Svc.GuiSvc   = s("GuiService")
    Svc.SS       = s("SoundService")
end

if not (Svc.Players and Svc.RS and Svc.UIS and Svc.TS and Svc.WS) then
    warn("[Aero] core services unavailable, aborting"); return
end

local LP = Svc.Players.LocalPlayer
if not LP then warn("[Aero] no LocalPlayer"); return end

local PG
do
    local ok, v = pcall(function() return LP:WaitForChild("PlayerGui", 20) end)
    if ok and v then PG = v end
    if not PG then PG = LP:FindFirstChild("PlayerGui") end
end
if not PG then warn("[Aero] no PlayerGui"); return end

local GuiParent = PG
if type(gethui) == "function" then
    local ok, v = pcall(gethui)
    if ok and v and v ~= game:GetService("CoreGui") then GuiParent = v end
end

local Camera = Svc.WS.CurrentCamera
local unpack = unpack or table.unpack

for _, parent in ipairs({PG, GuiParent}) do
    for _, n in ipairs({"AeroUI","AeroFOV","AeroESP","AeroHUD","AeroOverlay","AeroSAFOV"}) do
        local p = parent:FindFirstChild(n)
        if p then pcall(function() p:Destroy() end) end
    end
end

local St, RB, SA, ESP, MOV

local SETTINGS_FILE  = "AeroSettings.json"
local RAGE_ABOVE_DISTANCE = 4
local RAGE_MAX_DISTANCE   = 750

local cachedInset = nil
local cachedInsetTime = 0
local function getGuiInset()
    local now = tick()
    if cachedInset and (now - cachedInsetTime) < 5 then return cachedInset end
    cachedInsetTime = now
    if not Svc.GuiSvc then cachedInset = Vector2.zero; return cachedInset end
    local ok, ins = pcall(function() return Svc.GuiSvc:GetGuiInset() end)
    if ok and ins then cachedInset = ins else cachedInset = Vector2.zero end
    return cachedInset
end

local THEMES = {
    Purple = { bg=Color3.fromRGB(16,16,22), sb=Color3.fromRGB(20,20,28), pn=Color3.fromRGB(24,24,34),
               hov=Color3.fromRGB(36,28,54), st=Color3.fromRGB(60,44,90), txt=Color3.fromRGB(240,235,250),
               dim=Color3.fromRGB(160,150,185), acc=Color3.fromRGB(160,80,255), off=Color3.fromRGB(56,44,80),
               trk=Color3.fromRGB(60,44,90) },
    Blue   = { bg=Color3.fromRGB(14,20,28), sb=Color3.fromRGB(18,26,36), pn=Color3.fromRGB(22,32,46),
               hov=Color3.fromRGB(26,42,64), st=Color3.fromRGB(40,64,96), txt=Color3.fromRGB(230,240,255),
               dim=Color3.fromRGB(140,165,200), acc=Color3.fromRGB(40,165,255), off=Color3.fromRGB(40,58,84),
               trk=Color3.fromRGB(40,64,96) },
}

local Settings = {
    Aimbot = { Enabled=false, WallCheck=true, TeamCheck=true, DeadCheck=true,
        SpawnProtCheck=true, TargetNPCs=true,
        AimPart="Head",
        MaxDistance=500,
        ShowFOV=true, FOVSize=120, FOVColor=Color3.fromRGB(120,90,240), FOVTransparency=0.6 },
    SilentAim = { Enabled=false, Method="Viewport", Bodypart="Head",
        StickyAim=true, NoDelay=true, Hitsound=false,
        ShowFOV=true, FOVSize=150, FOVColor=Color3.fromRGB(255, 0, 0),
        TargetNPCs=true },
    Players = { Enabled=false, Chams=false, ShowName=true,
        ShowHealth=true, ShowDistance=true,
        TeamCheck=true, ShowTeam=true, Range=800,
        ShowNPCs=true,
        EnemyColor=Color3.fromRGB(255,60,60), TeammateColor=Color3.fromRGB(60,220,120) },
    Movement = { Fly=false, FlySpeed=60, Noclip=false },
    Ragebot  = { Enabled=false },
    UI       = { Theme="Purple", LastPage="Silent Aim", Position=nil },
}

local uiToggleRefs = {}
local PF = { onSaveStatus = nil }

-- Serialization
function PF.serializeVal(v)
    local ty = typeof(v)
    if ty == "Color3" then return { __t = "Color3", r = v.R, g = v.G, b = v.B } end
    if ty == "EnumItem" then return { __t = "EnumItem", e = tostring(v.EnumType):match("^Enum%.(.+)$") or "", n = v.Name } end
    if type(v) == "table" then
        local o = {}; for k, val in pairs(v) do o[k] = PF.serializeVal(val) end; return o
    end
    return v
end

function PF.deserializeVal(v)
    if type(v) ~= "table" then return v end
    if v.__t == "Color3" then return Color3.new(v.r, v.g, v.b) end
    if v.__t == "EnumItem" then
        local ok, et = pcall(function() return Enum[v.e] end)
        if ok and et then local ok2, item = pcall(function() return et[v.n] end); if ok2 then return item end end
        return nil
    end
    local o = {}; for k, val in pairs(v) do local dv = PF.deserializeVal(val); if dv ~= nil then o[k] = dv end end; return o
end

function PF.merge(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" and type(dst[k]) == "table" then PF.merge(dst[k], v) else dst[k] = v end
    end
end

function PF.saveSettingsNow()
    if type(writefile) ~= "function" or not Svc.HS then return false end
    local okWrite = pcall(writefile, SETTINGS_FILE, Svc.HS:JSONEncode({ Settings = PF.serializeVal(Settings) }))
    if PF.onSaveStatus then pcall(PF.onSaveStatus, okWrite) end
end

function PF.loadAutoSettings()
    if type(readfile) ~= "function" or not Svc.HS then return false end
    local ok, data = pcall(readfile, SETTINGS_FILE)
    if not ok or not data then return false end
    local okDec, decoded = pcall(function() return Svc.HS:JSONDecode(data) end)
    if okDec and type(decoded) == "table" and decoded.Settings then
        PF.merge(Settings, PF.deserializeVal(decoded.Settings))
    end
end

-- UI Library
local T = THEMES.Purple
local Font, FontMed, FontBold = Enum.Font.Gotham, Enum.Font.GothamMedium, Enum.Font.GothamBold

local H = {}
function H.new(class, props, children)
    local i = Instance.new(class)
    for k, v in pairs(props or {}) do i[k] = v end
    for _, c in ipairs(children or {}) do c.Parent = i end
    return i
end
function H.corner(r, p) return H.new("UICorner", {CornerRadius=UDim.new(0,r), Parent=p}) end
function H.stroke(c,t,p) return H.new("UIStroke", {Color=c, Thickness=t, ApplyStrokeMode=Enum.ApplyStrokeMode.Border, Parent=p}) end
function H.pad(t,b,l,r,p) return H.new("UIPadding", {PaddingTop=UDim.new(0,t), PaddingBottom=UDim.new(0,b), PaddingLeft=UDim.new(0,l), PaddingRight=UDim.new(0,r), Parent=p}) end
function H.clamp(v,lo,hi) return math.max(lo, math.min(hi, v)) end

local OverlayGui = H.new("ScreenGui", { Name="AeroOverlay", ResetOnSpawn=false, IgnoreGuiInset=true, DisplayOrder=999999, Parent=GuiParent })
local openLists = {}
function H.closeAllDropdowns() for i = #openLists, 1, -1 do pcall(openLists[i].close) end; openLists = {} end

local Wg = {}

function Wg.makeToggle(parent, order, opts)
    local value = opts.default == true
    local row = H.new("Frame", { Size=UDim2.new(1,0,0,28), BackgroundTransparency=1, LayoutOrder=order, Parent=parent })
    local lbl = H.new("TextLabel", { Text=opts.name, Font=FontBold, TextSize=13, TextColor3=T.txt, BackgroundTransparency=1, Size=UDim2.new(1,-32,1,0), TextXAlignment=Enum.TextXAlignment.Left, Parent=row })
    local box = H.new("Frame", { AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,0,0.5,0), Size=UDim2.fromOffset(24,24), BackgroundColor3=value and T.acc or T.off, BorderSizePixel=0, Parent=row })
    H.corner(12, box)
    local inner = H.new("Frame", { AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5), Size=UDim2.fromOffset(value and 14 or 10, value and 14 or 10), BackgroundColor3=Color3.new(1,1,1), BackgroundTransparency=value and 0 or 0.4, BorderSizePixel=0, Parent=box })
    H.corner(7, inner)
    
    local function apply(v)
        value = v
        Svc.TS:Create(box, TweenInfo.new(0.15), {BackgroundColor3=v and T.acc or T.off}):Play()
        Svc.TS:Create(inner, TweenInfo.new(0.15), {Size=UDim2.fromOffset(v and 14 or 10, v and 14 or 10), BackgroundTransparency = v and 0 or 0.4}):Play()
        if opts.callback then opts.callback(v) end
    end
    row.InputBegan:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 then apply(not value) end end)
    return apply
end

function Wg.makeSlider(parent, order, opts)
    local min, max, span = opts.min, opts.max, math.max(opts.max - opts.min, 1e-6)
    local value = opts.default or min
    local row = H.new("Frame", { Size=UDim2.new(1,0,0,44), BackgroundTransparency=1, LayoutOrder=order, Parent=parent })
    H.new("TextLabel", { Text=opts.name, Font=FontBold, TextSize=13, TextColor3=T.txt, BackgroundTransparency=1, Size=UDim2.new(1,0,0,16), TextXAlignment=Enum.TextXAlignment.Left, Parent=row })
    
    local trackHit = H.new("TextButton", { Text="", AutoButtonColor=false, BackgroundTransparency=1, Position=UDim2.fromOffset(0,20), Size=UDim2.new(1,-40,0,20), Parent=row })
    local trackBg = H.new("Frame", { AnchorPoint=Vector2.new(0,0.5), Position=UDim2.new(0,0,0.5,0), Size=UDim2.new(1,0,0,16), BackgroundColor3=T.sb, BorderSizePixel=0, Parent=trackHit })
    H.corner(4, trackBg); H.stroke(T.st, 1, trackBg)
    local fill = H.new("Frame", { Size=UDim2.fromScale((value-min)/span,1), BackgroundColor3=T.acc, BorderSizePixel=0, Parent=trackBg })
    H.corner(4, fill)
    
    local valLbl = H.new("TextLabel", { Text=math.floor(value), Font=FontBold, TextSize=13, TextColor3=T.txt, BackgroundTransparency=1, AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,0,0.5,0), Size=UDim2.fromOffset(36,16), TextXAlignment=Enum.TextXAlignment.Right, Parent=row })
    
    local btnMinus = H.new("TextLabel", { Text="-", Font=FontBold, TextSize=14, TextColor3=T.txt, BackgroundColor3=T.sb, AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,-18,0,20), Size=UDim2.fromOffset(16,20), TextXAlignment=Enum.TextXAlignment.Center, Parent=row })
    H.corner(4, btnMinus)
    local btnPlus = H.new("TextLabel", { Text="+", Font=FontBold, TextSize=14, TextColor3=T.txt, BackgroundColor3=T.sb, AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,20), Size=UDim2.fromOffset(16,20), TextXAlignment=Enum.TextXAlignment.Center, Parent=row })
    H.corner(4, btnPlus)

    local dragging = false
    local function update()
        local pos = (value - min) / span
        fill.Size = UDim2.fromScale(pos, 1)
        valLbl.Text = math.floor(value)
        if opts.callback then opts.callback(value) end
    end
    local function setFromX(x)
        local p = H.clamp((x - trackBg.AbsolutePosition.X) / math.max(trackBg.AbsoluteSize.X,1), 0, 1)
        value = min + p * (max - min)
        update()
    end
    trackHit.InputBegan:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; setFromX(inp.Position.X) end end)
    Svc.UIS.InputChanged:Connect(function(inp) if dragging then setFromX(inp.Position.X) end end)
    Svc.UIS.InputEnded:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
    
    btnMinus.InputBegan:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 then value = H.clamp(value - 5, min, max); update() end end)
    btnPlus.InputBegan:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 then value = H.clamp(value + 5, min, max); update() end end)
    return update
end

function Wg.makeDropdown(parent, order, opts)
    local value = opts.default or opts.options[1]
    local row = H.new("Frame", { Size=UDim2.new(1,0,0,48), BackgroundTransparency=1, LayoutOrder=order, Parent=parent })
    H.new("TextLabel", { Text=opts.name, Font=FontBold, TextSize=13, TextColor3=T.txt, BackgroundTransparency=1, Size=UDim2.new(1,0,0,18), TextXAlignment=Enum.TextXAlignment.Left, Parent=row })
    
    local box = H.new("TextButton", { Text="", AutoButtonColor=false, Position=UDim2.fromOffset(0,20), Size=UDim2.new(1,0,0,24), BackgroundColor3=T.sb, BorderSizePixel=0, Parent=row })
    H.corner(4, box); H.stroke(T.st,1,box)
    local lbl = H.new("TextLabel", { Text=tostring(value), Font=FontMed, TextSize=13, TextColor3=T.txt, BackgroundTransparency=1, Size=UDim2.new(1,-24,1,0), Position=UDim2.fromOffset(8,0), TextXAlignment=Enum.TextXAlignment.Left, Parent=box })
    H.new("TextLabel", { Text="+", Font=FontBold, TextSize=16, TextColor3=T.txt, BackgroundTransparency=1, AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,-8,0.5,0), Size=UDim2.fromOffset(12,16), Parent=box })
    
    local listFrame, closeToken = nil, 0
    local function closeList()
        if not listFrame then return end
        local f = listFrame; listFrame = nil; closeToken = closeToken + 1
        local token = closeToken
        for i = #openLists, 1, -1 do if openLists[i].frame == f then table.remove(openLists, i) end end
        Svc.TS:Create(f, TweenInfo.new(0.15), {Size=UDim2.fromOffset(f.AbsoluteSize.X, 0)}):Play()
        task.delay(0.15, function() if token == closeToken then f:Destroy() end end)
    end
    box.MouseButton1Click:Connect(function()
        if listFrame then closeList(); return end
        H.closeAllDropdowns()
        
        local rowH = 26
        local fullH = #opts.options * rowH + 8
        local boxAbs, boxSize = box.AbsolutePosition, box.AbsoluteSize
        local overlayAbs, overlaySize = OverlayGui.AbsolutePosition, OverlayGui.AbsoluteSize
        
        local listX = boxAbs.X - overlayAbs.X
        local listY = boxAbs.Y - overlayAbs.Y + boxSize.Y + 2
        if listY + fullH > overlaySize.Y then listY = boxAbs.Y - overlayAbs.Y - fullH - 2; if listY < 4 then listY = 4 end end
        
        listFrame = H.new("Frame", { BackgroundColor3=T.sb, BorderSizePixel=0, ZIndex=100, Position=UDim2.fromOffset(listX, listY), Size=UDim2.fromOffset(boxSize.X, 0), ClipsDescendants=true, Parent=OverlayGui })
        H.corner(4, listFrame); H.stroke(T.st,1,listFrame)
        local sl = H.new("ScrollingFrame", { Size=UDim2.fromScale(1,1), BackgroundTransparency=1, ScrollBarThickness=3, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y, ZIndex=101, Parent=listFrame })
        H.new("UIListLayout", {Padding=UDim.new(0,2), SortOrder=Enum.SortOrder.LayoutOrder, Parent=sl})
        H.pad(4,4,4,4, sl)
        
        for i, opt in ipairs(opts.options) do
            local r = H.new("TextButton", { Text=tostring(opt), Font=FontMed, TextSize=13, TextColor3=T.txt, AutoButtonColor=false, BackgroundColor3=(opt == value) and T.hov or T.pn, Size=UDim2.new(1,-4,0,rowH-2), LayoutOrder=i, ZIndex=102, Parent=sl })
            H.corner(4, r)
            r.MouseButton1Click:Connect(function()
                value = opt; lbl.Text = tostring(opt)
                if opts.callback then opts.callback(opt) end
                closeList()
            end)
        end
        Svc.TS:Create(listFrame, TweenInfo.new(0.18), {Size=UDim2.fromOffset(boxSize.X, fullH)}):Play()
        table.insert(openLists, { frame = listFrame, close = closeList })
    end)
end

-- Game Helpers
local G = {}
function G.getHeadPart(model)
    if not model then return nil end
    local direct = model:FindFirstChild("Head")
    if direct and direct:IsA("BasePart") then return direct end
    local best, bestY = nil, -math.huge
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") and p.Name:lower() == "head" then return p end
        if p:IsA("BasePart") and p.Position.Y > bestY then bestY = p.Position.Y; best = p end
    end
    return best
end
function G.getTorsoPart(model)
    for _, name in ipairs({"UpperTorso", "Torso", "Chest"}) do
        local p = model:FindFirstChild(name)
        if p and p:IsA("BasePart") then return p end
    end
    return G.getHeadPart(model)
end
function G.getRootPart(model)
    return model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
end
function G.getBodyPart(model, partName)
    if partName == "Head" then return G.getHeadPart(model) end
    if partName == "Torso" then return G.getTorsoPart(model) end
    if partName == "Left Arm" then return model:FindFirstChild("Left Arm") or model:FindFirstChild("LeftUpperArm") or model:FindFirstChild("LeftHand") end
    if partName == "Right Arm" then return model:FindFirstChild("Right Arm") or model:FindFirstChild("RightUpperArm") or model:FindFirstChild("RightHand") end
    if partName == "Left Leg" then return model:FindFirstChild("Left Leg") or model:FindFirstChild("LeftUpperLeg") or model:FindFirstChild("LeftFoot") end
    if partName == "Right Leg" then return model:FindFirstChild("Right Leg") or model:FindFirstChild("RightUpperLeg") or model:FindFirstChild("RightFoot") end
    return G.getHeadPart(model)
end
function G.alive()
    local c = LP.Character; if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end
function G.teamKey(plr)
    if not plr then return nil end
    if plr.Team then return plr.Team.Name end
    local ok, attr = pcall(function() return plr:GetAttribute("TeamID") end)
    if ok and attr then return tostring(attr) end
    return nil
end
function G.sameTeam(a, b)
    if not a or not b or a == b then return false end
    local ka, kb = G.teamKey(a), G.teamKey(b)
    return ka and kb and ka == kb
end

St = {
    saFovGui=nil, saFovCircle=nil, espGui=nil, fovGui=nil, fovCircle=nil,
    flyBV=nil, espCache={}, aimingHeld=false, aimLockedTarget=nil, aimLockedPart=nil,
    saTarget=nil, saRandomPart="Head", saRandomTime=0,
    gui=nil, root=nil, pageContainer=nil, rootScale=nil,
    npcCache={}, targetCache=nil, targetCacheTime=0,
    menuVisible=true, savedCameraType=nil, savedCameraSubject=nil, uiHovered=false,
    ragebotAnchoredRoot=nil, noclipSaved={}, noclipLastTick=0,
}

function St.getTargets()
    local now = tick()
    if St.targetCache and (now - St.targetCacheTime) < 0.05 then return St.targetCache end
    local list = {}
    
    -- NPC Scanning
    local includeNPCs = Settings.SilentAim.TargetNPCs or Settings.Aimbot.TargetNPCs or Settings.Players.ShowNPCs or Settings.Ragebot.Enabled
    if includeNPCs then
        for i = #St.npcCache, 1, -1 do
            local e = St.npcCache[i]
            if not e.model.Parent or not e.hum.Parent or e.hum.Health <= 0 then table.remove(St.npcCache, i) end
        end
        for _, e in ipairs(St.npcCache) do
            list[#list+1] = { plr=nil, hum=e.hum, root=e.root, model=e.model }
        end
    end
    
    -- Player Scanning
    for _, p in ipairs(Svc.Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            local root = G.getRootPart(p.Character)
            if hum and root and hum.Health > 0 then list[#list+1] = {plr=p, hum=hum, root=root, model=p.Character} end
        end
    end
    St.targetCache = list; St.targetCacheTime = now
    return list
end

Svc.WS.DescendantAdded:Connect(function(obj)
    if obj:IsA("Humanoid") then
        task.defer(function()
            local parent = obj.Parent
            if parent and parent:IsA("Model") and not Svc.Players:GetPlayerFromCharacter(parent) and parent ~= LP.Character then
                local root = G.getRootPart(parent)
                if root then table.insert(St.npcCache, {model=parent, hum=obj, root=root}) end
            end
        end)
    end
end)

-- ============================================================
-- SILENT AIM
-- ============================================================
SA = { hooked=false, oldNamecall=nil }

local function getSilentAimTarget()
    if not Settings.SilentAim.Enabled or not G.alive() or not Camera then return nil end
    local vp = Camera.ViewportSize
    local cx, cy = vp.X * 0.5, vp.Y * 0.5
    local best, bestDist = nil, math.huge

    if Settings.SilentAim.StickyAim and St.saTarget then
        if St.saTarget.model and St.saTarget.model.Parent and St.saTarget.hum.Health > 0 then
            local sp = Camera:WorldToViewportPoint(St.saTarget.root.Position)
            local d = math.sqrt((sp.X - cx)^2 + (sp.Y - cy)^2)
            if d <= Settings.SilentAim.FOVSize then return St.saTarget end
        end
        St.saTarget = nil
    end

    for _, t in ipairs(St.getTargets()) do
        if t.plr and Settings.Players.TeamCheck and G.sameTeam(LP, t.plr) then continue end
        local sp, onScreen = Camera:WorldToViewportPoint(t.root.Position)
        if onScreen and sp.Z > 0 then
            local d = math.sqrt((sp.X - cx)^2 + (sp.Y - cy)^2)
            if d <= Settings.SilentAim.FOVSize then
                if d < bestDist then bestDist = d; best = t end
            end
        end
    end
    if best then St.saTarget = best end
    return best
end

local function resolveSilentAimBodyPart(model)
    if Settings.SilentAim.Bodypart == "Random" then
        local parts = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}
        return G.getBodyPart(model, parts[math.random(#parts)])
    elseif Settings.SilentAim.Bodypart == "Random2" then
        if tick() - St.saRandomTime > 0.5 then
            local parts = {"Head", "Torso"}
            St.saRandomPart = parts[math.random(#parts)]
            St.saRandomTime = tick()
        end
        return G.getBodyPart(model, St.saRandomPart)
    else
        return G.getBodyPart(model, Settings.SilentAim.Bodypart)
    end
end

function SA.hook()
    if SA.hooked then return end
    local mt = getrawmetatable(game)
    if not mt then return end
    local oldNamecall = mt.__namecall
    setreadonly(mt, false)
    
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if not checkcaller() and Settings.SilentAim.Enabled and (method == "Raycast" or method == "FindPartOnRay") then
            local target = getSilentAimTarget()
            if target then
                local part = resolveSilentAimBodyPart(target.model)
                if part then
                    local args = {...}
                    if method == "Raycast" then
                        local origin, direction = args[1], args[2]
                        args[2] = (part.Position - origin).Unit * direction.Magnitude
                    elseif method == "FindPartOnRay" then
                        local ray = args[1]
                        args[1] = Ray.new(ray.Origin, (part.Position - ray.Origin).Unit * ray.Direction.Magnitude)
                    end
                    if Settings.SilentAim.Hitsound then
                        task.spawn(function()
                            local snd = Instance.new("Sound", Svc.SS)
                            snd.SoundId = "rbxasset://sounds/electronicpingshort.wav"
                            snd.Volume = 0.5
                            snd:Play()
                            Svc.TS:Create(snd, TweenInfo.new(0.5), {Volume=0}):Play()
                            task.wait(0.5)
                            snd:Destroy()
                        end)
                    end
                    return oldNamecall(self, unpack(args))
                end
            end
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(mt, true)
    SA.oldNamecall = oldNamecall
    SA.hooked = true
end

function SA.unhook()
    if not SA.hooked then return end
    local mt = getrawmetatable(game)
    if mt and SA.oldNamecall then
        setreadonly(mt, false); mt.__namecall = SA.oldNamecall; setreadonly(mt, true)
    end
    SA.hooked = false
end

function St.buildSAFOV()
    if St.saFovGui then St.saFovGui:Destroy() end
    St.saFovGui = H.new("ScreenGui", { Name="AeroSAFOV", ResetOnSpawn=false, IgnoreGuiInset=false, DisplayOrder=2147483638, Parent=GuiParent })
    St.saFovCircle = H.new("Frame", { AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5), Size=UDim2.fromOffset(Settings.SilentAim.FOVSize*2, Settings.SilentAim.FOVSize*2), BackgroundTransparency=1, BorderSizePixel=0, Parent=St.saFovGui })
    H.corner(9999, St.saFovCircle)
    H.stroke(Settings.SilentAim.FOVColor, 1.5, St.saFovCircle)
    St.saFovGui.Enabled = Settings.SilentAim.ShowFOV and Settings.SilentAim.Enabled
end

-- ============================================================
-- AIMBOT / RAGEBOT / MOVEMENT / ESP
-- ============================================================
function St.aimStep()
    if not Settings.Aimbot.Enabled or not G.alive() or not St.aimingHeld or Settings.Ragebot.Enabled then return end
    local t = St.aimLockedTarget
    if not t or not t.model.Parent or t.hum.Health <= 0 then
        t = nil
        for _, tgt in ipairs(St.getTargets()) do
            if tgt.plr and Settings.Aimbot.TeamCheck and G.sameTeam(LP, tgt.plr) then continue end
            local dist = (Camera.CFrame.Position - tgt.root.Position).Magnitude
            if dist < Settings.Aimbot.MaxDistance then t = tgt; break end
        end
        St.aimLockedTarget = t
    end
    if t then
        local part = G.getBodyPart(t.model, Settings.Aimbot.AimPart)
        if part then
            local sp, on = Camera:WorldToViewportPoint(part.Position)
            if on then
                local cx, cy = Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2
                if mouseMoveRel then mouseMoveRel(sp.X - cx, sp.Y - cy) end
            end
        end
    end
end

function St.rageStep()
    if not Settings.Ragebot.Enabled or not G.alive() then return end
    local char = LP.Character
    local hrp = G.getRootPart(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end
    
    local best, bestScore = nil, -math.huge
    for _, t in ipairs(St.getTargets()) do
        local n = tostring(t.model.Name or ""):lower()
        if n:find("explosive") then continue end
        local prio = n:find("skeleton") and 100 or 50
        local d = (hrp.Position - t.root.Position).Magnitude
        if d < RAGE_MAX_DISTANCE then
            local score = prio * 100000 - d
            if score > bestScore then bestScore = score; best = t end
        end
    end
    if best then
        hum.PlatformStand = true
        hum.AutoRotate = false
        local head = G.getHeadPart(best.model)
        local abovePos = best.root.Position + Vector3.new(0, RAGE_ABOVE_DISTANCE, 0)
        hrp.CFrame = CFrame.lookAt(abovePos, head.Position, Vector3.new(0,0,1))
        hrp.AssemblyLinearVelocity = Vector3.zero
        if not hrp.Anchored then hrp.Anchored = true end
    else
        if hrp.Anchored then hrp.Anchored = false end
        hum.PlatformStand = false
        hum.AutoRotate = true
    end
end

function St.moveStep()
    local char = LP.Character
    local hrp, hum = G.getRootPart(char), char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end
    
    if Settings.Movement.Fly then
        if not St.flyBV or not St.flyBV.Parent then
            St.flyBV = H.new("BodyVelocity", {MaxForce=Vector3.new(1e5,1e5,1e5), P=1250, Parent=hrp})
        end
        local move = Vector3.zero
        if Svc.UIS:IsKeyDown(Enum.KeyCode.W) then move += Camera.CFrame.LookVector end
        if Svc.UIS:IsKeyDown(Enum.KeyCode.S) then move -= Camera.CFrame.LookVector end
        if Svc.UIS:IsKeyDown(Enum.KeyCode.A) then move -= Camera.CFrame.RightVector end
        if Svc.UIS:IsKeyDown(Enum.KeyCode.D) then move += Camera.CFrame.RightVector end
        if Svc.UIS:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.yAxis end
        if move.Magnitude > 0 then move = move.Unit end
        St.flyBV.Velocity = move * Settings.Movement.FlySpeed
    elseif St.flyBV then St.flyBV:Destroy(); St.flyBV = nil end
    
    if Settings.Movement.Noclip then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
end

-- ============================================================
-- BUILD WINDOW (EXACT IMAGE MATCH)
-- ============================================================
local function buildWindow()
    if St.gui then St.gui:Destroy() end
    H.closeAllDropdowns()
    St.buildSAFOV()
    
    St.gui = H.new("ScreenGui", { Name="AeroUI", ResetOnSpawn=false, IgnoreGuiInset=true, DisplayOrder=2147483646, Parent=GuiParent })
    local root = H.new("Frame", { Name="Root", AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5), Size=UDim2.fromOffset(500,600), BackgroundColor3=T.bg, BorderSizePixel=0, ClipsDescendants=true, Parent=St.gui })
    St.root = root
    H.corner(0, root)
    
    local topBar = H.new("TextButton", { Name="TopBar", Text="", AutoButtonColor=false, BackgroundTransparency=1, Size=UDim2.new(1,0,0,40), Parent=root })
    H.new("TextLabel", { Text="Aero", Font=FontBold, TextSize=18, TextColor3=T.txt, BackgroundTransparency=1, Position=UDim2.fromOffset(16,10), Size=UDim2.fromOffset(200,20), TextXAlignment=Enum.TextXAlignment.Left, Parent=topBar })
    
    local sidebar = H.new("Frame", { Position=UDim2.fromOffset(0,40), Size=UDim2.new(0,120,1,-40), BackgroundColor3=T.sb, BorderSizePixel=0, Parent=root })
    local sidebarScroll = H.new("ScrollingFrame", { Size=UDim2.fromScale(1,1), BackgroundTransparency=1, ScrollBarThickness=0, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y, Parent=sidebar })
    H.new("UIListLayout", {Padding=UDim.new(0,4), Parent=sidebarScroll})
    H.pad(8,8,8,8, sidebarScroll)
    
    local pageContainer = H.new("Frame", { Position=UDim2.fromOffset(120,40), Size=UDim2.new(1,-120,1,-40), BackgroundTransparency=1, Parent=root })
    H.pad(16,16,16,16, pageContainer)
    
    local PAGES = {}
    local currentPage = nil
    local sidebarRows = {}

    local function makePage(name)
        local page = H.new("Frame", { Name=name, Size=UDim2.fromScale(1,1), BackgroundTransparency=1, Visible=false, Parent=pageContainer })
        local scroll = H.new("ScrollingFrame", { Size=UDim2.fromScale(1,1), BackgroundTransparency=1, ScrollBarThickness=2, ScrollBarImageColor3=T.st, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y, Parent=page })
        H.new("UIListLayout", {Padding=UDim.new(0,12), SortOrder=Enum.SortOrder.LayoutOrder, Parent=scroll})
        PAGES[name] = {page=page, content=scroll}
        return scroll
    end

    -- ================= SILENT AIM PAGE =================
    local saL = makePage("Silent Aim")
    
    -- Header Title
    local title = H.new("TextLabel", { Text="Silent Aim", Font=FontBold, TextSize=14, TextColor3=T.acc, BackgroundTransparency=1, Size=UDim2.new(1,0,0,20), TextXAlignment=Enum.TextXAlignment.Left, LayoutOrder=1, Parent=saL })
    
    -- Main Toggle Row
    local mainTglRow = H.new("Frame", { Size=UDim2.new(1,0,0,30), BackgroundTransparency=1, LayoutOrder=2, Parent=saL })
    local mtBox = H.new("Frame", { AnchorPoint=Vector2.new(0,0.5), Position=UDim2.new(0,0,0.5,0), Size=UDim2.fromOffset(30,16), BackgroundColor3=Settings.SilentAim.Enabled and T.acc or T.off, BorderSizePixel=0, Parent=mainTglRow })
    H.corner(8, mtBox)
    local mtInner = H.new("Frame", { AnchorPoint=Vector2.new(0,0.5), Position=UDim2.fromOffset(Settings.SilentAim.Enabled and 15 or 2,8), Size=UDim2.fromOffset(12,12), BackgroundColor3=Color3.new(1,1,1), BorderSizePixel=0, Parent=mtBox })
    H.corner(6, mtInner)
    H.new("TextLabel", { Text="Silent Aim", Font=FontBold, TextSize=13, TextColor3=T.txt, BackgroundTransparency=1, Position=UDim2.fromOffset(38,0), Size=UDim2.new(1,-38,1,0), TextXAlignment=Enum.TextXAlignment.Left, Parent=mainTglRow })
    H.new("TextLabel", { Text="[LMB | always]", Font=FontMed, TextSize=12, TextColor3=T.dim, BackgroundTransparency=1, AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,0,0.5,0), Size=UDim2.fromOffset(100,16), TextXAlignment=Enum.TextXAlignment.Right, Parent=mainTglRow })
    
    mtBox.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            local v = not Settings.SilentAim.Enabled
            Settings.SilentAim.Enabled = v
            if v then SA.hook() else SA.unhook() end
            if St.saFovGui then St.saFovGui.Enabled = v and Settings.SilentAim.ShowFOV end
            Svc.TS:Create(mtBox, TweenInfo.new(0.15), {BackgroundColor3 = v and T.acc or T.off}):Play()
            Svc.TS:Create(mtInner, TweenInfo.new(0.15), {Position = UDim2.fromOffset(v and 15 or 2, 8)}):Play()
        end
    end)
    
    H.new("TextLabel", { Text="Targeting", Font=FontBold, TextSize=14, TextColor3=T.acc, BackgroundTransparency=1, Size=UDim2.new(1,0,0,20), TextXAlignment=Enum.TextXAlignment.Left, LayoutOrder=3, Parent=saL })
    Wg.makeDropdown(saL, 4, { name="Method", options={"Viewport"}, default=Settings.SilentAim.Method, callback=function(v) Settings.SilentAim.Method = v end })
    Wg.makeDropdown(saL, 5, { name="Bodypart", options={"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "Random", "Random2"}, default=Settings.SilentAim.Bodypart, callback=function(v) Settings.SilentAim.Bodypart = v end })
    
    H.new("TextLabel", { Text="Settings", Font=FontBold, TextSize=14, TextColor3=T.acc, BackgroundTransparency=1, Size=UDim2.new(1,0,0,20), TextXAlignment=Enum.TextXAlignment.Left, LayoutOrder=6, Parent=saL })
    
    -- Custom Toggles matching image
    local function imgToggle(text, default, callback)
        local row = H.new("Frame", { Size=UDim2.new(1,0,0,24), BackgroundTransparency=1, LayoutOrder=0, Parent=saL })
        local box = H.new("Frame", { AnchorPoint=Vector2.new(0,0.5), Position=UDim2.new(0,0,0.5,0), Size=UDim2.fromOffset(30,16), BackgroundColor3=default and T.acc or T.off, BorderSizePixel=0, Parent=row })
        H.corner(8, box)
        local inner = H.new("Frame", { AnchorPoint=Vector2.new(0,0.5), Position=UDim2.fromOffset(default and 15 or 2,8), Size=UDim2.fromOffset(12,12), BackgroundColor3=Color3.new(1,1,1), BorderSizePixel=0, Parent=box })
        H.corner(6, inner)
        H.new("TextLabel", { Text=text, Font=FontBold, TextSize=13, TextColor3=T.txt, BackgroundTransparency=1, Position=UDim2.fromOffset(38,0), Size=UDim2.new(1,-38,1,0), TextXAlignment=Enum.TextXAlignment.Left, Parent=row })
        box.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                local v = not default
                Svc.TS:Create(box, TweenInfo.new(0.15), {BackgroundColor3 = v and T.acc or T.off}):Play()
                Svc.TS:Create(inner, TweenInfo.new(0.15), {Position = UDim2.fromOffset(v and 15 or 2, 8)}):Play()
                default = v
                callback(v)
            end
        end)
        return row
    end
    
    imgToggle("Sticky aim", Settings.SilentAim.StickyAim, function(v) Settings.SilentAim.StickyAim = v end).LayoutOrder = 7
    imgToggle("No delay", Settings.SilentAim.NoDelay, function(v) Settings.SilentAim.NoDelay = v end).LayoutOrder = 8
    imgToggle("Hitsound", Settings.SilentAim.Hitsound, function(v) Settings.SilentAim.Hitsound = v end).LayoutOrder = 9
    imgToggle("Target NPCs", Settings.SilentAim.TargetNPCs, function(v) Settings.SilentAim.TargetNPCs = v end).LayoutOrder = 10
    imgToggle("FOV", Settings.SilentAim.ShowFOV, function(v) Settings.SilentAim.ShowFOV = v; if St.saFovGui then St.saFovGui.Enabled = v and Settings.SilentAim.Enabled end end).LayoutOrder = 11
    
    -- Custom Slider
    local fovRadRow = Wg.makeSlider(saL, 12, {name="FOV radius", min=20, max=500, default=Settings.SilentAim.FOVSize, callback=function(v) 
        Settings.SilentAim.FOVSize = v
        if St.saFovCircle then St.saFovCircle.Size = UDim2.fromOffset(v*2, v*2) end
    end})
    
    -- Show FOV + Color Block
    local showFovRow = H.new("Frame", { Size=UDim2.new(1,0,0,24), BackgroundTransparency=1, LayoutOrder=13, Parent=saL })
    local sfBox = H.new("Frame", { AnchorPoint=Vector2.new(0,0.5), Position=UDim2.new(0,0,0.5,0), Size=UDim2.fromOffset(30,16), BackgroundColor3=Settings.SilentAim.ShowFOV and T.acc or T.off, BorderSizePixel=0, Parent=showFovRow })
    H.corner(8, sfBox)
    local sfInner = H.new("Frame", { AnchorPoint=Vector2.new(0,0.5), Position=UDim2.fromOffset(Settings.SilentAim.ShowFOV and 15 or 2,8), Size=UDim2.fromOffset(12,12), BackgroundColor3=Color3.new(1,1,1), BorderSizePixel=0, Parent=sfBox })
    H.corner(6, sfInner)
    H.new("TextLabel", { Text="Show FOV", Font=FontBold, TextSize=13, TextColor3=T.txt, BackgroundTransparency=1, Position=UDim2.fromOffset(38,0), Size=UDim2.new(1,-38,1,0), TextXAlignment=Enum.TextXAlignment.Left, Parent=showFovRow })
    
    sfBox.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            local v = not Settings.SilentAim.ShowFOV
            Settings.SilentAim.ShowFOV = v
            if St.saFovGui then St.saFovGui.Enabled = v and Settings.SilentAim.Enabled end
            Svc.TS:Create(sfBox, TweenInfo.new(0.15), {BackgroundColor3 = v and T.acc or T.off}):Play()
            Svc.TS:Create(sfInner, TweenInfo.new(0.15), {Position = UDim2.fromOffset(v and 15 or 2, 8)}):Play()
        end
    end)
    
    local cBtn = H.new("TextButton", { Text="", AutoButtonColor=false, BackgroundColor3=Settings.SilentAim.FOVColor, AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,0,0.5,0), Size=UDim2.fromOffset(16,16), BorderSizePixel=0, Parent=showFovRow })
    cBtn.MouseButton1Click:Connect(function()
        Settings.SilentAim.FOVColor = Settings.SilentAim.FOVColor == Color3.fromRGB(255,0,0) and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)
        cBtn.BackgroundColor3 = Settings.SilentAim.FOVColor
        if St.saFovCircle then local s = St.saFovCircle:FindFirstChildOfClass("UIStroke"); if s then s.Color = Settings.SilentAim.FOVColor end end
    end)

    -- ================= AIMBOT PAGE =================
    local aimL = makePage("Aimbot")
    uiToggleRefs.AimbotEnabled = Wg.makeToggle(aimL, 1, {name="Enabled", default=Settings.Aimbot.Enabled, callback=function(v) Settings.Aimbot.Enabled = v end})
    Wg.makeToggle(aimL, 2, {name="Target NPCs", default=Settings.Aimbot.TargetNPCs, callback=function(v) Settings.Aimbot.TargetNPCs = v end})
    Wg.makeSlider(aimL, 3, {name="FOV Size", min=20, max=500, default=Settings.Aimbot.FOVSize, callback=function(v) Settings.Aimbot.FOVSize = v end})

    -- ================= RAGEBOT PAGE =================
    local rageL = makePage("Ragebot")
    uiToggleRefs.RagebotEnabled = Wg.makeToggle(rageL, 1, {name="Enabled", default=Settings.Ragebot.Enabled, callback=function(v) Settings.Ragebot.Enabled = v end})
    H.new("TextLabel", { Text="Above mode • Range 750 studs\nPrioritises Skeleton", Font=Font, TextSize=12, TextColor3=T.dim, BackgroundTransparency=1, Size=UDim2.new(1,0,0,36), LayoutOrder=2, Parent=rageL })

    -- ================= MOVEMENT PAGE =================
    local movL = makePage("Movement")
    Wg.makeToggle(movL, 1, {name="Fly", default=Settings.Movement.Fly, callback=function(v) Settings.Movement.Fly = v end})
    Wg.makeToggle(movL, 2, {name="Noclip", default=Settings.Movement.Noclip, callback=function(v) Settings.Movement.Noclip = v end})

    -- ================= SIDEBAR =================
    local function addTab(name)
        local btn = H.new("TextButton", { Text="", AutoAction=false, BackgroundColor3=T.pn, Size=UDim2.new(1,0,0,30), Parent=sidebarScroll })
        H.corner(4, btn)
        local txt = H.new("TextLabel", { Text=name, Font=FontBold, TextSize=13, TextColor3=T.dim, BackgroundTransparency=1, Size=UDim2.fromScale(1,1), Parent=btn })
        
        btn.MouseEnter:Connect(function()
            if currentPage ~= name then txt.TextColor3 = T.txt; btn.BackgroundTransparency = 0.5 end
        end)
        btn.MouseLeave:Connect(function()
            if currentPage ~= name then txt.TextColor3 = T.dim; btn.BackgroundTransparency = 1 end
        end)
        btn.MouseButton1Click:Connect(function()
            currentPage = name
            for n, data in pairs(PAGES) do
                data.page.Visible = (n == name)
            end
            for _, child in ipairs(sidebarScroll:GetChildren()) do
                if child:IsA("TextButton") then
                    local label = child:FindFirstChildOfClass("TextLabel")
                    if label.Text == name then
                        child.BackgroundTransparency = 0
                        child.BackgroundColor3 = T.acc
                        label.TextColor3 = Color3.new(1,1,1)
                    else
                        child.BackgroundTransparency = 1
                        child.BackgroundColor3 = T.pn
                        label.TextColor3 = T.dim
                    end
                end
            end
        end)
        sidebarRows[name] = btn
    end

    addTab("Silent Aim")
    addTab("Aimbot")
    addTab("Ragebot")
    addTab("Movement")
    
    -- Start Page
    currentPage = "Silent Aim"
    PAGES["Silent Aim"].page.Visible = true
    sidebarRows["Silent Aim"].BackgroundTransparency = 0
    sidebarRows["Silent Aim"].BackgroundColor3 = T.acc
    sidebarRows["Silent Aim"]:FindFirstChildOfClass("TextLabel").TextColor3 = Color3.new(1,1,1)

    -- Dragging
    local dragging, startPos, dragStart
    topBar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = Vector2.new(inp.Position.X, inp.Position.Y); startPos = root.Position
        end
    end)
    Svc.UIS.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local d = Vector2.new(inp.Position.X, inp.Position.Y) - dragStart
            root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    Svc.UIS.InputEnded:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
end

-- ============================================================
-- RUNTIME HOOKS & BINDS
-- ============================================================
Svc.RS.RenderStepped:Connect(function()
    if not St.menuVisible then
        St.aimStep()
        St.rageStep()
        St.moveStep()
    end
    if Settings.SilentAim.Enabled then getSilentAimTarget() end
    if Settings.SilentAim.ShowFOV and St.saFovGui and St.saFovGui.Enabled and St.saFovCircle then
        local mp = Svc.UIS:GetMouseLocation()
        local inset = getGuiInset()
        St.saFovCircle.Position = UDim2.fromOffset(mp.X - inset.X, mp.Y - inset.Y)
    end
end)

Svc.UIS.InputBegan:Connect(function(inp, gpe)
    if gpe or St.uiHovered then return end
    if inp.UserInputType == Enum.UserInputType.MouseButton2 then St.aimingHeld = true end
    if inp.KeyCode == Enum.KeyCode.RightShift then
        St.menuVisible = not St.menuVisible
        St.gui.Enabled = St.menuVisible
    end
end)

Svc.UIS.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton2 then St.aimingHeld = false end
end)

PF.loadAutoSettings()
task.defer(function()
    buildWindow()
    if Settings.SilentAim.Enabled then SA.hook() end
    print("[Aero] loaded successfully")
end)
