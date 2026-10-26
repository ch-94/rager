--!nocheck
-- ============================================================
-- Aero Lite — v6 (Silent Aim + Audio Stripped)
-- ============================================================

print("[Aero Lite] booting...")

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
end

if not (Svc.Players and Svc.RS and Svc.UIS and Svc.TS and Svc.WS) then
    warn("[Aero Lite] core services unavailable, aborting"); return
end

local LP = Svc.Players.LocalPlayer
if not LP then warn("[Aero Lite] no LocalPlayer"); return end

local PG
do
    local ok, v = pcall(function() return LP:WaitForChild("PlayerGui", 20) end)
    if ok and v then PG = v end
    if not PG then PG = LP:FindFirstChild("PlayerGui") end
end
if not PG then warn("[Aero Lite] no PlayerGui"); return end

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

local St, RB, SA

local SETTINGS_FILE  = "AeroLiteSettings.json"
local SETTINGS_SCHEMA = 6
local AIM_SKIP_STUDS    = 3.0
local POINT_BLANK_STUDS = 1.5
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
    Red    = { bg=Color3.fromRGB(22,14,14), sb=Color3.fromRGB(30,18,18), pn=Color3.fromRGB(38,22,22),
               hov=Color3.fromRGB(60,30,30), st=Color3.fromRGB(84,40,40), txt=Color3.fromRGB(250,230,230),
               dim=Color3.fromRGB(200,140,140), acc=Color3.fromRGB(240,60,60), off=Color3.fromRGB(76,42,42),
               trk=Color3.fromRGB(84,40,40) },
    Green  = { bg=Color3.fromRGB(14,22,16), sb=Color3.fromRGB(18,30,22), pn=Color3.fromRGB(22,40,28),
               hov=Color3.fromRGB(28,58,42), st=Color3.fromRGB(44,80,58), txt=Color3.fromRGB(225,255,230),
               dim=Color3.fromRGB(140,200,160), acc=Color3.fromRGB(50,235,110), off=Color3.fromRGB(42,72,52),
               trk=Color3.fromRGB(44,80,58) },
}
local THEME_COLOR_KEYS = {"bg","sb","pn","hov","st","txt","dim","acc","off","trk"}
local COLOR_ROLE_LOOKUP = {}
for _, palette in pairs(THEMES) do
    for _, role in ipairs(THEME_COLOR_KEYS) do
        COLOR_ROLE_LOOKUP[palette[role]] = role
    end
end

local Settings = {
    Aimbot = { Enabled=false, WallCheck=true, TeamCheck=true, DeadCheck=true,
        SpawnProtCheck=true, TargetNPCs=true,
        AimPart="Head",
        MaxDistance=500,
        ShowFOV=true, FOVSize=120, FOVColor=Color3.fromRGB(120,90,240), FOVTransparency=0.6,
        Rainbow=false },
    SilentAim = { Enabled=false, Method="Viewport", Bodypart="Head",
        StickyAim=true, NoDelay=true,
        ShowFOV=true, FOVSize=150, FOVColor=Color3.fromRGB(255, 0, 0) },
    Players = { Enabled=false, Chams=false, ShowName=true,
        ShowHealth=true, ShowDistance=true,
        TeamCheck=true, ShowTeam=true, Range=800,
        RainbowEnemy=false, RainbowTeam=false,
        ShowNPCs=true,
        EnemyColor=Color3.fromRGB(255,60,60), TeammateColor=Color3.fromRGB(60,220,120) },
    Movement = { Fly=false, FlySpeed=60, Noclip=false },
    Ragebot  = { Enabled=false },
    Keybinds = {
        AimbotToggle  = Enum.KeyCode.F1,
        AimKey        = Enum.UserInputType.MouseButton2,
        EspToggle     = Enum.KeyCode.F3,
        RagebotToggle = Enum.KeyCode.F5,
        MenuKey       = Enum.KeyCode.RightShift,
        PanicKey      = Enum.KeyCode.P,
    },
    UI       = { Theme="Purple", ShowEnabled=true, LastPage="Silent Aim", Position=nil },
}

local uiToggleRefs = {}
local PF = { onSaveStatus = nil }

function PF.serializeVal(v)
    local ty = typeof(v)
    if ty == "Color3" then return { __t = "Color3", r = v.R, g = v.G, b = v.B } end
    if ty == "EnumItem" then
        local typeName = tostring(v.EnumType):match("^Enum%.(.+)$") or ""
        return { __t = "EnumItem", e = typeName, n = v.Name }
    end
    if type(v) == "table" then
        local o = {}
        for k, val in pairs(v) do o[k] = PF.serializeVal(val) end
        return o
    end
    return v
end

