--!nocheck
-- ============================================================
-- Aero Lite - v4.2 (Xeno-safe, 8 tabs, all settings wired)
-- Aimbot / Silent Aim / Triggerbot / Ragebot / Players /
-- Movement / Settings / Keybinds
-- ============================================================

print("[Aero Lite] stage 1: boot")

local Svc = {}
do
    local function s(name) local ok, v = pcall(function() return game:GetService(name) end); if ok then return v end end
    Svc.Players = s("Players"); Svc.RS = s("RunService"); Svc.UIS = s("UserInputService")
    Svc.TS = s("TweenService"); Svc.SS = s("SoundService"); Svc.WS = s("Workspace")
    Svc.HS = s("HttpService"); Svc.Stats = s("Stats"); Svc.GuiSvc = s("GuiService")
    Svc.VIM = s("VirtualInputManager")
end

if not (Svc.Players and Svc.RS and Svc.UIS and Svc.TS and Svc.WS) then
    warn("[Aero Lite] core services unavailable"); return
end

local LP = Svc.Players.LocalPlayer
if not LP then warn("[Aero Lite] no LocalPlayer"); return end

local PG
do
    local ok, v = pcall(function() return LP:WaitForChild("PlayerGui", 15) end)
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

local mouseMoveRel = nil
if type(mousemoverel) == "function" then mouseMoveRel = mousemoverel
elseif type(mouse_move_rel) == "function" then mouseMoveRel = mouse_move_rel
elseif type(syn) == "table" and type(syn.mousemoverel) == "function" then mouseMoveRel = syn.mousemoverel end

local unpack = table.unpack or unpack

for _, parent in ipairs({PG, GuiParent}) do
    for _, n in ipairs({"AeroUI","AeroFOV","AeroSAFOV","AeroTBFOV","AeroESP","AeroHUD","AeroOverlay"}) do
        local p = parent:FindFirstChild(n)
        if p then pcall(function() p:Destroy() end) end
    end
end

local ATAN2 = math.atan2 or function(y, x)
    if x > 0 then return math.atan(y / x) end
    if x < 0 then return math.atan(y / x) + (y >= 0 and math.pi or -math.pi) end
    if y > 0 then return math.pi / 2 end
    if y < 0 then return -math.pi / 2 end
    return 0
end

local St, RB, SA

local SETTINGS_FILE = "AeroLiteSettings.json"
local SETTINGS_SCHEMA = 6
local AIM_SKIP_STUDS = 3.0
local POINT_BLANK_STUDS = 1.5
local RAGE_ABOVE_DISTANCE = 4
local RAGE_MAX_DISTANCE = 750

local cachedInset, cachedInsetTime = nil, 0
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
               dim=Color3.fromRGB(160,150,185), acc=Color3.fromRGB(160,80,255), off=Color3.fromRGB(56,44,80), trk=Color3.fromRGB(60,44,90) },
    Blue = { bg=Color3.fromRGB(14,20,28), sb=Color3.fromRGB(18,26,36), pn=Color3.fromRGB(22,32,46),
             hov=Color3.fromRGB(26,42,64), st=Color3.fromRGB(40,64,96), txt=Color3.fromRGB(230,240,255),
             dim=Color3.fromRGB(140,165,200), acc=Color3.fromRGB(40,165,255), off=Color3.fromRGB(40,58,84), trk=Color3.fromRGB(40,64,96) },
    Red = { bg=Color3.fromRGB(22,14,14), sb=Color3.fromRGB(30,18,18), pn=Color3.fromRGB(38,22,22),
            hov=Color3.fromRGB(60,30,30), st=Color3.fromRGB(84,40,40), txt=Color3.fromRGB(250,230,230),
            dim=Color3.fromRGB(200,140,140), acc=Color3.fromRGB(240,60,60), off=Color3.fromRGB(76,42,42), trk=Color3.fromRGB(84,40,40) },
    Green = { bg=Color3.fromRGB(14,22,16), sb=Color3.fromRGB(18,30,22), pn=Color3.fromRGB(22,40,28),
              hov=Color3.fromRGB(28,58,42), st=Color3.fromRGB(44,80,58), txt=Color3.fromRGB(225,255,230),
              dim=Color3.fromRGB(140,200,160), acc=Color3.fromRGB(50,235,110), off=Color3.fromRGB(42,72,52), trk=Color3.fromRGB(44,80,58) },
    Orange = { bg=Color3.fromRGB(26,16,10), sb=Color3.fromRGB(36,22,14), pn=Color3.fromRGB(46,28,16),
               hov=Color3.fromRGB(70,40,20), st=Color3.fromRGB(96,58,28), txt=Color3.fromRGB(255,240,220),
               dim=Color3.fromRGB(220,165,120), acc=Color3.fromRGB(255,140,30), off=Color3.fromRGB(84,52,28), trk=Color3.fromRGB(96,58,28) },
    Pink = { bg=Color3.fromRGB(24,12,20), sb=Color3.fromRGB(32,16,28), pn=Color3.fromRGB(42,20,36),
             hov=Color3.fromRGB(64,28,56), st=Color3.fromRGB(88,40,76), txt=Color3.fromRGB(255,230,248),
             dim=Color3.fromRGB(220,150,195), acc=Color3.fromRGB(255,90,200), off=Color3.fromRGB(78,38,66), trk=Color3.fromRGB(88,40,76) },
    Cyan = { bg=Color3.fromRGB(10,22,24), sb=Color3.fromRGB(14,32,36), pn=Color3.fromRGB(18,42,46),
             hov=Color3.fromRGB(24,60,66), st=Color3.fromRGB(36,86,92), txt=Color3.fromRGB(225,255,255),
             dim=Color3.fromRGB(140,215,220), acc=Color3.fromRGB(40,240,240), off=Color3.fromRGB(34,74,78), trk=Color3.fromRGB(36,86,92) },
    Mono = { bg=Color3.fromRGB(14,14,14), sb=Color3.fromRGB(20,20,20), pn=Color3.fromRGB(26,26,26),
             hov=Color3.fromRGB(42,42,42), st=Color3.fromRGB(64,64,64), txt=Color3.fromRGB(245,245,245),
             dim=Color3.fromRGB(160,160,160), acc=Color3.fromRGB(230,230,230), off=Color3.fromRGB(54,54,54), trk=Color3.fromRGB(64,64,64) },
}
local THEME_NAMES = { "Purple","Blue","Red","Green","Orange","Pink","Cyan","Mono" }

local COLORS = {
    {n="Black",  c=Color3.fromRGB(0,0,0)}, {n="White",  c=Color3.fromRGB(255,255,255)},
    {n="Red",    c=Color3.fromRGB(240,60,60)}, {n="Orange", c=Color3.fromRGB(240,140,40)},
    {n="Yellow", c=Color3.fromRGB(240,220,50)}, {n="Green",  c=Color3.fromRGB(60,220,100)},
    {n="Cyan",   c=Color3.fromRGB(60,220,225)}, {n="Blue",   c=Color3.fromRGB(60,150,250)},
    {n="Purple", c=Color3.fromRGB(160,100,240)},
}

local THEME_COLOR_KEYS = {"bg","sb","pn","hov","st","txt","dim","acc","off","trk"}
local COLOR_ROLE_LOOKUP = {}
for _, palette in pairs(THEMES) do
    for _, role in ipairs(THEME_COLOR_KEYS) do COLOR_ROLE_LOOKUP[palette[role]] = role end
end

local Settings = {
    Aimbot = { Enabled=false, WallCheck=true, TeamCheck=true, DeadCheck=true,
        SpawnProtCheck=true, TargetNPCs=true, AimPart="Head", MaxDistance=500,
        ShowFOV=true, FOVSize=120, FOVColor=Color3.fromRGB(120,90,240), FOVTransparency=0.6,
        Rainbow=false, FOVStyle="Circle" },
    SilentAim = { Enabled=false, Bodypart="Head", TeamCheck=true, StickyAim=true,
        ShowFOV=true, FOVSize=150, FOVColor=Color3.fromRGB(255,0,0), FOVTransparency=0.7 },
    Triggerbot = { Enabled=false, AimPart="Head", Delay=50,
        TeamCheck=true, WallCheck=true, DeadCheck=true, SpawnProtCheck=true, TargetNPCs=true,
        MaxDistance=1000, ShowFOV=true, FOVSize=40,
        FOVColor=Color3.fromRGB(255,180,60), FOVTransparency=0.7 },
    Players = { Enabled=false, Chams=false, ShowName=true, ShowHealth=true, ShowDistance=true,
        TeamCheck=true, ShowTeam=true, Range=800, RainbowEnemy=false, RainbowTeam=false,
        ShowNPCs=true, EnemyColor=Color3.fromRGB(255,60,60), TeammateColor=Color3.fromRGB(60,220,120),
        ShowBox=false, ShowHealthBar=false, ShowTracers=false, TracerOrigin="Top" },
    Npcs = { ESPColor=Color3.fromRGB(255,175,70), RainbowNPC=false },
    Movement = { Fly=false, FlySpeed=60, Noclip=false },
    Ragebot = { Enabled=false },
    Keybinds = {
        AimbotToggle = Enum.KeyCode.F1, AimKey = Enum.UserInputType.MouseButton2,
        EspToggle = Enum.KeyCode.F3, RagebotToggle = Enum.KeyCode.F5,
        SilentAimToggle = Enum.KeyCode.F2, TriggerbotToggle = Enum.KeyCode.F4,
        MenuKey = Enum.KeyCode.RightShift, PanicKey = Enum.KeyCode.P,
    },
    UI = { Theme="Purple", ShowEnabled=true, LastPage="Aimbot", Position=nil },
}

local uiToggleRefs = {}
local PF = { onSaveStatus = nil }

function PF.serializeVal(v)
    local ty = typeof(v)
    if ty == "Color3" then return { __t="Color3", r=v.R, g=v.G, b=v.B } end
    if ty == "EnumItem" then
        local tn = tostring(v.EnumType):match("^Enum%.(.+)$") or ""
        return { __t="EnumItem", e=tn, n=v.Name }
    end
    if ty == "Vector3" then return { __t="Vector3", x=v.X, y=v.Y, z=v.Z } end
    if ty == "UDim2" then return { __t="UDim2", xs=v.X.Scale, xo=v.X.Offset, ys=v.Y.Scale, yo=v.Y.Offset } end
    if type(v) == "table" then
        local o = {}; for k, val in pairs(v) do o[k] = PF.serializeVal(val) end; return o
    end
    return v
end
function PF.deserializeVal(v)
    if type(v) ~= "table" then return v end
    if v.__t == "Color3" and type(v.r)=="number" and type(v.g)=="number" and type(v.b)=="number" then
        return Color3.new(v.r, v.g, v.b)
    end
    if v.__t == "Vector3" and type(v.x)=="number" and type(v.y)=="number" and type(v.z)=="number" then
        return Vector3.new(v.x, v.y, v.z)
    end
    if v.__t == "UDim2" and type(v.xs)=="number" and type(v.xo)=="number" and type(v.ys)=="number" and type(v.yo)=="number" then
        return UDim2.new(v.xs, v.xo, v.ys, v.yo)
    end
    if v.__t == "EnumItem" and type(v.e)=="string" and #v.e>0 and type(v.n)=="string" and #v.n>0 then
        local ok, et = pcall(function() return Enum[v.e] end)
        if ok and et then
            local ok2, item = pcall(function() return et[v.n] end)
            if ok2 and item then return item end
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
    local o = {}; for k, v in pairs(t) do o[k] = PF.deepCopy(v) end; return o
end
function PF.merge(dst, src)
    for k, v in pairs(src) do
        if type(v)=="table" and type(dst[k])=="table" then PF.merge(dst[k], v)
        else dst[k] = PF.deepCopy(v) end
    end
end
function PF.readFile(path)
    if type(readfile) ~= "function" then return nil end
    if type(isfile) == "function" then
        local ok, exists = pcall(isfile, path)
        if ok and not exists then return nil end
    end
    local ok, data = pcall(readfile, path)
    if not ok or type(data)~="string" or data=="" then return nil end
    return data
end
function PF.readJSON(path)
    local data = PF.readFile(path); if not data then return nil end
    local ok, d = pcall(function() return Svc.HS and Svc.HS:JSONDecode(data) end)
    if not ok or type(d)~="table" then return nil end
    return d
end
function PF.writeJSON(path, data)
    if type(writefile) ~= "function" or not Svc.HS then return false end
    local ok, json = pcall(function() return Svc.HS:JSONEncode(data) end)
    if not ok or type(json)~="string" then return false end
    return pcall(writefile, path, json) == true
end
function PF.saveSettingsNow()
    local prev = PF.readFile(SETTINGS_FILE)
    local payload = { schemaVersion=SETTINGS_SCHEMA, savedAt=tick(), Settings=PF.serializeVal(Settings) }
    local ok = PF.writeJSON(SETTINGS_FILE, payload)
    if ok and prev then pcall(writefile, SETTINGS_FILE .. ".bak", prev) end
    if PF.onSaveStatus then pcall(PF.onSaveStatus, ok) end
    return ok
end
local saveToken = 0
function PF.queueSave()
    saveToken = saveToken + 1
    local tok = saveToken
    task.delay(0.35, function() if tok == saveToken then pcall(PF.saveSettingsNow) end end)
end
function PF.saveNow() saveToken = saveToken + 1; pcall(PF.saveSettingsNow) end

local function migrateSettings()
    if type(Settings.Aimbot.SpawnProtCheck) ~= "boolean" then Settings.Aimbot.SpawnProtCheck = true end
    if type(Settings.Aimbot.TargetNPCs) ~= "boolean" then Settings.Aimbot.TargetNPCs = true end
    if type(Settings.Aimbot.ShowFOV) ~= "boolean" then Settings.Aimbot.ShowFOV = true end
    if type(Settings.Aimbot.Rainbow) ~= "boolean" then Settings.Aimbot.Rainbow = false end
    if type(Settings.Aimbot.FOVTransparency) ~= "number" then Settings.Aimbot.FOVTransparency = 0.6 end
    Settings.Aimbot.FOVTransparency = math.clamp(Settings.Aimbot.FOVTransparency, 0, 1)
    if type(Settings.Aimbot.FOVSize) ~= "number" then Settings.Aimbot.FOVSize = 120 end
    if typeof(Settings.Aimbot.FOVColor) ~= "Color3" then Settings.Aimbot.FOVColor = Color3.fromRGB(120,90,240) end
    local validFOV = {Circle=true, Square=true, Cross=true, Dot=true}
    if type(Settings.Aimbot.FOVStyle) ~= "string" or not validFOV[Settings.Aimbot.FOVStyle] then
        Settings.Aimbot.FOVStyle = "Circle"
    end
    local validAim = {Head=true, Torso=true, Random=true}
    if type(Settings.Aimbot.AimPart) ~= "string" or not validAim[Settings.Aimbot.AimPart] then
        Settings.Aimbot.AimPart = "Head"
    end

    if type(Settings.SilentAim) ~= "table" then Settings.SilentAim = {} end
    if type(Settings.SilentAim.Enabled) ~= "boolean" then Settings.SilentAim.Enabled = false end
    if type(Settings.SilentAim.Bodypart) ~= "string" or not validAim[Settings.SilentAim.Bodypart] then
        Settings.SilentAim.Bodypart = "Head"
    end
    if type(Settings.SilentAim.TeamCheck) ~= "boolean" then Settings.SilentAim.TeamCheck = true end
    if type(Settings.SilentAim.StickyAim) ~= "boolean" then Settings.SilentAim.StickyAim = true end
    if type(Settings.SilentAim.ShowFOV) ~= "boolean" then Settings.SilentAim.ShowFOV = true end
    if type(Settings.SilentAim.FOVSize) ~= "number" then Settings.SilentAim.FOVSize = 150 end
    if typeof(Settings.SilentAim.FOVColor) ~= "Color3" then Settings.SilentAim.FOVColor = Color3.fromRGB(255,0,0) end
    if type(Settings.SilentAim.FOVTransparency) ~= "number" then Settings.SilentAim.FOVTransparency = 0.7 end

    if type(Settings.Triggerbot) ~= "table" then Settings.Triggerbot = {} end
    if type(Settings.Triggerbot.Enabled) ~= "boolean" then Settings.Triggerbot.Enabled = false end
    if type(Settings.Triggerbot.AimPart) ~= "string" or not validAim[Settings.Triggerbot.AimPart] then
        Settings.Triggerbot.AimPart = "Head"
    end
    if type(Settings.Triggerbot.Delay) ~= "number" then Settings.Triggerbot.Delay = 50 end
    if type(Settings.Triggerbot.TeamCheck) ~= "boolean" then Settings.Triggerbot.TeamCheck = true end
    if type(Settings.Triggerbot.WallCheck) ~= "boolean" then Settings.Triggerbot.WallCheck = true end
    if type(Settings.Triggerbot.DeadCheck) ~= "boolean" then Settings.Triggerbot.DeadCheck = true end
    if type(Settings.Triggerbot.SpawnProtCheck) ~= "boolean" then Settings.Triggerbot.SpawnProtCheck = true end
    if type(Settings.Triggerbot.TargetNPCs) ~= "boolean" then Settings.Triggerbot.TargetNPCs = true end
    if type(Settings.Triggerbot.MaxDistance) ~= "number" then Settings.Triggerbot.MaxDistance = 1000 end
    if type(Settings.Triggerbot.ShowFOV) ~= "boolean" then Settings.Triggerbot.ShowFOV = true end
    if type(Settings.Triggerbot.FOVSize) ~= "number" then Settings.Triggerbot.FOVSize = 40 end
    if typeof(Settings.Triggerbot.FOVColor) ~= "Color3" then Settings.Triggerbot.FOVColor = Color3.fromRGB(255,180,60) end
    if type(Settings.Triggerbot.FOVTransparency) ~= "number" then Settings.Triggerbot.FOVTransparency = 0.7 end

    if type(Settings.Players.ShowBox) ~= "boolean" then Settings.Players.ShowBox = false end
    if type(Settings.Players.ShowHealthBar) ~= "boolean" then Settings.Players.ShowHealthBar = false end
    if type(Settings.Players.ShowTracers) ~= "boolean" then Settings.Players.ShowTracers = false end
    local validTracer = {Top=true, Center=true, Bottom=true}
    if type(Settings.Players.TracerOrigin) ~= "string" or not validTracer[Settings.Players.TracerOrigin] then
        Settings.Players.TracerOrigin = "Top"
    end

    if type(Settings.Npcs) ~= "table" then Settings.Npcs = {} end
    if typeof(Settings.Npcs.ESPColor) ~= "Color3" then Settings.Npcs.ESPColor = Color3.fromRGB(255,175,70) end
    if type(Settings.Npcs.RainbowNPC) ~= "boolean" then Settings.Npcs.RainbowNPC = false end

    if type(Settings.UI.ShowEnabled) ~= "boolean" then Settings.UI.ShowEnabled = true end
    if not THEMES[Settings.UI.Theme] then Settings.UI.Theme = "Purple" end

    local function ensureColor(tbl, key, fallback)
        if tbl and typeof(tbl[key]) ~= "Color3" then tbl[key] = fallback end
    end
    ensureColor(Settings.Players, "EnemyColor", Color3.fromRGB(255,60,60))
    ensureColor(Settings.Players, "TeammateColor", Color3.fromRGB(60,220,120))