function PF.deserializeVal(v)
    if type(v) ~= "table" then return v end
    if v.__t == "Color3" then
        if type(v.r) == "number" and type(v.g) == "number" and type(v.b) == "number" then
            return Color3.new(v.r, v.g, v.b)
        end
        return nil
    end
    if v.__t == "EnumItem" then
        if type(v.e) == "string" and #v.e > 0 and type(v.n) == "string" and #v.n > 0 then
            local ok, et = pcall(function() return Enum[v.e] end)
            if ok and et then
                local ok2, item = pcall(function() return et[v.n] end)
                if ok2 and item then return item end
            end
        end
        return nil
    end
    local o = {}
    for k, val in pairs(v) do
        local dv = PF.deserializeVal(val)
        if dv ~= nil then o[k] = dv end
    end
    return o
end

function PF.deepCopy(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = PF.deepCopy(v) end
    return o
end

function PF.merge(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" and type(dst[k]) == "table" then
            PF.merge(dst[k], v)
        else
            dst[k] = PF.deepCopy(v)
        end
    end
end

function PF.saveSettingsNow()
    if type(writefile) ~= "function" or not Svc.HS then return false end
    local payload = { schemaVersion = SETTINGS_SCHEMA, Settings = PF.serializeVal(Settings) }
    local okEnc, json = pcall(function() return Svc.HS:JSONEncode(payload) end)
    if not okEnc then return false end
    local okWrite = pcall(writefile, SETTINGS_FILE, json)
    if PF.onSaveStatus then pcall(PF.onSaveStatus, okWrite) end
    return okWrite
end

function PF.loadAutoSettings()
    if type(readfile) ~= "function" or not Svc.HS then return false end
    local ok, data = pcall(readfile, SETTINGS_FILE)
    if not ok or not data then return false end
    local okDec, decoded = pcall(function() return Svc.HS:JSONDecode(data) end)
    if not okDec or type(decoded) ~= "table" or type(decoded.Settings) ~= "table" then return false end
    local restored = PF.deserializeVal(decoded.Settings)
    for section, tbl in pairs(restored) do
        if type(tbl) == "table" and type(Settings[section]) == "table" then
            PF.merge(Settings[section], tbl)
        end
    end
    return true
end

local Font     = Enum.Font.Gotham
local FontMed  = Enum.Font.GothamMedium
local FontBold = Enum.Font.GothamBold

local T = {}
for k, v in pairs(THEMES[Settings.UI.Theme] or THEMES.Purple) do T[k] = v end

local ThemeBindings = {}
local ThemeRefreshers = {}
local Connections = {}
local WindowConnections = {}
local unloaded = false
local AeroUnload

local function track(c) table.insert(Connections, c); return c end
local function trackWindow(c) table.insert(WindowConnections, c); return c end

local H = {}
function H.new(class, props, children)
    local i = Instance.new(class)
    for k, v in pairs(props or {}) do
        i[k] = v
        if typeof(v) == "Color3" then
            local role = COLOR_ROLE_LOOKUP[v]
            if role then ThemeBindings[#ThemeBindings+1] = { instance=i, property=k, role=role } end
        end
    end
    for _, c in ipairs(children or {}) do c.Parent = i end
    return i
end
function H.corner(r, p) return H.new("UICorner", {CornerRadius=UDim.new(0,r), Parent=p}) end
function H.stroke(c,t,p) return H.new("UIStroke", {Color=c, Thickness=t, ApplyStrokeMode=Enum.ApplyStrokeMode.Border, Parent=p}) end
function H.pad(t,b,l,r,p) return H.new("UIPadding", {PaddingTop=UDim.new(0,t), PaddingBottom=UDim.new(0,b), PaddingLeft=UDim.new(0,l), PaddingRight=UDim.new(0,r), Parent=p}) end
function H.clamp(v,lo,hi) return math.max(lo, math.min(hi, v)) end
function H.unbindTheme(obj)
    for i = #ThemeBindings, 1, -1 do
        if ThemeBindings[i].instance == obj then table.remove(ThemeBindings, i) end
    end
end
function H.gradient(parent, topAlpha, bottomAlpha)
    H.new("UIGradient", {
        Parent = parent, Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, topAlpha or 0),
            NumberSequenceKeypoint.new(1, bottomAlpha or 0.35),
        }),
    })
end

local OverlayGui = H.new("ScreenGui", {
    Name = "AeroOverlay", ResetOnSpawn = false, IgnoreGuiInset = true,
    DisplayOrder = 2147483647, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = GuiParent,
})

local openLists = {}
function H.closeAllDropdowns()
    for i = #openLists, 1, -1 do
        local e = openLists[i]
        if e and e.close then pcall(e.close) end
    end
    openLists = {}
end

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
    fovGui = nil, fovCircle = nil,
    saFovGui = nil, saFovCircle = nil,
    espGui = nil, hudGui = nil, hudContainer = nil,
    flyBV = nil, espCache = {},
    aimingHeld = false, aimLockedTarget = nil, aimLockedPart = nil,
    aimGain = 1.0, aimGainErrPrev = 0,
    saTarget = nil, saLastPart = nil, saRandomPart = "Head", saRandomTime = 0,
    panicTimes = {},
    gui = nil, root = nil, pageContainer = nil, rootScale = nil, rootStrokeTween = nil,
    noclipSaved = {}, noclipLastTick = 0,
    npcCache = {}, targetCache = nil, targetCacheTime = 0,
    menuVisible = true, firstWindowBuild = true,
    savedCameraType = nil, savedCameraSubject = nil,
    statsLabel = nil, fpsFrames = 0, currentFps = 0, uiHovered = false,
    ragebotAnchoredRoot = nil,
}

function St.clearAimState()
    St.aimLockedTarget = nil; St.aimLockedPart = nil; St.aimGain = 1.0; St.aimGainErrPrev = 0
end

function St.getTargets()
    local now = tick()
    if St.targetCache and (now - St.targetCacheTime) < 0.05 then return St.targetCache end
    local list = {}
    for _, p in ipairs(Svc.Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            local root = G.getRootPart(p.Character)
            if hum and root and hum.Health > 0 then list[#list+1] = {plr=p, hum=hum, root=root, model=p.Character} end
        end
    end
    St.targetCache = list
    St.targetCacheTime = now
    return list
end

-- ============================================================
-- SILENT AIM (METATABLE HOOK)
-- ============================================================
SA = {}
SA.hooked = false
SA.oldNamecall = nil

local function getSilentAimTarget()
    if not Settings.SilentAim.Enabled or not G.alive() or not Camera then return nil end
    
    local vp = Camera.ViewportSize
    local cx, cy = vp.X * 0.5, vp.Y * 0.5
    local best, bestDist = nil, math.huge

    if Settings.SilentAim.StickyAim and St.saTarget then
        if St.saTarget.model and St.saTarget.model.Parent and St.saTarget.hum.Health > 0 then
            local root = St.saTarget.root
            local sp = Camera:WorldToViewportPoint(root.Position)
            local d = math.sqrt((sp.X - cx)^2 + (sp.Y - cy)^2)
            if d <= Settings.SilentAim.FOVSize then return St.saTarget end
        end
        St.saTarget = nil
    end

    for _, t in ipairs(St.getTargets()) do
        if t.plr and Settings.Players.TeamCheck and G.sameTeam(LP, t.plr) then continue end
        local root = t.root
        local sp, onScreen = Camera:WorldToViewportPoint(root.Position)
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
                        local origin = args[1]
                        local direction = args[2]
                        local length = direction.Magnitude
                        local newDir = (part.Position - origin).Unit * length
                        args[2] = newDir
                    elseif method == "FindPartOnRay" then
                        local ray = args[1]
                        local newRay = Ray.new(ray.Origin, (part.Position - ray.Origin).Unit * ray.Direction.Magnitude)
                        args[1] = newRay
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
        setreadonly(mt, false)
        mt.__namecall = SA.oldNamecall
        setreadonly(mt, true)
    end
    SA.hooked = false
end

function St.buildSAFOV()
    if St.saFovGui then St.saFovGui:Destroy() end
    St.saFovGui = H.new("ScreenGui", {
        Name = "AeroSAFOV", ResetOnSpawn=false, IgnoreGuiInset=false,
        DisplayOrder=2147483638, Parent=GuiParent,
    })
    St.saFovCircle = H.new("Frame", {
        AnchorPoint=Vector2.new(0.5,0.5),
        Position=UDim2.fromScale(0.5,0.5),
        Size=UDim2.fromOffset(Settings.SilentAim.FOVSize*2, Settings.SilentAim.FOVSize*2),
        BackgroundTransparency=1, BorderSizePixel=0, Parent=St.saFovGui,
    })
    H.corner(9999, St.saFovCircle)
    local s = H.stroke(Settings.SilentAim.FOVColor, 1.5, St.saFovCircle)
    H.unbindTheme(s)
    St.saFovGui.Enabled = Settings.SilentAim.ShowFOV and Settings.SilentAim.Enabled
end

-- ============================================================
-- GUI BUILDER
-- ============================================================
local Wg = {}

function Wg.makeToggle(parent, order, opts)
    local value = opts.default == true
    local colorTween, innerTween
    local row = H.new("TextButton", { Text="", AutoButtonColor=false, BackgroundTransparency=1, Size=UDim2.new(1,0,0,28), LayoutOrder=order, Parent=parent })
    local lbl = H.new("TextLabel", { Text=opts.name, Font=FontMed, TextSize=13, TextColor3=T.txt, BackgroundTransparency=1, Size=UDim2.new(1,-32,1,0), TextXAlignment=Enum.TextXAlignment.Left, Parent=row })
    local box = H.new("Frame", { AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,0,0.5,0), Size=UDim2.fromOffset(20,20), BackgroundColor3=value and T.acc or T.off, BorderSizePixel=0, Parent=row })
    H.corner(5, box)
    local inner = H.new("Frame", { AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5), Size=UDim2.fromOffset(value and 12 or 8, value and 12 or 8), BackgroundColor3=Color3.fromRGB(255,255,255), BorderSizePixel=0, BackgroundTransparency=value and 0 or 0.4, Parent=box })
    H.corner(9999, inner)
    
    local function apply(v, silent)
        local changed = (v ~= value)
        value = v
        if colorTween then colorTween:Cancel() end
        if innerTween then innerTween:Cancel() end
        colorTween = Svc.TS:Create(box, TweenInfo.new(0.15), {BackgroundColor3=v and T.acc or T.off})
        innerTween = Svc.TS:Create(inner, TweenInfo.new(0.15), {Size=UDim2.fromOffset(v and 12 or 8, v and 12 or 8), BackgroundTransparency = v and 0 or 0.4})
        colorTween:Play(); innerTween:Play()
        if changed and opts.callback then opts.callback(v) end
    end
    row.MouseButton1Click:Connect(function() apply(not value) end)
    return apply