end

function PF.loadAutoSettings()
    local decoded = PF.readJSON(SETTINGS_FILE) or PF.readJSON(SETTINGS_FILE .. ".bak")
    if not decoded or type(decoded.Settings) ~= "table" then return false end
    local ok = pcall(function()
        local restored = PF.deserializeVal(decoded.Settings)
        for section, tbl in pairs(restored) do
            if type(tbl)=="table" and type(Settings[section])=="table" then PF.merge(Settings[section], tbl) end
        end
        migrateSettings()
    end)
    return ok
end

local Font, FontMed, FontBold = Enum.Font.Gotham, Enum.Font.GothamMedium, Enum.Font.GothamBold

local T = {}
for k, v in pairs(THEMES[Settings.UI.Theme] or THEMES.Purple) do T[k] = v end

local rainbowHue = 0
local function rainbowTick(dt) rainbowHue = (rainbowHue + dt * 0.3) % 1 end
local function rainbowColor() return Color3.fromHSV(rainbowHue, 0.85, 1) end

local ThemeBindings, ThemeRefreshers = {}, {}
local Connections, WindowConnections = {}, {}
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
            if role then ThemeBindings[#ThemeBindings+1] = {instance=i, property=k, role=role} end
        end
    end
    for _, c in ipairs(children or {}) do c.Parent = i end
    return i
end
function H.corner(r,p) return H.new("UICorner", {CornerRadius=UDim.new(0,r), Parent=p}) end
function H.stroke(c,t,p) return H.new("UIStroke", {Color=c, Thickness=t, ApplyStrokeMode=Enum.ApplyStrokeMode.Border, Parent=p}) end
function H.pad(t,b,l,r,p) return H.new("UIPadding", {PaddingTop=UDim.new(0,t), PaddingBottom=UDim.new(0,b), PaddingLeft=UDim.new(0,l), PaddingRight=UDim.new(0,r), Parent=p}) end
function H.clamp(v,lo,hi) return math.max(lo, math.min(hi, v)) end
function H.unbindTheme(obj)
    for i = #ThemeBindings, 1, -1 do if ThemeBindings[i].instance == obj then table.remove(ThemeBindings, i) end end
end
function H.gradient(parent, ta, ba)
    H.new("UIGradient", {Parent=parent, Rotation=90,
        Transparency=NumberSequence.new({
            NumberSequenceKeypoint.new(0, ta or 0),
            NumberSequenceKeypoint.new(0.55, (ta or 0) + ((ba or 0.35) - (ta or 0)) * 0.35),
            NumberSequenceKeypoint.new(1, ba or 0.35)})})
end
function H.applyThemeBindings()
    for _, b in ipairs(ThemeBindings) do
        local obj = b.instance
        if obj and obj.Parent then
            local nm = obj.Name or ""
            if nm ~= "ThemeOptionSwatch" and nm ~= "ColorChoiceSwatch" and nm ~= "CustomColorSwatch" then
                if b.role and T[b.role] then pcall(function() obj[b.property] = T[b.role] end) end
            end
        end
    end
end
function H.pruneThemeBindings()
    local a = {}
    for _, b in ipairs(ThemeBindings) do if b.instance and b.instance.Parent then a[#a+1] = b end end
    ThemeBindings = a
end

local OverlayGui
do
    local function tryMake(p)
        local ok, g = pcall(function()
            return H.new("ScreenGui", {Name="AeroOverlay", ResetOnSpawn=false, IgnoreGuiInset=true,
                DisplayOrder=2147483647, ZIndexBehavior=Enum.ZIndexBehavior.Sibling, Parent=p})
        end)
        if ok then return g end
    end
    OverlayGui = tryMake(GuiParent)
    if not OverlayGui and GuiParent ~= PG then OverlayGui = tryMake(PG); if OverlayGui then GuiParent = PG end end
end
if not OverlayGui then warn("[Aero Lite] overlay create failed"); return end
print("[Aero Lite] stage 2: overlay ready")

local openLists = {}
function H.closeAllDropdowns()
    for i = #openLists, 1, -1 do local e = openLists[i]; if e and e.close then pcall(e.close) end end
    openLists = {}
end

local G = {}
function G.getHeadPart(model)
    if not model then return nil end
    local d = model:FindFirstChild("Head")
    if d and d:IsA("BasePart") then return d end
    for _, p in ipairs(model:GetChildren()) do
        if p:IsA("BasePart") and p.Name:lower()=="head" then return p end
    end
    local root = nil; local hum = model:FindFirstChildOfClass("Humanoid")
    if hum then root = hum.RootPart end
    if not root then root = model:FindFirstChild("HumanoidRootPart") end
    local best, bestY = nil, -math.huge
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") and p ~= root and p.Position.Y > bestY then bestY = p.Position.Y; best = p end
    end
    return best or root
end
function G.getTorsoPart(model)
    if not model then return nil end
    for _, nm in ipairs({"UpperTorso","Torso","Chest","Body"}) do
        local p = model:FindFirstChild(nm)
        if p and p:IsA("BasePart") then return p end
    end
    for _, p in ipairs(model:GetChildren()) do
        if p:IsA("BasePart") then
            local n = p.Name:lower()
            if n=="torso" or n=="uppertorso" or n=="chest" or n=="body" then return p end
        end
    end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum and hum.RootPart then return hum.RootPart end
    return model:FindFirstChild("HumanoidRootPart") or G.getHeadPart(model)
end
function G.getRootPart(model)
    if not model then return nil end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum and hum.RootPart then return hum.RootPart end
    local hrp = model:FindFirstChild("HumanoidRootPart"); if hrp then return hrp end
    local t = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
    if t then return t end
    return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end

local _hpCache = setmetatable({}, {__mode="k"})
function G.healthInfo(plr, hum, char)
    local now = tick(); local key = hum or char
    if key then local e = _hpCache[key]; if e and now - e.t < 0.1 then return e.hp, e.max end end
    if not hum and char then hum = char:FindFirstChildOfClass("Humanoid") end
    local humHP  = hum and tonumber(hum.Health) or nil
    local humMax = hum and tonumber(hum.MaxHealth) or nil
    local attrHP, attrMax
    if char then
        local a1, a2 = char:GetAttribute("Health"), char:GetAttribute("MaxHealth")
        if type(a1)=="number" and type(a2)=="number" and a2>0 then attrHP, attrMax = a1, a2 end
    end
    if not attrHP and plr then
        local a1, a2 = plr:GetAttribute("Health"), plr:GetAttribute("MaxHealth")
        if type(a1)=="number" and type(a2)=="number" and a2>0 then attrHP, attrMax = a1, a2 end
    end
    local maxHp = humMax or attrMax or 100; if maxHp <= 0 then maxHp = 100 end
    local hp = humHP or maxHp
    if attrHP and attrHP < hp then hp = attrHP end
    if hp < 0 then hp = 0 end
    if key then _hpCache[key] = {t=now, hp=hp, max=maxHp} end
    return hp, maxHp
end

local SPAWN_PROT_ATTRS = {
    "SpawnProtection","spawnProtection","Invincible","invincible","Invulnerable","invulnerable",
    "GodMode","godmode","Protected","protected","Protection","protection",
    "SpawnProtect","Immunity","immunity","Immune","immune","Safe","safe",
    "ForceField","forceField","Shield","shield","Shielded","shielded",
}
local SPAWN_PROT_CHILDREN = {"SpawnProtection","Protected","Invincible","GodMode","Safe","Immunity","ForceField","Shield","Shielded"}
local spawnProtCache = setmetatable({}, {__mode="k"})
function G.isSpawnProtected(plr, hum, model)
    if not model and not hum then return false end
    local now = tick(); local ck = model or hum
    local e = spawnProtCache[ck]; if e and (now - e.t) < 0.5 then return e.v end
    local result = false
    if model and model:FindFirstChildOfClass("ForceField") then result = true end
    if not result then
        for _, tgt in ipairs({hum, model, plr}) do
            if tgt and tgt.GetAttribute then
                for _, attr in ipairs(SPAWN_PROT_ATTRS) do
                    local ok, v = pcall(function() return tgt:GetAttribute(attr) end)
                    if ok and (v == true or (type(v)=="number" and v>0)) then result = true; break end
                end
                if result then break end
            end
        end
    end
    if not result and model then
        for _, nm in ipairs(SPAWN_PROT_CHILDREN) do
            local c = model:FindFirstChild(nm)
            if c and ((c:IsA("BoolValue") and c.Value) or
                     (c:IsA("IntValue") and c.Value>0) or
                     (c:IsA("NumberValue") and c.Value>0)) then result = true; break end
        end
    end
    spawnProtCache[ck] = {t=now, v=result}
    return result
end
function G.teamKey(plr)
    if not plr then return nil end
    local ok1, tid = pcall(function() return plr:GetAttribute("TeamID") end)
    if ok1 and tid ~= nil and tid ~= "" then return "rivals_" .. tostring(tid) end
    if plr.Team and plr.Team.Name ~= "" then return "team_" .. plr.Team.Name end
    local ok2, a = pcall(function() return plr:GetAttribute("Team") end)
    if ok2 and a ~= nil and a ~= "" then return "attr_" .. tostring(a) end
    if not plr.Neutral and plr.TeamColor then return "tc_" .. tostring(plr.TeamColor.Name) end
    return nil
end
local _tpc, _tpcT = setmetatable({}, {__mode="k"}), 0
function G.sameTeam(a, b)
    if not a or not b then return false end
    if a == b then return true end
    local now = tick()
    if now - _tpcT > 0.15 then _tpc = setmetatable({}, {__mode="k"}); _tpcT = now end
    local inner = _tpc[a]; if inner and inner[b] ~= nil then return inner[b] end
    local ka, kb = G.teamKey(a), G.teamKey(b)
    local r = (ka ~= nil and kb ~= nil and ka == kb) or false
    if not _tpc[a] then _tpc[a] = {} end; _tpc[a][b] = r
    if not _tpc[b] then _tpc[b] = {} end; _tpc[b][a] = r
    return r
end
function G.alive()
    local c = LP.Character; if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end

local _vmC, _vmT = nil, 0
function G.collectViewmodels()
    local now = tick(); if _vmC and now - _vmT < 0.2 then return _vmC end
    _vmT = now; local list, seen = {}, {}
    local function add(o) if o and not seen[o] then seen[o] = true; list[#list+1] = o end end
    if Camera then
        for _, o in ipairs(Camera:GetChildren()) do add(o) end
        for _, d in ipairs(Camera:GetDescendants()) do add(d) end
    end
    local char = LP.Character
    if char then
        for _, o in ipairs(char:GetChildren()) do
            if o:IsA("Tool") then add(o) end
            local n = o.Name:lower()
            if n:find("viewmodel") or n:find("arms") or n:find("weapon") or n:find("hands") or n:find("fps") or n:find("gun") or n=="vm" then add(o) end
        end
        local hum = char:FindFirstChildOfClass("Humanoid"); if hum then add(hum) end
    end
    for _, o in ipairs(Svc.WS:GetChildren()) do
        local n = o.Name:lower()
        if n:find("viewmodel") or n:find("arms") or n:find("weapon") or n:find("hands") or n:find("fps") or n:find("gun") or n=="vm" then add(o) end
    end
    _vmC = list; return list
end

local function collectOwnGuis()
    local t = {}
    for _, p in ipairs({PG, GuiParent}) do
        if p then
            for _, n in ipairs({"AeroUI","AeroFOV","AeroSAFOV","AeroTBFOV","AeroESP","AeroHUD","AeroOverlay"}) do
                local g = p:FindFirstChild(n); if g then t[#t+1] = g end
            end
        end
    end
    return t
end

local _losP, _losBuf = nil, {}
local function _getLOSParams()
    if not _losP then
        _losP = RaycastParams.new()
        _losP.FilterType = Enum.RaycastFilterType.Exclude
        _losP.IgnoreWater = true
    end
    return _losP
end
function G.hasLOS(targetPos, targetModel)
    if not Camera then return false end
    local char = LP.Character; if not char then return false end
    local myHead = G.getHeadPart(char) or char:FindFirstChild("HumanoidRootPart")
    if not myHead then return false end
    local delta = targetPos - myHead.Position
    local dist = delta.Magnitude
    if dist <= (AIM_SKIP_STUDS + POINT_BLANK_STUDS) then return true end
    local dir = delta.Unit
    local startPos = myHead.Position + dir * AIM_SKIP_STUDS
    local rayLen = (targetPos - startPos).Magnitude
    if rayLen < 0.1 then return true end
    local params = _getLOSParams()
    local excl = _losBuf; local n = 0
    n = n + 1; excl[n] = char
    for _, g in ipairs(collectOwnGuis()) do n = n + 1; excl[n] = g end
    if Camera then n = n + 1; excl[n] = Camera end
    if targetModel then n = n + 1; excl[n] = targetModel end
    for _, v in ipairs(G.collectViewmodels()) do n = n + 1; excl[n] = v end
    for i = n + 1, #excl do excl[i] = nil end
    params.FilterDescendantsInstances = excl
    local res = Svc.WS:Raycast(startPos, dir * rayLen, params)
    if res == nil then return true end
    local hit = res.Instance
    if hit then
        if hit:IsDescendantOf(char) then return true end
        if Camera and hit:IsDescendantOf(Camera) then return true end
        if (res.Position - targetPos).Magnitude < POINT_BLANK_STUDS then return true end
    end
    return false
end
function G.inputMatches(inp, binding)
    if binding == nil or typeof(binding) ~= "EnumItem" then return false end
    if binding.EnumType == Enum.KeyCode then
        return inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode == binding
    elseif binding.EnumType == Enum.UserInputType then
        return inp.UserInputType == binding
    end
    return false
end
function G.keyName(v)
    if typeof(v) ~= "EnumItem" then return "NONE" end
    if v.EnumType == Enum.UserInputType then
        if v == Enum.UserInputType.MouseButton1 then return "Mouse1" end
        if v == Enum.UserInputType.MouseButton2 then return "Mouse2" end
        if v == Enum.UserInputType.MouseButton3 then return "Mouse3" end
    end
    return v.Name
end
function G.getPing()
    if not Svc.Stats then return nil end
    local ok, item = pcall(function() return Svc.Stats.Network.ServerStatsItem["Data Ping"] end)
    if not ok or not item then return nil end
    local ok2, v = pcall(function() return item:GetValue() end)
    if ok2 and type(v)=="number" then return math.floor(v + 0.5) end
    return nil
end

St = {
    fovGui=nil, fovCircle=nil, saFovGui=nil, saFovCircle=nil, tbFovGui=nil, tbFovCircle=nil,
    espGui=nil, hudGui=nil, hudContainer=nil, flyBV=nil,
    espCache={}, aimingHeld=false, aimLockedTarget=nil, aimLockedPart=nil, aimLockedSince=0,
    aimGain=1.0, aimGainErrPrev=0, triggerLastFire=0, saTarget=nil, saTargetTime=0,
    panicTimes={}, gui=nil, root=nil, pageContainer=nil, rootScale=nil, rootStrokeTween=nil,
    noclipSaved={}, noclipLastTick=0, npcCache={}, lastNpcScan=0, hudChips={},
    menuVisible=true, firstWindowBuild=true, cameraOwner=nil,
    savedCameraType=nil, savedCameraSubject=nil,
    randomAim={target=nil, part="Head", start=0},
    targetCache=nil, targetCacheTime=0, statsLabel=nil,
    fpsFrames=0, currentFps=0, uiHovered=false, ragebotAnchoredRoot=nil,
    repaintSidebarTheme=nil,
}
function St.releaseCamera()
    if Camera and St.savedCameraType then
        Camera.CameraType = St.savedCameraType
        if St.savedCameraSubject then pcall(function() Camera.CameraSubject = St.savedCameraSubject end) end
    end
    St.savedCameraType=nil; St.savedCameraSubject=nil; St.cameraOwner=nil
end
function St.clearAimState() St.aimLockedTarget=nil; St.aimLockedPart=nil; St.aimLockedSince=0 end
function St.resetAimGain() St.aimGain=1.0; St.aimGainErrPrev=0 end
function St.getAimReference()
    if not Camera then return Vector2.zero end
    local vp = Camera.ViewportSize
    return Vector2.new(vp.X*0.5, vp.Y*0.5)
end
function St.getFOVCenter() return St.getAimReference() end

function St.buildFOV()
    if St.fovGui then pcall(function() St.fovGui:Destroy() end) end
    St.fovGui = H.new("ScreenGui", {Name="AeroFOV", ResetOnSpawn=false, IgnoreGuiInset=false,
        DisplayOrder=2147483640, ZIndexBehavior=Enum.ZIndexBehavior.Sibling, Parent=GuiParent})
    St.fovCircle = H.new("Frame", {Name="Circle", AnchorPoint=Vector2.new(0.5,0.5),
        Position=UDim2.fromScale(0.5,0.5),
        Size=UDim2.fromOffset(Settings.Aimbot.FOVSize*2, Settings.Aimbot.FOVSize*2),
        BackgroundTransparency=1, BorderSizePixel=0, Parent=St.fovGui})
    pcall(St.applyFOVStyle)
    pcall(St.updateFOV)
end
function St.applyFOVStyle()
    if not St.fovCircle then return end
    for _, c in ipairs(St.fovCircle:GetChildren()) do
        if c:IsA("UIStroke") or (c.Name and c.Name:match("^FovStyle")) then c:Destroy() end
    end
    local corner = St.fovCircle:FindFirstChildOfClass("UICorner")
    if not corner then corner = H.corner(9999, St.fovCircle) end
    local style = Settings.Aimbot.FOVStyle or "Circle"
    local color = Settings.Aimbot.FOVColor or Color3.fromRGB(120,90,240)
    local trans = Settings.Aimbot.FOVTransparency or 0.6
    local size = Settings.Aimbot.FOVSize or 120
    St.fovCircle.Size = UDim2.fromOffset(size*2, size*2)
    if style == "Circle" then
        corner.CornerRadius = UDim.new(0, 9999)
        local s = H.new("UIStroke", {Name="FovStyleStroke", Color=color, Thickness=1.5,
            Transparency=trans, ApplyStrokeMode=Enum.ApplyStrokeMode.Border, Parent=St.fovCircle})
        H.unbindTheme(s)
    elseif style == "Square" then
        corner.CornerRadius = UDim.new(0, 0)
        local s = H.new("UIStroke", {Name="FovStyleStroke", Color=color, Thickness=1.5,
            Transparency=trans, ApplyStrokeMode=Enum.ApplyStrokeMode.Border, Parent=St.fovCircle})
        H.unbindTheme(s)
    elseif style == "Cross" then
        corner.CornerRadius = UDim.new(0, 9999)
        local armLen = math.max(6, size * 0.2)
        H.new("Frame", {Name="FovStyleTop", AnchorPoint=Vector2.new(0.5,1), Position=UDim2.new(0.5,0,0.5,-size),
            Size=UDim2.fromOffset(1.5, armLen), BackgroundColor3=color, BackgroundTransparency=trans, BorderSizePixel=0, Parent=St.fovCircle})
        H.new("Frame", {Name="FovStyleBottom", AnchorPoint=Vector2.new(0.5,0), Position=UDim2.new(0.5,0,0.5,size),
            Size=UDim2.fromOffset(1.5, armLen), BackgroundColor3=color, BackgroundTransparency=trans, BorderSizePixel=0, Parent=St.fovCircle})
        H.new("Frame", {Name="FovStyleLeft", AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(0.5,-size,0.5,0),
            Size=UDim2.fromOffset(armLen, 1.5), BackgroundColor3=color, BackgroundTransparency=trans, BorderSizePixel=0, Parent=St.fovCircle})
        H.new("Frame", {Name="FovStyleRight", AnchorPoint=Vector2.new(0,0.5), Position=UDim2.new(0.5,size,0.5,0),
            Size=UDim2.fromOffset(armLen, 1.5), BackgroundColor3=color, BackgroundTransparency=trans, BorderSizePixel=0, Parent=St.fovCircle})
    elseif style == "Dot" then
        corner.CornerRadius = UDim.new(0, 9999)
        local ds = math.max(4, size * 0.08)
        H.new("Frame", {Name="FovStyleDot", AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new(0.5,0,0.5,0),
            Size=UDim2.fromOffset(ds, ds), BackgroundColor3=color, BackgroundTransparency=trans, BorderSizePixel=0, Parent=St.fovCircle})
    end
end
function St.updateFOV()
    if not St.fovCircle or not St.fovGui then return end
    St.fovCircle.Size = UDim2.fromOffset(Settings.Aimbot.FOVSize*2, Settings.Aimbot.FOVSize*2)
    St.fovGui.Enabled = Settings.Aimbot.ShowFOV
    local s = St.fovCircle:FindFirstChild("FovStyleStroke")
    if s then
        if not Settings.Aimbot.Rainbow then s.Color = Settings.Aimbot.FOVColor end
        s.Transparency = Settings.Aimbot.FOVTransparency
    end
end

function St.buildSAFOV()
    if St.saFovGui then pcall(function() St.saFovGui:Destroy() end) end
    St.saFovGui = H.new("ScreenGui", {Name="AeroSAFOV", ResetOnSpawn=false, IgnoreGuiInset=false,
        DisplayOrder=2147483639, ZIndexBehavior=Enum.ZIndexBehavior.Sibling, Parent=GuiParent})
    St.saFovCircle = H.new("Frame", {Name="Circle", AnchorPoint=Vector2.new(0.5,0.5),
        Position=UDim2.fromScale(0.5,0.5),
        Size=UDim2.fromOffset(Settings.SilentAim.FOVSize*2, Settings.SilentAim.FOVSize*2),
        BackgroundTransparency=1, BorderSizePixel=0, Parent=St.saFovGui})
    H.corner(9999, St.saFovCircle)
    local s = H.new("UIStroke", {Color=Settings.SilentAim.FOVColor, Thickness=1.5,
        Transparency=Settings.SilentAim.FOVTransparency,
        ApplyStrokeMode=Enum.ApplyStrokeMode.Border, Parent=St.saFovCircle})
    H.unbindTheme(s)
    St.saFovGui.Enabled = Settings.SilentAim.ShowFOV and Settings.SilentAim.Enabled
end
function St.updateSAFOV()
    if not St.saFovCircle or not St.saFovGui then return end
    St.saFovCircle.Size = UDim2.fromOffset(Settings.SilentAim.FOVSize*2, Settings.SilentAim.FOVSize*2)
    St.saFovGui.Enabled = Settings.SilentAim.ShowFOV and Settings.SilentAim.Enabled
    local s = St.saFovCircle:FindFirstChildOfClass("UIStroke")
    if s then s.Color = Settings.SilentAim.FOVColor; s.Transparency = Settings.SilentAim.FOVTransparency end
end

function St.buildTBFOV()
    if St.tbFovGui then pcall(function() St.tbFovGui:Destroy() end) end
    St.tbFovGui = H.new("ScreenGui", {Name="AeroTBFOV", ResetOnSpawn=false, IgnoreGuiInset=false,
        DisplayOrder=2147483638, ZIndexBehavior=Enum.ZIndexBehavior.Sibling, Parent=GuiParent})
    St.tbFovCircle = H.new("Frame", {Name="Circle", AnchorPoint=Vector2.new(0.5,0.5),
        Position=UDim2.fromScale(0.5,0.5),
        Size=UDim2.fromOffset(Settings.Triggerbot.FOVSize*2, Settings.Triggerbot.FOVSize*2),
        BackgroundTransparency=1, BorderSizePixel=0, Parent=St.tbFovGui})
    H.corner(9999, St.tbFovCircle)
    local s = H.new("UIStroke", {Color=Settings.Triggerbot.FOVColor, Thickness=1.5,
        Transparency=Settings.Triggerbot.FOVTransparency,
        ApplyStrokeMode=Enum.ApplyStrokeMode.Border, Parent=St.tbFovCircle})
    H.unbindTheme(s)
    St.tbFovGui.Enabled = Settings.Triggerbot.ShowFOV and Settings.Triggerbot.Enabled
end
function St.updateTBFOV()
    if not St.tbFovCircle or not St.tbFovGui then return end
    St.tbFovCircle.Size = UDim2.fromOffset(Settings.Triggerbot.FOVSize*2, Settings.Triggerbot.FOVSize*2)
    St.tbFovGui.Enabled = Settings.Triggerbot.ShowFOV and Settings.Triggerbot.Enabled
    local s = St.tbFovCircle:FindFirstChildOfClass("UIStroke")
    if s then s.Color = Settings.Triggerbot.FOVColor; s.Transparency = Settings.Triggerbot.FOVTransparency end
end

local HUD_FEATURES = {
    {key="Aimbot", label="AIMBOT", get=function() return Settings.Aimbot.Enabled end},
    {key="SilentAim", label="SILENT", get=function() return Settings.SilentAim.Enabled end},
    {key="Triggerbot", label="TRIGGER", get=function() return Settings.Triggerbot.Enabled end},
    {key="Ragebot", label="RAGEBOT", get=function() return Settings.Ragebot.Enabled end},
    {key="ESP", label="ESP", get=function() return Settings.Players.Enabled end},
    {key="Fly", label="FLY", get=function() return Settings.Movement.Fly end},
    {key="Noclip", label="NOCLIP", get=function() return Settings.Movement.Noclip end},
}
function St.buildHUD()
    if St.hudGui then pcall(function() St.hudGui:Destroy() end) end
    St.hudGui = H.new("ScreenGui", {Name="AeroHUD", ResetOnSpawn=false, IgnoreGuiInset=true,
        DisplayOrder=2147483641, ZIndexBehavior=Enum.ZIndexBehavior.Sibling, Parent=GuiParent})
    St.hudContainer = H.new("Frame", {Name="HUD", AnchorPoint=Vector2.new(0,0),
        Position=UDim2.new(2/8, 0, 0, 10), Size=UDim2.new(0,0,0,22),
        BackgroundTransparency=1, AutomaticSize=Enum.AutomaticSize.X, Parent=St.hudGui})
    H.new("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, Padding=UDim.new(0,12),
        SortOrder=Enum.SortOrder.LayoutOrder, VerticalAlignment=Enum.VerticalAlignment.Center, Parent=St.hudContainer})
    St.hudChips = {}
    for i, f in ipairs(HUD_FEATURES) do
        local chip = H.new("Frame", {Size=UDim2.fromOffset(0,20), AutomaticSize=Enum.AutomaticSize.X,
            BackgroundTransparency=1, BorderSizePixel=0, LayoutOrder=i, Visible=false, Parent=St.hudContainer})
        local lbl = H.new("TextLabel", {Text=f.label, Font=FontBold, TextSize=13, TextColor3=T.acc,
            BackgroundTransparency=1, Size=UDim2.new(0,0,1,0), AutomaticSize=Enum.AutomaticSize.X,
            TextStrokeColor3=Color3.new(0,0,0), TextStrokeTransparency=0.6, TextTransparency=1, Parent=chip})
        St.hudChips[f.key] = {frame=chip, label=lbl, active=false, def=f}
    end
end
function St.updateHUD()
    if not St.hudGui then return end
    St.hudGui.Enabled = Settings.UI.ShowEnabled
    if not St.hudGui.Enabled then return end
    for _, chip in pairs(St.hudChips) do
        local want = chip.def.get()
        if want ~= chip.active then
            chip.active = want
            if want then
                chip.frame.Visible = true; chip.label.TextColor3 = T.acc; chip.label.TextTransparency = 0
            else
                Svc.TS:Create(chip.label, TweenInfo.new(0.18), {TextTransparency=1}):Play()
                task.delay(0.2, function() if not chip.active then chip.frame.Visible = false end end)
            end
        end
    end
end

local npcPending = {}; local npcCacheDirty = false
local function tryRegisterNpc(model)
    if not model or not model.Parent or not model:IsA("Model") then return end
    local hum = model:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health <= 0 then return end
    if Svc.Players:GetPlayerFromCharacter(model) then return end
    if model == LP.Character then return end
    local root = G.getRootPart(model); if not root then return end
    local cache = St.npcCache
    for i = 1, #cache do if cache[i].model == model then return end end
    cache[#cache+1] = {model=model, hum=hum, root=root}
end
function St.scanNPCs()
    if next(npcPending) then
        local p = npcPending; npcPending = {}
        for m in pairs(p) do tryRegisterNpc(m) end
    end
    if npcCacheDirty then
        npcCacheDirty = false
        local cache = St.npcCache; local n = 0
        for i = 1, #cache do
            local e = cache[i]
            if e.model.Parent and e.hum.Parent and e.hum.Health > 0 then n = n + 1; cache[n] = e end
        end
        for i = #cache, n + 1, -1 do cache[i] = nil end
    end
end

track(Svc.WS.DescendantAdded:Connect(function(obj)
    if obj:IsA("Humanoid") then
        task.defer(function()
            local p = obj.Parent; if p and p:IsA("Model") then npcPending[p] = true end
        end)
    end
end))
track(Svc.WS.DescendantRemoving:Connect(function(obj)
    if obj:IsA("Humanoid") or obj:IsA("Model") then npcCacheDirty = true end
end))

task.spawn(function()
    local stack = {Svc.WS}; local processed = 0
    while #stack > 0 do
        if unloaded then return end
        local node = stack[#stack]; stack[#stack] = nil
        local children = node:GetChildren()
        for i = 1, #children do
            local c = children[i]
            if c:IsA("Humanoid") then
                local p = c.Parent; if p and p:IsA("Model") then tryRegisterNpc(p) end
            elseif c:IsA("Model") or c:IsA("Folder") then stack[#stack+1] = c end
            processed = processed + 1
        end
        if processed >= 500 then processed = 0; task.wait() end
    end
end)

function St.getTargets()
    local now = tick()
    if St.targetCache and (now - St.targetCacheTime) < 0.05 then return St.targetCache end
    local list = {}
    local includeNPCs = Settings.Players.ShowNPCs or Settings.Aimbot.TargetNPCs or Settings.Ragebot.Enabled
        or Settings.Triggerbot.TargetNPCs or Settings.SilentAim.Enabled
    if includeNPCs then
        St.scanNPCs()
        for _, e in ipairs(St.npcCache) do
            if e.model.Parent and e.hum.Parent and e.root.Parent and e.hum.Health > 0 then
                list[#list+1] = {plr=nil, hum=e.hum, root=e.root, model=e.model}
            end
        end
    end
    for _, p in ipairs(Svc.Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            local root = G.getRootPart(p.Character)
            if hum and root then list[#list+1] = {plr=p, hum=hum, root=root, model=p.Character} end
        end
    end
    St.targetCache = list; St.targetCacheTime = now
    return list
end

function St.pickAimPartWith(t, setting)
    if not t.model then return nil end
    if setting == "Random" then
        if St.randomAim.target ~= t.model then
            St.randomAim.target = t.model
            St.randomAim.part = (math.random() < 0.5) and "Head" or "Torso"
            St.randomAim.start = tick()
        elseif tick() - St.randomAim.start > 0.5 then
            St.randomAim.part = (St.randomAim.part == "Head") and "Torso" or "Head"
            St.randomAim.start = tick()
        end
        return St.randomAim.part == "Head"
            and (G.getHeadPart(t.model) or G.getTorsoPart(t.model))
            or (G.getTorsoPart(t.model) or G.getHeadPart(t.model))
    elseif setting == "Torso" then
        return G.getTorsoPart(t.model) or G.getHeadPart(t.model)
    end
    return G.getHeadPart(t.model) or G.getTorsoPart(t.model)
end
function St.worldToScreen(world)
    if not Camera then return nil end
    local sp, onScreen = Camera:WorldToViewportPoint(world)
    if not onScreen then return nil end
    return Vector2.new(sp.X, sp.Y)
end
function St.findBestTarget(cfg, partPicker)
    if not Camera then return nil end
    local center = St.getFOVCenter()
    local best, bestScore = nil, math.huge
    local checkSpawn = cfg.SpawnProtCheck and true or false
    for _, t in ipairs(St.getTargets()) do
        if not t.plr and not cfg.TargetNPCs then goto continue end
        if t.plr and cfg.TeamCheck and G.sameTeam(LP, t.plr) then goto continue end
        if cfg.DeadCheck and t.hum.Health <= 0 then goto continue end
        if checkSpawn and G.isSpawnProtected(t.plr, t.hum, t.model) then goto continue end
        local part = partPicker(t); if not part then goto continue end
        local sp = St.worldToScreen(part.Position); if not sp then goto continue end
        local d = (sp - center).Magnitude
        if d > cfg.FOVSize then goto continue end
        if cfg.WallCheck and not G.hasLOS(part.Position, t.model) then goto continue end
        local dist3 = (Camera.CFrame.Position - part.Position).Magnitude
        if dist3 > (cfg.MaxDistance or math.huge) then goto continue end
        if d < bestScore then bestScore, best = d, t end
        ::continue::
    end
    return best
end

function St.aimStep(_dt)
    if unloaded or not Camera then return end
    if Settings.Ragebot.Enabled then St.clearAimState(); return end
    if not Settings.Aimbot.Enabled or not G.alive() or not St.aimingHeld then St.clearAimState(); return end
    local t
    if St.aimLockedTarget then
        local L = St.aimLockedTarget
        local valid = true
        if not L.plr and not Settings.Aimbot.TargetNPCs then valid = false end
        if not (L and L.model and L.model.Parent) then valid = false
        elseif not (L.hum and L.hum.Health > 0) then valid = false
        else
            if Settings.Aimbot.TeamCheck and L.plr and G.sameTeam(LP, L.plr) then valid = false end
            if valid and Settings.Aimbot.SpawnProtCheck and G.isSpawnProtected(L.plr, L.hum, L.model) then valid = false end
            if valid then
                local part = St.aimLockedPart
                if not (part and part.Parent) then
                    part = St.pickAimPartWith(L, Settings.Aimbot.AimPart)
                    St.aimLockedPart = part
                end
                if not part then valid = false
                else
                    local dist3 = (Camera.CFrame.Position - part.Position).Magnitude
                    if dist3 > Settings.Aimbot.MaxDistance then valid = false
                    elseif Settings.Aimbot.WallCheck and not G.hasLOS(part.Position, L.model) then valid = false end
                end
            end
        end
        if valid then t = L else St.clearAimState() end
    end
    if not t then
        t = St.findBestTarget(Settings.Aimbot, function(tt) return St.pickAimPartWith(tt, Settings.Aimbot.AimPart) end)
        if t then
            St.aimLockedTarget = t
            St.aimLockedPart = St.pickAimPartWith(t, Settings.Aimbot.AimPart)
            St.aimLockedSince = tick()
            St.resetAimGain()
        end
    end
end

-- ============================================================
-- SILENT AIM
-- ============================================================
SA = {hooked=false, oldNamecall=nil}

function SA.getTarget()
    if not Settings.SilentAim.Enabled or not Camera then return nil end
    local vp = Camera.ViewportSize
    local cx, cy = vp.X * 0.5, vp.Y * 0.5
    if Settings.SilentAim.StickyAim and St.saTarget then
        local L = St.saTarget
        if L.model and L.model.Parent and L.hum and L.hum.Health > 0 then
            local part = St.pickAimPartWith(L, Settings.SilentAim.Bodypart)
            if part then
                local sp = Camera:WorldToViewportPoint(part.Position)
                if sp.Z > 0 then
                    local d = math.sqrt((sp.X - cx)^2 + (sp.Y - cy)^2)
                    if d <= Settings.SilentAim.FOVSize then return L end
                end
            end
        end
        St.saTarget = nil
    end
    local best, bestDist = nil, math.huge
    for _, t in ipairs(St.getTargets()) do
        if t.plr and Settings.SilentAim.TeamCheck and G.sameTeam(LP, t.plr) then goto continue end
        if t.hum.Health <= 0 then goto continue end
        local part = St.pickAimPartWith(t, Settings.SilentAim.Bodypart)
        if not part then goto continue end
        local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
        if onScreen and sp.Z > 0 then
            local d = math.sqrt((sp.X - cx)^2 + (sp.Y - cy)^2)
            if d <= Settings.SilentAim.FOVSize and d < bestDist then bestDist = d; best = t end
        end
        ::continue::
    end
    St.saTarget = best
    return best
end

function SA.hook()
    if SA.hooked then return end
    if type(getrawmetatable) ~= "function" or type(newcclosure) ~= "function"
       or type(getnamecallmethod) ~= "function" then
        warn("[Aero Lite] silent aim unsupported"); return
    end
    local mt = getrawmetatable(game); if not mt then return end
    local old = mt.__namecall
    if type(setreadonly) == "function" then setreadonly(mt, false) end
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if not checkcaller() and Settings.SilentAim.Enabled
           and (method == "Raycast" or method == "FindPartOnRay") then
            local target = SA.getTarget()
            if target then
                local part = St.pickAimPartWith(target, Settings.SilentAim.Bodypart)
                if part then
                    local args = {...}
                    if method == "Raycast" then
                        local origin = args[1]
                        local dir = args[2]
                        local len = dir.Magnitude
                        args[2] = (part.Position - origin).Unit * len
                    elseif method == "FindPartOnRay" then
                        local ray = args[1]
                        args[1] = Ray.new(ray.Origin, (part.Position - ray.Origin).Unit * ray.Direction.Magnitude)
                    end
                    return old(self, unpack(args))
                end
            end
        end
        return old(self, ...)
    end)
    if type(setreadonly) == "function" then setreadonly(mt, true) end
    SA.oldNamecall = old; SA.hooked = true
end
function SA.unhook()
    if not SA.hooked then return end
    if type(getrawmetatable) ~= "function" then SA.hooked = false; return end
    local mt = getrawmetatable(game)
    if mt and SA.oldNamecall then
        if type(setreadonly) == "function" then setreadonly(mt, false) end
        mt.__namecall = SA.oldNamecall
        if type(setreadonly) == "function" then setreadonly(mt, true) end
    end
    SA.hooked = false; SA.oldNamecall = nil
end

-- ============================================================
-- TRIGGERBOT
-- ============================================================
local function sendClick()
    if type(mouse1click) == "function" then
        if pcall(mouse1click) then return true end
    end
    if type(mouse1press) == "function" and type(mouse1release) == "function" then
        if pcall(function() mouse1press(); task.wait(0.01); mouse1release() end) then return true end
    end
    if Svc.VIM then
        local mp = Svc.UIS:GetMouseLocation()
        if pcall(function()
            Svc.VIM:SendMouseButtonEvent(mp.X, mp.Y, 0, true, game, 0)
            task.wait(0.005)
            Svc.VIM:SendMouseButtonEvent(mp.X, mp.Y, 0, false, game, 0)
        end) then return true end
    end
    return false
end

function St.triggerStep()
    if unloaded then return end
    if not Settings.Triggerbot.Enabled then return end
    if not G.alive() then return end
    if St.uiHovered then return end
    if not Camera then return end
    local now = tick()
    if now - (St.triggerLastFire or 0) < (Settings.Triggerbot.Delay / 1000) then return end
    local t = St.findBestTarget(Settings.Triggerbot, function(tt)
        return St.pickAimPartWith(tt, Settings.Triggerbot.AimPart)
    end)
    if t then
        if sendClick() then St.triggerLastFire = now end
    end
end

-- ============================================================
-- ESP
-- ============================================================
function St.ensureESPGui()
    if St.espGui and St.espGui.Parent then return end
    St.espGui = H.new("ScreenGui", {Name="AeroESP", ResetOnSpawn=false, IgnoreGuiInset=false,
        DisplayOrder=2147483637, ZIndexBehavior=Enum.ZIndexBehavior.Sibling, Parent=GuiParent})
end
function St.colorForTarget(plr, isNPC)
    if isNPC then
        if Settings.Npcs.RainbowNPC then return rainbowColor() end
        return Settings.Npcs.ESPColor
    end
    local isTeam = Settings.Players.TeamCheck and plr ~= nil and G.sameTeam(LP, plr)
    if isTeam then
        if Settings.Players.RainbowTeam then return rainbowColor() end
        return Settings.Players.TeammateColor
    else
        if Settings.Players.RainbowEnemy then return rainbowColor() end
        return Settings.Players.EnemyColor
    end
end
function St.destroyESP(d)
    if not d then return end
    for _, k in ipairs({"nameTag","cham","box","healthBar","tracer"}) do
        if d[k] then pcall(function() d[k]:Destroy() end) end
    end
end
function St.clearESP()
    local keys = {}; for k in pairs(St.espCache) do keys[#keys+1] = k end
    for _, k in ipairs(keys) do St.destroyESP(St.espCache[k]); St.espCache[k] = nil end
end
function St.clearESPByType(isNPC)
    isNPC = isNPC and true or false
    local keys = {}
    for k, d in pairs(St.espCache) do if (d.isNPC and true or false) == isNPC then keys[#keys+1] = k end end
    for _, k in ipairs(keys) do St.destroyESP(St.espCache[k]); St.espCache[k] = nil end
end
function St.destroyESPFor(plr) if St.espCache[plr] then St.destroyESP(St.espCache[plr]); St.espCache[plr] = nil end end
function St.buildESPFor(key, model, isNPC)
    local d = {isNPC=isNPC}
    local nameTag = H.new("BillboardGui", {AlwaysOnTop=true, Size=UDim2.fromOffset(220,34),
        StudsOffset=Vector3.new(0,3.4,0), Parent=St.espGui, Enabled=Settings.Players.ShowName})
    d.nameTag = nameTag
    d.name = H.new("TextLabel", {Size=UDim2.new(1,0,0,16), Position=UDim2.fromOffset(0,0),
        BackgroundTransparency=1, Font=FontBold, TextSize=14, TextColor3=Color3.new(1,1,1),
        TextStrokeColor3=Color3.new(0,0,0), TextStrokeTransparency=0.35, Text=tostring(key), Parent=nameTag})
    d.sub = H.new("TextLabel", {Size=UDim2.new(1,0,0,14), Position=UDim2.fromOffset(0,16),
        BackgroundTransparency=1, Font=FontMed, TextSize=12, TextColor3=Color3.fromRGB(220,220,220),
        TextStrokeColor3=Color3.new(0,0,0), TextStrokeTransparency=0.5, Text="", Parent=nameTag})
    return d
end
function St.ensureESPChildren(d, model)
    if Settings.Players.Chams then
        if not d.cham or not d.cham.Parent then
            if d.cham then pcall(function() d.cham:Destroy() end) end
            d.cham = H.new("Highlight", {FillColor=Settings.Players.EnemyColor, OutlineColor=Color3.new(0,0,0),
                FillTransparency=0.55, OutlineTransparency=0.4,
                DepthMode=Enum.HighlightDepthMode.AlwaysOnTop, Parent=model})
        end
    else
        if d.cham then pcall(function() d.cham:Destroy() end); d.cham = nil end
    end
end
function St.hideESP(d)
    if d.nameTag then d.nameTag.Enabled = false end
    if d.cham then d.cham.Enabled = false end
    if d.box then d.box.Visible = false end
    if d.healthBar then d.healthBar.Visible = false end
    if d.tracer then d.tracer.Visible = false end
end
local function getScreenBBox(model)
    if not Camera or not model then return nil end
    local ok, cf, size = pcall(function() return model:GetBoundingBox() end)
    if not ok or not cf or not size then return nil end
    local hx, hy, hz = size.X/2, size.Y/2, size.Z/2
    local corners = {
        Vector3.new(hx,hy,hz), Vector3.new(-hx,hy,hz), Vector3.new(hx,-hy,hz), Vector3.new(-hx,-hy,hz),
        Vector3.new(hx,hy,-hz), Vector3.new(-hx,hy,-hz), Vector3.new(hx,-hy,-hz), Vector3.new(-hx,-hy,-hz),
    }
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local anyValid = false
    for _, c in ipairs(corners) do
        local wp = (cf * CFrame.new(c.X, c.Y, c.Z)).Position
        local sp = Camera:WorldToViewportPoint(wp)
        if sp.Z > 0 then
            anyValid = true
            if sp.X < minX then minX = sp.X end; if sp.X > maxX then maxX = sp.X end
            if sp.Y < minY then minY = sp.Y end; if sp.Y > maxY then maxY = sp.Y end
        end
    end
    if not anyValid or maxX - minX < 1 or maxY - minY < 1 then return nil end
    return {x1=minX, y1=minY, x2=maxX, y2=maxY, w=maxX-minX, h=maxY-minY}
end
St.getScreenBBox = getScreenBBox

function St.updateESP()
    if unloaded then return end
    local playersOn = Settings.Players.Enabled
    local npcsOn = Settings.Players.ShowNPCs
    if not playersOn then St.clearESPByType(false) end
    if not npcsOn then St.clearESPByType(true) end
    if not playersOn and not npcsOn then return end
    pcall(St.ensureESPGui)
    if not St.espGui or not St.espGui.Parent or not Camera then return end
    local nameOn = Settings.Players.ShowName
    local showHp = Settings.Players.ShowHealth
    local showDist = Settings.Players.ShowDistance
    local chamsOn = Settings.Players.Chams
    local showTeam = Settings.Players.ShowTeam
    local teamCheck = Settings.Players.TeamCheck
    local rangeSq = Settings.Players.Range * Settings.Players.Range
    local boxOn = Settings.Players.ShowBox
    local hpBarOn = Settings.Players.ShowHealthBar
    local tracerOn = Settings.Players.ShowTracers
    local tracerOrigin = Settings.Players.TracerOrigin
    local vp = Camera.ViewportSize
    local camPos = Camera.CFrame.Position
    local seen = {}
    for _, tgt in ipairs(St.getTargets()) do
        local plr = tgt.plr; local isNPC = plr == nil
        local model, hum, root = tgt.model, tgt.hum, tgt.root
        local key = plr or model
        if not key then goto continue end
        if (isNPC and not npcsOn) or (not isNPC and not playersOn) then
            local s = St.espCache[key]; if s then St.destroyESP(s); St.espCache[key] = nil end
            goto continue
        end
        seen[key] = true
        if not (root and hum and hum.Health > 0) then
            local d = St.espCache[key]; if d then St.hideESP(d) end
            goto continue
        end
        local delta = camPos - root.Position
        local distSq = delta:Dot(delta)
        if distSq > rangeSq then
            local d = St.espCache[key]; if d then St.hideESP(d) end
            goto continue
        end
        local dist = math.sqrt(distSq)
        local isTeam = teamCheck and plr ~= nil and G.sameTeam(LP, plr)
        if isTeam and not showTeam then
            local d = St.espCache[key]; if d then St.hideESP(d) end
            goto continue
        end
        local d = St.espCache[key]
        if d and d.cham and not d.cham.Parent then
            St.destroyESP(d); St.espCache[key] = nil; d = nil
        end
        if not d then d = St.buildESPFor(key, model, isNPC); St.espCache[key] = d end
        d.plr = plr; d.hum = hum
        St.ensureESPChildren(d, model)
        local col = St.colorForTarget(plr, isNPC)
        if nameOn and d.nameTag then
            if not d.nameTag.Enabled then d.nameTag.Enabled = true end
            if d.nameTag.Adornee ~= root then d.nameTag.Adornee = root end
            local nameText = (plr and plr.Name) or (model.Name or "NPC")
            if d.name.Text ~= nameText then d.name.Text = nameText end
            if d.name.TextColor3 ~= col then d.name.TextColor3 = col end
            local distanceInt = math.floor(dist)
            local hpInt = nil
            if showHp then
                local hp, mx = G.healthInfo(plr, hum, model)
                if mx and mx > 0 then hpInt = math.floor(hp + 0.5) end
            end
            local parts = {}
            if showDist then parts[#parts+1] = distanceInt .. "m" end
            if hpInt ~= nil then parts[#parts+1] = hpInt .. " HP" end
            local subText = table.concat(parts, "  |  ")
            if d.sub.Text ~= subText then d.sub.Text = subText end
            d.sub.Visible = showDist or hpInt ~= nil
        elseif d.nameTag then d.nameTag.Enabled = false end
        if chamsOn and d.cham then
            if not d.cham.Enabled then d.cham.Enabled = true end
            if d.cham.FillColor ~= col then d.cham.FillColor = col end
            if d.cham.Parent ~= model then d.cham.Parent = model end
        elseif d.cham then d.cham.Enabled = false end
        local bbox = (boxOn or hpBarOn or tracerOn) and getScreenBBox(model) or nil
        if boxOn and bbox then
            if not d.box then
                d.box = H.new("Frame", {BackgroundTransparency=1, BorderSizePixel=0, Visible=false, ZIndex=2, Parent=St.espGui})
                H.corner(2, d.box)
                d.boxStroke = H.new("UIStroke", {Thickness=1, ApplyStrokeMode=Enum.ApplyStrokeMode.Border, Parent=d.box})
                H.unbindTheme(d.boxStroke)
            end
            d.box.Visible = true
            d.box.Position = UDim2.fromOffset(bbox.x1, bbox.y1)
            d.box.Size = UDim2.fromOffset(bbox.w, bbox.h)
            d.boxStroke.Color = col
        elseif d.box then d.box.Visible = false end
        if hpBarOn and bbox then
            if not d.healthBar then
                d.healthBar = H.new("Frame", {BackgroundColor3=Color3.fromRGB(20,20,20), BorderSizePixel=0, Visible=false, ZIndex=2, Parent=St.espGui})
                H.new("UIStroke", {Thickness=1, ApplyStrokeMode=Enum.ApplyStrokeMode.Border, Color=Color3.new(0,0,0), Parent=d.healthBar})
                d.healthBarFill = H.new("Frame", {BackgroundColor3=Color3.fromRGB(60,220,100), BorderSizePixel=0, Size=UDim2.fromScale(1,1), Parent=d.healthBar})
            end
            d.healthBar.Visible = true
            d.healthBar.Position = UDim2.fromOffset(bbox.x1 - 6, bbox.y1)
            d.healthBar.Size = UDim2.fromOffset(3, bbox.h)
            local hp, mx = G.healthInfo(plr, hum, model)
            local ratio = H.clamp(hp / math.max(mx, 1), 0, 1)
            d.healthBarFill.Size = UDim2.fromScale(1, ratio)
            d.healthBarFill.Position = UDim2.fromScale(0, 1 - ratio)
            d.healthBarFill.BackgroundColor3 = Color3.fromHSV(0.33 * ratio, 0.8, 1)
        elseif d.healthBar then d.healthBar.Visible = false end
        if tracerOn and bbox then
            if not d.tracer then
                d.tracer = H.new("Frame", {BackgroundColor3=Color3.new(1,1,1), BorderSizePixel=0,
                    AnchorPoint=Vector2.new(0.5,0.5), Visible=false, ZIndex=1, Parent=St.espGui})
            end
            d.tracer.Visible = true
            local origin
            if tracerOrigin == "Center" then origin = Vector2.new(vp.X/2, vp.Y/2)
            elseif tracerOrigin == "Bottom" then origin = Vector2.new(vp.X/2, vp.Y)
            else origin = Vector2.new(vp.X/2, 0) end
            local tx = (bbox.x1 + bbox.x2) / 2; local ty = bbox.y1
            local dx = tx - origin.X; local dy = ty - origin.Y
            local len = math.sqrt(dx*dx + dy*dy)
            if len < 0.5 then d.tracer.Visible = false
            else
                d.tracer.Size = UDim2.fromOffset(len, 1)
                d.tracer.Position = UDim2.fromOffset((origin.X + tx) / 2, (origin.Y + ty) / 2)
                d.tracer.Rotation = math.deg(ATAN2(dy, dx))
                d.tracer.BackgroundColor3 = col
            end
        elseif d.tracer then d.tracer.Visible = false end
        ::continue::
    end
    for k, d in pairs(St.espCache) do
        if not seen[k] then St.destroyESP(d); St.espCache[k] = nil end
    end
end

function St.moveStep()
    if unloaded or not Camera then return end
    local ch = LP.Character; if not ch then return end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    local root = G.getRootPart(ch)
    if not (hum and root) then return end
    if Settings.Movement.Fly then
        if not St.flyBV or not St.flyBV.Parent then
            St.flyBV = H.new("BodyVelocity", {MaxForce=Vector3.new(1e5,1e5,1e5), P=1250, Parent=root})
        end
        local move = Vector3.new(0,0,0)
        if Svc.UIS:IsKeyDown(Enum.KeyCode.W) then move += Camera.CFrame.LookVector end
        if Svc.UIS:IsKeyDown(Enum.KeyCode.S) then move -= Camera.CFrame.LookVector end
        if Svc.UIS:IsKeyDown(Enum.KeyCode.A) then move -= Camera.CFrame.RightVector end
        if Svc.UIS:IsKeyDown(Enum.KeyCode.D) then move += Camera.CFrame.RightVector end
        if Svc.UIS:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0,1,0) end
        if Svc.UIS:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.new(0,1,0) end
        if move.Magnitude > 0 then move = move.Unit end
        St.flyBV.Velocity = move * Settings.Movement.FlySpeed
    elseif St.flyBV then
        pcall(function() St.flyBV:Destroy() end); St.flyBV = nil
    end
    if Settings.Movement.Noclip then
        local now = tick()
        if now - St.noclipLastTick >= 0.1 then
            St.noclipLastTick = now
            for _, p in ipairs(ch:GetDescendants()) do
                if p:IsA("BasePart") then
                    if St.noclipSaved[p] == nil then St.noclipSaved[p] = p.CanCollide end
                    if p.CanCollide then p.CanCollide = false end
                end
            end
        end
    else
        for p, orig in pairs(St.noclipSaved) do
            if p.Parent and p:IsA("BasePart") then p.CanCollide = orig end
        end
        St.noclipSaved = {}
    end
    if not Settings.Ragebot.Enabled and St.ragebotAnchoredRoot then
        local a = St.ragebotAnchoredRoot
        if a.Parent and a.Anchored then pcall(function() a.Anchored = false end) end
        St.ragebotAnchoredRoot = nil
    end
end

RB = {target=nil, lockUntil=0, savedCFrame=nil, savedVelocity=nil, savedAutoRotate=true,
    savedWalkSpeed=nil, savedCharacter=nil, savedPlatformStand=false, savedMouseBehavior=nil, active=false}
function RB.save()
    local char = LP.Character
    local hrp = char and G.getRootPart(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    RB.savedCharacter = char
    if hrp then RB.savedCFrame = hrp.CFrame; RB.savedVelocity = hrp.AssemblyLinearVelocity end
    if hum then
        RB.savedAutoRotate = hum.AutoRotate
        RB.savedWalkSpeed = hum.WalkSpeed
        RB.savedPlatformStand = hum.PlatformStand
        hum.PlatformStand = true
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
    end
    RB.savedMouseBehavior = Svc.UIS.MouseBehavior
    RB.active = true
end
function RB.restore()
    local char = LP.Character
    local same = char ~= nil and char == RB.savedCharacter
    if St.ragebotAnchoredRoot and St.ragebotAnchoredRoot.Parent then
        pcall(function() St.ragebotAnchoredRoot.Anchored = false end)
    end
    St.ragebotAnchoredRoot = nil
    if RB.savedMouseBehavior then pcall(function() Svc.UIS.MouseBehavior = RB.savedMouseBehavior end); RB.savedMouseBehavior = nil end
    if not same then
        RB.savedCFrame=nil; RB.savedVelocity=nil; RB.savedWalkSpeed=nil; RB.savedCharacter=nil
        RB.savedPlatformStand=false; RB.active=false; return
    end
    local hrp = G.getRootPart(char); local hum = char:FindFirstChildOfClass("Humanoid")
    if hrp and RB.savedCFrame then
        if char.PivotTo then pcall(function() char:PivotTo(RB.savedCFrame) end) else hrp.CFrame = RB.savedCFrame end
        hrp.AssemblyLinearVelocity = RB.savedVelocity or Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end
    if hum then
        hum.AutoRotate = RB.savedAutoRotate
        hum.PlatformStand = RB.savedPlatformStand or false
        if RB.savedWalkSpeed ~= nil then hum.WalkSpeed = RB.savedWalkSpeed end
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
    end
    RB.savedCFrame=nil; RB.savedVelocity=nil; RB.savedWalkSpeed=nil
    RB.savedCharacter=nil; RB.savedPlatformStand=false; RB.active=false
end
function RB.reset()
    RB.target = nil; RB.lockUntil = 0
    if RB.active then RB.restore() end
    RB.savedCFrame=nil; RB.savedVelocity=nil; RB.savedCharacter=nil
end
local function rageNamePriority(model)
    if not model then return 50 end
    local n = tostring(model.Name or ""):lower()
    if n:find("explosive") then return -1 end
    if n:find("skeleton") then return 100 end
    return 50
end
function RB.findTarget()
    local myChar = LP.Character; local myRoot = myChar and G.getRootPart(myChar)
    if not myRoot then return nil end
    local best, bestScore = nil, -math.huge
    for _, t in ipairs(St.getTargets()) do
        if not t.hum or t.hum.Health <= 0 or not t.model or not t.model.Parent then goto continue end
        if t.plr and G.sameTeam(LP, t.plr) then goto continue end
        if G.isSpawnProtected(t.plr, t.hum, t.model) then goto continue end
        local pr = rageNamePriority(t.model); if pr < 0 then goto continue end
        local head = G.getHeadPart(t.model); local root = t.root or G.getRootPart(t.model)
        if not head or not root then goto continue end
        local d = (head.Position - myRoot.Position).Magnitude
        if d > RAGE_MAX_DISTANCE then goto continue end
        local score = pr * 100000 - d
        if score > bestScore then bestScore = score; best = t end
        ::continue::
    end
    return best
end
function St.rageStep()
    if unloaded or not Camera then return end
    if not Settings.Ragebot.Enabled or not G.alive() then
        if RB.active then RB.reset() end; return
    end
    local now = tick()
    local cm = LP.Character
    local myRoot = cm and G.getRootPart(cm)
    local myHum = cm and cm:FindFirstChildOfClass("Humanoid")
    if not myRoot or not myHum then if RB.active then RB.reset() end; return end
    if RB.active and RB.savedCharacter ~= cm then
        RB.savedCFrame=nil; RB.savedVelocity=nil; RB.savedWalkSpeed=nil; RB.savedCharacter=nil
        RB.savedPlatformStand=false; RB.active=false; RB.target=nil; RB.lockUntil=0
        if St.ragebotAnchoredRoot and St.ragebotAnchoredRoot.Parent then
            pcall(function() St.ragebotAnchoredRoot.Anchored = false end)
        end
        St.ragebotAnchoredRoot = nil
    end
    if not RB.active then RB.save() end
    myHum.PlatformStand = true; myHum.AutoRotate = false
    local L = RB.target
    local valid = L and RB.lockUntil > now
        and L.hum and L.hum.Health > 0
        and L.model and L.model.Parent
        and L.root and L.root.Parent
        and (L.root.Position - myRoot.Position).Magnitude <= RAGE_MAX_DISTANCE
        and (rageNamePriority(L.model) >= 0)
        and not G.isSpawnProtected(L.plr, L.hum, L.model)
    local t = valid and L or RB.findTarget()
    if t ~= RB.target then RB.target = t end
    if not t then RB.lockUntil = 0; if RB.active then RB.restore() end; return end
    RB.lockUntil = now + 10
    local head = G.getHeadPart(t.model)
    local tRoot = t.root or G.getRootPart(t.model)
    if not head or not tRoot or not tRoot:IsA("BasePart") then
        RB.target=nil; RB.lockUntil=0; if RB.active then RB.restore() end; return
    end
    local above = tRoot.Position + Vector3.new(0, RAGE_ABOVE_DISTANCE, 0)
    local delta = head.Position - above
    local look = (delta.Magnitude < 0.001) and Vector3.new(0,-1,0) or delta.Unit
    local hor = Vector3.new(look.X, 0, look.Z)
    if hor.Magnitude < 0.001 then hor = Vector3.new(1,0,0) else hor = hor.Unit end
    local goal = CFrame.lookAt(above, head.Position, hor)
    if cm.PivotTo then pcall(function() cm:PivotTo(goal) end) else myRoot.CFrame = goal end
    myRoot.AssemblyLinearVelocity = Vector3.zero
    myRoot.AssemblyAngularVelocity = Vector3.zero
    if not myRoot.Anchored then myRoot.Anchored = true end
    St.ragebotAnchoredRoot = myRoot
    if not St.menuVisible then
        if Svc.UIS.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
            pcall(function() Svc.UIS.MouseBehavior = Enum.MouseBehavior.LockCenter end)
        end
    elseif RB.savedMouseBehavior and Svc.UIS.MouseBehavior ~= RB.savedMouseBehavior then
        pcall(function() Svc.UIS.MouseBehavior = RB.savedMouseBehavior end)
    end
end

function St.updateStatsLabel()
    if not St.statsLabel or not St.statsLabel.Parent then return end
    local ping = G.getPing()
    local ps = ping and (tostring(ping) .. "ms") or "--"
    St.statsLabel.Text = "Ping: " .. ps .. "  FPS: " .. tostring(St.currentFps or 0)
end

local mainStarted, lastHUD, lastStatsTick = false, 0, 0
local errLogged = {}
local function safeCall(name, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and not errLogged[name] then errLogged[name] = true; warn("[Aero Lite] " .. name .. ": " .. tostring(err)) end
end
local function mainStep(dt)
    if unloaded then return end
    if not mainStarted then mainStarted = true; print("[Aero Lite] main loop running") end
    if Svc.WS.CurrentCamera ~= Camera then Camera = Svc.WS.CurrentCamera; cachedInset = nil end
    if not Camera then return end
    St.fpsFrames = (St.fpsFrames or 0) + 1
    if Settings.Aimbot.Rainbow or Settings.Players.RainbowEnemy or Settings.Players.RainbowTeam or Settings.Npcs.RainbowNPC then
        rainbowTick(dt)
        if Settings.Aimbot.Rainbow and St.fovCircle then
            local rc = rainbowColor()
            local s = St.fovCircle:FindFirstChild("FovStyleStroke"); if s then s.Color = rc end
            for _, c in ipairs(St.fovCircle:GetChildren()) do
                if c.Name and c.Name:match("^FovStyle") and c:IsA("Frame") then c.BackgroundColor3 = rc end
            end
        end
    end
    safeCall("aimStep", St.aimStep, dt)
    safeCall("triggerStep", St.triggerStep)
    safeCall("moveStep", St.moveStep)
    safeCall("rageStep", St.rageStep)
    local now = tick()
    safeCall("esp", St.updateESP)
    if now - lastHUD > 0.05 then lastHUD = now; safeCall("hud", St.updateHUD) end
    if now - lastStatsTick >= 1 then
        St.currentFps = St.fpsFrames; St.fpsFrames = 0; lastStatsTick = now
        safeCall("statsLabel", St.updateStatsLabel)
    end
end

local MAIN_BIND = "AeroLiteMainStep"
local AIM_CORRECT_BIND = "AeroLiteAimCorrect"
local function aimCorrectStep()
    if unloaded or not Settings.Aimbot.Enabled or Settings.Ragebot.Enabled then return end
    if not St.aimingHeld or not Camera or not mouseMoveRel then return end
    local t = St.aimLockedTarget
    if not (t and t.model and t.model.Parent) then return end
    if not (t.hum and t.hum.Health > 0) then return end
    local part = St.aimLockedPart
    if not (part and part.Parent) then part = St.pickAimPartWith(t, Settings.Aimbot.AimPart); St.aimLockedPart = part end
    if not part then return end
    local sp = Camera:WorldToViewportPoint(part.Position)
    if sp.Z <= 0 then return end
    local ref = St.getAimReference()
    local dx, dy = sp.X - ref.X, sp.Y - ref.Y
    local err = math.sqrt(dx*dx + dy*dy)
    if err < 0.1 then return end
    if St.aimGainErrPrev > 2 and err > 2 then
        local imp = St.aimGainErrPrev - err
        if imp > 1 then St.aimGain = math.min(St.aimGain * 1.05, 20)
        elseif imp < -1 then St.aimGain = math.max(St.aimGain * 0.92, 0.5) end
    end
    local md = Svc.UIS:GetMouseDelta()
    local px = H.clamp(md.X, -500, 500); local py = H.clamp(md.Y, -500, 500)
    local ax = dx * St.aimGain - px; local ay = dy * St.aimGain - py
    St.aimGainErrPrev = err
    if math.abs(ax) < 0.01 and math.abs(ay) < 0.01 then return end
    pcall(mouseMoveRel, ax, ay)
end

pcall(function() Svc.RS:UnbindFromRenderStep(MAIN_BIND) end)
pcall(function() Svc.RS:BindToRenderStep(MAIN_BIND, Enum.RenderPriority.Camera.Value + 50, mainStep) end)
pcall(function() Svc.RS:UnbindFromRenderStep(AIM_CORRECT_BIND) end)
pcall(function() Svc.RS:BindToRenderStep(AIM_CORRECT_BIND, Enum.RenderPriority.Camera.Value + 100, aimCorrectStep) end)
print("[Aero Lite] stage 3: runtime bound")

-- ============================================================
-- WIDGETS
-- ============================================================
local Wg = {}
function Wg.makeToggle(parent, order, opts)
    local value = opts.default == true
    local ct, it
    local row = H.new("TextButton", {Text="", AutoButtonColor=false, BackgroundTransparency=1,
        Size=UDim2.new(1,0,0,26), LayoutOrder=order, Parent=parent})
    local lbl = H.new("TextLabel", {Text=opts.name, Font=FontMed, TextSize=13, TextColor3=T.dim,
        BackgroundTransparency=1, Size=UDim2.new(1,-32,1,0), TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
    local box = H.new("Frame", {AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,0,0.5,0),
        Size=UDim2.fromOffset(20,20), BackgroundColor3=value and T.acc or T.off, BorderSizePixel=0, Parent=row})
    H.corner(5, box)
    local inner = H.new("Frame", {AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5),
        Size=UDim2.fromOffset(value and 12 or 8, value and 12 or 8),
        BackgroundColor3=Color3.new(1,1,1), BorderSizePixel=0,
        BackgroundTransparency=value and 0 or 0.4, Parent=box})
    H.corner(9999, inner)
    local function apply(v, silent)
        local changed = (v ~= value); value = v
        if ct then pcall(function() ct:Cancel() end) end
        if it then pcall(function() it:Cancel() end) end
        ct = Svc.TS:Create(box, TweenInfo.new(0.15), {BackgroundColor3=v and T.acc or T.off})
        it = Svc.TS:Create(inner, TweenInfo.new(0.15), {
            Size=UDim2.fromOffset(v and 12 or 8, v and 12 or 8), BackgroundTransparency=v and 0 or 0.4})
        ct:Play(); it:Play()
        if changed and opts.callback then opts.callback(v) end
        if changed and not silent then PF.queueSave() end
    end
    ThemeRefreshers[#ThemeRefreshers+1] = function()
        if ct then pcall(function() ct:Cancel() end); ct = nil end
        box.BackgroundColor3 = value and T.acc or T.off
    end
    row.MouseEnter:Connect(function() lbl.TextColor3 = T.txt end)
    row.MouseLeave:Connect(function() lbl.TextColor3 = T.dim end)
    row.MouseButton1Click:Connect(function()
        local s = box.Size
        Svc.TS:Create(box, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size=UDim2.fromOffset(s.X.Offset*0.92, s.Y.Offset*0.92)}):Play()
        task.delay(0.07, function()
            if box and box.Parent then
                Svc.TS:Create(box, TweenInfo.new(0.14, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size=s}):Play()
            end
        end)
        apply(not value)
    end)
    return apply
end

function Wg.makeSlider(parent, order, opts)
    local min, max = opts.min, opts.max
    local span = math.max(max - min, 1e-6)
    local fmt = opts.format or function(v) return tostring(math.floor(v+0.5)) end
    local function norm(v)
        v = H.clamp(tonumber(v) or min, min, max)
        if opts.step and opts.step > 0 then v = min + math.floor((v-min)/opts.step + 0.5) * opts.step; v = H.clamp(v, min, max) end
        return v
    end
    local value = norm(opts.default or min)
    local row = H.new("Frame", {Size=UDim2.new(1,0,0,42), BackgroundTransparency=1, LayoutOrder=order, Parent=parent})
    local lbl = H.new("TextLabel", {Text=opts.name, Font=Font, TextSize=13, TextColor3=T.dim, BackgroundTransparency=1,
        Size=UDim2.new(0.6,0,0,16), TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
    local valLbl = H.new("TextLabel", {Text=fmt(value), Font=FontMed, TextSize=13, TextColor3=T.txt, BackgroundTransparency=1,
        AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,0), Size=UDim2.new(0.4,0,0,16),
        TextXAlignment=Enum.TextXAlignment.Right, Parent=row})
    local trackHit = H.new("TextButton", {Text="", AutoButtonColor=false, BackgroundTransparency=1, BorderSizePixel=0,
        Position=UDim2.fromOffset(6,24), Size=UDim2.new(1,-12,0,12), Parent=row})
    local trackVis = H.new("Frame", {AnchorPoint=Vector2.new(0,0.5), Position=UDim2.new(0,0,0.5,0),
        Size=UDim2.new(1,0,0,4), BackgroundColor3=T.trk, BorderSizePixel=0, Parent=trackHit})
    H.corner(2, trackVis)
    local fill = H.new("Frame", {Size=UDim2.fromScale((value-min)/span,1), BackgroundColor3=T.acc, BorderSizePixel=0, Parent=trackVis})
    H.corner(2, fill)
    local knob = H.new("Frame", {AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new((value-min)/span,0,0.5,0),
        Size=UDim2.fromOffset(12,12), BackgroundColor3=Color3.new(1,1,1), BorderSizePixel=0, ZIndex=2, Parent=trackVis})
    H.corner(6, knob)
    local dragging = false
    local function setFromX(x)
        local raw = H.clamp((x - trackVis.AbsolutePosition.X) / math.max(trackVis.AbsoluteSize.X,1), 0, 1)
        value = norm(min + raw * (max - min))
        local pos = (value - min) / span
        fill.Size = UDim2.fromScale(pos, 1)
        knob.Position = UDim2.new(pos, 0, 0.5, 0)
        valLbl.Text = fmt(value)
        if opts.callback then opts.callback(value) end
    end
    trackHit.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true; setFromX(inp.Position.X)
        end
    end)
    trackWindow(Svc.UIS.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            setFromX(inp.Position.X)
        end
    end))
    trackWindow(Svc.UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            if dragging then PF.queueSave() end
            dragging = false
        end
    end))
    return function(v)
        value = norm(v)
        local pos = (value-min)/span
        Svc.TS:Create(fill, TweenInfo.new(0.2), {Size=UDim2.fromScale(pos,1)}):Play()
        Svc.TS:Create(knob, TweenInfo.new(0.2), {Position=UDim2.new(pos,0,0.5,0)}):Play()
        valLbl.Text = fmt(value)
        if opts.callback then opts.callback(value) end
    end
end

function Wg.makeDropdown(parent, order, opts)
    local value = opts.default or opts.options[1]
    local row = H.new("Frame", {Size=UDim2.new(1,0,0,44), BackgroundTransparency=1, LayoutOrder=order, Parent=parent})
    H.new("TextLabel", {Text=opts.name, Font=FontBold, TextSize=13, TextColor3=T.txt, BackgroundTransparency=1,
        Size=UDim2.new(1,0,0,18), TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
    local box = H.new("TextButton", {Text="", AutoButtonColor=false, Position=UDim2.fromOffset(0,20),
        Size=UDim2.new(1,0,0,24), BackgroundColor3=T.sb, BorderSizePixel=0, Parent=row})
    H.corner(6, box); H.stroke(T.st,1,box)
    local lbl = H.new("TextLabel", {Text=tostring(value), Font=FontMed, TextSize=12, TextColor3=T.txt,
        BackgroundTransparency=1, Size=UDim2.new(1,-24,1,0), Position=UDim2.fromOffset(8,0),
        TextXAlignment=Enum.TextXAlignment.Left, Parent=box})
    H.new("TextLabel", {Text="v", Font=FontBold, TextSize=12, TextColor3=T.dim, BackgroundTransparency=1,
        AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,-8,0.5,0), Size=UDim2.fromOffset(12,16), Parent=box})
    local listFrame, closeToken = nil, 0
    local function closeList()
        if not listFrame then return end
        local f = listFrame; listFrame = nil; closeToken = closeToken + 1
        local tok = closeToken
        for i = #openLists, 1, -1 do if openLists[i].frame == f then table.remove(openLists, i) end end
        local w = f.AbsoluteSize.X
        Svc.TS:Create(f, TweenInfo.new(0.15), {Size=UDim2.fromOffset(w, 0)}):Play()
        task.delay(0.15, function() if tok == closeToken then f:Destroy() end end)
    end
    box.MouseButton1Click:Connect(function()
        if listFrame then closeList(); return end
        H.closeAllDropdowns()
        local rowH = 26; local fullH = #opts.options * rowH + 8
        local bA = box.AbsolutePosition; local bS = box.AbsoluteSize
        local oA = OverlayGui.AbsolutePosition; local oS = OverlayGui.AbsoluteSize
        local lx = bA.X - oA.X; local ly = bA.Y - oA.Y + bS.Y + 2
        if ly + fullH > oS.Y then ly = bA.Y - oA.Y - fullH - 2; if ly < 4 then ly = 4 end end
        listFrame = H.new("Frame", {BackgroundColor3=T.sb, BorderSizePixel=0, ZIndex=100,
            Position=UDim2.fromOffset(lx, ly), Size=UDim2.fromOffset(bS.X, 0),
            ClipsDescendants=true, Parent=OverlayGui})
        H.corner(6, listFrame); H.stroke(T.st,1,listFrame)
        local sl = H.new("ScrollingFrame", {Size=UDim2.fromScale(1,1), BackgroundTransparency=1, ScrollBarThickness=3,
            ScrollBarImageColor3=T.st, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y, ZIndex=101, Parent=listFrame})
        H.new("UIListLayout", {Padding=UDim.new(0,2), SortOrder=Enum.SortOrder.LayoutOrder, Parent=sl})
        H.pad(4,4,4,4, sl)
        for i, o in ipairs(opts.options) do
            local r = H.new("TextButton", {Text=tostring(o), Font=FontMed, TextSize=12, TextColor3=T.txt,
                AutoButtonColor=false, BackgroundColor3=(o == value) and T.hov or T.pn,
                Size=UDim2.new(1,-4,0,rowH-2), LayoutOrder=i, ZIndex=102, Parent=sl})
            H.corner(4, r)
            r.MouseButton1Click:Connect(function()
                value = o; lbl.Text = tostring(o)
                if opts.callback then opts.callback(o) end
                PF.queueSave(); closeList()
            end)
        end
        Svc.TS:Create(listFrame, TweenInfo.new(0.18), {Size=UDim2.fromOffset(bS.X, fullH)}):Play()
        table.insert(openLists, {frame=listFrame, close=closeList})
    end)
    return function(v)
        if type(v) == "string" then value = v; lbl.Text = v; if opts.callback then opts.callback(v) end end
    end
end

function Wg.makeColorPicker(parent, order, opts)
    local value = opts.default or COLORS[1].c
    local row = H.new("Frame", {Size=UDim2.new(1,0,0,48), BackgroundTransparency=1, LayoutOrder=order, Parent=parent})
    local titleRow = H.new("Frame", {Size=UDim2.new(1,0,0,22), BackgroundTransparency=1, Parent=row})
    H.new("TextLabel", {Text=opts.name, Font=Font, TextSize=13, TextColor3=T.dim, BackgroundTransparency=1,
        Size=UDim2.new(1,-30,1,0), TextXAlignment=Enum.TextXAlignment.Left, Parent=titleRow})
    local curBox = H.new("Frame", {Name="CustomColorSwatch", AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,0,0.5,0),
        Size=UDim2.fromOffset(22,18), BackgroundColor3=value, BorderSizePixel=0, Parent=titleRow})
    H.corner(4, curBox); H.stroke(T.st,1,curBox)
    local strip = H.new("Frame", {Position=UDim2.fromOffset(0,24), Size=UDim2.new(1,0,0,22),
        BackgroundColor3=T.sb, BorderSizePixel=0, Parent=row})
    H.corner(6, strip); H.stroke(T.st,1,strip)
    H.new("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, Padding=UDim.new(0,4),
        HorizontalAlignment=Enum.HorizontalAlignment.Center, VerticalAlignment=Enum.VerticalAlignment.Center, Parent=strip})
    local swatches = {}
    local function highlight(sel)
        for j, s in ipairs(swatches) do
            Svc.TS:Create(s, TweenInfo.new(0.15), {Size=UDim2.fromOffset(j==sel and 15 or 12, j==sel and 15 or 12)}):Play()
        end
    end
    for i, c in ipairs(COLORS) do
        local sw = H.new("TextButton", {Name="ColorChoiceSwatch", Text="", AutoButtonColor=false,
            BackgroundColor3=c.c, Size=UDim2.fromOffset(12,12), BorderSizePixel=0, Parent=strip})
        H.corner(4, sw)
        swatches[i] = sw
        if c.c == value then sw.Size = UDim2.fromOffset(15,15) end
        sw.MouseButton1Click:Connect(function()
            value = c.c; highlight(i); curBox.BackgroundColor3 = value
            if opts.callback then opts.callback(value) end
            PF.queueSave()
        end)
    end
    return function(v)
        value = v; curBox.BackgroundColor3 = v
        for i, c in ipairs(COLORS) do if c.c == v then highlight(i) end end
        if opts.callback then opts.callback(v) end
    end
end

-- ============================================================
-- WINDOW
-- ============================================================
local function buildWindow()
    print("[Aero Lite] stage 4: buildWindow start")
    local PAGES = {}; local currentPage = nil; local sidebarHoverState = {}
    for k in pairs(uiToggleRefs) do uiToggleRefs[k] = nil end
    local repaintSidebarTheme
    for _, c in ipairs(WindowConnections) do pcall(function() c:Disconnect() end) end
    WindowConnections = {}
    ThemeBindings = {}; ThemeRefreshers = {}
    if St.rootStrokeTween then pcall(function() St.rootStrokeTween:Cancel() end) end
    St.rootStrokeTween = nil
    H.closeAllDropdowns()
    if not THEMES[Settings.UI.Theme] then Settings.UI.Theme = "Purple" end
    for k in pairs(T) do T[k] = nil end
    for k, v in pairs(THEMES[Settings.UI.Theme]) do T[k] = v end
    if St.gui then pcall(function() St.gui:Destroy() end) end
    PAGES = {}; sidebarHoverState = {}
    pcall(St.buildFOV)
    pcall(St.buildSAFOV)
    pcall(St.buildTBFOV)
    pcall(St.buildHUD)
    pcall(St.ensureESPGui)

    St.gui = H.new("ScreenGui", {Name="AeroUI", ResetOnSpawn=false, IgnoreGuiInset=true,
        DisplayOrder=2147483646, ZIndexBehavior=Enum.ZIndexBehavior.Sibling, Parent=GuiParent})

    local WIN_W, WIN_H, TOP_H, SB_W = 860, 580, 54, 190
    if Settings.UI.Position then
        local vp = Camera and Camera.ViewportSize or Vector2.new(1920,1080)
        local p = Settings.UI.Position
        local ax = H.clamp(p.X.Scale * vp.X + p.X.Offset, 200, vp.X - 200)
        local ay = H.clamp(p.Y.Scale * vp.Y + p.Y.Offset, 120, vp.Y - 120)
        Settings.UI.Position = UDim2.new(0, ax, 0, ay)
    end
    local root = H.new("Frame", {Name="Root", AnchorPoint=Vector2.new(0.5,0.5),
        Position=Settings.UI.Position or UDim2.fromScale(0.5,0.5),
        Size=UDim2.fromOffset(WIN_W, WIN_H), BackgroundColor3=T.bg, BorderSizePixel=0,
        ClipsDescendants=true, Parent=St.gui})
    St.root = root
    H.corner(16, root); H.stroke(T.st,1,root); H.gradient(root, 0, 0.5)
    St.rootScale = H.new("UIScale", {Scale=1, Parent=root})
    root.MouseEnter:Connect(function() St.uiHovered = true end)
    root.MouseLeave:Connect(function() St.uiHovered = false end)

    local topBar = H.new("TextButton", {Name="TopBar", Text="", AutoButtonColor=false, BackgroundTransparency=1,
        Size=UDim2.new(1,0,0,TOP_H), Parent=root})
    do
        local icon = H.new("Frame", {Name="TriangleIcon", Size=UDim2.fromOffset(36,36),
            Position=UDim2.new(0,11,0.5,0), AnchorPoint=Vector2.new(0,0.5), BackgroundTransparency=1, Parent=topBar})
        local cx, cy, r, count = 18, 18, 11, 8
        for i = 1, count do
            local ad = (i - 1) * (360 / count) - 90
            local rad = math.rad(ad)
            H.new("TextLabel", {Text="\u{25B2}", Font=FontBold, TextSize=13, TextColor3=T.acc,
                BackgroundTransparency=1, Size=UDim2.fromOffset(14,14),
                Position=UDim2.fromOffset(cx + math.cos(rad)*r, cy + math.sin(rad)*r),
                AnchorPoint=Vector2.new(0.5,0.5), Rotation=ad+180, Parent=icon})
        end
    end
    H.new("TextLabel", {Text="Aero", Font=FontBold, TextSize=19, TextColor3=T.txt, BackgroundTransparency=1,
        Position=UDim2.fromOffset(58,14), Size=UDim2.fromOffset(200,26),
        TextXAlignment=Enum.TextXAlignment.Left, Parent=topBar})
    H.new("TextLabel", {Text=tostring(LP.DisplayName) .. " (" .. tostring(LP.Name) .. ")",
        Font=FontMed, TextSize=13, TextColor3=T.txt, BackgroundTransparency=1,
        AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new(0.5,0,0.5,0),
        Size=UDim2.fromOffset(400,20), TextXAlignment=Enum.TextXAlignment.Center, Parent=topBar})
    St.statsLabel = H.new("TextLabel", {Text="Ping: --  FPS: --", Font=FontMed, TextSize=13, TextColor3=T.dim,
        BackgroundTransparency=1, AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,-20,0.5,0),
        Size=UDim2.fromOffset(180,20), TextXAlignment=Enum.TextXAlignment.Right, Parent=topBar})
    local saveInd = H.new("Frame", {Name="SaveIndicator", Size=UDim2.fromOffset(6,6),
        Position=UDim2.fromOffset(52,27), AnchorPoint=Vector2.new(0.5,0.5),
        BackgroundColor3=T.acc, BackgroundTransparency=1, BorderSizePixel=0, Parent=topBar})
    H.corner(9999, saveInd)
    PF.onSaveStatus = function(ok)
        saveInd.BackgroundColor3 = ok and T.acc or Color3.fromRGB(240,80,80)
        saveInd.BackgroundTransparency = 0
        Svc.TS:Create(saveInd, TweenInfo.new(0.9), {BackgroundTransparency=1}):Play()
    end
    H.new("Frame", {Size=UDim2.new(1,-36,0,1), Position=UDim2.fromOffset(18,TOP_H-1),
        BackgroundColor3=T.st, BorderSizePixel=0, Parent=root})

    local body = H.new("Frame", {Name="Body", Position=UDim2.fromOffset(0,TOP_H),
        Size=UDim2.new(1,0,1,-TOP_H), BackgroundTransparency=1, ClipsDescendants=true, Parent=root})
    local sidebar = H.new("Frame", {Size=UDim2.new(0,SB_W,1,0), BackgroundColor3=T.sb, BorderSizePixel=0, Parent=body})
    H.corner(16, sidebar); H.gradient(sidebar, 0, 0.5)
    local sidebarScroll = H.new("ScrollingFrame", {Size=UDim2.new(1,-16,1,-16), Position=UDim2.fromOffset(8,8),
        BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=3, ScrollBarImageColor3=T.st,
        CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y, Parent=sidebar})
    H.new("UIListLayout", {Padding=UDim.new(0,14), SortOrder=Enum.SortOrder.LayoutOrder,
        HorizontalAlignment=Enum.HorizontalAlignment.Center, Parent=sidebarScroll})
    local pageContainer = H.new("Frame", {Position=UDim2.fromOffset(SB_W,0), Size=UDim2.new(1,-SB_W,1,0),
        BackgroundTransparency=1, ClipsDescendants=true, Parent=body})
    H.pad(14,10,14,14, pageContainer)
    St.pageContainer = pageContainer

    local function makePage(name)
        local p = H.new("Frame", {Name=name, Size=UDim2.fromScale(1,1), BackgroundTransparency=1,
            Visible=false, Position=UDim2.new(0,0,0,0), Parent=pageContainer})
        PAGES[name] = p; return p
    end
    local function twoColumn(page)
        local r = H.new("Frame", {Size=UDim2.fromScale(1,1), BackgroundTransparency=1, Parent=page})
        H.new("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, Padding=UDim.new(0,14),
            SortOrder=Enum.SortOrder.LayoutOrder, Parent=r})
        local function panel(title, order)
            local p = H.new("Frame", {Size=UDim2.new(0.5,-7,1,0), BackgroundColor3=T.pn, BorderSizePixel=0,
                LayoutOrder=order, Parent=r})
            H.corner(10,p); H.stroke(T.st,1,p); H.gradient(p, 0, 0.4)
            H.new("TextLabel", {Text=title, Font=FontBold, TextSize=15, TextColor3=T.txt, BackgroundTransparency=1,
                Position=UDim2.fromOffset(16,12), Size=UDim2.new(1,-32,0,22),
                TextXAlignment=Enum.TextXAlignment.Left, Parent=p})
            local c = H.new("ScrollingFrame", {Position=UDim2.fromOffset(12,42), Size=UDim2.new(1,-24,1,-54),
                BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=3, ScrollBarImageColor3=T.st,
                CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y, Parent=p})
            H.new("UIListLayout", {Padding=UDim.new(0,10), SortOrder=Enum.SortOrder.LayoutOrder, Parent=c})
            H.new("UIPadding", {PaddingRight=UDim.new(0,6), Parent=c})
            return c
        end
        return panel
    end
    local function fullPanel(page, title)
        local p = H.new("Frame", {Size=UDim2.fromScale(1,1), BackgroundColor3=T.pn, BorderSizePixel=0, Parent=page})
        H.corner(10,p); H.stroke(T.st,1,p); H.gradient(p, 0, 0.4)
        H.new("TextLabel", {Text=title, Font=FontBold, TextSize=15, TextColor3=T.txt, BackgroundTransparency=1,
            Position=UDim2.fromOffset(16,12), Size=UDim2.new(1,-32,0,22),
            TextXAlignment=Enum.TextXAlignment.Left, Parent=p})
        local c = H.new("ScrollingFrame", {Position=UDim2.fromOffset(12,42), Size=UDim2.new(1,-24,1,-54),
            BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=3, ScrollBarImageColor3=T.st,
            CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y, Parent=p})
        H.new("UIListLayout", {Padding=UDim.new(0,10), SortOrder=Enum.SortOrder.LayoutOrder, Parent=c})
        H.new("UIPadding", {PaddingRight=UDim.new(0,6), Parent=c})
        return c
    end

    -- ====== AIMBOT ======
    local aimbotPage = makePage("Aimbot")
    local ac = twoColumn(aimbotPage)
    local aimL = ac("Aimbot", 1)
    uiToggleRefs.AimbotEnabled = Wg.makeToggle(aimL, 1, {name="Enabled", default=Settings.Aimbot.Enabled,
        callback=function(v) Settings.Aimbot.Enabled = v; if not v then St.clearAimState(); St.resetAimGain() end end})
    Wg.makeDropdown(aimL, 2, {name="Aim Part", options={"Head","Torso","Random"},
        default=Settings.Aimbot.AimPart,
        callback=function(v) Settings.Aimbot.AimPart = v; St.aimLockedPart = nil end})
    Wg.makeToggle(aimL, 3, {name="Wall Check", default=Settings.Aimbot.WallCheck,
        callback=function(v) Settings.Aimbot.WallCheck = v end})
    Wg.makeToggle(aimL, 4, {name="Team Check", default=Settings.Aimbot.TeamCheck,
        callback=function(v) Settings.Aimbot.TeamCheck = v end})
    Wg.makeToggle(aimL, 5, {name="Dead Check", default=Settings.Aimbot.DeadCheck,
        callback=function(v) Settings.Aimbot.DeadCheck = v end})
    Wg.makeToggle(aimL, 6, {name="Spawn Prot Check", default=Settings.Aimbot.SpawnProtCheck,
        callback=function(v) Settings.Aimbot.SpawnProtCheck = v; if v then St.clearAimState() end end})
    Wg.makeToggle(aimL, 7, {name="Target NPCs", default=Settings.Aimbot.TargetNPCs,
        callback=function(v)
            Settings.Aimbot.TargetNPCs = v
            St.targetCache = nil
            if not v and St.aimLockedTarget and not St.aimLockedTarget.plr then St.clearAimState() end
        end})
    Wg.makeSlider(aimL, 8, {name="Max Distance", min=0, max=1500, default=Settings.Aimbot.MaxDistance,
        format=function(v) return math.floor(v).." studs" end,
        callback=function(v) Settings.Aimbot.MaxDistance = v end})
    local aimR = ac("FOV", 2)
    Wg.makeToggle(aimR, 1, {name="Show FOV", default=Settings.Aimbot.ShowFOV,
        callback=function(v) Settings.Aimbot.ShowFOV = v; St.updateFOV() end})
    Wg.makeDropdown(aimR, 2, {name="FOV Style", options={"Circle","Square","Cross","Dot"},
        default=Settings.Aimbot.FOVStyle,
        callback=function(v) Settings.Aimbot.FOVStyle = v; St.applyFOVStyle(); St.updateFOV() end})
    Wg.makeSlider(aimR, 3, {name="FOV Size", min=20, max=500, default=Settings.Aimbot.FOVSize,
        format=function(v) return math.floor(v).." px" end,
        callback=function(v) Settings.Aimbot.FOVSize = v; St.updateFOV() end})
    Wg.makeSlider(aimR, 4, {name="FOV Transparency", min=0, max=100,
        default=math.floor(Settings.Aimbot.FOVTransparency*100),
        format=function(v) return math.floor(v).."%" end,
        callback=function(v) Settings.Aimbot.FOVTransparency = v/100; St.updateFOV() end})
    Wg.makeColorPicker(aimR, 5, {name="FOV Color", default=Settings.Aimbot.FOVColor,
        callback=function(v) Settings.Aimbot.FOVColor = v; St.applyFOVStyle(); St.updateFOV() end})
    Wg.makeToggle(aimR, 6, {name="Rainbow FOV", default=Settings.Aimbot.Rainbow,
        callback=function(v) Settings.Aimbot.Rainbow = v; if not v then St.applyFOVStyle(); St.updateFOV() end end})

    -- ====== SILENT AIM ======
    local saPage = makePage("Silent Aim")
    local sac = twoColumn(saPage)
    local saL = sac("Silent Aim", 1)
    uiToggleRefs.SilentAimEnabled = Wg.makeToggle(saL, 1, {name="Enabled", default=Settings.SilentAim.Enabled,
        callback=function(v)
            Settings.SilentAim.Enabled = v
            if v then SA.hook() else SA.unhook() end
            St.updateSAFOV()
        end})
    Wg.makeDropdown(saL, 2, {name="Bodypart", options={"Head","Torso","Random"},
        default=Settings.SilentAim.Bodypart,
        callback=function(v) Settings.SilentAim.Bodypart = v; St.saTarget = nil end})
    Wg.makeToggle(saL, 3, {name="Team Check", default=Settings.SilentAim.TeamCheck,
        callback=function(v) Settings.SilentAim.TeamCheck = v end})
    Wg.makeToggle(saL, 4, {name="Sticky Aim", default=Settings.SilentAim.StickyAim,
        callback=function(v) Settings.SilentAim.StickyAim = v; if not v then St.saTarget = nil end end})
    local saR = sac("FOV", 2)
    Wg.makeToggle(saR, 1, {name="Show FOV", default=Settings.SilentAim.ShowFOV,
        callback=function(v) Settings.SilentAim.ShowFOV = v; St.updateSAFOV() end})
    Wg.makeSlider(saR, 2, {name="FOV Size", min=20, max=500, default=Settings.SilentAim.FOVSize,
        format=function(v) return math.floor(v).." px" end,
        callback=function(v) Settings.SilentAim.FOVSize = v; St.updateSAFOV() end})
    Wg.makeSlider(saR, 3, {name="FOV Transparency", min=0, max=100,
        default=math.floor(Settings.SilentAim.FOVTransparency*100),
        format=function(v) return math.floor(v).."%" end,
        callback=function(v) Settings.SilentAim.FOVTransparency = v/100; St.updateSAFOV() end})
    Wg.makeColorPicker(saR, 4, {name="FOV Color", default=Settings.SilentAim.FOVColor,
        callback=function(v) Settings.SilentAim.FOVColor = v; St.updateSAFOV() end})
    H.new("TextLabel", {Text="Hooks Workspace:Raycast / FindPartOnRay. Requires checkcaller, newcclosure, getrawmetatable.",
        Font=Font, TextSize=11, TextColor3=T.dim, BackgroundTransparency=1,
        Size=UDim2.new(1,0,0,32), LayoutOrder=5, TextWrapped=true, Parent=saL})

    -- ====== TRIGGERBOT ======
    local tbPage = makePage("Triggerbot")
    local tbc = twoColumn(tbPage)
    local tbL = tbc("Triggerbot", 1)
    uiToggleRefs.TriggerbotEnabled = Wg.makeToggle(tbL, 1, {name="Enabled", default=Settings.Triggerbot.Enabled,
        callback=function(v) Settings.Triggerbot.Enabled = v; St.updateTBFOV() end})
    Wg.makeDropdown(tbL, 2, {name="Aim Part", options={"Head","Torso","Random"},
        default=Settings.Triggerbot.AimPart,
        callback=function(v) Settings.Triggerbot.AimPart = v end})
    Wg.makeSlider(tbL, 3, {name="Delay", min=0, max=500, default=Settings.Triggerbot.Delay,
        format=function(v) return math.floor(v).." ms" end,
        callback=function(v) Settings.Triggerbot.Delay = v end})
    Wg.makeToggle(tbL, 4, {name="Team Check", default=Settings.Triggerbot.TeamCheck,
        callback=function(v) Settings.Triggerbot.TeamCheck = v end})
    Wg.makeToggle(tbL, 5, {name="Wall Check", default=Settings.Triggerbot.WallCheck,
        callback=function(v) Settings.Triggerbot.WallCheck = v end})
    Wg.makeToggle(tbL, 6, {name="Dead Check", default=Settings.Triggerbot.DeadCheck,
        callback=function(v) Settings.Triggerbot.DeadCheck = v end})
    Wg.makeToggle(tbL, 7, {name="Spawn Prot Check", default=Settings.Triggerbot.SpawnProtCheck,
        callback=function(v) Settings.Triggerbot.SpawnProtCheck = v end})
    Wg.makeToggle(tbL, 8, {name="Target NPCs", default=Settings.Triggerbot.TargetNPCs,
        callback=function(v) Settings.Triggerbot.TargetNPCs = v end})
    Wg.makeSlider(tbL, 9, {name="Max Distance", min=0, max=1500, default=Settings.Triggerbot.MaxDistance,
        format=function(v) return math.floor(v).." studs" end,
        callback=function(v) Settings.Triggerbot.MaxDistance = v end})
    local tbR = tbc("FOV", 2)
    Wg.makeToggle(tbR, 1, {name="Show FOV", default=Settings.Triggerbot.ShowFOV,
        callback=function(v) Settings.Triggerbot.ShowFOV = v; St.updateTBFOV() end})
    Wg.makeSlider(tbR, 2, {name="FOV Size", min=10, max=300, default=Settings.Triggerbot.FOVSize,
        format=function(v) return math.floor(v).." px" end,
        callback=function(v) Settings.Triggerbot.FOVSize = v; St.updateTBFOV() end})
    Wg.makeSlider(tbR, 3, {name="FOV Transparency", min=0, max=100,
        default=math.floor(Settings.Triggerbot.FOVTransparency*100),
        format=function(v) return math.floor(v).."%" end,
        callback=function(v) Settings.Triggerbot.FOVTransparency = v/100; St.updateTBFOV() end})
    Wg.makeColorPicker(tbR, 4, {name="FOV Color", default=Settings.Triggerbot.FOVColor,
        callback=function(v) Settings.Triggerbot.FOVColor = v; St.updateTBFOV() end})

    -- ====== RAGEBOT ======
    local ragePage = makePage("Ragebot")
    local rg = fullPanel(ragePage, "Ragebot")
    uiToggleRefs.RagebotEnabled = Wg.makeToggle(rg, 1, {name="Enabled", default=Settings.Ragebot.Enabled,
        callback=function(v) Settings.Ragebot.Enabled = v; if not v then RB.reset() end end})
    H.new("TextLabel", {Text="Above mode - Range 750 studs - Distance 4 studs\nFlat facing down - Mouse + body locked - Camera stays free\nPrioritises Skeleton - Skips Explosive",
        Font=Font, TextSize=11, TextColor3=T.dim, BackgroundTransparency=1, Size=UDim2.new(1,0,0,48),
        LayoutOrder=2, TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true, Parent=rg})

    -- ====== PLAYERS ======
    local playersPage = makePage("Players")
    local plc = twoColumn(playersPage)
    local plL = plc("Toggles", 1)
    uiToggleRefs.EspEnabled = Wg.makeToggle(plL, 1, {name="Enabled", default=Settings.Players.Enabled,
        callback=function(v) Settings.Players.Enabled = v; if not v then St.clearESPByType(false) end end})
    Wg.makeToggle(plL, 2, {name="Show NPCs", default=Settings.Players.ShowNPCs,
        callback=function(v) Settings.Players.ShowNPCs = v; St.targetCache = nil; if not v then St.clearESPByType(true) end end})
    Wg.makeToggle(plL, 3, {name="Name", default=Settings.Players.ShowName,
        callback=function(v) Settings.Players.ShowName = v end})
    Wg.makeToggle(plL, 4, {name="Health (text)", default=Settings.Players.ShowHealth,
        callback=function(v) Settings.Players.ShowHealth = v end})
    Wg.makeToggle(plL, 5, {name="Distance", default=Settings.Players.ShowDistance,
        callback=function(v) Settings.Players.ShowDistance = v end})
    Wg.makeToggle(plL, 6, {name="Show Team", default=Settings.Players.ShowTeam,
        callback=function(v) Settings.Players.ShowTeam = v end})
    Wg.makeToggle(plL, 7, {name="Chams", default=Settings.Players.Chams,
        callback=function(v) Settings.Players.Chams = v end})
    Wg.makeToggle(plL, 8, {name="Team Check", default=Settings.Players.TeamCheck,
        callback=function(v) Settings.Players.TeamCheck = v end})
    Wg.makeToggle(plL, 9, {name="Box", default=Settings.Players.ShowBox,
        callback=function(v) Settings.Players.ShowBox = v end})
    Wg.makeToggle(plL, 10, {name="Health Bar", default=Settings.Players.ShowHealthBar,
        callback=function(v) Settings.Players.ShowHealthBar = v end})
    Wg.makeToggle(plL, 11, {name="Tracers", default=Settings.Players.ShowTracers,
        callback=function(v) Settings.Players.ShowTracers = v end})
    local plR = plc("Customize", 2)
    Wg.makeSlider(plR, 1, {name="ESP Range", min=50, max=1500, default=Settings.Players.Range,
        format=function(v) return math.floor(v).." studs" end,
        callback=function(v) Settings.Players.Range = v end})
    Wg.makeColorPicker(plR, 2, {name="Enemy Color", default=Settings.Players.EnemyColor,
        callback=function(v) Settings.Players.EnemyColor = v end})
    Wg.makeColorPicker(plR, 3, {name="Teammate Color", default=Settings.Players.TeammateColor,
        callback=function(v) Settings.Players.TeammateColor = v end})
    Wg.makeColorPicker(plR, 4, {name="NPC Color", default=Settings.Npcs.ESPColor,
        callback=function(v) Settings.Npcs.ESPColor = v end})
    Wg.makeToggle(plR, 5, {name="Rainbow Enemy", default=Settings.Players.RainbowEnemy,
        callback=function(v) Settings.Players.RainbowEnemy = v end})
    Wg.makeToggle(plR, 6, {name="Rainbow Team", default=Settings.Players.RainbowTeam,
        callback=function(v) Settings.Players.RainbowTeam = v end})
    Wg.makeToggle(plR, 7, {name="Rainbow NPC", default=Settings.Npcs.RainbowNPC,
        callback=function(v) Settings.Npcs.RainbowNPC = v end})
    Wg.makeDropdown(plR, 8, {name="Tracer Origin", options={"Top","Center","Bottom"},
        default=Settings.Players.TracerOrigin,
        callback=function(v) Settings.Players.TracerOrigin = v end})

    -- ====== MOVEMENT ======
    local movePage = makePage("Movement")
    local mv = fullPanel(movePage, "Movement")
    uiToggleRefs.Fly = Wg.makeToggle(mv, 1, {name="Fly", default=Settings.Movement.Fly,
        callback=function(v) Settings.Movement.Fly = v end})
    Wg.makeSlider(mv, 2, {name="Fly Speed", min=10, max=500, default=Settings.Movement.FlySpeed,
        format=function(v) return math.floor(v).." spd" end,
        callback=function(v) Settings.Movement.FlySpeed = v end})
    uiToggleRefs.Noclip = Wg.makeToggle(mv, 3, {name="Noclip", default=Settings.Movement.Noclip,
        callback=function(v) Settings.Movement.Noclip = v end})

    -- ====== SETTINGS ======
    local settingsPage = makePage("Settings")
    local stc = twoColumn(settingsPage)
    local stL = stc("UI", 1)
    Wg.makeDropdown(stL, 1, {name="Theme", options=THEME_NAMES, default=Settings.UI.Theme,
        callback=function(v)
            if not THEMES[v] then return end
            Settings.UI.Theme = v
            for k in pairs(T) do T[k] = nil end
            for k, val in pairs(THEMES[v]) do T[k] = val end
            H.applyThemeBindings()
            for _, fn in ipairs(ThemeRefreshers) do pcall(fn) end
            if St.repaintSidebarTheme then pcall(St.repaintSidebarTheme) end
            PF.queueSave()
        end})
    Wg.makeToggle(stL, 2, {name="Show HUD", default=Settings.UI.ShowEnabled,
        callback=function(v) Settings.UI.ShowEnabled = v; St.updateHUD() end})

    local unloadRow = H.new("TextButton", {Text="", AutoButtonColor=false, BackgroundColor3=T.pn,
        Size=UDim2.new(1,0,0,32), LayoutOrder=99, Parent=stL})
    H.corner(6, unloadRow); H.gradient(unloadRow, 0, 0.4)
    local unloadLbl = H.new("TextLabel", {Text="Unload Script", Font=FontBold, TextSize=13,
        TextColor3=Color3.fromRGB(240,80,80), BackgroundTransparency=1, Size=UDim2.fromScale(1,1), Parent=unloadRow})
    local unloadArmed = false
    unloadRow.MouseButton1Click:Connect(function()
        if not unloadArmed then
            unloadArmed = true; unloadLbl.Text = "Click again to confirm"
            task.delay(1.5, function() if unloadArmed then unloadArmed = false; unloadLbl.Text = "Unload Script" end end)
        else AeroUnload() end
    end)
    local stR = stc("Info", 2)
    H.new("TextLabel", {Text="Aero Lite v4.2\n\nUse F1-F5 to toggle features.\nRightShift to open/close menu.\nPress P 3× to unload.",
        Font=Font, TextSize=12, TextColor3=T.dim, BackgroundTransparency=1,
        Size=UDim2.new(1,0,0,120), LayoutOrder=1, TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Top, TextWrapped=true, Parent=stR})

    -- ====== KEYBINDS ======
    local keyPage = makePage("Keybinds")
    local kb = fullPanel(keyPage, "Keybinds (click to rebind)")

    local function makeKeybindRow(name, settingKey, order)
        local row = H.new("TextButton", {Text="", AutoButtonColor=false, Size=UDim2.new(1,0,0,28),
            BackgroundColor3=T.pn, BackgroundTransparency=0.4, LayoutOrder=order, Parent=kb})
        H.corner(6, row)
        local nameLbl = H.new("TextLabel", {Text=name, Font=Font, TextSize=13, TextColor3=T.dim,
            BackgroundTransparency=1, Size=UDim2.new(0.55,0,1,0), Position=UDim2.fromOffset(10,0),
            TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
        local box = H.new("Frame", {AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,-6,0.5,0),
            Size=UDim2.new(0.4,0,0,24), BackgroundColor3=T.sb, BorderSizePixel=0, Parent=row})
        H.corner(6, box); H.stroke(T.st,1,box)
        local valLbl = H.new("TextLabel", {Text=G.keyName(Settings.Keybinds[settingKey]),
            Font=FontMed, TextSize=12, TextColor3=T.txt, BackgroundTransparency=1,
            Size=UDim2.fromScale(1,1), Parent=box})
        local listening, listenStart, conn = false, 0, nil
        local function stopListen(revert)
            listening = false
            if conn then conn:Disconnect(); conn = nil end
            if revert then valLbl.Text = G.keyName(Settings.Keybinds[settingKey]) end
            valLbl.TextColor3 = T.txt
        end
        row.MouseButton1Click:Connect(function()
            if listening then return end
            listening = true; listenStart = tick()
            valLbl.Text = "Press a key..."; valLbl.TextColor3 = T.acc
            conn = Svc.UIS.InputBegan:Connect(function(inp, gpe)
                if not listening then return end
                if tick() - listenStart < 0.2 then return end
                if inp.KeyCode == Enum.KeyCode.Escape then stopListen(true); return end
                if gpe then return end
                if inp.UserInputType == Enum.UserInputType.MouseMovement then return end
                local nb
                if inp.UserInputType == Enum.UserInputType.Keyboard then nb = inp.KeyCode
                else nb = inp.UserInputType end
                Settings.Keybinds[settingKey] = nb
                valLbl.Text = G.keyName(nb)
                stopListen(false)
                PF.queueSave()
            end)
        end)
        row.MouseEnter:Connect(function() if not listening then nameLbl.TextColor3 = T.txt end end)
        row.MouseLeave:Connect(function() if not listening then nameLbl.TextColor3 = T.dim end end)
    end

    makeKeybindRow("Aimbot Toggle",   "AimbotToggle",   1)
    makeKeybindRow("Silent Aim Toggle","SilentAimToggle", 2)
    makeKeybindRow("Triggerbot Toggle","TriggerbotToggle", 3)
    makeKeybindRow("Ragebot Toggle",  "RagebotToggle",  4)
    makeKeybindRow("ESP Toggle",      "EspToggle",      5)
    makeKeybindRow("Aim Key (Hold)",  "AimKey",         6)
    makeKeybindRow("Menu Key",        "MenuKey",        7)
    makeKeybindRow("Panic Key (x3)",  "PanicKey",       8)
    H.new("TextLabel", {Text="Click a row and press a key. Escape cancels.",
        Font=Font, TextSize=11, TextColor3=T.dim, BackgroundTransparency=1,
        Size=UDim2.new(1,0,0,20), LayoutOrder=99, TextXAlignment=Enum.TextXAlignment.Left,
        TextWrapped=true, Parent=kb})

    -- ====== SIDEBAR ======
    local sectionCounter = 0
    local sidebarRows = {}
    local sidebarTweens = {}
    local hoveredSidebarRow = nil

    local function applySidebarVisual(name, hover)
        local entry = sidebarRows[name]; if not entry then return end
        local active = (name == currentPage)
        local prior = sidebarTweens[name]
        if prior then for _, tw in ipairs(prior) do pcall(function() tw:Cancel() end) end end
        entry.label.Font = active and FontMed or Font
        local rt = Svc.TS:Create(entry.row, TweenInfo.new(0.13, Enum.EasingStyle.Quad), {
            BackgroundColor3 = active and T.hov or T.pn,
            BackgroundTransparency = active and 0 or 1})
        local lt = Svc.TS:Create(entry.label, TweenInfo.new(0.13, Enum.EasingStyle.Quad), {
            TextColor3 = hover and (active and T.txt or T.dim:Lerp(T.txt, 0.5)) or (active and T.txt or T.dim),
            Position = UDim2.fromOffset((hover and not active) and 12 or 10, 0)})
        sidebarTweens[name] = {rt, lt}
        rt:Play(); lt:Play()
    end

    local pageTransitionToken = 0
    local pageTweens = {}
    local function animatePageTo(name)
        local newPage = PAGES[name]; if not newPage then return end
        H.closeAllDropdowns()
        for pg, tw in pairs(pageTweens) do pcall(function() tw:Cancel() end); pageTweens[pg] = nil end
        if name == currentPage then
            pageTransitionToken = pageTransitionToken + 1
            for _, pg in pairs(PAGES) do pg.Visible = pg == newPage; pg.Position = UDim2.new(0,0,0,0) end
            newPage.Visible = true; newPage.Position = UDim2.new(0,0,0,0); return
        end
        pageTransitionToken = pageTransitionToken + 1
        local tok = pageTransitionToken
        local oldPage = PAGES[currentPage]
        for _, pg in pairs(PAGES) do
            if pg ~= oldPage and pg ~= newPage then pg.Visible = false; pg.Position = UDim2.new(0,0,0,0) end
        end
        local hgt = pageContainer.AbsoluteSize.Y; if hgt <= 1 then hgt = 580 end
        if oldPage and oldPage ~= newPage then
            oldPage.Visible = true; oldPage.Position = UDim2.new(0,0,0,0)
            local tw = Svc.TS:Create(oldPage, TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut),
                {Position=UDim2.new(0,0,0,-hgt)})
            pageTweens[oldPage] = tw; tw:Play()
        end
        newPage.Position = UDim2.new(0,0,0,hgt); newPage.Visible = true
        local tw = Svc.TS:Create(newPage, TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut),
            {Position=UDim2.new(0,0,0,0)})
        pageTweens[newPage] = tw; tw:Play()
        currentPage = name
        Settings.UI.LastPage = name
        PF.queueSave()
        task.delay(0.34, function()
            if tok ~= pageTransitionToken then return end
            if oldPage and oldPage ~= PAGES[currentPage] then
                oldPage.Visible = false; oldPage.Position = UDim2.new(0,0,0,0); pageTweens[oldPage] = nil
            end
            newPage.Position = UDim2.new(0,0,0,0); pageTweens[newPage] = nil
        end)
    end

    local function addSection(title, items)
        sectionCounter = sectionCounter + 1
        local secH = 22 + (#items * 26)
        local sec = H.new("Frame", {Size=UDim2.new(1,0,0,secH), BackgroundTransparency=1,
            LayoutOrder=sectionCounter, Parent=sidebarScroll})
        H.new("UIListLayout", {Padding=UDim.new(0,2), SortOrder=Enum.SortOrder.LayoutOrder, Parent=sec})
        local hdr = H.new("TextLabel", {Text=title, Font=FontBold, TextSize=14, TextColor3=T.txt,
            BackgroundTransparency=1, Size=UDim2.new(1,0,0,22), TextXAlignment=Enum.TextXAlignment.Left,
            LayoutOrder=0, Parent=sec})
        H.pad(0,0,8,0,hdr)
        for i, item in ipairs(items) do
            local row = H.new("TextButton", {Text="", AutoButtonColor=false, Size=UDim2.new(1,0,0,24),
                BackgroundColor3=T.pn, BackgroundTransparency=1, LayoutOrder=i, Parent=sec})
            H.corner(6, row)
            local lbl = H.new("TextLabel", {Text=item.name, Font=Font, TextSize=13, TextColor3=T.dim,
                BackgroundTransparency=1, Size=UDim2.new(1,-16,1,0), Position=UDim2.fromOffset(10,0),
                TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
            sidebarRows[item.name] = {row=row, label=lbl}
            row.MouseEnter:Connect(function()
                if hoveredSidebarRow and hoveredSidebarRow ~= item.name then
                    sidebarHoverState[hoveredSidebarRow] = false
                    applySidebarVisual(hoveredSidebarRow, false)
                end
                hoveredSidebarRow = item.name; sidebarHoverState[item.name] = true
                applySidebarVisual(item.name, true)
            end)
            row.MouseLeave:Connect(function()
                if hoveredSidebarRow == item.name then hoveredSidebarRow = nil end
                sidebarHoverState[item.name] = false
                applySidebarVisual(item.name, false)
            end)
            row.MouseButton1Click:Connect(function()
                if currentPage == item.name then return end
                animatePageTo(item.name)
                if repaintSidebarTheme then repaintSidebarTheme() end
            end)
        end
    end

    addSection("Combat", {{name="Aimbot"}, {name="Silent Aim"}, {name="Triggerbot"}, {name="Ragebot"}})
    addSection("Visuals", {{name="Players"}})
    addSection("Movement", {{name="Movement"}})
    addSection("Config", {{name="Settings"}, {name="Keybinds"}})

    local startPage = Settings.UI.LastPage or "Aimbot"
    if not PAGES[startPage] then startPage = "Aimbot" end
    PAGES[startPage].Visible = true
    PAGES[startPage].Position = UDim2.new(0,0,0,0)
    currentPage = startPage
    Settings.UI.LastPage = startPage
    for name in pairs(sidebarRows) do applySidebarVisual(name, false) end
    repaintSidebarTheme = function()
        for name in pairs(sidebarRows) do applySidebarVisual(name, sidebarHoverState[name] == true) end
    end
    St.repaintSidebarTheme = repaintSidebarTheme

    -- drag
    local dragging, dragStartMouse, startPos
    trackWindow(Svc.UIS.InputBegan:Connect(function(inp)
        if not St.menuVisible or not St.gui or not St.gui.Enabled then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        local mp = inp.Position; local tp = topBar.AbsolutePosition; local ts = topBar.AbsoluteSize
        if mp.X >= tp.X and mp.X <= tp.X + ts.X and mp.Y >= tp.Y and mp.Y <= tp.Y + ts.Y then
            dragging = true; dragStartMouse = Vector2.new(mp.X, mp.Y); startPos = root.Position
        end
    end))
    trackWindow(Svc.UIS.InputChanged:Connect(function(inp)
        if not dragging or inp.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local d = Vector2.new(inp.Position.X, inp.Position.Y) - dragStartMouse
        root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end))
    trackWindow(Svc.UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
            dragging = false
            Settings.UI.Position = root.Position
            PF.queueSave()
        end
    end))
    root.MouseEnter:Connect(function()
        local s = root:FindFirstChildOfClass("UIStroke")
        if s then
            if St.rootStrokeTween then pcall(function() St.rootStrokeTween:Cancel() end) end
            St.rootStrokeTween = Svc.TS:Create(s, TweenInfo.new(0.2), {Color=T.acc}); St.rootStrokeTween:Play()
        end
    end)
    root.MouseLeave:Connect(function()
        local s = root:FindFirstChildOfClass("UIStroke")
        if s then
            if St.rootStrokeTween then pcall(function() St.rootStrokeTween:Cancel() end) end
            St.rootStrokeTween = Svc.TS:Create(s, TweenInfo.new(0.2), {Color=T.st}); St.rootStrokeTween:Play()
        end
    end)
    H.pruneThemeBindings()
    if St.firstWindowBuild then
        St.firstWindowBuild = false
        St.rootScale.Scale = 0.05
        Svc.TS:Create(St.rootScale, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Scale=1}):Play()
    end
    print("[Aero Lite] stage 5: buildWindow done")
end

local function openMenu()
    if not St.gui then return end
    St.gui.Enabled = true; St.menuVisible = true
    if St.rootScale then
        St.rootScale.Scale = 0.05
        Svc.TS:Create(St.rootScale, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Scale=1}):Play()
    end
end
local function closeMenu()
    if not St.gui then return end
    St.menuVisible = false; St.uiHovered = false
    H.closeAllDropdowns()
    if St.rootScale then
        Svc.TS:Create(St.rootScale, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Scale=0.05}):Play()
        task.delay(0.2, function() if not St.menuVisible then St.gui.Enabled = false end end)
    else
        St.gui.Enabled = false
    end
end

track(Svc.UIS.InputBegan:Connect(function(inp, gpe)
    if St.uiHovered and inp.UserInputType == Enum.UserInputType.MouseButton1 then return end
    if gpe then return end
    if G.inputMatches(inp, Settings.Keybinds.AimKey) then St.aimingHeld = true end
    if G.inputMatches(inp, Settings.Keybinds.AimbotToggle) then
        local nv = not Settings.Aimbot.Enabled
        if uiToggleRefs.AimbotEnabled then uiToggleRefs.AimbotEnabled(nv) else Settings.Aimbot.Enabled = nv end
        if not nv then St.clearAimState(); St.resetAimGain() end
        PF.queueSave(); return
    end
    if G.inputMatches(inp, Settings.Keybinds.SilentAimToggle) then
        local nv = not Settings.SilentAim.Enabled
        if uiToggleRefs.SilentAimEnabled then uiToggleRefs.SilentAimEnabled(nv) else
            Settings.SilentAim.Enabled = nv
            if nv then SA.hook() else SA.unhook() end
        end
        St.updateSAFOV()
        PF.queueSave(); return
    end
    if G.inputMatches(inp, Settings.Keybinds.TriggerbotToggle) then
        local nv = not Settings.Triggerbot.Enabled
        if uiToggleRefs.TriggerbotEnabled then uiToggleRefs.TriggerbotEnabled(nv) else Settings.Triggerbot.Enabled = nv end
        St.updateTBFOV()
        PF.queueSave(); return
    end
    if G.inputMatches(inp, Settings.Keybinds.EspToggle) then
        local nv = not Settings.Players.Enabled
        if uiToggleRefs.EspEnabled then uiToggleRefs.EspEnabled(nv) else
            Settings.Players.Enabled = nv
            if not nv then St.clearESPByType(false) end
        end
        PF.queueSave(); return
    end
    if G.inputMatches(inp, Settings.Keybinds.RagebotToggle) then
        local nv = not Settings.Ragebot.Enabled
        if uiToggleRefs.RagebotEnabled then uiToggleRefs.RagebotEnabled(nv) else
            Settings.Ragebot.Enabled = nv
            if not nv then RB.reset() end
        end
        PF.queueSave(); return
    end
    if G.inputMatches(inp, Settings.Keybinds.MenuKey) then
        if St.menuVisible then closeMenu() else openMenu() end
        if St.fovGui then St.fovGui.Enabled = Settings.Aimbot.ShowFOV end
        if St.saFovGui then St.updateSAFOV() end
        if St.tbFovGui then St.updateTBFOV() end
        return
    end
    if G.inputMatches(inp, Settings.Keybinds.PanicKey) then
        local now = tick()
        table.insert(St.panicTimes, now)
        while #St.panicTimes > 0 and now - St.panicTimes[1] > 1.5 do table.remove(St.panicTimes, 1) end
        if #St.panicTimes >= 3 then AeroUnload() end
        return
    end
end))
track(Svc.UIS.InputEnded:Connect(function(inp)
    if G.inputMatches(inp, Settings.Keybinds.AimKey) then
        St.aimingHeld = false; St.clearAimState()
    end
end))

local function wirePlayerESP(plr)
    if plr == LP then return end
    track(plr.CharacterAdded:Connect(function() St.destroyESPFor(plr) end))
    track(plr.CharacterRemoving:Connect(function() St.destroyESPFor(plr) end))
end
for _, plr in ipairs(Svc.Players:GetPlayers()) do wirePlayerESP(plr) end
track(Svc.Players.PlayerAdded:Connect(function(plr) St.espCache[plr] = nil; wirePlayerESP(plr) end))
track(Svc.Players.PlayerRemoving:Connect(function(plr)
    St.destroyESPFor(plr)
    if St.aimLockedTarget and St.aimLockedTarget.plr == plr then St.clearAimState() end
    if RB.target and RB.target.plr == plr then RB.target = nil end
    if St.saTarget and St.saTarget.plr == plr then St.saTarget = nil end
end))

track(LP.CharacterAdded:Connect(function()
    St.clearESP(); St.clearAimState(); St.resetAimGain()
    St.aimingHeld = false; St.saTarget = nil
    RB.target = nil; RB.lockUntil = 0
    RB.savedCFrame = nil; RB.savedVelocity = nil; RB.active = false
    RB.savedPlatformStand = false; RB.savedMouseBehavior = nil
    if St.ragebotAnchoredRoot and St.ragebotAnchoredRoot.Parent then
        pcall(function() St.ragebotAnchoredRoot.Anchored = false end)
    end
    St.ragebotAnchoredRoot = nil
    if St.cameraOwner == "ragebot" then St.releaseCamera() end
    cachedInset = nil
    St.noclipSaved = {}
end))

function AeroUnload()
    if unloaded then return end
    unloaded = true
    pcall(SA.unhook)
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        if RB.savedPlatformStand ~= nil then pcall(function() hum.PlatformStand = RB.savedPlatformStand end) end
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
    end
    if St.ragebotAnchoredRoot and St.ragebotAnchoredRoot.Parent then
        pcall(function() St.ragebotAnchoredRoot.Anchored = false end)
    end
    St.ragebotAnchoredRoot = nil
    Settings.Movement.Fly = false
    Settings.Movement.Noclip = false
    pcall(RB.reset)
    PF.onSaveStatus = nil
    PF.saveSettingsNow()
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    Connections = {}
    for _, c in ipairs(WindowConnections) do pcall(function() c:Disconnect() end) end
    WindowConnections = {}
    ThemeBindings = {}; ThemeRefreshers = {}
    if St.rootStrokeTween then pcall(function() St.rootStrokeTween:Cancel() end) end
    St.rootStrokeTween = nil
    H.closeAllDropdowns()
    for _, d in pairs(St.espCache) do St.destroyESP(d) end
    St.espCache = {}
    for part, orig in pairs(St.noclipSaved) do
        if part.Parent and part:IsA("BasePart") then pcall(function() part.CanCollide = orig end) end
    end
    St.noclipSaved = {}
    St.panicTimes = {}
    St.releaseCamera()
    pcall(function() Svc.RS:UnbindFromRenderStep(MAIN_BIND) end)
    pcall(function() Svc.RS:UnbindFromRenderStep(AIM_CORRECT_BIND) end)
    for _, gui in ipairs({St.fovGui, St.saFovGui, St.tbFovGui, St.espGui, St.hudGui, St.gui, OverlayGui}) do
        if gui then pcall(function() gui:Destroy() end) end
    end
    if St.flyBV then pcall(function() St.flyBV:Destroy() end) end
    print("[Aero Lite] unloaded")
end

local settingsOk, settingsLoaded = pcall(PF.loadAutoSettings)
print(settingsOk and settingsLoaded and "[Aero Lite] stage 6: settings loaded" or "[Aero Lite] stage 6: settings defaulted")

task.defer(function()
    local ok, err = pcall(buildWindow)
    if ok then print("[Aero Lite] loaded successfully")
    else warn("[Aero Lite] buildWindow failed: " .. tostring(err)) end
end)