end

function Wg.makeSlider(parent, order, opts)
    local min, max = opts.min, opts.max
    local span = math.max(max - min, 1e-6)
    local value = opts.default or min
    local row = H.new("Frame", { Size=UDim2.new(1,0,0,42), BackgroundTransparency=1, LayoutOrder=order, Parent=parent })
    local lbl = H.new("TextLabel", { Text=opts.name, Font=Font, TextSize=13, TextColor3=T.txt, BackgroundTransparency=1, Size=UDim2.new(0.6,0,0,16), TextXAlignment=Enum.TextXAlignment.Left, Parent=row })
    local valLbl = H.new("TextLabel", { Text=math.floor(value), Font=FontMed, TextSize=13, TextColor3=T.txt, BackgroundTransparency=1, AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,0), Size=UDim2.new(0.4,0,0,16), TextXAlignment=Enum.TextXAlignment.Right, Parent=row })
    local trackHit = H.new("TextButton", { Text="", AutoButtonColor=false, BackgroundTransparency=1, BorderSizePixel=0, Position=UDim2.fromOffset(6,24), Size=UDim2.new(1,-12,0,12), Parent=row })
    local trackVis = H.new("Frame", { AnchorPoint=Vector2.new(0,0.5), Position=UDim2.new(0,0,0.5,0), Size=UDim2.new(1,0,0,4), BackgroundColor3=T.trk, BorderSizePixel=0, Parent=trackHit })
    H.corner(2, trackVis)
    local fill = H.new("Frame", { Size=UDim2.fromScale((value-min)/span,1), BackgroundColor3=T.acc, BorderSizePixel=0, Parent=trackVis })
    H.corner(2, fill)
    local knob = H.new("Frame", { AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new((value-min)/span,0,0.5,0), Size=UDim2.fromOffset(12,12), BackgroundColor3=Color3.new(1,1,1), BorderSizePixel=0, ZIndex=2, Parent=trackVis })
    H.corner(6, knob)
    
    local dragging = false
    local function setFromX(x)
        local rawPos = H.clamp((x - trackVis.AbsolutePosition.X) / math.max(trackVis.AbsoluteSize.X,1), 0, 1)
        value = min + rawPos * (max - min)
        local pos = (value - min) / span
        fill.Size = UDim2.fromScale(pos,1)
        knob.Position = UDim2.new(pos,0,0.5,0)
        valLbl.Text = math.floor(value)
        if opts.callback then opts.callback(value) end
    end
    trackHit.InputBegan:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; setFromX(inp.Position.X) end end)
    trackWindow(Svc.UIS.InputChanged:Connect(function(inp) if dragging then setFromX(inp.Position.X) end end))
    trackWindow(Svc.UIS.InputEnded:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end))
    return function(v) value = v; setFromX(0) end
end

function Wg.makeDropdown(parent, order, opts)
    local value = opts.default or opts.options[1]
    local row = H.new("Frame", { Size=UDim2.new(1,0,0,44), BackgroundTransparency=1, LayoutOrder=order, Parent=parent })
    H.new("TextLabel", { Text=opts.name, Font=FontBold, TextSize=13, TextColor3=T.txt, BackgroundTransparency=1, Size=UDim2.new(1,0,0,18), TextXAlignment=Enum.TextXAlignment.Left, Parent=row })
    local box = H.new("TextButton", { Text="", AutoButtonColor=false, Position=UDim2.fromOffset(0,20), Size=UDim2.new(1,0,0,24), BackgroundColor3=T.sb, BorderSizePixel=0, Parent=row })
    H.corner(6, box); H.stroke(T.st,1,box)
    local lbl = H.new("TextLabel", { Text=tostring(value), Font=FontMed, TextSize=12, TextColor3=T.txt, BackgroundTransparency=1, Size=UDim2.new(1,-24,1,0), Position=UDim2.fromOffset(8,0), TextXAlignment=Enum.TextXAlignment.Left, Parent=box })
    H.new("TextLabel", { Text="+", Font=FontBold, TextSize=14, TextColor3=T.dim, BackgroundTransparency=1, AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,-8,0.5,0), Size=UDim2.fromOffset(12,16), Parent=box })
    
    local listFrame, blockerConn, closeToken = nil, nil, 0
    local function closeList()
        if not listFrame then return end
        local f = listFrame; listFrame = nil; closeToken = closeToken + 1
        local token = closeToken
        for i = #openLists, 1, -1 do if openLists[i].frame == f then table.remove(openLists, i) end end
        local w = f.AbsoluteSize.X
        Svc.TS:Create(f, TweenInfo.new(0.15), {Size=UDim2.fromOffset(w, 0)}):Play()
        task.delay(0.15, function() if token == closeToken then f:Destroy() end end)
        if blockerConn then blockerConn:Disconnect(); blockerConn = nil end
    end
    box.MouseButton1Click:Connect(function()
        if listFrame then closeList(); return end
        H.closeAllDropdowns()
        
        local optionList = opts.options
        local rowH = 26
        local fullH = #optionList * rowH + 8
        local boxAbs = box.AbsolutePosition
        local boxSize = box.AbsoluteSize
        local overlayAbs = OverlayGui.AbsolutePosition
        local overlaySize = OverlayGui.AbsoluteSize
        
        local listX = boxAbs.X - overlayAbs.X
        local listY = boxAbs.Y - overlayAbs.Y + boxSize.Y + 2
        if listY + fullH > overlaySize.Y then listY = boxAbs.Y - overlayAbs.Y - fullH - 2; if listY < 4 then listY = 4 end end
        
        listFrame = H.new("Frame", { BackgroundColor3=T.sb, BorderSizePixel=0, ZIndex=100, Position=UDim2.fromOffset(listX, listY), Size=UDim2.fromOffset(boxSize.X, 0), ClipsDescendants=true, Parent=OverlayGui })
        H.corner(6, listFrame); H.stroke(T.st,1,listFrame)
        local sl = H.new("ScrollingFrame", { Size=UDim2.fromScale(1,1), BackgroundTransparency=1, ScrollBarThickness=3, ScrollBarImageColor3=T.st, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y, ZIndex=101, Parent=listFrame })
        H.new("UIListLayout", {Padding=UDim.new(0,2), SortOrder=Enum.SortOrder.LayoutOrder, Parent=sl})
        H.pad(4,4,4,4, sl)
        
        for i, opt in ipairs(optionList) do
            local r = H.new("TextButton", { Text=tostring(opt), Font=FontMed, TextSize=12, TextColor3=T.txt, AutoButtonColor=false, BackgroundColor3=(opt == value) and T.hov or T.pn, Size=UDim2.new(1,-4,0,rowH-2), LayoutOrder=i, ZIndex=102, Parent=sl })
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

-- ============================================================
-- BUILD WINDOW
-- ============================================================
local function buildWindow()
    local PAGES = {}
    local currentPage = nil
    local sidebarRows = {}
    local sidebarTweens = {}

    for _, c in ipairs(WindowConnections) do pcall(function() c:Disconnect() end) end
    WindowConnections = {}
    ThemeBindings = {}; ThemeRefreshers = {}
    H.closeAllDropdowns()

    if St.gui then pcall(function() St.gui:Destroy() end) end
    St.buildSAFOV()

    St.gui = H.new("ScreenGui", { Name="AeroUI", ResetOnSpawn=false, IgnoreGuiInset=true, DisplayOrder=2147483646, Parent=GuiParent })

    local root = H.new("Frame", { Name="Root", AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5), Size=UDim2.fromOffset(820,560), BackgroundColor3=T.bg, BorderSizePixel=0, ClipsDescendants=true, Parent=St.gui })
    St.root = root
    H.corner(16, root); H.stroke(T.st,1,root); H.gradient(root, 0, 0.5)
    St.rootScale = H.new("UIScale", {Scale = 1, Parent = root})
    root.MouseEnter:Connect(function() St.uiHovered = true end)
    root.MouseLeave:Connect(function() St.uiHovered = false end)

    local topBar = H.new("TextButton", { Name="TopBar", Text="", AutoButtonColor=false, BackgroundTransparency=1, Size=UDim2.new(1,0,0,54), Parent=root })
    H.new("TextLabel", { Text="Aero", Font=FontBold, TextSize=19, TextColor3=T.txt, BackgroundTransparency=1, Position=UDim2.fromOffset(20,14), Size=UDim2.fromOffset(200,26), TextXAlignment=Enum.TextXAlignment.Left, Parent=topBar })
    
    local body = H.new("Frame", { Name="Body", Position=UDim2.fromOffset(0,54), Size=UDim2.new(1,0,1,-54), BackgroundTransparency=1, Parent=root })
    local sidebar = H.new("Frame", { Size=UDim2.new(0,190,1,0), BackgroundColor3=T.sb, BorderSizePixel=0, Parent=body })
    H.corner(16, sidebar)
    
    local pageContainer = H.new("Frame", { Position=UDim2.fromOffset(190,0), Size=UDim2.new(1,-190,1,0), BackgroundTransparency=1, Parent=body })
    H.pad(14,14,14,14, pageContainer)

    local function makePage(name)
        local page = H.new("Frame", { Name=name, Size=UDim2.fromScale(1,1), BackgroundTransparency=1, Visible=false, Parent=pageContainer })
        PAGES[name] = page; return page
    end

    -- ================= SILENT AIM PAGE =================
    local saPage = makePage("Silent Aim")
    local saL = H.new("ScrollingFrame", { Size=UDim2.fromScale(1,1), BackgroundTransparency=1, ScrollBarThickness=3, ScrollBarImageColor3=T.st, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y, Parent=saPage })
    H.new("UIListLayout", {Padding=UDim.new(0,10), SortOrder=Enum.SortOrder.LayoutOrder, Parent=saL})

    H.new("TextLabel", { Text="Silent Aim", Font=FontBold, TextSize=15, TextColor3=T.txt, BackgroundTransparency=1, Size=UDim2.new(1,0,0,22), TextXAlignment=Enum.TextXAlignment.Left, LayoutOrder=1, Parent=saL })
    
    local function makeCustomSAEnable()
        local row = H.new("Frame", { Size=UDim2.new(1,0,0,28), BackgroundTransparency=1, LayoutOrder=2, Parent=saL })
        local lbl = H.new("TextLabel", { Text="Silent Aim", Font=FontBold, TextSize=13, TextColor3=T.txt, BackgroundTransparency=1, Size=UDim2.new(1,-140,1,0), TextXAlignment=Enum.TextXAlignment.Left, Parent=row })
        local hint = H.new("TextLabel", { Text="[LMB | always]", Font=FontMed, TextSize=12, TextColor3=T.dim, BackgroundTransparency=1, AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,-32,0.5,0), Size=UDim2.fromOffset(100,16), TextXAlignment=Enum.TextXAlignment.Right, Parent=row })
        local box = H.new("Frame", { AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,0,0.5,0), Size=UDim2.fromOffset(20,20), BackgroundColor3=Settings.SilentAim.Enabled and T.acc or T.off, BorderSizePixel=0, Parent=row })
        H.corner(10, box)
        local inner = H.new("Frame", { AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5), Size=UDim2.fromOffset(Settings.SilentAim.Enabled and 12 or 8, Settings.SilentAim.Enabled and 12 or 8), BackgroundColor3=Color3.fromRGB(255,255,255), BorderSizePixel=0, BackgroundTransparency=Settings.SilentAim.Enabled and 0 or 0.4, Parent=box })
        H.corner(9999, inner)
        
        row.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                local newVal = not Settings.SilentAim.Enabled
                Settings.SilentAim.Enabled = newVal
                if newVal then SA.hook() else SA.unhook() end
                if St.saFovGui then St.saFovGui.Enabled = newVal and Settings.SilentAim.ShowFOV end
                
                local cT = Svc.TS:Create(box, TweenInfo.new(0.15), {BackgroundColor3 = newVal and T.acc or T.off})
                local iT = Svc.TS:Create(inner, TweenInfo.new(0.15), {Size=UDim2.fromOffset(newVal and 12 or 8, newVal and 12 or 8), BackgroundTransparency = newVal and 0 or 0.4})
                cT:Play(); iT:Play()
            end
        end)
    end
    makeCustomSAEnable()

    H.new("TextLabel", { Text="Targeting", Font=FontBold, TextSize=14, TextColor3=T.acc, BackgroundTransparency=1, Size=UDim2.new(1,0,0,22), TextXAlignment=Enum.TextXAlignment.Left, LayoutOrder=3, Parent=saL })
    Wg.makeDropdown(saL, 4, { name="Method", options={"Viewport"}, default=Settings.SilentAim.Method, callback=function(v) Settings.SilentAim.Method = v end })
    Wg.makeDropdown(saL, 5, { name="Bodypart", options={"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "Random", "Random2"}, default=Settings.SilentAim.Bodypart, callback=function(v) Settings.SilentAim.Bodypart = v end })

    H.new("TextLabel", { Text="Settings", Font=FontBold, TextSize=14, TextColor3=T.acc, BackgroundTransparency=1, Size=UDim2.new(1,0,0,22), TextXAlignment=Enum.TextXAlignment.Left, LayoutOrder=6, Parent=saL })
    Wg.makeToggle(saL, 7, {name="Sticky aim", default=Settings.SilentAim.StickyAim, callback=function(v) Settings.SilentAim.StickyAim = v end})
    Wg.makeToggle(saL, 8, {name="No delay", default=Settings.SilentAim.NoDelay, callback=function(v) Settings.SilentAim.NoDelay = v end})
    Wg.makeToggle(saL, 9, {name="FOV", default=Settings.SilentAim.ShowFOV, callback=function(v) Settings.SilentAim.ShowFOV = v; if St.saFovGui then St.saFovGui.Enabled = v and Settings.SilentAim.Enabled end end})
    Wg.makeSlider(saL, 10, {name="FOV radius", min=20, max=500, default=Settings.SilentAim.FOVSize, callback=function(v) 
        Settings.SilentAim.FOVSize = v
        if St.saFovCircle then St.saFovCircle.Size = UDim2.fromOffset(v*2, v*2) end
    end})
    
    -- Custom "Show FOV" toggle + color block
    local saColorRow = H.new("Frame", {Size=UDim2.new(1,0,0,28), BackgroundTransparency=1, LayoutOrder=11, Parent=saL})
    local saShowFovLbl = H.new("TextLabel", {Text="Show FOV", Font=FontMed, TextSize=13, TextColor3=T.txt, BackgroundTransparency=1, Size=UDim2.new(1,-60,1,0), TextXAlignment=Enum.TextXAlignment.Left, Parent=saColorRow})
    local cBtn = H.new("TextButton", {Text="", AutoButtonColor=false, BackgroundColor3=Settings.SilentAim.FOVColor, AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,-30,0.5,0), Size=UDim2.fromOffset(22,18), BorderSizePixel=0, Parent=saColorRow})
    H.corner(4, cBtn)
    local sfBox = H.new("Frame", {AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,0,0.5,0), Size=UDim2.fromOffset(20,20), BackgroundColor3=Settings.SilentAim.ShowFOV and T.acc or T.off, BorderSizePixel=0, Parent=saColorRow})
    H.corner(10, sfBox)
    local sfInner = H.new("Frame", {AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5), Size=UDim2.fromOffset(Settings.SilentAim.ShowFOV and 12 or 8, Settings.SilentAim.ShowFOV and 12 or 8), BackgroundColor3=Color3.fromRGB(255,255,255), BorderSizePixel=0, BackgroundTransparency=Settings.SilentAim.ShowFOV and 0 or 0.4, Parent=sfBox})
    H.corner(9999, sfInner)
    
    sfBox.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            local newVal = not Settings.SilentAim.ShowFOV
            Settings.SilentAim.ShowFOV = newVal
            if St.saFovGui then St.saFovGui.Enabled = newVal and Settings.SilentAim.Enabled end
            Svc.TS:Create(sfBox, TweenInfo.new(0.15), {BackgroundColor3 = newVal and T.acc or T.off}):Play()
            Svc.TS:Create(sfInner, TweenInfo.new(0.15), {Size=UDim2.fromOffset(newVal and 12 or 8, newVal and 12 or 8), BackgroundTransparency = newVal and 0 or 0.4}):Play()
        end
    end)
    
    cBtn.MouseButton1Click:Connect(function()
        Settings.SilentAim.FOVColor = Settings.SilentAim.FOVColor == Color3.fromRGB(255,0,0) and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)
        cBtn.BackgroundColor3 = Settings.SilentAim.FOVColor
        if St.saFovCircle then local s = St.saFovCircle:FindFirstChildOfClass("UIStroke"); if s then s.Color = Settings.SilentAim.FOVColor end end
    end)

    -- ================= AIMBOT PAGE =================
    local aimPage = makePage("Aimbot")
    local aimL = H.new("ScrollingFrame", { Size=UDim2.fromScale(1,1), BackgroundTransparency=1, ScrollBarThickness=3, ScrollBarImageColor3=T.st, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y, Parent=aimPage })
    H.new("UIListLayout", {Padding=UDim.new(0,10), SortOrder=Enum.SortOrder.LayoutOrder, Parent=aimL})
    uiToggleRefs.AimbotEnabled = Wg.makeToggle(aimL, 1, {name="Enabled", default=Settings.Aimbot.Enabled, callback=function(v) Settings.Aimbot.Enabled = v; if not v then St.clearAimState() end end})
    Wg.makeSlider(aimL, 2, {name="FOV Size", min=20, max=500, default=Settings.Aimbot.FOVSize, callback=function(v) Settings.Aimbot.FOVSize = v end})

    -- ================= RAGEBOT PAGE =================
    local ragePage = makePage("Ragebot")
    local rg = H.new("ScrollingFrame", { Size=UDim2.fromScale(1,1), BackgroundTransparency=1, ScrollBarThickness=3, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y, Parent=ragePage })
    H.new("UIListLayout", {Padding=UDim.new(0,10), Parent=rg})
    uiToggleRefs.RagebotEnabled = Wg.makeToggle(rg, 1, {name="Enabled", default=Settings.Ragebot.Enabled, callback=function(v) Settings.Ragebot.Enabled = v; if not v and RB then RB.reset() end end})
    H.new("TextLabel", { Text = "Above mode • Range 750 studs\nPrioritises Skeleton", Font = Font, TextSize = 12, TextColor3 = T.dim, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,36), LayoutOrder = 2, Parent = rg })

    -- ================= SIDEBAR =================
    local function addSection(title, items)
        local sec = H.new("Frame", { Size=UDim2.new(1,0,0,22+(#items*26)), BackgroundTransparency=1, Parent=sidebar })
        H.new("UIListLayout", {Padding=UDim.new(0,2), Parent=sec})
        local hdr = H.new("TextLabel", { Text=title, Font=FontBold, TextSize=14, TextColor3=T.txt, BackgroundTransparency=1, Size=UDim2.new(1,0,0,22), TextXAlignment=Enum.TextXAlignment.Left, Parent=sec })
        H.pad(0,0,8,0,hdr)
        for i, item in ipairs(items) do
            local row = H.new("TextButton", { Text="", AutoButtonColor=false, Size=UDim2.new(1,0,0,24), BackgroundColor3=T.pn, BackgroundTransparency=1, LayoutOrder=i, Parent=sec })
            H.corner(6, row)
            local lbl = H.new("TextLabel", { Text=item.name, Font=Font, TextSize=13, TextColor3=T.dim, BackgroundTransparency=1, Size=UDim2.new(1,-16,1,0), Position=UDim2.fromOffset(10,0), TextXAlignment=Enum.TextXAlignment.Left, Parent=row })
            sidebarRows[item.name] = {row=row, label=lbl}
            
            local function applyVisual(isHover)
                local isActive = (currentPage == item.name)
                if sidebarTweens[item.name] then for _, t in ipairs(sidebarTweens[item.name]) do t:Cancel() end end
                local rT = Svc.TS:Create(row, TweenInfo.new(0.12), { BackgroundColor3 = isActive and T.hov or T.pn, BackgroundTransparency = isActive and 0 or 1 })
                local lT = Svc.TS:Create(lbl, TweenInfo.new(0.12), { TextColor3 = isActive and T.txt or (isHover and T.txt or T.dim), Position = UDim2.fromOffset((isHover and not isActive) and 12 or 10, 0) })
                rT:Play(); lT:Play()
                sidebarTweens[item.name] = {rT, lT}
            end
            
            row.MouseEnter:Connect(function() applyVisual(true) end)
            row.MouseLeave:Connect(function() applyVisual(false) end)
            row.MouseButton1Click:Connect(function()
                for name, entry in pairs(sidebarRows) do
                    local isAct = (name == item.name)
                    if sidebarTweens[name] then for _, t in ipairs(sidebarTweens[name]) do t:Cancel() end end
                    entry.row.BackgroundColor3 = isAct and T.hov or T.pn
                    entry.row.BackgroundTransparency = isAct and 0 or 1
                    entry.label.TextColor3 = isAct and T.txt or T.dim
                    entry.label.Position = UDim2.fromOffset(10, 0)
                end
                currentPage = item.name
                for n, p in pairs(PAGES) do p.Visible = (n == currentPage) end
            end)
        end
    end

    addSection("Combat", { {name="Silent Aim"}, {name="Aimbot"}, {name="Ragebot"} })
    
    currentPage = "Silent Aim"
    PAGES["Silent Aim"].Visible = true
    sidebarRows["Silent Aim"].row.BackgroundColor3 = T.hov
    sidebarRows["Silent Aim"].row.BackgroundTransparency = 0
    sidebarRows["Silent Aim"].label.TextColor3 = T.txt
    sidebarRows["Silent Aim"].label.Position = UDim2.fromOffset(10, 0)

    -- DRAG
    local dragging, dragStart, startPos
    trackWindow(Svc.UIS.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            local mp = inp.Position; local tp = topBar.AbsolutePosition
            if mp.X >= tp.X and mp.X <= tp.X+topBar.AbsoluteSize.X and mp.Y >= tp.Y and mp.Y <= tp.Y+topBar.AbsoluteSize.Y then
                dragging = true; dragStart = Vector2.new(mp.X, mp.Y); startPos = root.Position
            end
        end
    end))
    trackWindow(Svc.UIS.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local d = Vector2.new(inp.Position.X, inp.Position.Y) - dragStart
            root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))
    trackWindow(Svc.UIS.InputEnded:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end))
end

-- ============================================================
-- MAIN LOOP & BINDS
-- ============================================================
local mainStep = function()
    if unloaded then return end
    if Svc.WS.CurrentCamera ~= Camera then Camera = Svc.WS.CurrentCamera end
    -- Visual updates only (Silent Aim is handled by __namecall hook)
    if Settings.SilentAim.Enabled then
        local t = getSilentAimTarget()
        St.saTarget = t
    end
end

track(Svc.RS.RenderStepped:Connect(mainStep))

track(Svc.UIS.InputBegan:Connect(function(inp, gpe)
    if gpe or St.uiHovered then return end
    if Settings.Keybinds and G.inputMatches(inp, Settings.Keybinds.MenuKey) then
        St.menuVisible = not St.menuVisible
        St.gui.Enabled = St.menuVisible
    end
end))

function AeroUnload()
    if unloaded then return end
    unloaded = true
    SA.unhook()
    if St.gui then St.gui:Destroy() end
    if St.saFovGui then St.saFovGui:Destroy() end
    if St.fovGui then St.fovGui:Destroy() end
    for _, c in ipairs(Connections) do c:Disconnect() end
    print("[Aero Lite] unloaded")
end

PF.loadAutoSettings()
task.defer(function()
    buildWindow()
    if Settings.SilentAim.Enabled then SA.hook() end
    print("[Aero Lite] loaded successfully")
end)
