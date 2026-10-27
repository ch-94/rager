--!nocheck
-- ============================================================
-- Aero — v10 (No Audio + Silent Aim)
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
    Svc.L        = s("Lighting")
    Svc.VIM      = s("VirtualInputManager")
    Svc.Stats    = s("Stats")
    Svc.GuiSvc   = s("GuiService")
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

local mouseMoveRel = nil
if type(mousemoverel) == "function" then mouseMoveRel = mousemoverel
elseif type(mouse_move_rel) == "function" then mouseMoveRel = mouse_move_rel
elseif type(syn) == "table" and type(syn.mousemoverel) == "function" then mouseMoveRel = syn.mousemoverel
elseif type(fluxus) == "table" and type(fluxus.mousemoverel) == "function" then mouseMoveRel = fluxus.mousemoverel
end

for _, parent in ipairs({PG, GuiParent}) do
    for _, n in ipairs({"AeroUI","AeroFOV","AeroTracers","AeroESP","AeroHUD","AeroOverlay","AeroCursor","AeroSAFOV"}) do
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

local St, FC, RB, SA

-- ============================================================
-- CONSTANTS
-- ============================================================
local SETTINGS_FILE  = "AeroSettings.json"
local PRESET_FILE    = "AeroPresets_v5.json"
local PRESET_BACKUP  = "AeroPresets_v5.bak.json"
local SETTINGS_SCHEMA = 31

local AIM_SKIP_STUDS         = 3.0
local POINT_BLANK_STUDS      = 1.5
local RAGE_ABOVE_DISTANCE    = 4

local function resolveAssetId(str)
    if type(str) ~= "string" then return nil end
    str = str:gsub("^%s+", ""):gsub("%s+$", "")
    if str == "" then return nil end
    if str:match("^rbxassetid://") or str:match("^rbxasset://") then return str end
    local digits = str:match("^(%d+)$")
    if digits and #digits <= 15 then
        local n = tonumber(digits)
        if n and n > 0 and n < 1e15 then
            return "rbxassetid://" .. tostring(math.floor(n))
        end
    end
    return nil
end

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
    Orange = { bg=Color3.fromRGB(26,16,10), sb=Color3.fromRGB(36,22,14), pn=Color3.fromRGB(46,28,16),
               hov=Color3.fromRGB(70,40,20), st=Color3.fromRGB(96,58,28), txt=Color3.fromRGB(255,240,220),
               dim=Color3.fromRGB(220,165,120), acc=Color3.fromRGB(255,140,30), off=Color3.fromRGB(84,52,28),
               trk=Color3.fromRGB(96,58,28) },
    Pink   = { bg=Color3.fromRGB(24,12,20), sb=Color3.fromRGB(32,16,28), pn=Color3.fromRGB(42,20,36),
               hov=Color3.fromRGB(64,28,56), st=Color3.fromRGB(88,40,76), txt=Color3.fromRGB(255,230,248),
               dim=Color3.fromRGB(220,150,195), acc=Color3.fromRGB(255,90,200), off=Color3.fromRGB(78,38,66),
               trk=Color3.fromRGB(88,40,76) },
    Cyan   = { bg=Color3.fromRGB(10,22,24), sb=Color3.fromRGB(14,32,36), pn=Color3.fromRGB(18,42,46),
               hov=Color3.fromRGB(24,60,66), st=Color3.fromRGB(36,86,92), txt=Color3.fromRGB(225,255,255),
               dim=Color3.fromRGB(140,215,220), acc=Color3.fromRGB(40,240,240), off=Color3.fromRGB(34,74,78),
               trk=Color3.fromRGB(36,86,92) },
    Mono   = { bg=Color3.fromRGB(14,14,14), sb=Color3.fromRGB(20,20,20), pn=Color3.fromRGB(26,26,26),
               hov=Color3.fromRGB(42,42,42), st=Color3.fromRGB(64,64,64), txt=Color3.fromRGB(245,245,245),
               dim=Color3.fromRGB(160,160,160), acc=Color3.fromRGB(230,230,230), off=Color3.fromRGB(54,54,54),
               trk=Color3.fromRGB(64,64,64) },
}
local THEME_NAMES = { "Purple","Blue","Red","Green","Orange","Pink","Cyan","Mono" }

local SKYBOXES = {
    Normal      = nil,
    Red         = "rbxassetid://6084040684",
    ["Baby Blue"] = "rbxassetid://9170347594",
    ["Deep Blue"] = "rbxassetid://7550851349",
    Green       = "rbxassetid://7435314787",
    Purple      = "rbxassetid://10950947531",
    Pink        = "rbxassetid://9418596884",
    Yellow      = "rbxassetid://5864273618",
    Orange      = "rbxassetid://4622789690",
}
local SKYBOX_NAMES = { "Normal", "Red", "Baby Blue", "Deep Blue", "Green", "Purple", "Pink", "Yellow", "Orange", "Custom" }
local BUILTIN_SKY_SET = {}
for _, n in ipairs(SKYBOX_NAMES) do BUILTIN_SKY_SET[n] = true end

local COLORS = {
    {n="Black",  c=Color3.fromRGB(0,0,0)},
    {n="White",  c=Color3.fromRGB(255,255,255)},
    {n="Red",    c=Color3.fromRGB(240,60,60)},
    {n="Orange", c=Color3.fromRGB(240,140,40)},
    {n="Yellow", c=Color3.fromRGB(240,220,50)},
    {n="Green",  c=Color3.fromRGB(60,220,100)},
    {n="Cyan",   c=Color3.fromRGB(60,220,225)},
    {n="Blue",   c=Color3.fromRGB(60,150,250)},
    {n="Purple", c=Color3.fromRGB(160,100,240)},
}

local THEME_COLOR_KEYS = {"bg","sb","pn","hov","st","txt","dim","acc","off","trk"}
local COLOR_ROLE_LOOKUP = {}
for _, palette in pairs(THEMES) do
    for _, role in ipairs(THEME_COLOR_KEYS) do
        COLOR_ROLE_LOOKUP[palette[role]] = role
    end
end

local CUSTOM_FEATURE_NAMES = {
    "Fly", "WalkSpeed Override", "Noclip", "Infinite Jump", "Jump Height Override",
    "Freecam", "Box", "Tracers", "Chams", "Health Bar", "Name", "Show Team",
    "Rainbow Enemy", "Rainbow Team", "NPC ESP", "NPC Aimbot", "NPC Ragebot",
    "NPC Triggerbot", "Ambience", "Fog", "Glow", "Brightness", "Time",
    "Rainfall", "Snowfall",
}

-- ============================================================
-- SETTINGS
-- ============================================================
local Settings = {
    Aimbot = { Enabled=false, WallCheck=true, TeamCheck=true, DeadCheck=true,
        SpawnProtCheck=true, TargetNPCs=true,
        AimPart="Head", Mode="Mouse",
        MaxDistance=500, Smoothing=50, Strength=100, Delay=0,
        ShowFOV=true, FOVSize=120, FOVColor=Color3.fromRGB(120,90,240), FOVTransparency=0.6,
        FOVMode="Center", Rainbow=false,
        FOVOffsetX=0, FOVOffsetY=0 },
    SilentAim = { Enabled=false, WallCheck=true, TeamCheck=true, TargetNPCs=true,
        Bodypart="Head", ShowFOV=true, FOVSize=150, FOVColor=Color3.fromRGB(255, 0, 0) },
    Triggerbot = { Enabled=false, TeamCheck=true, DeadCheck=true, WallCheck=true,
        SpawnProtCheck=true,
        HoldEnabled=false, HoldKey=Enum.UserInputType.MouseButton2,
        RMBDelay=0.10, InitialDelay=0.05, ShotDelay=0.02,
        Distance=400, TriggerPart="Head" },
    Players = { Enabled=false, Tracers=false, Chams=false, HealthBar=false, ShowName=true, Box=false,
        TeamCheck=true, ShowTeam=true, Range=800,
        RainbowEnemy=false, RainbowTeam=false,
        EnemyColor=Color3.fromRGB(255,60,60), TeammateColor=Color3.fromRGB(60,220,120) },
    Npcs = { ESP=true, ESPColor=Color3.fromRGB(255,175,70), RainbowNPC=false,
             ShowCursor=false, CursorColor=Color3.fromRGB(255,255,255), CursorRainbow=false,
             Aimbot=true, Ragebot=true, Triggerbot=true },
    Movement = { Fly=false, FlySpeed=60, WalkSpeedEn=false, WalkSpeed=16, Noclip=false, InfiniteJump=false,
        JumpHeightEn=false, JumpHeight=7.2 },
    Ragebot  = { Enabled=false, Distance=750, Mode="Above", OrbitSpeed=3, RageDistance=4,
        TeamCheck=true, SpawnProtCheck=true, TargetNPCs=true },
    World    = {
        Ambience   = { Enabled=false, Color=Color3.fromRGB(100,100,100) },
        Fog        = { Enabled=false, Color=Color3.fromRGB(180,180,180), Distance=500 },
        Glow       = { Enabled=false, Color=Color3.fromRGB(120,90,240), Intensity=0.8 },
        Brightness = { Enabled=false, Value=2 },
        Time       = { Enabled=false, Value=14 },
        Skybox     = "Normal",
        CustomSkyID = "",
        SavedSkyboxes = {},
        Freecam    = { Enabled=false, Speed=60 },
        Snow       = { Enabled=false, Intensity=50 },
        Rain       = { Enabled=false, Intensity=50 },
    },
    Keybinds = {
        AimbotToggle     = Enum.KeyCode.F1,
        AimKey           = Enum.UserInputType.MouseButton2,
        TriggerbotToggle = Enum.KeyCode.F2,
        EspToggle        = Enum.KeyCode.F3,
        RagebotToggle    = Enum.KeyCode.F5,
        SilentAimKey     = Enum.KeyCode.LeftAlt,
        MenuKey          = Enum.KeyCode.RightShift,
        PanicKey         = Enum.KeyCode.P,
        Custom = {
            {feature=nil, key=nil},
            {feature=nil, key=nil},
            {feature=nil, key=nil},
            {feature=nil, key=nil},
        },
    },
    UI       = { Theme="Purple", ShowEnabled=true, LastPage="Aimbot", Position=nil },
}

local Presets = {}
local uiToggleRefs = {}

local PF = { onSaveStatus = nil }

local function getBuiltinKeybinds()
    return {
        {name="AimbotToggle",     key=Settings.Keybinds.AimbotToggle},
        {name="AimKey",           key=Settings.Keybinds.AimKey},
        {name="TriggerbotToggle", key=Settings.Keybinds.TriggerbotToggle},
        {name="TriggerKey",       key=Settings.Triggerbot.HoldKey},
        {name="EspToggle",        key=Settings.Keybinds.EspToggle},
        {name="RagebotToggle",    key=Settings.Keybinds.RagebotToggle},
        {name="SilentAimKey",     key=Settings.Keybinds.SilentAimKey},
        {name="MenuKey",          key=Settings.Keybinds.MenuKey},
        {name="PanicKey",         key=Settings.Keybinds.PanicKey},
    }
end

local function keyInUse(key, exceptName)
    if key == nil then return false end
    for _, b in ipairs(getBuiltinKeybinds()) do
        if b.name ~= exceptName and b.key == key then return true end
    end
    for i, other in ipairs(Settings.Keybinds.Custom) do
        if other.key == key then return true end
    end
    return false
end

-- ============================================================
-- CUSTOM ACTIONS
-- ============================================================
local CustomActions = {}
do
    local function toggleSimple(refName, getter, setter)
        return function()
            local r = uiToggleRefs[refName]
            local newVal = not getter()
            if r then r(newVal)
            else setter(newVal) end
        end
    end

    CustomActions["Fly"] = toggleSimple("Fly",
        function() return Settings.Movement.Fly end,
        function(v) Settings.Movement.Fly = v end)
    CustomActions["WalkSpeed Override"] = toggleSimple("WalkSpeedEn",
        function() return Settings.Movement.WalkSpeedEn end,
        function(v) Settings.Movement.WalkSpeedEn = v end)
    CustomActions["Noclip"] = toggleSimple("Noclip",
        function() return Settings.Movement.Noclip end,
        function(v) Settings.Movement.Noclip = v end)
    CustomActions["Infinite Jump"] = toggleSimple("InfiniteJump",
        function() return Settings.Movement.InfiniteJump end,
        function(v) Settings.Movement.InfiniteJump = v end)
    CustomActions["Jump Height Override"] = toggleSimple("JumpHeightEn",
        function() return Settings.Movement.JumpHeightEn end,
        function(v) Settings.Movement.JumpHeightEn = v end)
    CustomActions["Freecam"] = function()
        local r = uiToggleRefs.FreecamToggle
        local newVal = not Settings.World.Freecam.Enabled
        if r then r(newVal)
        else
            Settings.World.Freecam.Enabled = newVal
            if FC then
                if newVal then FC.activate() else FC.deactivate() end
            end
        end
    end
    CustomActions["Box"] = toggleSimple("PlayerBox",
        function() return Settings.Players.Box end,
        function(v) Settings.Players.Box = v end)
    CustomActions["Tracers"] = toggleSimple("PlayerTracers",
        function() return Settings.Players.Tracers end,
        function(v) Settings.Players.Tracers = v end)
    CustomActions["Chams"] = toggleSimple("PlayerChams",
        function() return Settings.Players.Chams end,
        function(v) Settings.Players.Chams = v end)
    CustomActions["Health Bar"] = toggleSimple("PlayerHealthBar",
        function() return Settings.Players.HealthBar end,
        function(v) Settings.Players.HealthBar = v end)
    CustomActions["Name"] = toggleSimple("PlayerName",
        function() return Settings.Players.ShowName end,
        function(v) Settings.Players.ShowName = v end)
    CustomActions["Show Team"] = toggleSimple("ShowTeam",
        function() return Settings.Players.ShowTeam end,
        function(v) Settings.Players.ShowTeam = v end)
    CustomActions["Rainbow Enemy"] = toggleSimple("RainbowEnemy",
        function() return Settings.Players.RainbowEnemy end,
        function(v) Settings.Players.RainbowEnemy = v end)
    CustomActions["Rainbow Team"] = toggleSimple("RainbowTeam",
        function() return Settings.Players.RainbowTeam end,
        function(v) Settings.Players.RainbowTeam = v end)
    CustomActions["NPC ESP"] = function()
        local r = uiToggleRefs.NpcESP
        local newVal = not Settings.Npcs.ESP
        if r then r(newVal)
        else
            Settings.Npcs.ESP = newVal
            if St then St.targetCache = nil end
        end
    end
    CustomActions["NPC Aimbot"] = function()
        local r = uiToggleRefs.NpcAimbot
        local newVal = not Settings.Npcs.Aimbot
        if r then r(newVal)
        else
            Settings.Npcs.Aimbot = newVal
            if St then
                St.targetCache = nil
                if not newVal and St.aimLockedTarget and not St.aimLockedTarget.plr then
                    St.aimLockedTarget = nil; St.aimLockedSince = 0
                end
            end
        end
    end
    CustomActions["NPC Ragebot"] = function()
        local r = uiToggleRefs.NpcRagebot
        local newVal = not Settings.Npcs.Ragebot
        if r then r(newVal)
        else
            Settings.Npcs.Ragebot = newVal
            if St then St.targetCache = nil end
            if not newVal and RB and RB.target and not RB.target.plr then RB.reset() end
        end
    end
    CustomActions["NPC Triggerbot"] = function()
        local r = uiToggleRefs.NpcTriggerbot
        local newVal = not Settings.Npcs.Triggerbot
        if r then r(newVal)
        else
            Settings.Npcs.Triggerbot = newVal
            if St then
                St.targetCache = nil
                if not newVal then St.hoverSince = nil; St.lastTargetSeen = nil end
            end
        end
    end
    CustomActions["Ambience"] = toggleSimple("Ambience",
        function() return Settings.World.Ambience.Enabled end,
        function(v) Settings.World.Ambience.Enabled = v end)
    CustomActions["Fog"] = toggleSimple("Fog",
        function() return Settings.World.Fog.Enabled end,
        function(v) Settings.World.Fog.Enabled = v end)
    CustomActions["Glow"] = toggleSimple("Glow",
        function() return Settings.World.Glow.Enabled end,
        function(v) Settings.World.Glow.Enabled = v end)
    CustomActions["Brightness"] = toggleSimple("Brightness",
        function() return Settings.World.Brightness.Enabled end,
        function(v) Settings.World.Brightness.Enabled = v end)
    CustomActions["Time"] = toggleSimple("Time",
        function() return Settings.World.Time.Enabled end,
        function(v) Settings.World.Time.Enabled = v end)
    CustomActions["Rainfall"] = toggleSimple("Rainfall",
        function() return Settings.World.Rain.Enabled end,
        function(v) Settings.World.Rain.Enabled = v end)
    CustomActions["Snowfall"] = toggleSimple("Snowfall",
        function() return Settings.World.Snow.Enabled end,
        function(v) Settings.World.Snow.Enabled = v end)
end

-- ============================================================
-- SERIALIZATION + FILES
-- ============================================================
function PF.serializeVal(v)
    local ty = typeof(v)
    if ty == "Color3" then return { __t = "Color3", r = v.R, g = v.G, b = v.B } end
    if ty == "EnumItem" then
        local typeName = tostring(v.EnumType):match("^Enum%.(.+)$") or ""
        return { __t = "EnumItem", e = typeName, n = v.Name }
    end
    if ty == "Vector3" then return { __t = "Vector3", x = v.X, y = v.Y, z = v.Z } end
    if ty == "UDim2" then return { __t = "UDim2", xs = v.X.Scale, xo = v.X.Offset, ys = v.Y.Scale, yo = v.Y.Offset } end
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
    if v.__t == "Vector3" then
        if type(v.x) == "number" and type(v.y) == "number" and type(v.z) == "number" then
            return Vector3.new(v.x, v.y, v.z)
        end
        return nil
    end
    if v.__t == "UDim2" then
        if type(v.xs) == "number" and type(v.xo) == "number"
           and type(v.ys) == "number" and type(v.yo) == "number" then
            return UDim2.new(v.xs, v.xo, v.ys, v.yo)
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

function PF.readFile(path)
    if type(readfile) ~= "function" then return nil end
    if type(isfile) == "function" then
        local ok, exists = pcall(isfile, path)
        if ok and not exists then return nil end
    end
    local ok, data = pcall(readfile, path)
    if not ok or type(data) ~= "string" or data == "" then return nil end
    return data
end

function PF.readJSON(path)
    local data = PF.readFile(path)
    if not data then return nil end
    local ok, decoded = pcall(function() return Svc.HS and Svc.HS:JSONDecode(data) end)
    if not ok or type(decoded) ~= "table" then return nil end
    return decoded
end

function PF.writeJSON(path, data)
    if type(writefile) ~= "function" or not Svc.HS then return false end
    local okEnc, json = pcall(function() return Svc.HS:JSONEncode(data) end)
    if not okEnc or type(json) ~= "string" then return false end
    local okWrite = pcall(writefile, path, json)
    return okWrite == true
end

function PF.saveSettingsNow()
    local prev = PF.readFile(SETTINGS_FILE)
    local payload = {
        schemaVersion = SETTINGS_SCHEMA,
        savedAt = tick(),
        Settings = PF.serializeVal(Settings),
    }
    local ok = PF.writeJSON(SETTINGS_FILE, payload)
    if not ok then warn("[Aero] Failed to save settings") end
    if ok and prev and type(writefile) == "function" then
        pcall(writefile, SETTINGS_FILE .. ".bak", prev)
    end
    if PF.onSaveStatus then pcall(PF.onSaveStatus, ok) end
    return ok
end

local saveToken = 0
function PF.queueSave()
    saveToken = saveToken + 1
    local tok = saveToken
    task.delay(0.35, function()
        if tok ~= saveToken then return end
        pcall(PF.saveSettingsNow)
    end)
end

function PF.saveNow()
    saveToken = saveToken + 1
    pcall(PF.saveSettingsNow)
end

local function migrateSettings()
    local oldRainbow = Settings.Players.Rainbow
    if oldRainbow ~= nil then
        if oldRainbow then
            Settings.Players.RainbowEnemy = true
            Settings.Players.RainbowTeam = true
        end
        Settings.Players.Rainbow = nil
    end
    local oldDelay = Settings.Triggerbot.Delay
    if oldDelay ~= nil then
        if type(oldDelay) == "number" then
            Settings.Triggerbot.InitialDelay = oldDelay
        end
        Settings.Triggerbot.Delay = nil
    end
    if type(Settings.Keybinds.Custom) ~= "table" then
        Settings.Keybinds.Custom = {}
    end
    for i = 1, 4 do
        local entry = Settings.Keybinds.Custom[i]
        if type(entry) ~= "table" then
            Settings.Keybinds.Custom[i] = {feature=nil, key=nil}
        else
            if entry.feature ~= nil and type(entry.feature) ~= "string" then
                entry.feature = nil
            end
            if entry.feature == "" then entry.feature = nil end
            if entry.key == Enum.KeyCode.Unknown then entry.key = nil end
            if entry.key ~= nil and typeof(entry.key) ~= "EnumItem" then
                entry.key = nil
            end
        end
    end
    if type(Settings.Aimbot.FOVOffsetX) ~= "number" then Settings.Aimbot.FOVOffsetX = 0 end
    if type(Settings.Aimbot.FOVOffsetY) ~= "number" then Settings.Aimbot.FOVOffsetY = 0 end
    if type(Settings.Aimbot.SpawnProtCheck) ~= "boolean" then Settings.Aimbot.SpawnProtCheck = true end
    if type(Settings.Triggerbot.SpawnProtCheck) ~= "boolean" then Settings.Triggerbot.SpawnProtCheck = true end
    if type(Settings.Ragebot.SpawnProtCheck) ~= "boolean" then Settings.Ragebot.SpawnProtCheck = true end
    if type(Settings.Aimbot.FOVMode) ~= "string" then Settings.Aimbot.FOVMode = "Center" end
    if type(Settings.SilentAim) ~= "table" then Settings.SilentAim = {} end
    if type(Settings.SilentAim.WallCheck) ~= "boolean" then Settings.SilentAim.WallCheck = true end
    if type(Settings.SilentAim.TeamCheck) ~= "boolean" then Settings.SilentAim.TeamCheck = true end
    if type(Settings.SilentAim.TargetNPCs) ~= "boolean" then Settings.SilentAim.TargetNPCs = true end
    if type(Settings.SilentAim.Bodypart) ~= "string" then Settings.SilentAim.Bodypart = "Head" end
    if type(Settings.SilentAim.FOVSize) ~= "number" then Settings.SilentAim.FOVSize = 150 end
    if type(Settings.SilentAim.ShowFOV) ~= "boolean" then Settings.SilentAim.ShowFOV = true end
    if typeof(Settings.SilentAim.FOVColor) ~= "Color3" then Settings.SilentAim.FOVColor = Color3.fromRGB(255, 0, 0) end
    if type(Settings.Keybinds.SilentAimKey) ~= "EnumItem" then Settings.Keybinds.SilentAimKey = Enum.KeyCode.LeftAlt end
end

function PF.loadAutoSettings()
    local decoded = PF.readJSON(SETTINGS_FILE) or PF.readJSON(SETTINGS_FILE .. ".bak")
    if not decoded then return false end
    local restored = decoded.Settings
    if type(restored) ~= "table" then return false end
    local legacyShowNPCs = type(restored.Players) == "table" and restored.Players.ShowNPCs
    local hasNpcSettings = type(restored.Npcs) == "table"
    local ok, err = pcall(function()
        restored = PF.deserializeVal(restored)
        for section, tbl in pairs(restored) do
            if type(tbl) == "table" and type(Settings[section]) == "table" then
                PF.merge(Settings[section], tbl)
            end
        end
        if not hasNpcSettings and type(legacyShowNPCs) == "boolean" then
            Settings.Npcs.ESP = legacyShowNPCs
            Settings.Npcs.Aimbot = legacyShowNPCs
            Settings.Npcs.Ragebot = legacyShowNPCs
            Settings.Npcs.Triggerbot = legacyShowNPCs
        end
        migrateSettings()
    end)
    if not ok then
        warn("[Aero] Settings load error: " .. tostring(err))
        return false
    end
    return true
end

function PF.countPresets()
    local n = 0
    for _ in pairs(Presets) do n = n + 1 end
    return n
end

function PF.savePresets()
    if type(writefile) ~= "function" or not Svc.HS then return false end
    local prev = PF.readFile(PRESET_FILE)
    local payload = {
        schemaVersion = SETTINGS_SCHEMA,
        savedAt = tick(),
        presets = PF.serializeVal(Presets),
    }
    if not PF.writeJSON(PRESET_FILE, payload) then
        warn("[Aero] Failed to save presets")
        return false
    end
    if prev then pcall(writefile, PRESET_BACKUP, prev) end
    return true
end

function PF.loadPresets()
    local decoded = PF.readJSON(PRESET_FILE) or PF.readJSON(PRESET_BACKUP)
    if not decoded then return false end
    local ok, err = pcall(function()
        local restored = PF.deserializeVal(decoded.presets or decoded)
        if type(restored) ~= "table" then return end
        local any = false
        for k, v in pairs(restored) do
            if type(k) == "string" and type(v) == "table" then any = true; break end
        end
        if not any then return end
        for k in pairs(Presets) do Presets[k] = nil end
        for k, v in pairs(restored) do
            if type(k) == "string" and type(v) == "table" then Presets[k] = v end
        end
    end)
    if not ok then
        warn("[Aero] Preset load error: " .. tostring(err))
        return false
    end
    return true
end

-- ============================================================
-- FONTS / CONNECTIONS / THEME
-- ============================================================
local Font     = Enum.Font.Gotham
local FontMed  = Enum.Font.GothamMedium
local FontBold = Enum.Font.GothamBold

local T = {}
for k, v in pairs(THEMES[Settings.UI.Theme] or THEMES.Purple) do T[k] = v end

local rainbowHue = 0
local function rainbowTick(dt)
    rainbowHue = (rainbowHue + dt * 0.3) % 1
end
local function rainbowColor()
    return Color3.fromHSV(rainbowHue, 0.85, 1)
end

local ThemeBindings = {}
local ThemeRefreshers = {}

local Connections = {}
local WindowConnections = {}
local unloaded = false
local AeroUnload

local function track(c) table.insert(Connections, c); return c end
local function trackWindow(c) table.insert(WindowConnections, c); return c end

-- ============================================================
-- HELPERS
-- ============================================================
local H = {}
function H.new(class, props, children)
    local i = Instance.new(class)
    for k, v in pairs(props or {}) do
        i[k] = v
        if typeof(v) == "Color3" then
            local role = COLOR_ROLE_LOOKUP[v]
            if role then
                ThemeBindings[#ThemeBindings+1] = { instance=i, property=k, role=role }
            end
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
        if ThemeBindings[i].instance == obj then
            table.remove(ThemeBindings, i)
        end
    end
end

function H.gradient(parent, topAlpha, bottomAlpha)
    H.new("UIGradient", {
        Parent = parent, Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, topAlpha or 0),
            NumberSequenceKeypoint.new(0.55, (topAlpha or 0) + ((bottomAlpha or 0.35) - (topAlpha or 0)) * 0.35),
            NumberSequenceKeypoint.new(1, bottomAlpha or 0.35),
        }),
    })
end
function H.applyThemeBindings()
    local active = {}
    for _, b in ipairs(ThemeBindings) do
        local obj = b.instance
        if obj and obj.Parent then
            active[#active+1] = b
            local name = obj.Name or ""
            local isCustom = name == "ThemeOptionSwatch" or name == "ColorChoiceSwatch" or name == "CustomColorSwatch"
            if not isCustom then
                local role = b.role
                if role and T[role] then pcall(function() obj[b.property] = T[role] end) end
            end
        end
    end
    ThemeBindings = active
end
function H.pruneThemeBindings()
    local active = {}
    for _, b in ipairs(ThemeBindings) do
        if b.instance and b.instance.Parent then active[#active+1] = b end
    end
    ThemeBindings = active
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

local activeKeybindListener = nil

-- ============================================================
-- GAME HELPERS
-- ============================================================
local G = {}

function G.getViewportMouse()
    local mp = Svc.UIS:GetMouseLocation()
    local inset = getGuiInset()
    return Vector2.new(mp.X - inset.X, mp.Y - inset.Y)
end

function G.getHeadPart(model)
    if not model then return nil end
    local direct = model:FindFirstChild("Head")
    if direct and direct:IsA("BasePart") then return direct end
    for _, part in ipairs(model:GetChildren()) do
        if part:IsA("BasePart") and part.Name:lower() == "head" then return part end
    end
    local rootPart = nil
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum then rootPart = hum.RootPart end
    if not rootPart then rootPart = model:FindFirstChild("HumanoidRootPart") end
    local best, bestY = nil, -math.huge
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") and p ~= rootPart then
            if p.Position.Y > bestY then
                bestY = p.Position.Y
                best = p
            end
        end
    end
    if best then return best end
    return rootPart
end

function G.getTorsoPart(model)
    if not model then return nil end
    for _, name in ipairs({"UpperTorso", "Torso", "Chest", "Body", "TorsoUpper"}) do
        local p = model:FindFirstChild(name)
        if p and p:IsA("BasePart") then return p end
    end
    for _, part in ipairs(model:GetChildren()) do
        if part:IsA("BasePart") then
            local n = part.Name:lower()
            if n == "torso" or n == "uppertorso" or n == "chest" or n == "body"
               or n == "lowertorso" or n == "lower torso" then
                return part
            end
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
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp end
    local torso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
    if torso then return torso end
    return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end

function G.getAimPart(model, setting)
    if not model then return nil end
    if setting == "Head" then
        return G.getHeadPart(model) or G.getTorsoPart(model)
    elseif setting == "Torso" then
        return G.getTorsoPart(model) or G.getHeadPart(model)
    end
    return G.getHeadPart(model) or G.getTorsoPart(model)
end

local _hpCache = setmetatable({}, {__mode = "k"})
function G.healthInfo(plr, hum, char)
    local now = tick()
    local key = hum or char
    if key then
        local e = _hpCache[key]
        if e and now - e.t < 0.1 then return e.hp, e.max end
    end
    if not hum and char then hum = char:FindFirstChildOfClass("Humanoid") end
    local humHP  = hum and tonumber(hum.Health) or nil
    local humMax = hum and tonumber(hum.MaxHealth) or nil

    local attrHP, attrMax
    if char then
        local a1, a2 = char:GetAttribute("Health"), char:GetAttribute("MaxHealth")
        if type(a1) == "number" and type(a2) == "number" and a2 > 0 then attrHP, attrMax = a1, a2 end
    end
    if not attrHP and plr then
        local a1, a2 = plr:GetAttribute("Health"), plr:GetAttribute("MaxHealth")
        if type(a1) == "number" and type(a2) == "number" and a2 > 0 then attrHP, attrMax = a1, a2 end
    end

    local maxHp = humMax or attrMax or 100
    if maxHp <= 0 then maxHp = 100 end
    local hp = humHP or maxHp
    if attrHP and attrHP < hp then hp = attrHP end
    if hp < 0 then hp = 0 end
    if key then _hpCache[key] = {t = now, hp = hp, max = maxHp} end
    return hp, maxHp
end

local SPAWN_PROT_ATTRS = {
    "SpawnProtection", "spawnProtection", "spawnprotection",
    "Invincible", "invincible", "Invulnerable", "invulnerable",
    "GodMode", "godmode", "Godmode",
    "Protected", "protected", "Protection", "protection",
    "SpawnProtect", "spawnProtect",
    "Immunity", "immunity", "Immune", "immune",
    "Safe", "safe", "ForceField", "forceField",
    "Shield", "shield", "Shielded", "shielded",
}
local SPAWN_PROT_CHILDREN = {
    "SpawnProtection", "Protected", "Invincible", "GodMode",
    "Safe", "Immunity", "ForceField", "Shield", "Shielded",
}
local spawnProtCache = setmetatable({}, {__mode = "k"})

function G.isSpawnProtected(plr, hum, model)
    if not model and not hum then return false end
    local now = tick()
    local cacheKey = model or hum
    local entry = spawnProtCache[cacheKey]
    if entry and (now - entry.t) < 0.5 then return entry.v end

    local result = false
    if model and model:FindFirstChildOfClass("ForceField") then
        result = true
    end
    if not result then
        local targets = {hum, model, plr}
        for _, tgt in ipairs(targets) do
            if tgt and tgt.GetAttribute then
                for _, attr in ipairs(SPAWN_PROT_ATTRS) do
                    local ok, v = pcall(function() return tgt:GetAttribute(attr) end)
                    if ok then
                        if v == true then result = true; break end
                        if type(v) == "number" and v > 0 then result = true; break end
                    end
                end
                if result then break end
            end
        end
    end
    if not result and model then
        for _, name in ipairs(SPAWN_PROT_CHILDREN) do
            local child = model:FindFirstChild(name)
            if child then
                if child:IsA("BoolValue") and child.Value then result = true; break end
                if child:IsA("IntValue") and child.Value > 0 then result = true; break end
                if child:IsA("NumberValue") and child.Value > 0 then result = true; break end
            end
        end
    end
    spawnProtCache[cacheKey] = {t = now, v = result}
    return result
end

function G.teamKey(plr)
    if not plr then return nil end
    local ok1, teamId = pcall(function() return plr:GetAttribute("TeamID") end)
    if ok1 and teamId ~= nil and teamId ~= "" then return "rivals_" .. tostring(teamId) end
    if plr.Team and plr.Team.Name ~= "" then return "team_" .. plr.Team.Name end
    local ok2, attr = pcall(function() return plr:GetAttribute("Team") end)
    if ok2 and attr ~= nil and attr ~= "" then return "attr_" .. tostring(attr) end
    if not plr.Neutral and plr.TeamColor then return "tc_" .. tostring(plr.TeamColor.Name) end
    return nil
end

local _teamPairCache = setmetatable({}, {__mode = "k"})
local _teamPairCacheT = 0
function G.sameTeam(a, b)
    if not a or not b then return false end
    if a == b then return true end
    local now = tick()
    if now - _teamPairCacheT > 0.15 then
        _teamPairCache = setmetatable({}, {__mode = "k"})
        _teamPairCacheT = now
    end
    local inner = _teamPairCache[a]
    if inner and inner[b] ~= nil then return inner[b] end
    local ka, kb = G.teamKey(a), G.teamKey(b)
    local res = (ka ~= nil and kb ~= nil and ka == kb) or false
    if not _teamPairCache[a] then _teamPairCache[a] = {} end
    _teamPairCache[a][b] = res
    if not _teamPairCache[b] then _teamPairCache[b] = {} end
    _teamPairCache[b][a] = res
    return res
end

function G.alive()
    local c = LP.Character; if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end

local _vmCache, _vmCacheT = nil, 0
function G.collectViewmodels()
    local now = tick()
    if _vmCache and now - _vmCacheT < 0.2 then return _vmCache end
    _vmCacheT = now
    local list = {}
    local seen = {}
    local function add(obj)
        if obj and not seen[obj] then seen[obj] = true; list[#list+1] = obj end
    end
    if Camera then
        for _, obj in ipairs(Camera:GetChildren()) do add(obj) end
        for _, desc in ipairs(Camera:GetDescendants()) do add(desc) end
    end
    local char = LP.Character
    if char then
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("Tool") then add(obj) end
            local n = obj.Name:lower()
            if n:find("viewmodel") or n:find("arms") or n:find("weapon") or n:find("hands")
               or n:find("fps") or n:find("gun") or n == "vm" then
                add(obj)
            end
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then add(hum) end
    end
    for _, obj in ipairs(Svc.WS:GetChildren()) do
        local n = obj.Name:lower()
        if n:find("viewmodel") or n:find("arms") or n:find("weapon") or n:find("hands")
           or n:find("fps") or n:find("gun") or n == "vm" then
            add(obj)
        end
    end
    _vmCache = list
    return list
end

local function collectOwnGuis()
    local t = {}
    for _, p in ipairs({PG, GuiParent}) do
        if p then
            for _, n in ipairs({"AeroUI","AeroFOV","AeroESP","AeroHUD","AeroOverlay","AeroSAFOV"}) do
                local g = p:FindFirstChild(n)
                if g then t[#t+1] = g end
            end
        end
    end
    return t
end

local _losParams = nil
local _losExclBuf = {}
local function _getLOSParams()
    if not _losParams then
        _losParams = RaycastParams.new()
        _losParams.FilterType = Enum.RaycastFilterType.Exclude
        _losParams.IgnoreWater = true
    end
    return _losParams
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
    local excl = _losExclBuf
    local n = 0
    n = n + 1; excl[n] = char
    for _, g in ipairs(collectOwnGuis()) do n = n + 1; excl[n] = g end
    if Camera then n = n + 1; excl[n] = Camera end
    if targetModel then n = n + 1; excl[n] = targetModel end
    for _, v in ipairs(G.collectViewmodels()) do n = n + 1; excl[n] = v end
    for i = n + 1, #excl do excl[i] = nil end
    params.FilterDescendantsInstances = excl
    local result = Svc.WS:Raycast(startPos, dir * rayLen, params)
    if result == nil then return true end
    local hit = result.Instance
    if hit then
        if hit:IsDescendantOf(char) then return true end
        if Camera and hit:IsDescendantOf(Camera) then return true end
        if (result.Position - targetPos).Magnitude < POINT_BLANK_STUDS then return true end
    end
    return false
end

function G.inputMatches(inp, binding)
    if binding == nil then return false end
    if typeof(binding) ~= "EnumItem" then return false end
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
    if ok2 and type(v) == "number" then return math.floor(v + 0.5) end
    return nil
end

-- ============================================================
-- RUNTIME STATE
-- ============================================================
St = {
    fovGui = nil, fovCircle = nil,
    espGui = nil,
    cursorGui = nil, cursorDot = nil,
    hudGui = nil, hudContainer = nil,
    flyBV = nil,
    espCache = {},
    aimingHeld = false,
    saHeld = false,
    aimLockedTarget = nil,
    aimLockedSince = 0,
    hoverSince = nil, lastClick = 0, lastTargetSeen = nil,
    triggerHoldHeld = false, triggerHoldSince = 0,
    panicTimes = {},
    gui = nil, root = nil, pageContainer = nil, rootScale = nil, rootStrokeTween = nil,
    originalWalkSpeed = 16,
    savedJump = nil,
    savedWalk = nil,
    noclipSaved = {},
    noclipLastTick = 0,
    npcCache = {},
    lastNpcScan = 0,
    tracers = {},
    hudChips = {},
    menuVisible = true,
    firstWindowBuild = true,
    cameraOwner = nil,
    savedCameraType = nil,
    savedCameraSubject = nil,
    randomAim = { target=nil, part="Head", start=0 },
    targetCache = nil, targetCacheTime = 0,
    statsLabel = nil,
    fpsFrames = 0, currentFps = 0,
    freecamActive = false,
    uiHovered = false,
    lastCursorTick = 0,
    _rbCheck = 0, _rbActive = false,
}
function St.takeCamera()
    if not Camera then return end
    if not St.savedCameraType then
        local cur = Camera.CameraType
        St.savedCameraType = (cur == Enum.CameraType.Scriptable) and Enum.CameraType.Custom or cur
        St.savedCameraSubject = Camera.CameraSubject
    end
    Camera.CameraType = Enum.CameraType.Scriptable
end
function St.releaseCamera()
    if Camera and St.savedCameraType then
        Camera.CameraType = St.savedCameraType
        if St.savedCameraSubject then pcall(function() Camera.CameraSubject = St.savedCameraSubject end) end
    end
    St.savedCameraType = nil
    St.savedCameraSubject = nil
    St.cameraOwner = nil
end

-- ============================================================
-- FOV
-- ============================================================
function St.getFOVCenter()
    if not Camera then return Vector2.zero end
    local ox = tonumber(Settings.Aimbot.FOVOffsetX) or 0
    local oy = tonumber(Settings.Aimbot.FOVOffsetY) or 0
    if Settings.Aimbot.FOVMode == "Cursor" then
        local mp = G.getViewportMouse()
        return Vector2.new(mp.X + ox, mp.Y + oy)
    end
    local vp = Camera.ViewportSize
    return Vector2.new(vp.X * 0.5 + ox, vp.Y * 0.5 + oy)
end

function St.getAimReference()
    if not Camera then return Vector2.zero end
    local vp = Camera.ViewportSize
    return Vector2.new(vp.X * 0.5, vp.Y * 0.5)
end

function St.buildFOV()
    if St.fovGui then pcall(function() St.fovGui:Destroy() end) end
    St.fovGui = H.new("ScreenGui", {
        Name = "AeroFOV", ResetOnSpawn=false, IgnoreGuiInset=false,
        DisplayOrder=2147483640, ZIndexBehavior=Enum.ZIndexBehavior.Sibling, Parent=GuiParent,
    })
    St.fovCircle = H.new("Frame", {
        Name="Circle", AnchorPoint=Vector2.new(0.5,0.5),
        Position=UDim2.fromScale(0.5,0.5),
        Size=UDim2.fromOffset(Settings.Aimbot.FOVSize*2, Settings.Aimbot.FOVSize*2),
        BackgroundTransparency=1, BorderSizePixel=0, Parent=St.fovGui,
    })
    H.corner(9999, St.fovCircle)
    local s = H.stroke(Settings.Aimbot.FOVColor, 1.5, St.fovCircle)
    H.unbindTheme(s)
    if s then
        s.Color = Settings.Aimbot.Rainbow and rainbowColor() or Settings.Aimbot.FOVColor
        s.Transparency = Settings.Aimbot.FOVTransparency
    end
    St.fovGui.Enabled = Settings.Aimbot.ShowFOV
end
function St.updateFOV()
    if not St.fovCircle or not St.fovGui then return end
    St.fovCircle.Size = UDim2.fromOffset(Settings.Aimbot.FOVSize*2, Settings.Aimbot.FOVSize*2)
    St.fovGui.Enabled = Settings.Aimbot.ShowFOV
    local s = St.fovCircle:FindFirstChildOfClass("UIStroke")
    if s then
        if not Settings.Aimbot.Rainbow then
            s.Color = Settings.Aimbot.FOVColor
        end
        s.Transparency = Settings.Aimbot.FOVTransparency
    end
end
function St.updateFOVPosition()
    if not (St.fovCircle and St.fovGui and St.fovGui.Enabled) then return end
    local center = St.getFOVCenter()
    St.fovCircle.Position = UDim2.fromOffset(center.X, center.Y)
end

-- ============================================================
-- SILENT AIM FOV
-- ============================================================
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

function St.updateSAFOV()
    if not St.saFovCircle or not St.saFovGui then return end
    St.saFovGui.Enabled = Settings.SilentAim.ShowFOV and Settings.SilentAim.Enabled
    if not St.saFovGui.Enabled then return end
    local mp = Svc.UIS:GetMouseLocation()
    local inset = getGuiInset()
    St.saFovCircle.Position = UDim2.fromOffset(mp.X - inset.X, mp.Y - inset.Y)
end

-- ============================================================
-- CURSOR DOT
-- ============================================================
function St.buildCursorDot()
    if St.cursorGui then pcall(function() St.cursorGui:Destroy() end) end
    St.cursorGui = H.new("ScreenGui", {
        Name = "AeroCursor", ResetOnSpawn = false, IgnoreGuiInset = false,
        DisplayOrder = 2147483645, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = GuiParent, Enabled = false,
    })
    St.cursorDot = H.new("Frame", {
        Name = "Dot", Size = UDim2.fromOffset(8, 8),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(-100, -100),
        BackgroundColor3 = Settings.Npcs.CursorColor,
        BackgroundTransparency = 0.15, BorderSizePixel = 0, Parent = St.cursorGui,
    })
    H.corner(9999, St.cursorDot)
    H.new("UIStroke", {
        Color = Color3.fromRGB(0, 0, 0), Thickness = 1, Transparency = 0.4,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = St.cursorDot,
    })
end

function St.updateCursorDot()
    if not St.cursorDot or not St.cursorGui then return end
    local enabled = Settings.Npcs.ShowCursor
    St.cursorGui.Enabled = enabled
    if not enabled then return end
    local now = tick()
    if now - St.lastCursorTick < 0.016 then return end
    St.lastCursorTick = now
    local mp = G.getViewportMouse()
    St.cursorDot.Position = UDim2.fromOffset(mp.X, mp.Y)
    local col = Settings.Npcs.CursorRainbow and rainbowColor() or Settings.Npcs.CursorColor
    if St.cursorDot.BackgroundColor3 ~= col then
        St.cursorDot.BackgroundColor3 = col
    end
end

-- ============================================================
-- HUD
-- ============================================================
local HUD_FEATURES = {
    { key="Aimbot",  label="AIMBOT",  get=function() return Settings.Aimbot.Enabled end },
    { key="SilentAim",label="SILENT",  get=function() return Settings.SilentAim.Enabled end },
    { key="Triggerbot", label="TRIGGERBOT", get=function() return Settings.Triggerbot.Enabled end },
    { key="Ragebot", label="RAGEBOT", get=function() return Settings.Ragebot.Enabled end },
    { key="ESP",     label="ESP",     get=function() return Settings.Players.Enabled end },
    { key="Freecam", label="FREECAM", get=function() return Settings.World.Freecam.Enabled end },
}
function St.buildHUD()
    if St.hudGui then pcall(function() St.hudGui:Destroy() end) end
    St.hudGui = H.new("ScreenGui", {
        Name="AeroHUD", ResetOnSpawn=false, IgnoreGuiInset=true,
        DisplayOrder=2147483641, ZIndexBehavior=Enum.ZIndexBehavior.Sibling, Parent=GuiParent,
    })
    St.hudContainer = H.new("Frame", {
        Name="HUD", AnchorPoint=Vector2.new(0, 0),
        Position=UDim2.new(2/8, 0, 0, 10), Size=UDim2.new(0, 0, 0, 22),
        BackgroundTransparency=1, AutomaticSize=Enum.AutomaticSize.X, Parent=St.hudGui,
    })
    H.new("UIListLayout", {
        FillDirection=Enum.FillDirection.Horizontal, Padding=UDim.new(0, 12),
        SortOrder=Enum.SortOrder.LayoutOrder, VerticalAlignment=Enum.VerticalAlignment.Center,
        Parent=St.hudContainer,
    })
    St.hudChips = {}
    for i, f in ipairs(HUD_FEATURES) do
        local chip = H.new("Frame", {
            Size=UDim2.fromOffset(0, 20), AutomaticSize=Enum.AutomaticSize.X,
            BackgroundTransparency=1, BorderSizePixel=0, LayoutOrder=i, Visible=false,
            Parent=St.hudContainer,
        })
        local lbl = H.new("TextLabel", {
            Text=f.label, Font=FontBold, TextSize=13, TextColor3=T.acc,
            BackgroundTransparency=1, Size=UDim2.new(0, 0, 1, 0),
            AutomaticSize=Enum.AutomaticSize.X,
            TextStrokeColor3=Color3.fromRGB(0,0,0), TextStrokeTransparency=0.6,
            TextTransparency=1, Parent=chip,
        })
        St.hudChips[f.key] = { frame=chip, label=lbl, active=false, def=f }
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
                chip.frame.Visible = true
                chip.label.TextColor3 = T.acc
                chip.label.TextTransparency = 0
            else
                Svc.TS:Create(chip.label, TweenInfo.new(0.18), {TextTransparency=1}):Play()
                task.delay(0.2, function()
                    if not chip.active then chip.frame.Visible = false end
                end)
            end
        end
    end
end

-- ============================================================
-- TARGETS
-- ============================================================
local npcPending = {}
local npcCacheDirty = false

local function tryRegisterNpc(model)
    if not model or not model.Parent then return end
    if not model:IsA("Model") then return end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    if Svc.Players:GetPlayerFromCharacter(model) then return end
    if model == LP.Character then return end
    local root = G.getRootPart(model)
    if not root then return end
    local cache = St.npcCache
    for i = 1, #cache do
        if cache[i].model == model then return end
    end
    cache[#cache + 1] = {model=model, hum=hum, root=root}
end

function St.scanNPCs()
    if next(npcPending) then
        local pending = npcPending
        npcPending = {}
        for model in pairs(pending) do
            tryRegisterNpc(model)
        end
    end
    if npcCacheDirty then
        npcCacheDirty = false
        local cache = St.npcCache
        local n = 0
        for i = 1, #cache do
            local e = cache[i]
            if e.model.Parent and e.hum.Parent and e.hum.Health > 0 then
                n = n + 1
                cache[n] = e
            end
        end
        for i = #cache, n + 1, -1 do cache[i] = nil end
    end
end

track(Svc.WS.DescendantAdded:Connect(function(obj)
    if obj:IsA("Humanoid") then
        task.defer(function()
            local parent = obj.Parent
            if parent and parent:IsA("Model") then
                npcPending[parent] = true
            end
        end)
    end
end))
track(Svc.WS.DescendantRemoving:Connect(function(obj)
    if obj:IsA("Humanoid") or obj:IsA("Model") then
        npcCacheDirty = true
    end
end))

task.spawn(function()
    local stack = {Svc.WS}
    local processed = 0
    while #stack > 0 do
        if unloaded then return end
        local node = stack[#stack]
        stack[#stack] = nil
        local children = node:GetChildren()
        for i = 1, #children do
            local child = children[i]
            if child:IsA("Humanoid") then
                local parent = child.Parent
                if parent and parent:IsA("Model") then
                    tryRegisterNpc(parent)
                end
            elseif child:IsA("Model") or child:IsA("Folder") then
                stack[#stack + 1] = child
            end
            processed = processed + 1
        end
        if processed >= 500 then
            processed = 0
            task.wait()
        end
    end
end)

function St.getTargets()
    local now = tick()
    if St.targetCache and (now - St.targetCacheTime) < 0.05 then
        return St.targetCache
    end
    local list = {}
    local npcSettings = Settings.Npcs
    local includeNPCs = npcSettings.ESP or npcSettings.Aimbot or npcSettings.Ragebot or npcSettings.Triggerbot or Settings.SilentAim.TargetNPCs
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
    St.targetCache = list
    St.targetCacheTime = now
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
        if St.randomAim.part == "Head" then
            return G.getHeadPart(t.model) or G.getTorsoPart(t.model)
        else
            return G.getTorsoPart(t.model) or G.getHeadPart(t.model)
        end
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

function St.computeAimFactor(smoothing, strength, dt)
    if smoothing <= 0.01 and strength >= 0.99 then return 1 end
    local speed = 200 * (1 - smoothing) + 20
    local factor = (1 - math.exp(-speed * dt)) * strength
    if factor >= 0.999 then factor = 1 end
    return factor
end

function St.findBestTarget(cfg, partPicker)
    if not Camera then return nil end
    local center = St.getFOVCenter()
    local best, bestScore = nil, math.huge
    local checkSpawn = cfg.SpawnProtCheck and true or false
    for _, t in ipairs(St.getTargets()) do
        if not t.plr and not Settings.Npcs.Aimbot then continue end
        if t.plr and cfg.TeamCheck and G.sameTeam(LP, t.plr) then continue end
        if cfg.DeadCheck and t.hum.Health <= 0 then continue end
        if checkSpawn and G.isSpawnProtected(t.plr, t.hum, t.model) then continue end
        local part = partPicker(t); if not part then continue end
        local sp = St.worldToScreen(part.Position); if not sp then continue end
        local d = (sp - center).Magnitude
        if d > cfg.FOVSize then continue end
        if cfg.WallCheck and not G.hasLOS(part.Position, t.model) then continue end
        local dist3 = (Camera.CFrame.Position - part.Position).Magnitude
        if dist3 > cfg.MaxDistance then continue end
        if d < bestScore then bestScore, best = d, t end
    end
    return best
end

-- ============================================================
-- AIMBOT
-- ============================================================
function St.aimStep(dt)
    if unloaded or not Camera then return end
    if St.freecamActive then
        St.aimLockedTarget = nil; St.aimLockedSince = 0; return
    end
    if Settings.Ragebot.Enabled then
        St.aimLockedTarget = nil; St.aimLockedSince = 0; return
    end
    if not Settings.Aimbot.Enabled or not G.alive() or not St.aimingHeld then
        St.aimLockedTarget = nil; St.aimLockedSince = 0; return
    end

    local t
    if St.aimLockedTarget then
        local locked = St.aimLockedTarget
        local stillValid = true
        if not locked.plr and not Settings.Npcs.Aimbot then
            stillValid = false
        end
        if not (locked and locked.model and locked.model.Parent) then
            stillValid = false
        elseif not (locked.hum and locked.hum.Health > 0) then
            stillValid = false
        else
            if Settings.Aimbot.TeamCheck and locked.plr and G.sameTeam(LP, locked.plr) then
                stillValid = false
            end
            if stillValid and Settings.Aimbot.SpawnProtCheck
               and G.isSpawnProtected(locked.plr, locked.hum, locked.model) then
                stillValid = false
            end
            if stillValid then
                local part = St.pickAimPartWith(locked, Settings.Aimbot.AimPart)
                if not part then
                    stillValid = false
                else
                    local dist3 = (Camera.CFrame.Position - part.Position).Magnitude
                    if dist3 > Settings.Aimbot.MaxDistance then
                        stillValid = false
                    elseif Settings.Aimbot.WallCheck and not G.hasLOS(part.Position, locked.model) then
                        stillValid = false
                    else
                        local sp = St.worldToScreen(part.Position)
                        if not sp then
                            stillValid = false
                        else
                            local center = St.getFOVCenter()
                            if (sp - center).Magnitude > Settings.Aimbot.FOVSize then
                                stillValid = false
                            end
                        end
                    end
                end
            end
        end
        if stillValid then
            t = locked
        else
            St.aimLockedTarget = nil
            St.aimLockedSince = 0
        end
    end

    if not t then
        t = St.findBestTarget(Settings.Aimbot, function(tt) return St.pickAimPartWith(tt, Settings.Aimbot.AimPart) end)
        if t then
            St.aimLockedTarget = t
            St.aimLockedSince = tick()
        end
    end
    if not t then return end
    if Settings.Aimbot.Delay > 0 and (tick() - St.aimLockedSince) < Settings.Aimbot.Delay then
        return
    end
    local part = St.pickAimPartWith(t, Settings.Aimbot.AimPart); if not part then return end
    local smoothing = H.clamp(Settings.Aimbot.Smoothing / 100, 0, 1)
    local strength = H.clamp(Settings.Aimbot.Strength / 100, 0, 1)
    if strength <= 0 then return end
    local factor = St.computeAimFactor(smoothing, strength, dt)
    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
    if not onScreen then return end

    local aimRef = St.getAimReference()
    local dx = screenPos.X - aimRef.X
    local dy = screenPos.Y - aimRef.Y

    local mx = dx * factor
    local my = dy * factor
    if math.abs(mx) < 0.01 and math.abs(my) < 0.01 then return end
    if mouseMoveRel then
        pcall(mouseMoveRel, mx, my)
    else
        local cam = Camera.CFrame
        local newCam = CFrame.new(cam.Position, part.Position)
        local newLook = cam.LookVector:Lerp(newCam.LookVector, factor)
        Camera.CFrame = CFrame.lookAt(cam.Position, cam.Position + newLook)
    end
end

-- ============================================================
-- SILENT AIM (METATABLE)
-- ============================================================
SA = { hooked=false, oldNamecall=nil }

local function getSilentAimTarget()
    if not Settings.SilentAim.Enabled or not St.saHeld or not G.alive() or not Camera then return nil end
    local vp = Camera.ViewportSize
    local cx, cy = vp.X * 0.5, vp.Y * 0.5
    local best, bestDist = nil, math.huge

    for _, t in ipairs(St.getTargets()) do
        if t.plr and Settings.SilentAim.TeamCheck and G.sameTeam(LP, t.plr) then continue end
        if not t.plr and not Settings.SilentAim.TargetNPCs then continue end
        
        local sp, onScreen = Camera:WorldToViewportPoint(t.root.Position)
        if onScreen and sp.Z > 0 then
            local d = math.sqrt((sp.X - cx)^2 + (sp.Y - cy)^2)
            if d <= Settings.SilentAim.FOVSize then
                if Settings.SilentAim.WallCheck then
                    local part = G.getAimPart(t.model, Settings.SilentAim.Bodypart)
                    if part and not G.hasLOS(part.Position, t.model) then continue end
                end
                if d < bestDist then bestDist = d; best = t end
            end
        end
    end
    return best
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
                local part = G.getAimPart(target.model, Settings.SilentAim.Bodypart)
                if part then
                    local args = {...}
                    if method == "Raycast" then
                        local origin, direction = args[1], args[2]
                        args[2] = (part.Position - origin).Unit * direction.Magnitude
                    elseif method == "FindPartOnRay" then
                        local ray = args[1]
                        args[1] = Ray.new(ray.Origin, (part.Position - ray.Origin).Unit * ray.Direction.Magnitude)
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

-- ============================================================
-- TRIGGERBOT
-- ============================================================
local function crosshairOnPart(part, cx, cy)
    if not part or not part.Parent then return false end
    local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
    if not onScreen or sp.Z <= 0 then return false end
    local cf = part.CFrame
    local half = part.Size * 0.5
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    for sx = -1, 1, 2 do
        for sy = -1, 1, 2 do
            for sz = -1, 1, 2 do
                local world = cf * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)
                local p = Camera:WorldToViewportPoint(world)
                if p.Z > 0 then
                    if p.X < minX then minX = p.X end
                    if p.X > maxX then maxX = p.X end
                    if p.Y < minY then minY = p.Y end
                    if p.Y > maxY then maxY = p.Y end
                end
            end
        end
    end
    if minX == math.huge then return false end
    local minHalf = 4
    if maxX - minX < minHalf * 2 then
        local c = (minX + maxX) * 0.5
        minX = c - minHalf; maxX = c + minHalf
    end
    if maxY - minY < minHalf * 2 then
        local c = (minY + maxY) * 0.5
        minY = c - minHalf; maxY = c + minHalf
    end
    return cx >= minX and cx <= maxX and cy >= minY and cy <= maxY
end

function St.triggerTarget()
    if not Camera then return nil end
    local vp = Camera.ViewportSize
    local cx, cy = vp.X * 0.5, vp.Y * 0.5

    local char = LP.Character
    local myHead = char and (G.getHeadPart(char) or char:FindFirstChild("HumanoidRootPart"))
    local myPos = myHead and myHead.Position or Camera.CFrame.Position

    local maxDist = Settings.Triggerbot.Distance
    local req = Settings.Triggerbot.TriggerPart
    if req == "Random" then req = "Any" end
    local checkWall = Settings.Triggerbot.WallCheck
    local teamCheck = Settings.Triggerbot.TeamCheck
    local deadCheck = Settings.Triggerbot.DeadCheck
    local checkSpawn = Settings.Triggerbot.SpawnProtCheck and true or false
    local best, bestScore = nil, math.huge
    for _, t in ipairs(St.getTargets()) do
        if not t.plr and not Settings.Npcs.Triggerbot then continue end
        if teamCheck and t.plr and G.sameTeam(LP, t.plr) then continue end
        if deadCheck and t.hum.Health <= 0 then continue end
        if checkSpawn and G.isSpawnProtected(t.plr, t.hum, t.model) then continue end
        local model = t.model
        if not model then continue end
        local head  = G.getHeadPart(model)
        local torso = G.getTorsoPart(model)
        local candidates = {}
        if head  then candidates[#candidates+1] = {p=head,  cls="Head"} end
        if torso and torso ~= head then candidates[#candidates+1] = {p=torso, cls="Torso"} end
        for _, c in ipairs(candidates) do
            if req ~= "Any" and req ~= c.cls then continue end
            local wPos = c.p.Position
            local delta = wPos - myPos
            local dist3 = delta.Magnitude
            if dist3 > maxDist then continue end
            if not crosshairOnPart(c.p, cx, cy) then continue end
            if checkWall and not G.hasLOS(wPos, model) then continue end
            local sp = Camera:WorldToViewportPoint(wPos)
            local dx, dy = sp.X - cx, sp.Y - cy
            local sd = math.sqrt(dx*dx + dy*dy)
            local score = sd + (c.cls == "Torso" and 8 or 0)
            if score < bestScore then
                bestScore = score
                best = {plr=t.plr, hum=t.hum, model=model, part=c.p, cls=c.cls}
            end
        end
    end
    return best
end

function St.fireClick()
    if not Camera then return end
    local vp = Camera.ViewportSize
    local cx, cy = math.floor(vp.X * 0.5), math.floor(vp.Y * 0.5)
    if type(mouse1click) == "function" then pcall(mouse1click); return end
    if type(mouse1press) == "function" and type(mouse1release) == "function" then
        task.spawn(function()
            pcall(mouse1press); task.wait(0.008); pcall(mouse1release)
        end)
        return
    end
    if Svc.VIM then
        task.spawn(function()
            pcall(function()
                Svc.VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
                task.wait(0.008)
                Svc.VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
            end)
        end)
    end
end

function St.triggerStep(now)
    if St.menuVisible then St.hoverSince = nil; St.lastTargetSeen = nil; return end
    if St.freecamActive then St.hoverSince = nil; St.lastTargetSeen = nil; return end
    if not Settings.Triggerbot.Enabled then St.hoverSince = nil; St.lastTargetSeen = nil; return end
    if not G.alive() then St.hoverSince = nil; St.lastTargetSeen = nil; return end
    if Settings.Triggerbot.HoldEnabled then
        if not St.triggerHoldHeld then St.hoverSince = nil; St.lastTargetSeen = nil; return end
        if (now - St.triggerHoldSince) < Settings.Triggerbot.RMBDelay then return end
    end
    local t = St.triggerTarget()
    local GRACE = 0.15
    if t then
        if not St.hoverSince then St.hoverSince = now end
        St.lastTargetSeen = now
    else
        if not St.lastTargetSeen or (now - St.lastTargetSeen) > GRACE then
            St.hoverSince = nil; St.lastTargetSeen = nil
            return
        end
    end
    if St.hoverSince and (now - St.hoverSince) >= Settings.Triggerbot.InitialDelay then
        local minBetween = math.max(Settings.Triggerbot.ShotDelay, 0.005)
        if (now - St.lastClick) >= minBetween then
            St.lastClick = now
            St.fireClick()
        end
    end
end

-- ============================================================
-- ESP
-- ============================================================
function St.ensureESPGui()
    if St.espGui and St.espGui.Parent then return end
    St.espGui = H.new("ScreenGui", {
        Name="AeroESP", ResetOnSpawn=false, IgnoreGuiInset=true,
        DisplayOrder=2147483639, ZIndexBehavior=Enum.ZIndexBehavior.Sibling, Parent=GuiParent,
    })
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

function St.getTargetBounds(t, d)
    local model = t.model
    local root = t.root
    if not model or not root or not Camera then return nil end

    if d.boundsModel ~= model or d.boundsRoot ~= root then
        d.boundsModel = model
        d.boundsRoot = root
        d.boundsHead = G.getHeadPart(model)
        d.boundsBody = G.getTorsoPart(model) or root
        d.boundsLeg = model:FindFirstChild("Left Leg") or model:FindFirstChild("Right Leg")
        d.boundsLeftArm = model:FindFirstChild("Left Arm") or model:FindFirstChild("LeftHand")
            or model:FindFirstChild("LeftLowerArm") or model:FindFirstChild("LeftUpperArm")
        d.boundsRightArm = model:FindFirstChild("Right Arm") or model:FindFirstChild("RightHand")
            or model:FindFirstChild("RightLowerArm") or model:FindFirstChild("RightUpperArm")
    end

    local head = d.boundsHead
    local body = d.boundsBody
    if not body or not body.Parent then
        body = G.getTorsoPart(model) or root
        d.boundsBody = body
    end
    if head and not head.Parent then
        head = G.getHeadPart(model)
        d.boundsHead = head
    end

    local rootPos = root.Position
    local topY = head and (head.Position.Y + head.Size.Y * 0.5) or (rootPos.Y + 3.2)
    local hipHeight = t.hum and t.hum.HipHeight or 2
    local bottomY
    if t.hum and t.hum.RigType == Enum.HumanoidRigType.R6 then
        local leg = d.boundsLeg
        if leg and leg.Parent then
            bottomY = leg.Position.Y - leg.Size.Y * 0.5
        else
            bottomY = rootPos.Y - body.Size.Y * 0.5 - 2
        end
    else
        bottomY = rootPos.Y - hipHeight - root.Size.Y * 0.5
    end
    if topY - bottomY < 1 then
        topY = rootPos.Y + 3
        bottomY = rootPos.Y - 3
    end

    local width = math.max(root.Size.X, body.Size.X, head and head.Size.X or 0) * 0.9
    local depth = math.max(root.Size.Z, body.Size.Z, head and head.Size.Z or 0) * 0.5
    width = math.max(width, 0.7)
    depth = math.max(depth, 0.35)
    local rightV = Vector3.new(root.CFrame.RightVector.X, 0, root.CFrame.RightVector.Z)
    local forwardV = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
    if rightV.Magnitude < 0.001 then rightV = Vector3.new(1, 0, 0) else rightV = rightV.Unit end
    if forwardV.Magnitude < 0.001 then forwardV = Vector3.new(-rightV.Z, 0, rightV.X) else forwardV = forwardV.Unit end
    local leftArm, rightArm = d.boundsLeftArm, d.boundsRightArm
    if leftArm and leftArm.Parent then
        width = math.max(width, math.abs((leftArm.Position - rootPos):Dot(rightV)) + leftArm.Size.X * 0.5)
    end
    if rightArm and rightArm.Parent then
        width = math.max(width, math.abs((rightArm.Position - rootPos):Dot(rightV)) + rightArm.Size.X * 0.5)
    end

    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local found = false

    for yIndex = 1, 2 do
        local y = yIndex == 1 and topY or bottomY
        for xSign = -1, 1, 2 do
            for zSign = -1, 1, 2 do
                local offset = rightV * (width * xSign) + forwardV * (depth * zSign)
                local corner = Vector3.new(rootPos.X + offset.X, y, rootPos.Z + offset.Z)
                local screen = Camera:WorldToViewportPoint(corner)
                if screen.Z > 0 then
                    found = true
                    minX = math.min(minX, screen.X)
                    maxX = math.max(maxX, screen.X)
                    minY = math.min(minY, screen.Y)
                    maxY = math.max(maxY, screen.Y)
                end
            end
        end
    end

    if not found then return nil end
    local viewport = Camera.ViewportSize
    if viewport.X <= 0 or viewport.Y <= 0 then return nil end
    if maxX < 0 or minX > viewport.X or maxY < 0 or minY > viewport.Y then return nil end

    local left = math.clamp(minX, 0, viewport.X)
    local rightC = math.clamp(maxX, 0, viewport.X)
    local topY2 = math.clamp(minY, 0, viewport.Y)
    local botY = math.clamp(maxY, 0, viewport.Y)
    local width2 = rightC - left
    local height = botY - topY2
    if width2 < 1 or height < 6 or height > 4000 then return nil end
    if width2 < 8 then
        local centerX = (left + rightC) * 0.5
        left = math.max(0, centerX - 4)
        rightC = math.min(viewport.X, centerX + 4)
        width2 = rightC - left
    end

    local inset = getGuiInset()
    return {
        topY = topY2, botY = botY,
        left = left, right = rightC,
        centerX = (left + rightC) * 0.5, centerY = (topY2 + botY) * 0.5,
        width = width2, height = height,
        screenOffsetX = inset.X, screenOffsetY = inset.Y,
    }
end

function St.destroyESP(d)
    if d.nameTag then pcall(function() d.nameTag:Destroy() end) end
    if d.cham then pcall(function() d.cham:Destroy() end) end
    if d.box then pcall(function() d.box:Destroy() end); d.box = nil end
    if d.hpBar then pcall(function() d.hpBar:Destroy() end); d.hpBar = nil end
    d.bars = nil; d.hpFill = nil
end

function St.clearESP()
    local keys = {}
    for k in pairs(St.espCache) do keys[#keys+1] = k end
    for _, k in ipairs(keys) do
        St.destroyESP(St.espCache[k])
        St.espCache[k] = nil
    end
end

function St.clearESPByType(isNPC)
    isNPC = isNPC and true or false
    local keys = {}
    for key, d in pairs(St.espCache) do
        if (d.isNPC and true or false) == isNPC then keys[#keys+1] = key end
    end
    for _, key in ipairs(keys) do
        St.destroyESP(St.espCache[key])
        St.espCache[key] = nil
    end
end

function St.destroyESPFor(plr)
    if St.espCache[plr] then St.destroyESP(St.espCache[plr]); St.espCache[plr] = nil end
end

function St.makeBox()
    local box = H.new("Frame", {
        Name = "BoxESP",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(-4000, -4000),
        Size = UDim2.fromOffset(0, 0),
        Visible = false,
        ClipsDescendants = false,
        ZIndex = 3,
        Parent = St.espGui,
    })
    local bars = {}
    for i = 1, 8 do
        bars[i] = H.new("Frame", {
            Name = "Bar" .. i,
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            Parent = box,
        })
    end
    return box, bars
end

function St.makeHPBar()
    local track = H.new("Frame", {
        Name = "HPBar",
        BackgroundColor3 = Color3.fromRGB(10, 10, 10),
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(-4000, -4000),
        Size = UDim2.fromOffset(4, 0),
        Visible = false,
        ZIndex = 4,
        Parent = St.espGui,
    })
    H.corner(1, track)
    local fill = H.new("Frame", {
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.fromScale(0.5, 1),
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(80, 220, 120),
        BorderSizePixel = 0,
        Parent = track,
    })
    H.corner(1, fill)
    return track, fill
end

function St.buildESPFor(key, model, isNPC)
    local d = {isNPC=isNPC}
    local nameTag = H.new("BillboardGui", {
        AlwaysOnTop=true, Size=UDim2.fromOffset(220, 34),
        StudsOffset=Vector3.new(0, 3.4, 0), Parent=St.espGui,
        Enabled = Settings.Players.ShowName,
    })
    d.nameTag = nameTag
    d.name = H.new("TextLabel", {
        Size=UDim2.new(1,0,0,16), Position=UDim2.fromOffset(0,0),
        BackgroundTransparency=1, Font=FontBold,
        TextSize=14, TextColor3=Color3.new(1,1,1),
        TextStrokeColor3=Color3.new(0,0,0), TextStrokeTransparency=0.35,
        Text = tostring(key), Parent=nameTag,
    })
    d.sub = H.new("TextLabel", {
        Size=UDim2.new(1,0,0,14), Position=UDim2.fromOffset(0,16),
        BackgroundTransparency=1, Font=FontMed,
        TextSize=12, TextColor3=Color3.fromRGB(220,220,220),
        TextStrokeColor3=Color3.new(0,0,0), TextStrokeTransparency=0.5,
        Text = "", Parent=nameTag,
    })
    return d
end

function St.ensureESPChildren(d, model)
    if Settings.Players.Chams then
        if not d.cham or not d.cham.Parent then
            if d.cham then pcall(function() d.cham:Destroy() end) end
            d.cham = H.new("Highlight", {
                FillColor = Settings.Players.EnemyColor,
                OutlineColor = Color3.new(0, 0, 0),
                FillTransparency = 0.55,
                OutlineTransparency = 0.4,
                DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
                Parent = model,
            })
        end
    else
        if d.cham then pcall(function() d.cham:Destroy() end); d.cham = nil end
    end
    if Settings.Players.Box then
        if not d.box then
            d.box, d.bars = St.makeBox()
            d.lastBoxBounds = nil; d.lastBoxColor = nil
        end
    else
        if d.box then
            pcall(function() d.box:Destroy() end)
            d.box = nil; d.bars = nil; d.lastBoxBounds = nil; d.lastBoxColor = nil
        end
    end
    if Settings.Players.HealthBar then
        if not d.hpBar then
            d.hpBar, d.hpFill = St.makeHPBar()
            d.lastHpLayout = nil; d.lastHpPct = nil
        end
    else
        if d.hpBar then
            pcall(function() d.hpBar:Destroy() end)
            d.hpBar = nil; d.hpFill = nil; d.lastHpLayout = nil; d.lastHpPct = nil
        end
    end
end

function St.hideESP(d)
    if d.nameTag then d.nameTag.Enabled = false end
    if d.cham then d.cham.Enabled = false end
    if d.box then d.box.Visible = false end
    if d.hpBar then d.hpBar.Visible = false end
end

function St.updateBoxESP(d, bounds, col)
    if not d.box or not bounds then
        if d.box then d.box.Visible = false end
        return
    end
    local bw = bounds.width
    local bh = bounds.height
    local cx = bounds.centerX + (bounds.screenOffsetX or 0)
    local cy = bounds.centerY + (bounds.screenOffsetY or 0)
    local prev = d.lastBoxBounds
    local moved = not prev or math.abs(prev.x - cx) >= 0.5
        or math.abs(prev.y - cy) >= 0.5
        or math.abs(prev.w - bw) >= 0.5 or math.abs(prev.h - bh) >= 0.5
    if moved then
        d.box.Position = UDim2.fromOffset(cx, cy)
        d.box.Size = UDim2.fromOffset(bw, bh)
        local C = math.clamp(math.min(bw, bh) * 0.24, 8, 26)
        local TH = 2
        local bars = d.bars
        bars[1].Position = UDim2.fromOffset(0, 0);            bars[1].Size = UDim2.fromOffset(C, TH)
        bars[2].Position = UDim2.fromOffset(0, 0);            bars[2].Size = UDim2.fromOffset(TH, C)
        bars[3].Position = UDim2.fromOffset(bw - C, 0);       bars[3].Size = UDim2.fromOffset(C, TH)
        bars[4].Position = UDim2.fromOffset(bw - TH, 0);      bars[4].Size = UDim2.fromOffset(TH, C)
        bars[5].Position = UDim2.fromOffset(0, bh - TH);      bars[5].Size = UDim2.fromOffset(C, TH)
        bars[6].Position = UDim2.fromOffset(0, bh - C);       bars[6].Size = UDim2.fromOffset(TH, C)
        bars[7].Position = UDim2.fromOffset(bw - C, bh - TH); bars[7].Size = UDim2.fromOffset(C, TH)
        bars[8].Position = UDim2.fromOffset(bw - TH, bh - C); bars[8].Size = UDim2.fromOffset(TH, C)
        d.lastBoxBounds = {x=cx, y=cy, w=bw, h=bh}
    end
    if d.lastBoxColor ~= col then
        for i = 1, 8 do d.bars[i].BackgroundColor3 = col end
        d.lastBoxColor = col
    end
    if not d.box.Visible then d.box.Visible = true end
end

function St.updateHPBar(d, bounds, hum, model, plr, hp, maxHp)
    if not d.hpBar or not d.hpFill or not bounds then
        if d.hpBar then d.hpBar.Visible = false end
        return
    end
    if hp == nil or maxHp == nil then hp, maxHp = G.healthInfo(plr, hum, model) end
    local pct = H.clamp(hp / math.max(maxHp, 1), 0, 1)
    local barX = bounds.left - 6 + (bounds.screenOffsetX or 0)
    local barY = bounds.centerY + (bounds.screenOffsetY or 0)
    local barW = 4
    local barH = bounds.height
    if barH < 12 then barH = 12 end
    if barH > 400 then barH = 400 end
    local barLayout = d.lastHpLayout
    if not barLayout or math.abs(barLayout.x-barX) >= 0.5 or math.abs(barLayout.y-barY) >= 0.5
        or math.abs(barLayout.h-barH) >= 0.5 then
        d.hpBar.Position = UDim2.fromOffset(barX, barY)
        d.hpBar.Size = UDim2.fromOffset(barW, barH)
        d.lastHpLayout = {x=barX, y=barY, h=barH}
    end
    if not d.hpBar.Visible then d.hpBar.Visible = true end
    if d.lastHpPct == nil or math.abs(d.lastHpPct - pct) >= 0.002 then
        d.hpFill.Size = UDim2.fromScale(1, pct)
        d.lastHpPct = pct
    end
    local isTeam = Settings.Players.TeamCheck and plr ~= nil and G.sameTeam(LP, plr)
    local isNPC = plr == nil
    local fillColor
    if isNPC and Settings.Npcs.RainbowNPC then
        fillColor = rainbowColor()
    elseif (isTeam and Settings.Players.RainbowTeam) or (not isTeam and not isNPC and Settings.Players.RainbowEnemy) then
        fillColor = rainbowColor()
    else
        local r = math.floor(255 * (1 - pct))
        local g = math.floor(215 * pct)
        local b = math.floor(60 * pct)
        fillColor = Color3.fromRGB(r, g, b)
    end
    if d.hpFill.BackgroundColor3 ~= fillColor then d.hpFill.BackgroundColor3 = fillColor end
end

function St.updateESP()
    if unloaded then return end
    local playersOn = Settings.Players.Enabled
    local npcsOn = Settings.Npcs.ESP
    if not playersOn then St.clearESPByType(false) end
    if not npcsOn then St.clearESPByType(true) end
    if not playersOn and not npcsOn then return end
    St.ensureESPGui()
    if not Camera then return end

    local boxOn = Settings.Players.Box
    local hpOn = Settings.Players.HealthBar
    local nameOn = Settings.Players.ShowName
    local chamsOn = Settings.Players.Chams
    local showTeam = Settings.Players.ShowTeam
    local teamCheck = Settings.Players.TeamCheck
    local range = Settings.Players.Range
    local rangeSq = range * range

    local camPos = Camera.CFrame.Position
    local seen = {}
    for _, tgt in ipairs(St.getTargets()) do
        local plr = tgt.plr
        local isNPC = plr == nil
        local model = tgt.model
        local hum = tgt.hum
        local root = tgt.root
        local key = plr or model
        if not key then continue end
        if (isNPC and not npcsOn) or (not isNPC and not playersOn) then
            local stale = St.espCache[key]
            if stale then St.destroyESP(stale); St.espCache[key] = nil end
            continue
        end
        seen[key] = true

        if not (root and hum and hum.Health > 0) then
            local d = St.espCache[key]
            if d then St.hideESP(d) end
            continue
        end

        local delta = camPos - root.Position
        local distSq = delta:Dot(delta)
        if distSq > rangeSq then
            local d = St.espCache[key]
            if d then St.hideESP(d) end
            continue
        end
        local dist = math.sqrt(distSq)

        local isTeam = teamCheck and plr ~= nil and G.sameTeam(LP, plr)
        if isTeam and not showTeam then
            local d = St.espCache[key]
            if d then St.hideESP(d) end
            continue
        end

        local d = St.espCache[key]
        if d and d.cham and not d.cham.Parent then
            St.destroyESP(d); St.espCache[key] = nil; d = nil
        end
        if not d then d = St.buildESPFor(key, model, isNPC); St.espCache[key] = d end
        d.plr = plr; d.hum = hum

        St.ensureESPChildren(d, model)

        local col = St.colorForTarget(plr, isNPC)
        local hp, maxHp
        if hpOn then hp, maxHp = G.healthInfo(plr, hum, model) end

        if nameOn and d.nameTag then
            if not d.nameTag.Enabled then d.nameTag.Enabled = true end
            if d.nameTag.Adornee ~= root then d.nameTag.Adornee = root end
            local nameText = (plr and plr.Name) or (model.Name or "NPC")
            if d.name.Text ~= nameText then d.name.Text = nameText end
            if d.name.TextColor3 ~= col then d.name.TextColor3 = col end
            local distanceInt = math.floor(dist)
            local hpInt = hpOn and maxHp and maxHp > 0 and math.floor(hp + 0.5) or nil
            local hasHpText = hpInt ~= nil
            if d.lastSubDistance ~= distanceInt or d.lastSubHP ~= hpInt or d.lastSubHasHP ~= hasHpText then
                local subText = hasHpText and string.format("%dm  |  %d HP", distanceInt, hpInt)
                    or string.format("%dm", distanceInt)
                if d.sub.Text ~= subText then d.sub.Text = subText end
                d.lastSubDistance = distanceInt
                d.lastSubHP = hpInt
                d.lastSubHasHP = hasHpText
            end
        elseif d.nameTag then
            if d.nameTag.Enabled then d.nameTag.Enabled = false end
        end

        if chamsOn and d.cham then
            if not d.cham.Enabled then d.cham.Enabled = true end
            if d.cham.FillColor ~= col then d.cham.FillColor = col end
            if d.cham.Parent ~= model then d.cham.Parent = model end
        elseif d.cham then
            if d.cham.Enabled then d.cham.Enabled = false end
        end

        if boxOn or hpOn then
            local bounds = St.getTargetBounds(tgt, d)
            if boxOn and d.box then
                St.updateBoxESP(d, bounds, col)
            elseif d.box then
                d.box.Visible = false
            end
            if hpOn and d.hpBar then
                St.updateHPBar(d, bounds, hum, model, plr, hp, maxHp)
            elseif d.hpBar then
                d.hpBar.Visible = false
            end
        else
            if d.box then d.box.Visible = false end
            if d.hpBar then d.hpBar.Visible = false end
        end
    end

    for key, d in pairs(St.espCache) do
        if not seen[key] then
            St.destroyESP(d); St.espCache[key] = nil
        end
    end
end

-- ============================================================
-- TRACERS
-- ============================================================
function St.destroyTracer(key)
    local entry = St.tracers[key]
    if not entry then return end
    pcall(function() entry.frame:Destroy() end)
    St.tracers[key] = nil
end
function St.clearTracers()
    local keys = {}
    for key in pairs(St.tracers) do keys[#keys+1] = key end
    for _, key in ipairs(keys) do
        St.destroyTracer(key)
    end
end
function St.clearTracersByType(isNPC)
    isNPC = isNPC and true or false
    local keys = {}
    for key, entry in pairs(St.tracers) do
        if (entry.isNPC and true or false) == isNPC then keys[#keys+1] = key end
    end
    for _, key in ipairs(keys) do St.destroyTracer(key) end
end
function St.updateTracers()
    if unloaded or not Camera then return end
    local playersOn = Settings.Players.Enabled
    local npcsOn = Settings.Npcs.ESP
    if not Settings.Players.Tracers or (not playersOn and not npcsOn) then
        if next(St.tracers) then St.clearTracers() end
        return
    end
    local vp = Camera.ViewportSize
    if vp.Y <= 0 then return end
    local inset = getGuiInset()
    local startX = vp.X * 0.5 + inset.X
    local startY = vp.Y + inset.Y
    local camPos = Camera.CFrame.Position
    local showTeam = Settings.Players.ShowTeam
    local teamCheck = Settings.Players.TeamCheck
    local range = Settings.Players.Range
    local rangeSq = range * range
    local active = {}
    for _, tgt in ipairs(St.getTargets()) do
        local plr = tgt.plr
        local isNPC = plr == nil
        if (isNPC and not npcsOn) or (not isNPC and not playersOn) then continue end
        local model = tgt.model
        local root = tgt.root
        local hum = tgt.hum
        if root and hum and hum.Health > 0 then
            local d = camPos - root.Position
            if d:Dot(d) <= rangeSq then
                local isTeam = teamCheck and plr ~= nil and G.sameTeam(LP, plr)
                if not (isTeam and not showTeam) then
                    local key = plr or model
                    active[key] = true
                    local entry = St.tracers[key]
                    if not entry then
                        local f = H.new("Frame", {
                            BackgroundColor3 = Color3.new(1,1,1),
                            BorderSizePixel = 0,
                            AnchorPoint = Vector2.new(0.5, 0.5),
                            Position = UDim2.fromOffset(-4000, -4000),
                            Size = UDim2.fromOffset(0, 2),
                            Visible = false,
                            ZIndex = 2,
                            Parent = St.espGui,
                        })
                        H.new("UIGradient", {
                            Parent = f, Rotation = 0,
                            Transparency = NumberSequence.new({
                                NumberSequenceKeypoint.new(0, 0.05),
                                NumberSequenceKeypoint.new(1, 0.75),
                            }),
                        })
                        entry = { frame = f, isNPC = isNPC }
                        St.tracers[key] = entry
                    end
                    entry.isNPC = isNPC
                    if not entry.head or not entry.head.Parent then
                        entry.head = G.getHeadPart(model)
                    end
                    local head = entry.head
                    local world = head and head.Position or root.Position
                    local sp = Camera:WorldToViewportPoint(world)
                    local targetScreenX = sp.X + inset.X
                    local targetScreenY = sp.Y + inset.Y
                    local onScreen = sp.Z > 0
                        and targetScreenX >= -8 and targetScreenX <= (vp.X + inset.X) + 8
                        and targetScreenY >= -8 and targetScreenY <= (vp.Y + inset.Y) + 8
                    if onScreen then
                        local dx = targetScreenX - startX
                        local dy = targetScreenY - startY
                        local length = math.sqrt(dx*dx + dy*dy)
                        if length >= 6 then
                            local midX = (startX + targetScreenX) * 0.5
                            local midY = (startY + targetScreenY) * 0.5
                            entry.frame.Position = UDim2.fromOffset(midX, midY)
                            entry.frame.Size = UDim2.fromOffset(length, 2)
                            entry.frame.Rotation = math.deg(ATAN2(dy, dx))
                            local col = St.colorForTarget(plr, isNPC)
                            if entry.frame.BackgroundColor3 ~= col then entry.frame.BackgroundColor3 = col end
                            entry.frame.Visible = true
                        else
                            entry.frame.Visible = false
                        end
                    else
                        entry.frame.Visible = false
                    end
                end
            end
        end
    end
    local toRemove = {}
    for key in pairs(St.tracers) do
        if not active[key] then toRemove[#toRemove+1] = key end
    end
    for _, key in ipairs(toRemove) do
        St.destroyTracer(key)
    end
end

-- ============================================================
-- WALKSPEED HOOK
-- ============================================================
local WSHook = { installed=false, meta=nil, orig=nil, wrap=nil }
function WSHook.install()
    if WSHook.installed then return end
    local okG, getMt = pcall(function() return getrawmetatable end)
    if not okG or type(getMt) ~= "function" then return end
    local okM, mt = pcall(function() return getMt(game) end)
    if not okM or type(mt) ~= "table" then return end
    local oldNI = rawget(mt, "__newindex")
    if type(oldNI) ~= "function" then return end
    local function hook(self, key, value)
        if key == "WalkSpeed" and typeof(self) == "Instance" then
            local okA, isHum = pcall(function() return self:IsA("Humanoid") end)
            if okA and isHum and not unloaded and Settings.Movement.WalkSpeedEn then
                local char = LP.Character
                if char and self.Parent == char then
                    return oldNI(self, key, Settings.Movement.WalkSpeed)
                end
            end
        end
        return oldNI(self, key, value)
    end
    local wrapped = hook
    if type(newcclosure) == "function" then
        local okW, w = pcall(newcclosure, hook)
        if okW and w then wrapped = w end
    end
    if type(setreadonly) == "function" then pcall(setreadonly, mt, false) end
    mt.__newindex = wrapped
    if type(setreadonly) == "function" then pcall(setreadonly, mt, true) end
    WSHook.meta = mt; WSHook.orig = oldNI; WSHook.wrap = wrapped; WSHook.installed = true
end
function WSHook.remove()
    local mt = WSHook.meta
    if not mt or not WSHook.installed then return end
    if rawget(mt, "__newindex") == WSHook.wrap then
        if type(setreadonly) == "function" then pcall(setreadonly, mt, false) end
        pcall(function() mt.__newindex = WSHook.orig end)
        if type(setreadonly) == "function" then pcall(setreadonly, mt, true) end
    end
    WSHook.installed = false; WSHook.meta = nil; WSHook.orig = nil; WSHook.wrap = nil
end

-- ============================================================
-- MOVEMENT
-- ============================================================
function St.moveStep()
    if unloaded or not Camera then return end
    if St.freecamActive then return end
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

    if Settings.Movement.WalkSpeedEn then
        if not St.savedWalk then St.savedWalk = hum.WalkSpeed end
        if hum.WalkSpeed ~= Settings.Movement.WalkSpeed then
            hum.WalkSpeed = Settings.Movement.WalkSpeed
        end
    else
        if St.savedWalk then
            pcall(function() hum.WalkSpeed = St.savedWalk end)
            St.savedWalk = nil
        elseif St.originalWalkSpeed and St.originalWalkSpeed > 0
               and math.abs(hum.WalkSpeed - St.originalWalkSpeed) > 0.5 then
            hum.WalkSpeed = St.originalWalkSpeed
        end
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

    if Settings.Movement.JumpHeightEn then
        if not St.savedJump then
            St.savedJump = {
                UseJumpPower = hum.UseJumpPower,
                JumpPower = hum.JumpPower,
                JumpHeight = hum.JumpHeight,
            }
        end
        pcall(function() hum.UseJumpPower = false end)
        local target = Settings.Movement.JumpHeight
        if target <= 0 then target = 0.1 end
        if math.abs((hum.JumpHeight or 0) - target) > 0.01 then
            pcall(function() hum.JumpHeight = target end)
        end
    else
        if St.savedJump then
            pcall(function()
                hum.UseJumpPower = St.savedJump.UseJumpPower
                hum.JumpPower = St.savedJump.JumpPower
                hum.JumpHeight = St.savedJump.JumpHeight
            end)
            St.savedJump = nil
        end
    end

    if Settings.Movement.InfiniteJump and hum and root then
        if Svc.UIS:IsKeyDown(Enum.KeyCode.Space) then
            local state = hum:GetState()
            if state == Enum.HumanoidStateType.Freefall then
                local jumpSpeed = 50
                if hum.UseJumpPower and type(hum.JumpPower) == "number" then
                    jumpSpeed = hum.JumpPower
                elseif type(hum.JumpHeight) == "number" and hum.JumpHeight > 0 then
                    jumpSpeed = math.sqrt(2 * 196.2 * hum.JumpHeight)
                end
                if jumpSpeed > 0 and root.AssemblyLinearVelocity.Y < jumpSpeed * 0.75 then
                    root.AssemblyLinearVelocity = Vector3.new(
                        root.AssemblyLinearVelocity.X, jumpSpeed, root.AssemblyLinearVelocity.Z)
                end
            end
        end
    end
end

-- ============================================================
-- RAGEBOT
-- ============================================================
RB = {
    target=nil, lockUntil=0,
    savedCFrame=nil, savedVelocity=nil,
    savedAutoRotate=true, savedWalkSpeed=nil, savedCharacter=nil,
    savedPlatformStand=false,
    active=false, orbitAngle=nil, randomAngle=nil, randomUntil=0,
}
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
    end
    RB.active = true
end
function RB.restore()
    local char = LP.Character
    local sameCharacter = char ~= nil and char == RB.savedCharacter
    if not sameCharacter then
        RB.savedCFrame=nil; RB.savedVelocity=nil; RB.savedWalkSpeed=nil; RB.savedCharacter=nil
        RB.savedPlatformStand=false; RB.active=false
        if St.cameraOwner == "ragebot" then St.releaseCamera() end
        return
    end
    local hrp = G.getRootPart(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hrp and RB.savedCFrame then
        if char.PivotTo then
            pcall(function() char:PivotTo(RB.savedCFrame) end)
        else
            hrp.CFrame = RB.savedCFrame
        end
        hrp.AssemblyLinearVelocity = RB.savedVelocity or Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end
    if hum then
        hum.AutoRotate = RB.savedAutoRotate
        hum.PlatformStand = RB.savedPlatformStand or false
        if RB.savedWalkSpeed ~= nil then hum.WalkSpeed = RB.savedWalkSpeed end
    end
    RB.savedCFrame = nil; RB.savedVelocity = nil; RB.savedWalkSpeed = nil
    RB.savedCharacter = nil; RB.savedPlatformStand = false
    RB.active = false
    if St.cameraOwner == "ragebot" then St.releaseCamera() end
end
function RB.reset()
    RB.target = nil; RB.lockUntil = 0; RB.orbitAngle = nil; RB.randomAngle = nil; RB.randomUntil = 0
    if RB.active then RB.restore() end
    RB.savedCFrame = nil; RB.savedVelocity = nil; RB.savedCharacter = nil
end
function RB.findTarget()
    local myChar = LP.Character
    local myRoot = myChar and G.getRootPart(myChar)
    if not myRoot then return nil end
    local best, bestDist = nil, math.huge
    local checkSpawn = Settings.Ragebot.SpawnProtCheck and true or false
    for _, t in ipairs(St.getTargets()) do
        if not t.plr and not Settings.Npcs.Ragebot then continue end
        if t.plr and Settings.Ragebot.TeamCheck and G.sameTeam(LP, t.plr) then continue end
        if not t.hum or t.hum.Health <= 0 or not t.model or not t.model.Parent then continue end
        if checkSpawn and G.isSpawnProtected(t.plr, t.hum, t.model) then continue end
        local head = G.getHeadPart(t.model)
        local root = t.root or G.getRootPart(t.model)
        if not head or not root then continue end
        local d = (head.Position - myRoot.Position).Magnitude
        if d <= Settings.Ragebot.Distance and d < bestDist then bestDist = d; best = t end
    end
    return best
end

function St.rageStep()
    if unloaded or not Camera then return end
    if St.freecamActive then if RB.active then RB.reset() end return end
    if not Settings.Ragebot.Enabled or not G.alive() then
        if RB.active then RB.reset() end
        return
    end
    local now = tick()
    local charModel = LP.Character
    local myRoot = charModel and G.getRootPart(charModel)
    local myHum = charModel and charModel:FindFirstChildOfClass("Humanoid")
    if not myRoot or not myHum then
        if RB.active then RB.reset() end
        return
    end
    if RB.active and RB.savedCharacter ~= charModel then
        RB.savedCFrame=nil; RB.savedVelocity=nil; RB.savedWalkSpeed=nil; RB.savedCharacter=nil
        RB.savedPlatformStand=false; RB.active=false; RB.target=nil; RB.lockUntil=0
    end
    if not RB.active then RB.save() end
    myHum.PlatformStand = true
    myHum.AutoRotate = false

    local checkSpawn = Settings.Ragebot.SpawnProtCheck and true or false
    local lockedValid = RB.target
        and RB.lockUntil > now
        and (RB.target.plr ~= nil or Settings.Npcs.Ragebot)
        and RB.target.hum and RB.target.hum.Health > 0
        and RB.target.model and RB.target.model.Parent
        and RB.target.root and RB.target.root.Parent
        and (RB.target.root.Position - myRoot.Position).Magnitude <= Settings.Ragebot.Distance
        and not (checkSpawn and RB.target.plr and G.isSpawnProtected(RB.target.plr, RB.target.hum, RB.target.model))
    local t = lockedValid and RB.target or RB.findTarget()
    if t ~= RB.target then
        RB.target = t
        RB.orbitAngle = nil; RB.randomAngle = nil; RB.randomUntil = 0
    end
    if not t then
        RB.lockUntil = 0
        if RB.active then RB.restore() end
        return
    end
    RB.lockUntil = now + 10

    local head = G.getHeadPart(t.model)
    local targetRoot = t.root or G.getRootPart(t.model)
    if not head or not targetRoot or not targetRoot:IsA("BasePart") then
        RB.target=nil; RB.lockUntil=0
        if RB.active then RB.restore() end
        return
    end

    local distance = H.clamp(tonumber(Settings.Ragebot.RageDistance) or 6, 1, 30)
    local mode = Settings.Ragebot.Mode or "Orbit"
    local forward = Vector3.new(targetRoot.CFrame.LookVector.X, 0, targetRoot.CFrame.LookVector.Z)
    if forward.Magnitude < 0.001 then forward = Vector3.new(0, 0, -1) else forward = forward.Unit end
    local offset
    if mode == "Orbit" then
        local relative = myRoot.Position - targetRoot.Position
        if not RB.orbitAngle then RB.orbitAngle = (relative.Magnitude > 0.05) and math.atan2(relative.Z, relative.X) or 0 end
        local speed = H.clamp(tonumber(Settings.Ragebot.OrbitSpeed) or 3, 0, 50)
        RB.orbitAngle = (RB.orbitAngle + speed * (1/60)) % (math.pi * 2)
        offset = Vector3.new(math.cos(RB.orbitAngle) * distance, 0.5, math.sin(RB.orbitAngle) * distance)
    elseif mode == "Behind" then
        offset = -forward * distance + Vector3.new(0, 0.5, 0)
    elseif mode == "Infront" then
        offset = forward * distance + Vector3.new(0, 0.5, 0)
    elseif mode == "Above" then
        offset = Vector3.new(0, distance, 0)
    elseif mode == "Below" then
        offset = Vector3.new(0, -distance, 0)
    elseif mode == "Random" then
        if not RB.randomAngle or now >= RB.randomUntil then
            RB.randomAngle = math.random() * math.pi * 2
            RB.randomUntil = now + 0.7 + math.random() * 0.8
        end
        offset = Vector3.new(math.cos(RB.randomAngle) * distance, 0.5, math.sin(RB.randomAngle) * distance)
    else
        offset = -forward * distance + Vector3.new(0, 0.5, 0)
    end

    local targetPos = targetRoot.Position + offset
    local goalCFrame = CFrame.lookAt(targetPos, head.Position)

    if charModel.PivotTo then
        pcall(function() charModel:PivotTo(goalCFrame) end)
    else
        myRoot.CFrame = goalCFrame
    end

    myRoot.AssemblyLinearVelocity = Vector3.zero
    myRoot.AssemblyAngularVelocity = Vector3.zero

    if St.cameraOwner ~= "ragebot" then
        if St.cameraOwner ~= nil then St.releaseCamera() end
        St.takeCamera(); St.cameraOwner = "ragebot"
    end
    Camera.CameraType = Enum.CameraType.Scriptable

    local myHead = G.getHeadPart(charModel) or myRoot
    local camPos = myHead.Position
    local dirVec = head.Position - camPos
    local dirLen = dirVec.Magnitude
    if dirLen < 0.75 then
        camPos = head.Position - dirVec.Unit * 1
    end
    Camera.CFrame = CFrame.lookAt(camPos, head.Position, Vector3.new(0, 1, 0))
    Camera.Focus = CFrame.new(head.Position)
end

-- ============================================================
-- WORLD
-- ============================================================
local WR = {
    Ambience   = { saved=false, sAmbient=nil, sOutdoor=nil },
    Fog        = { saved=false, sColor=nil, sStart=nil, sEnd=nil },
    GlowBloom  = { saved=false, created=false, instance=nil, sEnabled=nil, sIntensity=nil, sSize=nil, sThreshold=nil },
    GlowCC     = { saved=false, created=false, instance=nil, sEnabled=nil, sTint=nil, sBrightness=nil, sContrast=nil, sSaturation=nil },
    GlowRays   = { saved=false, created=false, instance=nil, sEnabled=nil, sIntensity=nil, sSpread=nil },
    Brightness = { saved=false, sValue=nil },
    Time       = { saved=false, sValue=nil },
    Sky        = { saved=false, created=false, instance=nil,
                   sBk=nil, sDn=nil, sFt=nil, sLf=nil, sRt=nil, sUp=nil, sStars=nil, sCelest=nil,
                   sSunSize=nil, sMoonSize=nil },
    lastApply  = 0,
    lastSky    = nil,
    lastGlowOn = nil,
    lastLoopAt = nil,
}

local function blendNumberFactory(force, dt)
    local alpha = force and 1 or (1 - math.exp(-9 * (dt or 0.1)))
    return function(current, target)
        if force then return target end
        return current + (target - current) * alpha
    end
end
local function blendColorFactory(force, dt)
    local alpha = force and 1 or (1 - math.exp(-9 * (dt or 0.1)))
    return function(current, target)
        return current:Lerp(target, alpha)
    end
end
local function colorClose(a, b)
    return math.abs(a.R-b.R) < 0.01 and math.abs(a.G-b.G) < 0.01 and math.abs(a.B-b.B) < 0.01
end

function WR.loopApply(force)
    if not Svc.L then return end
    if not force then
        local W = Settings.World
        local anyOn = W.Ambience.Enabled or W.Fog.Enabled or W.Time.Enabled or W.Brightness.Enabled
        local anySaved = WR.Ambience.saved or WR.Fog.saved or WR.Time.saved or WR.Brightness.saved
        if not anyOn and not anySaved then return end
    end
    local L = Svc.L
    local now = tick()
    local dt = WR.lastLoopAt and H.clamp(now - WR.lastLoopAt, 0, 0.25) or 0.1
    WR.lastLoopAt = now
    local blendNumber = blendNumberFactory(force, dt)
    local blendColor = blendColorFactory(force, dt)

    local S = Settings.World.Ambience
    if S.Enabled then
        if not WR.Ambience.saved then
            WR.Ambience.sAmbient = L.Ambient
            WR.Ambience.sOutdoor = L.OutdoorAmbient
            WR.Ambience.saved = true
        end
        local targetAmbient = Color3.new(0,0,0):Lerp(S.Color, 0.6)
        L.Ambient = blendColor(L.Ambient, targetAmbient)
        L.OutdoorAmbient = blendColor(L.OutdoorAmbient, S.Color)
    elseif WR.Ambience.saved then
        L.Ambient = blendColor(L.Ambient, WR.Ambience.sAmbient)
        L.OutdoorAmbient = blendColor(L.OutdoorAmbient, WR.Ambience.sOutdoor)
        if force or colorClose(L.Ambient, WR.Ambience.sAmbient) and colorClose(L.OutdoorAmbient, WR.Ambience.sOutdoor) then
            L.Ambient = WR.Ambience.sAmbient; L.OutdoorAmbient = WR.Ambience.sOutdoor
            WR.Ambience.saved = false
        end
    end

    local F = Settings.World.Fog
    if F.Enabled then
        if not WR.Fog.saved then
            WR.Fog.sColor = L.FogColor; WR.Fog.sStart = L.FogStart; WR.Fog.sEnd = L.FogEnd
            WR.Fog.saved = true
        end
        L.FogColor = blendColor(L.FogColor, F.Color)
        L.FogStart = blendNumber(L.FogStart, math.max(0, F.Distance * 0.35))
        L.FogEnd = blendNumber(L.FogEnd, math.max(F.Distance * 0.35 + 1, F.Distance))
    elseif WR.Fog.saved then
        L.FogColor = blendColor(L.FogColor, WR.Fog.sColor)
        L.FogStart = blendNumber(L.FogStart, WR.Fog.sStart)
        L.FogEnd = blendNumber(L.FogEnd, WR.Fog.sEnd)
        if force or (colorClose(L.FogColor, WR.Fog.sColor) and math.abs(L.FogStart - WR.Fog.sStart) < 0.1 and math.abs(L.FogEnd - WR.Fog.sEnd) < 0.1) then
            L.FogColor=WR.Fog.sColor; L.FogStart=WR.Fog.sStart; L.FogEnd=WR.Fog.sEnd
            WR.Fog.saved=false
        end
    end

    local TM = Settings.World.Time
    if TM.Enabled then
        if not WR.Time.saved then WR.Time.sValue = L.ClockTime; WR.Time.saved = true end
        local delta = ((TM.Value - L.ClockTime + 12) % 24) - 12
        L.ClockTime = (L.ClockTime + delta * blendNumber(0, 1)) % 24
    elseif WR.Time.saved then
        local delta = ((WR.Time.sValue - L.ClockTime + 12) % 24) - 12
        L.ClockTime = (L.ClockTime + delta * blendNumber(0, 1)) % 24
        if force or math.abs(delta) < 0.01 then L.ClockTime=WR.Time.sValue; WR.Time.saved=false end
    end

    local BR = Settings.World.Brightness
    if BR.Enabled then
        if not WR.Brightness.saved then WR.Brightness.sValue = L.Brightness; WR.Brightness.saved = true end
        L.Brightness = blendNumber(L.Brightness, BR.Value)
    elseif WR.Brightness.saved then
        L.Brightness = blendNumber(L.Brightness, WR.Brightness.sValue)
        if force or math.abs(L.Brightness - WR.Brightness.sValue) < 0.01 then
            L.Brightness=WR.Brightness.sValue; WR.Brightness.saved=false
        end
    end
end

function WR.changeApply()
    if not Svc.L then return end
    local L = Svc.L
    local S = Settings.World.Glow
    local glowKey = (S.Enabled and 1 or 0) .. "|" .. tostring(S.Intensity) .. "|" .. tostring(S.Color)
    if WR.lastGlowOn ~= glowKey then
        WR.lastGlowOn = glowKey
        if S.Enabled then
            local function getEffect(state, name, className)
                local effect = state.instance
                if not effect or not effect.Parent then
                    effect = L:FindFirstChild(name)
                    if not effect then
                        effect = Instance.new(className); effect.Name = name; effect.Parent = L
                        state.created = true
                    else
                        state.created = false
                    end
                    state.instance = effect
                    state.saved = false
                end
                return effect
            end
            local bloom = getEffect(WR.GlowBloom, "AeroBloom", "BloomEffect")
            local cc = getEffect(WR.GlowCC, "AeroGlowTint", "ColorCorrectionEffect")
            local rays = getEffect(WR.GlowRays, "AeroSunRays", "SunRaysEffect")
            if not WR.GlowBloom.saved then
                WR.GlowBloom.sEnabled=bloom.Enabled; WR.GlowBloom.sIntensity=bloom.Intensity
                WR.GlowBloom.sSize=bloom.Size; WR.GlowBloom.sThreshold=bloom.Threshold
                WR.GlowBloom.saved=true
            end
            if not WR.GlowCC.saved then
                WR.GlowCC.sEnabled=cc.Enabled; WR.GlowCC.sTint=cc.TintColor
                WR.GlowCC.sBrightness=cc.Brightness; WR.GlowCC.sContrast=cc.Contrast
                WR.GlowCC.sSaturation=cc.Saturation
                WR.GlowCC.saved=true
            end
            if not WR.GlowRays.saved then
                WR.GlowRays.sEnabled=rays.Enabled; WR.GlowRays.sIntensity=rays.Intensity
                WR.GlowRays.sSpread=rays.Spread; WR.GlowRays.saved=true
            end
            local intensity = H.clamp(tonumber(S.Intensity) or 0, 0, 3)
            local strength = intensity / 3
            local active = intensity > 0.001
            bloom.Enabled=active; bloom.Intensity=strength * 1.1; bloom.Size=28; bloom.Threshold=1.15
            cc.Enabled=active
            cc.TintColor=Color3.new(1,1,1):Lerp(S.Color, 0.2 * strength)
            cc.Brightness=strength * 0.025; cc.Contrast=strength * 0.035; cc.Saturation=strength * 0.08
            rays.Enabled=active; rays.Intensity=strength * 0.075; rays.Spread=0.82
        else
            local function release(state, restore)
                if not state.saved then return end
                local effect = state.instance
                if effect and effect.Parent then
                    if state.created then
                        pcall(function() effect:Destroy() end)
                    else
                        pcall(function() restore(effect, state) end)
                    end
                end
                state.saved=false; state.created=false; state.instance=nil
            end
            release(WR.GlowBloom, function(e, st)
                e.Enabled=st.sEnabled; e.Intensity=st.sIntensity; e.Size=st.sSize; e.Threshold=st.sThreshold
            end)
            release(WR.GlowCC, function(e, st)
                e.Enabled=st.sEnabled; e.TintColor=st.sTint; e.Brightness=st.sBrightness
                e.Contrast=st.sContrast; e.Saturation=st.sSaturation
            end)
            release(WR.GlowRays, function(e, st)
                e.Enabled=st.sEnabled; e.Intensity=st.sIntensity; e.Spread=st.sSpread
            end)
        end
    end

    local setting = Settings.World.Skybox or "Normal"
    local targetId = nil
    if SKYBOXES[setting] then
        targetId = SKYBOXES[setting]
    elseif setting == "Custom" then
        targetId = resolveAssetId(Settings.World.CustomSkyID)
    elseif Settings.World.SavedSkyboxes[setting] then
        targetId = resolveAssetId(Settings.World.SavedSkyboxes[setting])
    end
    local skyKey = targetId or "none"
    if WR.lastSky ~= skyKey then
        WR.lastSky = skyKey
        local st = WR.Sky
        if targetId then
            local sky = st.instance
            if not sky or not sky.Parent then
                sky = L:FindFirstChild("AeroSky")
                if not sky then
                    sky = L:FindFirstChildOfClass("Sky")
                    if not sky then
                        sky = Instance.new("Sky"); sky.Name = "AeroSky"; sky.Parent = L
                        st.created = true
                    else
                        st.created = false
                    end
                end
                st.instance = sky
            end
            if not st.saved then
                st.sBk = sky.SkyboxBk; st.sDn = sky.SkyboxDn; st.sFt = sky.SkyboxFt
                st.sLf = sky.SkyboxLf; st.sRt = sky.SkyboxRt; st.sUp = sky.SkyboxUp
                st.sStars = sky.StarCount; st.sCelest = sky.CelestialBodiesShown
                st.sSunSize = sky.SunAngularSize; st.sMoonSize = sky.MoonAngularSize
                st.saved = true
            end
            pcall(function()
                sky.SkyboxBk = targetId
                sky.SkyboxDn = targetId
                sky.SkyboxFt = targetId
                sky.SkyboxLf = targetId
                sky.SkyboxRt = targetId
                sky.SkyboxUp = targetId
                sky.CelestialBodiesShown = false
            end)
        elseif st.saved then
            local sky = st.instance
            if sky and sky.Parent then
                if st.created then pcall(function() sky:Destroy() end)
                else
                    pcall(function()
                        sky.SkyboxBk = st.sBk; sky.SkyboxDn = st.sDn; sky.SkyboxFt = st.sFt
                        sky.SkyboxLf = st.sLf; sky.SkyboxRt = st.sRt; sky.SkyboxUp = st.sUp
                        sky.StarCount = st.sStars; sky.CelestialBodiesShown = st.sCelest
                        sky.SunAngularSize = st.sSunSize; sky.MoonAngularSize = st.sMoonSize
                    end)
                end
            end
            st.saved = false; st.created = false; st.instance = nil
        end
    end
end

function WR.resetCache()
    WR.lastSky = nil
    WR.lastGlowOn = nil
    WR.lastLoopAt = nil
end

function WR.apply(force)
    WR.loopApply(force)
    WR.changeApply()
end

-- ============================================================
-- WEATHER
-- ============================================================
local Wthr = { part=nil, snow=nil, rain=nil, rainSound=nil }
function Wthr.ensure()
    if Wthr.part and Wthr.part.Parent
        and Wthr.snow and Wthr.snow.Parent == Wthr.part
        and Wthr.rain and Wthr.rain.Parent == Wthr.part
        and Wthr.rainSound and Wthr.rainSound.Parent == Wthr.part then
        return
    end
    if Wthr.part then pcall(function() Wthr.part:Destroy() end) end
    Wthr.part, Wthr.snow, Wthr.rain, Wthr.rainSound = nil, nil, nil, nil
    local part = Instance.new("Part")
    part.Name = "AeroWeather"
    part.Size = Vector3.new(220, 1, 220)
    part.Anchored = true; part.CanCollide = false; part.Transparency = 1
    pcall(function() part.CanQuery = false end)
    pcall(function() part.CanTouch = false end)
    pcall(function() part.CastShadow = false end)
    part.Parent = Svc.WS
    Wthr.part = part
    local snow = Instance.new("ParticleEmitter")
    snow.Name = "AeroSnow"
    snow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    snow.Rate = 0
    snow.Lifetime = NumberRange.new(6, 10)
    snow.Speed = NumberRange.new(6, 14)
    snow.SpreadAngle = Vector2.new(20, 20)
    snow.Rotation = NumberRange.new(0, 360)
    snow.RotSpeed = NumberRange.new(-40, 40)
    snow.EmissionDirection = Enum.NormalId.Bottom
    snow.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.15, 1.4),
        NumberSequenceKeypoint.new(0.85, 1.4),
        NumberSequenceKeypoint.new(1, 0),
    })
    snow.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.15, 0.05),
        NumberSequenceKeypoint.new(0.85, 0.05),
        NumberSequenceKeypoint.new(1, 1),
    })
    snow.Color = ColorSequence.new(Color3.new(1, 1, 1))
    snow.Acceleration = Vector3.new(0, -9, 0)
    snow.VelocityInheritance = 0
    snow.LightEmission = 0.7
    pcall(function() snow.LightInfluence = 0 end)
    snow.Parent = part
    Wthr.snow = snow
    local rain = Instance.new("ParticleEmitter")
    rain.Name = "AeroRain"
    rain.Texture = "rbxassetid://241876428"
    rain.Rate = 0
    rain.Lifetime = NumberRange.new(1.0, 1.6)
    rain.Speed = NumberRange.new(50, 80)
    rain.SpreadAngle = Vector2.new(3, 3)
    rain.EmissionDirection = Enum.NormalId.Bottom
    rain.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.1, 1.8),
        NumberSequenceKeypoint.new(0.9, 1.8),
        NumberSequenceKeypoint.new(1, 0),
    })
    rain.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.1, 0.15),
        NumberSequenceKeypoint.new(0.9, 0.15),
        NumberSequenceKeypoint.new(1, 1),
    })
    rain.Color = ColorSequence.new(Color3.fromRGB(200, 220, 245))
    rain.Acceleration = Vector3.new(0, -160, 0)
    rain.VelocityInheritance = 0
    rain.LightEmission = 0.35
    pcall(function() rain.LightInfluence = 0 end)
    rain.Parent = part
    Wthr.rain = rain
    local rainSound = Instance.new("Sound")
    rainSound.Name = "AeroRainSound"
    rainSound.SoundId = "rbxassetid://1587930499"
    rainSound.Looped = true
    rainSound.Volume = 0
    rainSound.RollOffMode = Enum.RollOffMode.InverseTapered
    rainSound.RollOffMaxDistance = 120
    rainSound.RollOffMinDistance = 10
    rainSound.Parent = part
    Wthr.rainSound = rainSound
end
function Wthr.update(dt)
    dt = H.clamp(tonumber(dt) or 0.1, 0, 0.1)
    local snowOn = Settings.World.Snow.Enabled
    local rainOn = Settings.World.Rain.Enabled
    if snowOn or rainOn then Wthr.ensure() end
    local alpha = 1 - math.exp(-5 * math.max(dt, 1/240))
    if Wthr.part and Wthr.part.Parent and Camera then
        Wthr.part.CFrame = CFrame.new(Camera.CFrame.Position + Vector3.new(0, 45, 0))
    end
    if Wthr.snow then
        local targetRate = snowOn and H.clamp(Settings.World.Snow.Intensity * 3, 0, 600) or 0
        Wthr.snow.Rate = Wthr.snow.Rate + (targetRate - Wthr.snow.Rate) * alpha
    end
    if Wthr.rain then
        local targetRate = rainOn and H.clamp(Settings.World.Rain.Intensity * 4.5, 0, 900) or 0
        Wthr.rain.Rate = Wthr.rain.Rate + (targetRate - Wthr.rain.Rate) * alpha
    end
    if Wthr.rainSound then
        local targetVolume = rainOn and H.clamp(Settings.World.Rain.Intensity / 180, 0, 0.7) or 0
        Wthr.rainSound.Volume = Wthr.rainSound.Volume + (targetVolume - Wthr.rainSound.Volume) * alpha
        if rainOn and not Wthr.rainSound.IsPlaying then
            pcall(function() Wthr.rainSound:Play() end)
        elseif not rainOn and Wthr.rainSound.IsPlaying and Wthr.rainSound.Volume < 0.005 then
            Wthr.rainSound.Volume = 0
            pcall(function() Wthr.rainSound:Stop() end)
        end
    end
    if not snowOn and not rainOn and Wthr.part
        and (not Wthr.snow or Wthr.snow.Rate < 0.5)
        and (not Wthr.rain or Wthr.rain.Rate < 0.5)
        and (not Wthr.rainSound or Wthr.rainSound.Volume < 0.005) then
        pcall(function() Wthr.part:Destroy() end)
        Wthr.part, Wthr.snow, Wthr.rain, Wthr.rainSound = nil, nil, nil, nil
    end
end

-- ============================================================
-- FREECAM
-- ============================================================
FC = {
    active=false, position=Vector3.zero, yaw=0, pitch=0,
    sType=nil, sSubject=nil, sWS=nil, sJP=nil, sJH=nil, sMB=nil, sCharacter=nil, sHumanoid=nil,
}
function FC.activate()
    if FC.active or not Camera then return end
    FC.active = true; St.freecamActive = true
    FC.position = Camera.CFrame.Position
    FC.sType = Camera.CameraType; FC.sSubject = Camera.CameraSubject; FC.sMB = Svc.UIS.MouseBehavior
    local look = Camera.CFrame.LookVector
    FC.yaw = ATAN2(-look.X, -look.Z)
    FC.pitch = math.asin(H.clamp(look.Y, -1, 1))
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    FC.sCharacter = char; FC.sHumanoid = hum
    if hum then
        FC.sWS = hum.WalkSpeed; FC.sJP = hum.JumpPower; FC.sJH = hum.JumpHeight
        hum.WalkSpeed = 0
        pcall(function() hum.JumpPower = 0 end)
        pcall(function() hum.JumpHeight = 0 end)
    end
    Camera.CameraType = Enum.CameraType.Scriptable
    Svc.UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
end
function FC.deactivate()
    if not FC.active then return end
    FC.active = false; St.freecamActive = false
    local currentChar = LP.Character
    local sameCharacter = currentChar ~= nil and currentChar == FC.sCharacter
    local hum = sameCharacter and FC.sHumanoid or (currentChar and currentChar:FindFirstChildOfClass("Humanoid"))
    if Camera then
        if FC.sType then pcall(function() Camera.CameraType = FC.sType end) end
        local subject = FC.sSubject
        if subject and subject.Parent == nil and currentChar then subject = currentChar:FindFirstChildOfClass("Humanoid") end
        if not sameCharacter and hum then subject = hum end
        if subject then pcall(function() Camera.CameraSubject = subject end) end
    end
    if sameCharacter and hum then
        if FC.sWS ~= nil then hum.WalkSpeed = FC.sWS end
        if FC.sJP ~= nil then pcall(function() hum.JumpPower = FC.sJP end) end
        if FC.sJH ~= nil then pcall(function() hum.JumpHeight = FC.sJH end) end
    end
    pcall(function() Svc.UIS.MouseBehavior = FC.sMB or Enum.MouseBehavior.Default end)
    FC.sCharacter=nil; FC.sHumanoid=nil; FC.sWS=nil; FC.sJP=nil; FC.sJH=nil
end
function FC.step(dt)
    if unloaded or not Camera then return end
    if not Settings.World.Freecam.Enabled then
        if FC.active then FC.deactivate() end
        return
    end
    if not FC.active then FC.activate() end
    if not FC.active then return end
    if Camera.CameraType ~= Enum.CameraType.Scriptable then
        pcall(function() Camera.CameraType = Enum.CameraType.Scriptable end)
    end
    local wantLock = (not St.menuVisible) and (not St.uiHovered)
    local newMB = wantLock and Enum.MouseBehavior.LockCenter or Enum.MouseBehavior.Default
    if Svc.UIS.MouseBehavior ~= newMB then pcall(function() Svc.UIS.MouseBehavior = newMB end) end
    if wantLock and type(Svc.UIS.GetMouseDelta) == "function" then
        local ok, delta = pcall(function() return Svc.UIS:GetMouseDelta() end)
        if ok and delta then
            local sens = 0.003
            FC.yaw = FC.yaw - delta.X * sens
            FC.pitch = H.clamp(FC.pitch - delta.Y * sens, -math.pi/2 + 0.01, math.pi/2 - 0.01)
        end
    end
    local speed = Settings.World.Freecam.Speed
    if Svc.UIS:IsKeyDown(Enum.KeyCode.LeftShift) then speed = speed * 3 end
    local forward = Vector3.new(-math.sin(FC.yaw), 0, -math.cos(FC.yaw))
    local right   = Vector3.new( math.cos(FC.yaw), 0, -math.sin(FC.yaw))
    local move = Vector3.new(0, 0, 0)
    if Svc.UIS:IsKeyDown(Enum.KeyCode.W) then move = move + forward end
    if Svc.UIS:IsKeyDown(Enum.KeyCode.S) then move = move - forward end
    if Svc.UIS:IsKeyDown(Enum.KeyCode.A) then move = move - right end
    if Svc.UIS:IsKeyDown(Enum.KeyCode.D) then move = move + right end
    if Svc.UIS:IsKeyDown(Enum.KeyCode.Space) or Svc.UIS:IsKeyDown(Enum.KeyCode.E) then
        move = move + Vector3.new(0, 1, 0)
    end
    if Svc.UIS:IsKeyDown(Enum.KeyCode.LeftControl) or Svc.UIS:IsKeyDown(Enum.KeyCode.Q) then
        move = move - Vector3.new(0, 1, 0)
    end
    if move.Magnitude > 0 then FC.position = FC.position + move.Unit * speed * dt end
    Camera.CFrame = CFrame.new(FC.position) * CFrame.fromEulerAnglesYXZ(FC.pitch, FC.yaw, 0)
    Camera.Focus = Camera.CFrame
end

-- ============================================================
-- STATS
-- ============================================================
function St.updateStatsLabel()
    if not St.statsLabel or not St.statsLabel.Parent then return end
    local ping = G.getPing()
    local pingStr = ping and (tostring(ping) .. "ms") or "--"
    local fpsStr = tostring(St.currentFps or 0)
    St.statsLabel.Text = "Ping: " .. pingStr .. "  FPS: " .. fpsStr
end

-- ============================================================
-- MAIN LOOP
-- ============================================================
local mainStarted = false
local lastHUD, lastStatsTick = 0,0
local errLogged = {}
local function safeCall(name, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and not errLogged[name] then
        errLogged[name] = true
        warn("[Aero] " .. name .. " error: " .. tostring(err))
    end
end
local function mainStep(dt)
    if unloaded then return end
    if not mainStarted then mainStarted = true; print("[Aero] main loop running") end
    if Svc.WS.CurrentCamera ~= Camera then
        Camera = Svc.WS.CurrentCamera
        cachedInset = nil
    end
    if not Camera then return end
    St.fpsFrames = (St.fpsFrames or 0) + 1

    local _rbNow = tick()
    if _rbNow - (St._rbCheck or 0) > 0.1 then
        St._rbCheck = _rbNow
        St._rbActive = Settings.Aimbot.Rainbow
            or Settings.Players.RainbowEnemy
            or Settings.Players.RainbowTeam
            or Settings.Npcs.RainbowNPC
            or Settings.Npcs.CursorRainbow
    end
    if St._rbActive then
        rainbowTick(dt)
        if Settings.Aimbot.Rainbow and St.fovCircle then
            local s = St.fovCircle:FindFirstChildOfClass("UIStroke")
            if s then s.Color = rainbowColor() end
        end
    end

    safeCall("aimStep", St.aimStep, dt)
    safeCall("triggerStep", St.triggerStep, tick())
    safeCall("moveStep", St.moveStep)
    safeCall("rageStep", St.rageStep)
    safeCall("freecam", FC.step, dt)

    local now = tick()
    safeCall("worldLoop", WR.loopApply)
    safeCall("worldChange", WR.changeApply)
    safeCall("weather", Wthr.update, dt)
    safeCall("esp", St.updateESP)
    safeCall("tracers", St.updateTracers)
    safeCall("cursorDot", St.updateCursorDot)
    safeCall("saFov", St.updateSAFOV)
    if now - lastHUD > 0.1 then lastHUD = now; safeCall("hud", St.updateHUD) end
    if Settings.Aimbot.ShowFOV then safeCall("fovPosition", St.updateFOVPosition) end
    if now - lastStatsTick >= 1 then
        St.currentFps = St.fpsFrames
        St.fpsFrames = 0
        lastStatsTick = now
        safeCall("statsLabel", St.updateStatsLabel)
    end
end
local MAIN_BIND = "AeroMainStep"
pcall(function() Svc.RS:UnbindFromRenderStep(MAIN_BIND) end)
pcall(function() Svc.RS:BindToRenderStep(MAIN_BIND, Enum.RenderPriority.Camera.Value + 50, mainStep) end)
print("[Aero] runtime bound")

-- ============================================================
-- WIDGETS
-- ============================================================
local Wg = {}

function Wg.makeToggle(parent, order, opts)
    local value = opts.default == true
    local colorTween, innerTween
    local row = H.new("TextButton", {
        Text="", AutoButtonColor=false, BackgroundTransparency=1,
        Size=UDim2.new(1,0,0,26), LayoutOrder=order, Parent=parent,
    })
    local lbl = H.new("TextLabel", {
        Text=opts.name, Font=FontMed, TextSize=13, TextColor3=T.dim, BackgroundTransparency=1,
        Size=UDim2.new(1,-32,1,0), TextXAlignment=Enum.TextXAlignment.Left, Parent=row,
    })
    local box = H.new("Frame", {
        AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,0,0.5,0),
        Size=UDim2.fromOffset(20,20), BackgroundColor3=value and T.acc or T.off,
        BorderSizePixel=0, Parent=row,
    })
    H.corner(5, box)
    local inner = H.new("Frame", {
        AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5),
        Size=UDim2.fromOffset(value and 12 or 8, value and 12 or 8),
        BackgroundColor3=Color3.fromRGB(255,255,255), BorderSizePixel=0,
        BackgroundTransparency=value and 0 or 0.4, Parent=box,
    })
    H.corner(9999, inner)
    local function apply(v, silent)
        local changed = (v ~= value)
        value = v
        if colorTween then pcall(function() colorTween:Cancel() end) end
        if innerTween then pcall(function() innerTween:Cancel() end) end
        colorTween = Svc.TS:Create(box, TweenInfo.new(0.15), {BackgroundColor3=v and T.acc or T.off})
        innerTween = Svc.TS:Create(inner, TweenInfo.new(0.15), {
            Size=UDim2.fromOffset(v and 12 or 8, v and 12 or 8),
            BackgroundTransparency = v and 0 or 0.4,
        })
        colorTween:Play(); innerTween:Play()
        if changed and opts.callback then opts.callback(v) end
        if changed and not silent then PF.queueSave() end
    end
    ThemeRefreshers[#ThemeRefreshers+1] = function()
        if colorTween then pcall(function() colorTween:Cancel() end); colorTween = nil end
        box.BackgroundColor3 = value and T.acc or T.off
    end
    row.MouseEnter:Connect(function() lbl.TextColor3 = T.txt end)
    row.MouseLeave:Connect(function() lbl.TextColor3 = T.dim end)
    row.MouseButton1Click:Connect(function()
        local s = box.Size
        Svc.TS:Create(box, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size=UDim2.fromOffset(s.X.Offset * 0.92, s.Y.Offset * 0.92)}):Play()
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
    local function normalize(v)
        v = H.clamp(tonumber(v) or min, min, max)
        if opts.step and opts.step > 0 then
            v = min + math.floor((v - min) / opts.step + 0.5) * opts.step
            v = H.clamp(v, min, max)
        end
        return v
    end
    local value = normalize(opts.default or min)
    local row = H.new("Frame", {
        Size=UDim2.new(1,0,0,42), BackgroundTransparency=1, LayoutOrder=order, Parent=parent,
    })
    local lbl = H.new("TextLabel", {
        Text=opts.name, Font=Font, TextSize=13, TextColor3=T.dim, BackgroundTransparency=1,
        Size=UDim2.new(0.6,0,0,16), TextXAlignment=Enum.TextXAlignment.Left, Parent=row,
    })
    local valLbl = H.new("TextLabel", {
        Text=fmt(value), Font=FontMed, TextSize=13, TextColor3=T.txt, BackgroundTransparency=1,
        AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,0),
        Size=UDim2.new(0.4,0,0,16), TextXAlignment=Enum.TextXAlignment.Right, Parent=row,
    })
    local trackHit = H.new("TextButton", {
        Text="", AutoButtonColor=false, BackgroundTransparency=1, BorderSizePixel=0,
        Position=UDim2.fromOffset(6,24), Size=UDim2.new(1,-12,0,12), Parent=row,
    })
    local trackVis = H.new("Frame", {
        AnchorPoint=Vector2.new(0,0.5), Position=UDim2.new(0,0,0.5,0),
        Size=UDim2.new(1,0,0,4), BackgroundColor3=T.trk, BorderSizePixel=0, Parent=trackHit,
    })
    H.corner(2, trackVis)
    local fill = H.new("Frame", {
        Size=UDim2.fromScale((value-min)/span,1), BackgroundColor3=T.acc,
        BorderSizePixel=0, Parent=trackVis,
    })
    H.corner(2, fill)
    local knob = H.new("Frame", {
        AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new((value-min)/span,0,0.5,0),
        Size=UDim2.fromOffset(12,12), BackgroundColor3=Color3.new(1,1,1), BorderSizePixel=0,
        ZIndex=2, Parent=trackVis,
    })
    H.corner(6, knob)
    local dragging = false
    local function setFromX(x)
        local rawPos = H.clamp((x - trackVis.AbsolutePosition.X) / math.max(trackVis.AbsoluteSize.X,1), 0, 1)
        value = normalize(min + rawPos * (max - min))
        local pos = (value - min) / span
        fill.Size = UDim2.fromScale(pos,1)
        knob.Position = UDim2.new(pos,0,0.5,0)
        valLbl.Text = fmt(value)
        if opts.callback then opts.callback(value) end
    end
    trackHit.MouseEnter:Connect(function() trackVis.BackgroundColor3 = T.hov end)
    trackHit.MouseLeave:Connect(function() trackVis.BackgroundColor3 = T.trk end)
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
        value = normalize(v)
        local pos = (value-min)/span
        Svc.TS:Create(fill, TweenInfo.new(0.2), {Size=UDim2.fromScale(pos,1)}):Play()
        Svc.TS:Create(knob, TweenInfo.new(0.2), {Position=UDim2.new(pos,0,0.5,0)}):Play()
        valLbl.Text = fmt(value)
        if opts.callback then opts.callback(value) end
    end
end

function Wg.makeButton(parent, order, opts)
    local row = H.new("TextButton", {
        Text="", AutoButtonColor=false, BackgroundTransparency=1,
        Size=UDim2.new(1,0,0,28), LayoutOrder=order, Parent=parent,
    })
    local lbl = H.new("TextLabel", {
        Text=opts.name, Font=Font, TextSize=13, TextColor3=T.dim, BackgroundTransparency=1,
        Size=UDim2.new(0.4,0,1,0), TextXAlignment=Enum.TextXAlignment.Left, Parent=row,
    })
    local box = H.new("Frame", {
        AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,0,0.5,0),
        Size=UDim2.new(0.58,0,0,26), BackgroundColor3=T.sb, BorderSizePixel=0, Parent=row,
    })
    H.corner(6, box); H.stroke(T.st,1,box)
    local pressScale = H.new("UIScale", {Scale=1, Parent=row})
    local text = H.new("TextLabel", {
        Text=(opts.default or ""), Font=Font, TextSize=12, TextColor3=T.txt, BackgroundTransparency=1,
        Size=UDim2.new(1,-16,1,0), Position=UDim2.fromOffset(10,0),
        TextXAlignment=Enum.TextXAlignment.Left, Parent=box,
    })
    row.MouseEnter:Connect(function() lbl.TextColor3 = T.txt end)
    row.MouseLeave:Connect(function() lbl.TextColor3 = T.dim end)
    if opts.callback then
        row.MouseButton1Click:Connect(function()
            Svc.TS:Create(pressScale, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale=0.98}):Play()
            task.delay(0.07, function()
                if pressScale and pressScale.Parent then
                    Svc.TS:Create(pressScale, TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Scale=1}):Play()
                end
            end)
            opts.callback()
        end)
    end
    return row, text, box
end

function Wg.makeDropdown(parent, order, opts)
    local showLabel = opts.showLabel ~= false
    local function getOptions()
        local o = opts.options
        if type(o) == "function" then o = o() end
        if type(o) ~= "table" then o = {} end
        return o
    end
    local initOptions = getOptions()
    local value = opts.default or initOptions[1] or ""
    local row = H.new("Frame", {
        Size=UDim2.new(1,0,0,28), BackgroundTransparency=1, LayoutOrder=order, Parent=parent,
    })
    if showLabel then
        H.new("TextLabel", {
            Text=opts.name, Font=Font, TextSize=13, TextColor3=T.dim, BackgroundTransparency=1,
            Size=UDim2.new(0.4,0,1,0), TextXAlignment=Enum.TextXAlignment.Left, Parent=row,
        })
    end
    local boxWidth = showLabel and 0.58 or 1
    local box = H.new("TextButton", {
        Text="", AutoButtonColor=false, AnchorPoint=Vector2.new(1,0.5),
        Position=UDim2.new(1,0,0.5,0), Size=UDim2.new(boxWidth,0,0,26),
        BackgroundColor3=T.sb, BorderSizePixel=0, Parent=row,
    })
    H.corner(6, box); H.stroke(T.st,1,box)
    local currentSwatch = nil
    if opts.getSwatch then
        local c = opts.getSwatch(value)
        if c then
            currentSwatch = H.new("Frame", {
                Name="ThemeOptionSwatch", BackgroundColor3=c, BorderSizePixel=0,
                Size=UDim2.fromOffset(12,12), Position=UDim2.new(0, 8, 0.5, 0),
                AnchorPoint=Vector2.new(0, 0.5), Parent=box,
            })
            H.corner(3, currentSwatch)
        end
    end
    local labelX = currentSwatch and 26 or 10
    local lbl = H.new("TextLabel", {
        Text=tostring(value), Font=Font, TextSize=12, TextColor3=T.txt,
        BackgroundTransparency=1, Size=UDim2.new(1, -labelX - 20, 1, 0),
        Position=UDim2.fromOffset(labelX, 0),
        TextXAlignment=Enum.TextXAlignment.Left, Parent=box,
    })
    H.new("TextLabel", {
        Text="v", Font=FontBold, TextSize=12, TextColor3=T.dim,
        BackgroundTransparency=1, AnchorPoint=Vector2.new(1,0.5),
        Position=UDim2.new(1,-10,0.5,0), Size=UDim2.fromOffset(12,16), Parent=box,
    })
    local listFrame, blockerConn, closeToken = nil, nil, 0
    local pendingOpen = false
    local function removeFromOpenLists(f)
        for i = #openLists, 1, -1 do
            if openLists[i].frame == f then table.remove(openLists, i) end
        end
    end
    local function closeList()
        if not listFrame then return end
        local f = listFrame
        listFrame = nil
        closeToken = closeToken + 1
        local token = closeToken
        removeFromOpenLists(f)
        local w = f.AbsoluteSize.X
        if w <= 0 then w = 200 end
        Svc.TS:Create(f, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Size=UDim2.fromOffset(w, 0)}):Play()
        task.delay(0.2, function() if token == closeToken then pcall(function() f:Destroy() end) end end)
        if blockerConn then pcall(function() blockerConn:Disconnect() end); blockerConn = nil end
    end
    box.MouseEnter:Connect(function() box.BackgroundColor3 = T.hov end)
    box.MouseLeave:Connect(function() box.BackgroundColor3 = T.sb end)
    box.MouseButton1Click:Connect(function()
        if listFrame then closeList(); return end
        if pendingOpen then return end
        pendingOpen = true
        task.delay(0.5, function() pendingOpen = false end)
        for i = #openLists, 1, -1 do
            local e = openLists[i]
            if e and e.close and e.frame ~= listFrame then pcall(e.close) end
        end
        local boxAbsSnap  = box.AbsolutePosition
        local boxSizeSnap = box.AbsoluteSize
        task.spawn(function()
            Svc.RS.Heartbeat:Wait(); task.wait(); Svc.RS.Heartbeat:Wait()
            pendingOpen = false
            if listFrame then return end
            local optionList = getOptions()
            local count = #optionList
            if count == 0 then return end
            local rowH = 26
            local fullH = count * rowH + 8
            local boxAbs  = boxAbsSnap
            local boxSize = boxSizeSnap
            if boxSize.X <= 1 then boxSize = Vector2.new(200, boxSize.Y) end
            if boxSize.Y <= 1 then boxSize = Vector2.new(boxSize.X, 26) end
            local overlayAbs = OverlayGui.AbsolutePosition
            local overlaySize = OverlayGui.AbsoluteSize
            local listX = boxAbs.X - overlayAbs.X
            local listY = boxAbs.Y - overlayAbs.Y + boxSize.Y + 2
            if listY + fullH > overlaySize.Y then
                listY = boxAbs.Y - overlayAbs.Y - fullH - 2
                if listY < 4 then listY = 4 end
            end
            if listX + boxSize.X > overlaySize.X then
                listX = overlaySize.X - boxSize.X - 4
            end
            if listX < 4 then listX = 4 end
            listFrame = H.new("Frame", {
                BackgroundColor3=T.sb, BorderSizePixel=0, ZIndex=10,
                Position=UDim2.fromOffset(listX, listY),
                Size=UDim2.fromOffset(boxSize.X, 0),
                ClipsDescendants=true, Parent=OverlayGui,
            })
            H.corner(8, listFrame); H.stroke(T.st,1,listFrame)
            table.insert(openLists, { frame = listFrame, close = closeList })
            local inner = H.new("Frame", {
                Size=UDim2.fromOffset(boxSize.X, fullH),
                BackgroundTransparency=1, BorderSizePixel=0, ZIndex=11, Parent=listFrame,
            })
            local sl = H.new("ScrollingFrame", {
                Size=UDim2.fromScale(1,1), BackgroundTransparency=1, BorderSizePixel=0,
                ScrollBarThickness=3, ScrollBarImageColor3=T.st, CanvasSize=UDim2.new(),
                AutomaticCanvasSize=Enum.AutomaticSize.Y, ZIndex=12, Parent=inner,
            })
            H.new("UIListLayout", {Padding=UDim.new(0,2), SortOrder=Enum.SortOrder.LayoutOrder, Parent=sl})
            H.pad(4,4,4,4, sl)
            for i, opt in ipairs(optionList) do
                local r = H.new("TextButton", {
                    Text="", AutoButtonColor=false,
                    BackgroundColor3=(opt == value) and T.hov or T.pn,
                    Size=UDim2.new(1,-4,0,rowH-2), LayoutOrder=i, ZIndex=13, Parent=sl,
                })
                H.corner(5, r)
                local textLeft = 8
                if opts.getSwatch then
                    local swCol = opts.getSwatch(opt)
                    if swCol then
                        local sw = H.new("Frame", {
                            Name="ThemeOptionSwatch", BackgroundColor3=swCol, BorderSizePixel=0,
                            Size=UDim2.fromOffset(12, 12), Position=UDim2.new(0, 8, 0.5, 0),
                            AnchorPoint=Vector2.new(0, 0.5), ZIndex=14, Parent=r,
                        })
                        H.corner(3, sw)
                        textLeft = 26
                    end
                end
                H.new("TextLabel", {
                    Text=tostring(opt), Font=Font, TextSize=12, TextColor3=T.txt,
                    BackgroundTransparency=1, ZIndex=14,
                    Position=UDim2.fromOffset(textLeft, 0),
                    Size=UDim2.new(1, -textLeft - 8, 1, 0),
                    TextXAlignment=Enum.TextXAlignment.Left, Parent=r,
                })
                r.MouseEnter:Connect(function()
                    Svc.TS:Create(r, TweenInfo.new(0.1), {BackgroundColor3=T.hov}):Play()
                end)
                r.MouseLeave:Connect(function()
                    if opt ~= value then
                        Svc.TS:Create(r, TweenInfo.new(0.1), {BackgroundColor3=T.pn}):Play()
                    end
                end)
                r.MouseButton1Click:Connect(function()
                    value = opt
                    lbl.Text = tostring(opt)
                    if currentSwatch and opts.getSwatch then
                        local c = opts.getSwatch(opt)
                        if c then currentSwatch.BackgroundColor3 = c end
                    end
                    if opts.callback then opts.callback(opt) end
                    PF.queueSave()
                    closeList()
                end)
            end
            Svc.TS:Create(listFrame, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size=UDim2.fromOffset(boxSize.X, fullH)}):Play()
            task.defer(function()
                if blockerConn then pcall(function() blockerConn:Disconnect() end) end
                blockerConn = trackWindow(Svc.UIS.InputBegan:Connect(function(inp, gpe)
                    if gpe then return end
                    if not listFrame then
                        if blockerConn then pcall(function() blockerConn:Disconnect() end); blockerConn = nil end
                        return
                    end
                    if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                    local mp = Svc.UIS:GetMouseLocation()
                    local ap, as = listFrame.AbsolutePosition, listFrame.AbsoluteSize
                    local inside = mp.X >= ap.X and mp.X <= ap.X+as.X and mp.Y >= ap.Y and mp.Y <= ap.Y+as.Y
                    local liveBoxAbs  = box.AbsolutePosition
                    local liveBoxSize = box.AbsoluteSize
                    local onBox = mp.X >= liveBoxAbs.X and mp.X <= liveBoxAbs.X+liveBoxSize.X
                        and mp.Y >= liveBoxAbs.Y and mp.Y <= liveBoxAbs.Y+liveBoxSize.Y
                    if not inside and not onBox then closeList() end
                end))
            end)
        end)
    end)
    return function(v)
        value = v
        lbl.Text = tostring(v)
        if currentSwatch and opts.getSwatch then
            local c = opts.getSwatch(v)
            if c then currentSwatch.BackgroundColor3 = c end
        end
        if opts.callback then opts.callback(v) end
    end
end

function Wg.makeColorPicker(parent, order, opts)
    local value = opts.default or COLORS[1].c
    local row = H.new("Frame", {
        Size=UDim2.new(1,0,0,48), BackgroundTransparency=1, LayoutOrder=order, Parent=parent,
    })
    local titleRow = H.new("Frame", {Size=UDim2.new(1,0,0,22), BackgroundTransparency=1, Parent=row})
    H.new("TextLabel", {
        Text=opts.name, Font=Font, TextSize=13, TextColor3=T.dim, BackgroundTransparency=1,
        Size=UDim2.new(1,-30,1,0), TextXAlignment=Enum.TextXAlignment.Left, Parent=titleRow,
    })
    local curBox = H.new("Frame", {
        Name="CustomColorSwatch", AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,0,0.5,0),
        Size=UDim2.fromOffset(22,18), BackgroundColor3=value, BorderSizePixel=0, Parent=titleRow,
    })
    H.corner(4, curBox); H.stroke(T.st,1,curBox)
    local strip = H.new("Frame", {
        Position = UDim2.fromOffset(0, 24), Size=UDim2.new(1,0,0,22),
        BackgroundColor3=T.sb, BorderSizePixel=0, Parent=row,
    })
    H.corner(6, strip); H.stroke(T.st,1,strip)
    H.new("UIListLayout", {
        FillDirection=Enum.FillDirection.Horizontal, Padding=UDim.new(0,4),
        HorizontalAlignment=Enum.HorizontalAlignment.Center,
        VerticalAlignment=Enum.VerticalAlignment.Center, Parent=strip,
    })
    local swatches = {}
    local swatchTweens = {}
    local function highlight(sel)
        for j, s in ipairs(swatches) do
            if swatchTweens[j] then pcall(function() swatchTweens[j]:Cancel() end) end
            local tw = Svc.TS:Create(s, TweenInfo.new(0.15),
                {Size = UDim2.fromOffset(j==sel and 15 or 12, j==sel and 15 or 12)})
            swatchTweens[j] = tw
            tw:Play()
        end
    end
    for i, c in ipairs(COLORS) do
        local sw = H.new("TextButton", {
            Name="ColorChoiceSwatch", Text="", AutoButtonColor=false, BackgroundColor3=c.c,
            Size=UDim2.fromOffset(12,12), BorderSizePixel=0, Parent=strip,
        })
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
        value = v
        curBox.BackgroundColor3 = v
        for i, c in ipairs(COLORS) do if c.c == v then highlight(i) end end
        if opts.callback then opts.callback(v) end
    end
end

function Wg.makeKeybind(parent, order, opts)
    local value = opts.default
    if value == Enum.KeyCode.Unknown then value = nil end
    local showLabel = opts.showLabel ~= false
    local row = H.new("Frame", {
        Size=UDim2.new(1,0,0,26), BackgroundTransparency=1, LayoutOrder=order, Parent=parent,
    })
    if showLabel then
        H.new("TextLabel", {
            Text=opts.name, Font=Font, TextSize=13, TextColor3=T.dim, BackgroundTransparency=1,
            Size=UDim2.new(0.5,0,1,0), TextXAlignment=Enum.TextXAlignment.Left, Parent=row,
        })
    end
    local boxWidth = showLabel and 0.46 or 1
    local box = H.new("TextButton", {
        Text="", AutoButtonColor=false, AnchorPoint=Vector2.new(1,0.5),
        Position=UDim2.new(1,0,0.5,0), Size=UDim2.new(boxWidth,0,0,24),
        BackgroundColor3=T.sb, BorderSizePixel=0, Parent=row,
    })
    H.corner(6, box); H.stroke(T.st,1,box)
    local lbl = H.new("TextLabel", {
        Text="NONE", Font=FontMed, TextSize=12, TextColor3=T.txt,
        BackgroundTransparency=1, Size=UDim2.fromScale(1,1), Parent=box,
    })

    local lastBindTime = 0
    local listening = false

    local function refreshVisual()
        if opts.validate then
            if value ~= nil then
                box.BackgroundColor3 = T.hov
                lbl.TextColor3 = T.acc
            else
                box.BackgroundColor3 = T.sb
                lbl.TextColor3 = T.dim
            end
        else
            box.BackgroundColor3 = T.sb
            lbl.TextColor3 = T.txt
        end
        lbl.Text = value and G.keyName(value) or "NONE"
    end
    refreshVisual()

    box.MouseButton1Click:Connect(function()
        if tick() - lastBindTime < 0.15 then return end
        if listening then return end
        if activeKeybindListener then pcall(activeKeybindListener.cancel) end
        listening = true
        lbl.Text = "..."; lbl.TextColor3 = T.acc
        activeKeybindListener = {
            cancel = function()
                if not listening then return end
                listening = false
                refreshVisual()
                activeKeybindListener = nil
            end,
        }
    end)
    box.MouseButton2Click:Connect(function()
        if tick() - lastBindTime < 0.15 then return end
        if listening then return end
        value = nil
        refreshVisual()
        if opts.callback then opts.callback(nil) end
        PF.saveNow()
    end)
    trackWindow(Svc.UIS.InputBegan:Connect(function(inp)
        if not listening then return end
        if inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode == Enum.KeyCode.Escape then
            listening = false
            activeKeybindListener = nil
            refreshVisual()
            return
        end
        local nv = nil
        if inp.UserInputType == Enum.UserInputType.Keyboard then
            if inp.KeyCode == Enum.KeyCode.Unknown then
                listening = false
                activeKeybindListener = nil
                refreshVisual()
                return
            end
            nv = inp.KeyCode
        elseif inp.UserInputType == Enum.UserInputType.MouseButton1 then nv = Enum.UserInputType.MouseButton1
        elseif inp.UserInputType == Enum.UserInputType.MouseButton2 then nv = Enum.UserInputType.MouseButton2
        elseif inp.UserInputType == Enum.UserInputType.MouseButton3 then nv = Enum.UserInputType.MouseButton3
        end
        if nv then
            if opts.validate then
                local ok, msg = opts.validate(nv)
                if not ok then
                    listening = false
                    activeKeybindListener = nil
                    lbl.Text = msg or "In use"
                    lbl.TextColor3 = Color3.fromRGB(240, 80, 80)
                    task.delay(1.0, function()
                        if lbl and lbl.Parent then refreshVisual() end
                    end)
                    return
                end
            end
            value = nv
            listening = false
            activeKeybindListener = nil
            lastBindTime = tick()
            refreshVisual()
            if opts.callback then opts.callback(value) end
            PF.saveNow()
        end
    end))
end

function Wg.makeTextbox(parent, order, opts)
    local row = H.new("Frame", {
        Size=UDim2.new(1,0,0,28), BackgroundTransparency=1, LayoutOrder=order, Parent=parent,
    })
    H.new("TextLabel", {
        Text=opts.name, Font=Font, TextSize=13, TextColor3=T.dim, BackgroundTransparency=1,
        Size=UDim2.new(0.4,0,1,0), TextXAlignment=Enum.TextXAlignment.Left, Parent=row,
    })
    local box = H.new("Frame", {
        AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,0,0.5,0),
        Size=UDim2.new(0.58,0,0,26), BackgroundColor3=T.sb, BorderSizePixel=0, Parent=row,
    })
    H.corner(6, box); H.stroke(T.st,1,box)
    local tb = H.new("TextBox", {
        Text = opts.default or "", PlaceholderText=opts.placeholder or "",
        Font=Font, TextSize=12, TextColor3=T.txt, PlaceholderColor3=T.dim,
        BackgroundTransparency=1, Size=UDim2.new(1,-16,1,0), Position=UDim2.fromOffset(8,0),
        TextXAlignment=Enum.TextXAlignment.Left, ClearTextOnFocus=false, Parent=box,
    })
    if opts.callback then
        tb.FocusLost:Connect(function()
            local out = opts.callback(tb.Text)
            if type(out) == "string" then tb.Text = out end
        end)
    end
    return tb
end

function Wg.doubleConfirm(row, textLabel, defaultText, action)
    local armed = false
    row.MouseButton1Click:Connect(function()
        if not armed then
            armed = true; textLabel.Text = "Confirm?"
            task.delay(1.2, function() if armed then armed = false; textLabel.Text = defaultText end end)
        else
            armed = false; textLabel.Text = defaultText; action()
        end
    end)
end

-- ============================================================
-- BUILD WINDOW
-- ============================================================
local function getPresetOptions()
    local arr = {}
    for name in pairs(Presets) do table.insert(arr, name) end
    table.sort(arr)
    if #arr == 0 then table.insert(arr, "(none)") end
    return arr
end

local function dedupeSkyboxName(name)
    if not BUILTIN_SKY_SET[name] then return name end
    local i = 2
    while BUILTIN_SKY_SET[name .. " (" .. i .. ")"] or Settings.World.SavedSkyboxes[name .. " (" .. i .. ")"] do
        i = i + 1
    end
    return name .. " (" .. i .. ")"
end

local function getSkyboxList()
    local arr = {}
    for _, n in ipairs(SKYBOX_NAMES) do arr[#arr+1] = n end
    for name in pairs(Settings.World.SavedSkyboxes) do arr[#arr+1] = name end
    return arr
end

local function buildWindow()
    local PAGES = {}
    local currentPage = nil
    local sidebarHoverState = {}

    for k in pairs(uiToggleRefs) do uiToggleRefs[k] = nil end

    local repaintSidebarTheme
    for _, c in ipairs(WindowConnections) do pcall(function() c:Disconnect() end) end
    WindowConnections = {}
    ThemeBindings = {}
    ThemeRefreshers = {}
    if St.rootStrokeTween then pcall(function() St.rootStrokeTween:Cancel() end) end
    St.rootStrokeTween = nil
    H.closeAllDropdowns()

    local startupPalette = THEMES[Settings.UI.Theme] or THEMES.Purple
    if not THEMES[Settings.UI.Theme] then Settings.UI.Theme = "Purple" end
    for k in pairs(T) do T[k] = nil end
    for k, v in pairs(startupPalette) do T[k] = v end

    if St.gui then pcall(function() St.gui:Destroy() end) end
    PAGES = {}
    sidebarHoverState = {}
    St.buildFOV()
    St.buildHUD()
    St.ensureESPGui()
    St.buildCursorDot()
    St.buildSAFOV()

    St.gui = H.new("ScreenGui", {
        Name="AeroUI", ResetOnSpawn=false, IgnoreGuiInset=true,
        DisplayOrder=2147483646, ZIndexBehavior=Enum.ZIndexBehavior.Sibling, Parent=GuiParent,
    })

    local WIN_W, WIN_H = 820, 560
    local TOP_H = 54
    local SB_W = 190

    if Settings.UI.Position then
        local vp = Camera and Camera.ViewportSize or Vector2.new(1920, 1080)
        local p = Settings.UI.Position
        local ax = p.X.Scale * vp.X + p.X.Offset
        local ay = p.Y.Scale * vp.Y + p.Y.Offset
        ax = H.clamp(ax, 200, vp.X - 200)
        ay = H.clamp(ay, 120, vp.Y - 120)
        Settings.UI.Position = UDim2.new(0, ax, 0, ay)
    end

    local root = H.new("Frame", {
        Name="Root", AnchorPoint=Vector2.new(0.5,0.5),
        Position=Settings.UI.Position or UDim2.fromScale(0.5,0.5),
        Size=UDim2.fromOffset(WIN_W,WIN_H),
        BackgroundColor3=T.bg, BorderSizePixel=0, ClipsDescendants=true, Parent=St.gui,
    })
    St.root = root
    H.corner(16, root); H.stroke(T.st,1,root); H.gradient(root, 0, 0.5)
    St.rootScale = H.new("UIScale", {Scale = 1, Parent = root})

    root.MouseEnter:Connect(function() St.uiHovered = true end)
    root.MouseLeave:Connect(function() St.uiHovered = false end)

    local topBar = H.new("TextButton", {
        Name="TopBar", Text="", AutoButtonColor=false, BackgroundTransparency=1,
        Size=UDim2.new(1,0,0,TOP_H), Parent=root,
    })

    do
        local icon = H.new("Frame", {
            Name="TriangleIcon", Size=UDim2.fromOffset(36, 36),
            Position=UDim2.new(0, 11, 0.5, 0), AnchorPoint=Vector2.new(0, 0.5),
            BackgroundTransparency=1, Parent=topBar,
        })
        local cx, cy, radius, count = 18, 18, 11, 8
        for i = 1, count do
            local angleDeg = (i - 1) * (360 / count) - 90
            local rad = math.rad(angleDeg)
            local px = cx + math.cos(rad) * radius
            local py = cy + math.sin(rad) * radius
            H.new("TextLabel", {
                Text = "\u{25B2}",
                Font = FontBold, TextSize = 13, TextColor3 = T.acc,
                BackgroundTransparency = 1, Size = UDim2.fromOffset(14, 14),
                Position = UDim2.fromOffset(px, py),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Rotation = angleDeg + 180, Parent = icon,
            })
        end
    end

    H.new("TextLabel", {
        Text="Aero", Font=FontBold, TextSize=19, TextColor3=T.txt,
        BackgroundTransparency=1, Position=UDim2.fromOffset(58,14),
        Size=UDim2.fromOffset(200,26), TextXAlignment=Enum.TextXAlignment.Left, Parent=topBar,
    })
    H.new("TextLabel", {
        Text = tostring(LP.DisplayName) .. " (" .. tostring(LP.Name) .. ")",
        Font = FontMed, TextSize = 13, TextColor3 = T.txt, BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.fromOffset(400, 20), TextXAlignment = Enum.TextXAlignment.Center, Parent = topBar,
    })
    St.statsLabel = H.new("TextLabel", {
        Text = "Ping: --  FPS: --", Font = FontMed, TextSize = 13, TextColor3 = T.dim,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.5, 0),
        Size = UDim2.fromOffset(180, 20), TextXAlignment = Enum.TextXAlignment.Right, Parent = topBar,
    })

    local saveIndicator = H.new("Frame", {
        Name = "SaveIndicator",
        Size = UDim2.fromOffset(6, 6),
        Position = UDim2.fromOffset(52, 27),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = T.acc, BackgroundTransparency = 1,
        BorderSizePixel = 0, Parent = topBar,
    })
    H.corner(9999, saveIndicator)
    PF.onSaveStatus = function(ok)
        saveIndicator.BackgroundColor3 = ok and T.acc or Color3.fromRGB(240, 80, 80)
        saveIndicator.BackgroundTransparency = 0
        Svc.TS:Create(saveIndicator, TweenInfo.new(0.9), {BackgroundTransparency = 1}):Play()
    end

    H.new("Frame", {
        Size=UDim2.new(1,-36,0,1), Position=UDim2.fromOffset(18,TOP_H-1),
        BackgroundColor3=T.st, BorderSizePixel=0, Parent=root,
    })

    local body = H.new("Frame", {
        Name="Body", Position=UDim2.fromOffset(0,TOP_H),
        Size=UDim2.new(1,0,1,-TOP_H), BackgroundTransparency=1,
        ClipsDescendants=true, Parent=root,
    })

    local sidebar = H.new("Frame", {
        Size=UDim2.new(0,SB_W,1,0), BackgroundColor3=T.sb, BorderSizePixel=0, Parent=body,
    })
    H.corner(16, sidebar); H.gradient(sidebar, 0, 0.5)

    local sidebarScroll = H.new("ScrollingFrame", {
        Size=UDim2.new(1,-16,1,-16), Position=UDim2.fromOffset(8,8),
        BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=3,
        ScrollBarImageColor3=T.st, CanvasSize=UDim2.new(),
        AutomaticCanvasSize=Enum.AutomaticSize.Y, Parent=sidebar,
    })
    H.new("UIListLayout", {
        Padding=UDim.new(0,14), SortOrder=Enum.SortOrder.LayoutOrder,
        HorizontalAlignment=Enum.HorizontalAlignment.Center, Parent=sidebarScroll,
    })

    local pageContainer = H.new("Frame", {
        Position=UDim2.fromOffset(SB_W,0), Size=UDim2.new(1,-SB_W,1,0),
        BackgroundTransparency=1, ClipsDescendants=true, Parent=body,
    })
    H.pad(14,10,14,14, pageContainer)
    St.pageContainer = pageContainer

    local function makePage(name)
        local page = H.new("Frame", {
            Name=name, Size=UDim2.fromScale(1,1), BackgroundTransparency=1,
            Visible=false, Position=UDim2.new(0,0,0,0), Parent=pageContainer,
        })
        PAGES[name] = page
        return page
    end

    local function twoColumn(page)
        local r = H.new("Frame", {Size=UDim2.fromScale(1,1), BackgroundTransparency=1, Parent=page})
        H.new("UIListLayout", {
            FillDirection=Enum.FillDirection.Horizontal,
            Padding=UDim.new(0,14), SortOrder=Enum.SortOrder.LayoutOrder, Parent=r,
        })
        local function panel(title, order)
            local p = H.new("Frame", {
                Size=UDim2.new(0.5,-7,1,0), BackgroundColor3=T.pn, BorderSizePixel=0,
                LayoutOrder=order, Parent=r,
            })
            H.corner(10,p); H.stroke(T.st,1,p); H.gradient(p, 0, 0.4)
            H.new("TextLabel", {
                Text=title, Font=FontBold, TextSize=15, TextColor3=T.txt,
                BackgroundTransparency=1, Position=UDim2.fromOffset(16,12),
                Size=UDim2.new(1,-32,0,22), TextXAlignment=Enum.TextXAlignment.Left, Parent=p,
            })
            local content = H.new("ScrollingFrame", {
                Position=UDim2.fromOffset(12,42), Size=UDim2.new(1,-24,1,-54),
                BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=3,
                ScrollBarImageColor3=T.st, CanvasSize=UDim2.new(),
                AutomaticCanvasSize=Enum.AutomaticSize.Y, Parent=p,
            })
            H.new("UIListLayout", {Padding=UDim.new(0,10), SortOrder=Enum.SortOrder.LayoutOrder, Parent=content})
            H.new("UIPadding", {PaddingRight=UDim.new(0,6), Parent=content})
            return content
        end
        return panel
    end

    local function fullPanel(page, title)
        local p = H.new("Frame", {
            Size=UDim2.fromScale(1,1), BackgroundColor3=T.pn, BorderSizePixel=0, Parent=page,
        })
        H.corner(10,p); H.stroke(T.st,1,p); H.gradient(p, 0, 0.4)
        H.new("TextLabel", {
            Text=title, Font=FontBold, TextSize=15, TextColor3=T.txt,
            BackgroundTransparency=1, Position=UDim2.fromOffset(16,12),
            Size=UDim2.new(1,-32,0,22), TextXAlignment=Enum.TextXAlignment.Left, Parent=p,
        })
        local content = H.new("ScrollingFrame", {
            Position=UDim2.fromOffset(12,42), Size=UDim2.new(1,-24,1,-54),
            BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=3,
            ScrollBarImageColor3=T.st, CanvasSize=UDim2.new(),
            AutomaticCanvasSize=Enum.AutomaticSize.Y, Parent=p,
        })
        H.new("UIListLayout", {Padding=UDim.new(0,10), SortOrder=Enum.SortOrder.LayoutOrder, Parent=content})
        H.new("UIPadding", {PaddingRight=UDim.new(0,6), Parent=content})
        return content
    end

    -- SILENT AIM PAGE
    local saPage = makePage("Silent Aim")
    local saCol = twoColumn(saPage)
    local saL = saCol("Silent Aim", 1)
    local saR = saCol("Settings", 2)

    uiToggleRefs.SAEnabled = Wg.makeToggle(saL, 1, {name="Enabled", default=Settings.SilentAim.Enabled, callback=function(v) Settings.SilentAim.Enabled = v; if v then SA.hook() else SA.unhook() end; if St.saFovGui then St.saFovGui.Enabled = v and Settings.SilentAim.ShowFOV end end})
    Wg.makeDropdown(saL, 2, {name="Method", options={"Viewport"}, default="Viewport"})
    Wg.makeDropdown(saL, 3, {name="Bodypart", options={"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "Random", "Random2"}, default=Settings.SilentAim.Bodypart, callback=function(v) Settings.SilentAim.Bodypart = v end})

    Wg.makeToggle(saR, 1, {name="Wall Check", default=Settings.SilentAim.WallCheck, callback=function(v) Settings.SilentAim.WallCheck = v end})
    Wg.makeToggle(saR, 2, {name="Target NPCs", default=Settings.SilentAim.TargetNPCs, callback=function(v) Settings.SilentAim.TargetNPCs = v end})
    Wg.makeToggle(saR, 3, {name="Show FOV", default=Settings.SilentAim.ShowFOV, callback=function(v) Settings.SilentAim.ShowFOV = v; if St.saFovGui then St.saFovGui.Enabled = v and Settings.SilentAim.Enabled end end})
    Wg.makeSlider(saR, 4, {name="FOV Size", min=20, max=500, default=Settings.SilentAim.FOVSize, callback=function(v) Settings.SilentAim.FOVSize = v; if St.saFovCircle then St.saFovCircle.Size = UDim2.fromOffset(v*2, v*2) end end})
    Wg.makeColorPicker(saR, 5, {name="FOV Color", default=Settings.SilentAim.FOVColor, callback=function(v) Settings.SilentAim.FOVColor = v; if St.saFovCircle then local s = St.saFovCircle:FindFirstChildOfClass("UIStroke"); if s then s.Color = v end end end})

    -- AIMBOT
    local aimbotPage = makePage("Aimbot")
    local col = twoColumn(aimbotPage)
    local aimL = col("Aimbot", 1)
    uiToggleRefs.AimbotEnabled = Wg.makeToggle(aimL, 1, {name="Enabled", default=Settings.Aimbot.Enabled,
        callback=function(v)
            Settings.Aimbot.Enabled = v
            if not v then St.aimLockedTarget = nil; St.aimLockedSince = 0 end
        end})
    Wg.makeToggle(aimL, 2, {name="Wall Check", default=Settings.Aimbot.WallCheck, callback=function(v) Settings.Aimbot.WallCheck = v end})
    Wg.makeToggle(aimL, 3, {name="Team Check", default=Settings.Aimbot.TeamCheck, callback=function(v) Settings.Aimbot.TeamCheck = v end})
    Wg.makeToggle(aimL, 4, {name="Dead Check", default=Settings.Aimbot.DeadCheck, callback=function(v) Settings.Aimbot.DeadCheck = v end})
    Wg.makeToggle(aimL, 5, {name="Spawn Prot Check", default=Settings.Aimbot.SpawnProtCheck, callback=function(v) Settings.Aimbot.SpawnProtCheck = v; if v then St.aimLockedTarget = nil; St.aimLockedSince = 0 end end})
    Wg.makeToggle(aimL, 6, {name="Target NPCs", default=Settings.Npcs.Aimbot, callback=function(v) Settings.Npcs.Aimbot = v end})
    Wg.makeDropdown(aimL, 7, {name="Aim Part", options={"Head","Torso","Random"}, default=Settings.Aimbot.AimPart, callback=function(v) Settings.Aimbot.AimPart = v end})
    Wg.makeSlider(aimL, 8, {name="Max Distance", min=0, max=1500, default=Settings.Aimbot.MaxDistance, format=function(v) return math.floor(v).." studs" end, callback=function(v) Settings.Aimbot.MaxDistance = v end})
    Wg.makeSlider(aimL, 9, {name="Smoothing", min=0, max=100, default=Settings.Aimbot.Smoothing, format=function(v) return math.floor(v).."%" end, callback=function(v) Settings.Aimbot.Smoothing = v end})
    Wg.makeSlider(aimL, 10, {name="Strength", min=1, max=100, default=Settings.Aimbot.Strength, format=function(v) return math.floor(v).."%" end, callback=function(v) Settings.Aimbot.Strength = v end})
    Wg.makeSlider(aimL, 11, {name="Aimbot Delay", min=0, max=2, step=0.05, default=Settings.Aimbot.Delay, format=function(v) return string.format("%.2fs", v) end, callback=function(v) Settings.Aimbot.Delay = v; St.aimLockedTarget = nil; St.aimLockedSince = 0 end})

    local aimR = col("FOV", 2)
    Wg.makeToggle(aimR, 1, {name="Show FOV", default=Settings.Aimbot.ShowFOV, callback=function(v) Settings.Aimbot.ShowFOV = v; St.updateFOV() end})
    Wg.makeDropdown(aimR, 2, {name="FOV Mode", options={"Center","Cursor"}, default=Settings.Aimbot.FOVMode, callback=function(v) Settings.Aimbot.FOVMode = v; St.updateFOVPosition() end})
    Wg.makeSlider(aimR, 3, {name="FOV Size", min=20, max=500, default=Settings.Aimbot.FOVSize, format=function(v) return math.floor(v).." px" end, callback=function(v) Settings.Aimbot.FOVSize = v; St.updateFOV() end})
    Wg.makeSlider(aimR, 4, {name="FOV Transparency", min=0, max=100, default=math.floor(Settings.Aimbot.FOVTransparency*100), format=function(v) return math.floor(v).."%" end, callback=function(v) Settings.Aimbot.FOVTransparency = v/100; St.updateFOV() end})
    Wg.makeColorPicker(aimR, 5, {name="FOV Color", default=Settings.Aimbot.FOVColor, callback=function(v) Settings.Aimbot.FOVColor = v; St.updateFOV() end})
    Wg.makeToggle(aimR, 6, {name="Rainbow FOV", default=Settings.Aimbot.Rainbow, callback=function(v) Settings.Aimbot.Rainbow = v; if not v then St.updateFOV() end end})
    Wg.makeSlider(aimR, 7, {name="FOV Offset X", min=-100, max=100, step=1, default=Settings.Aimbot.FOVOffsetX, format=function(v) return string.format("%d px", math.floor(v + 0.5)) end, callback=function(v) Settings.Aimbot.FOVOffsetX = v end})
    Wg.makeSlider(aimR, 8, {name="FOV Offset Y", min=-100, max=100, step=1, default=Settings.Aimbot.FOVOffsetY, format=function(v) return string.format("%d px", math.floor(v + 0.5)) end, callback=function(v) Settings.Aimbot.FOVOffsetY = v end})

    -- TRIGGERBOT
    local trigPage = makePage("Triggerbot")
    local trigCol = twoColumn(trigPage)
    local trigL = trigCol("Toggles", 1)
    local trigR = trigCol("Settings", 2)

    uiToggleRefs.TriggerbotEnabled = Wg.makeToggle(trigL, 1, {name="Enabled", default=Settings.Triggerbot.Enabled, callback=function(v) Settings.Triggerbot.Enabled = v end})
    Wg.makeToggle(trigL, 2, {name="Team Check", default=Settings.Triggerbot.TeamCheck, callback=function(v) Settings.Triggerbot.TeamCheck = v end})
    Wg.makeToggle(trigL, 3, {name="Dead Check", default=Settings.Triggerbot.DeadCheck, callback=function(v) Settings.Triggerbot.DeadCheck = v end})
    Wg.makeToggle(trigL, 4, {name="Wall Check", default=Settings.Triggerbot.WallCheck, callback=function(v) Settings.Triggerbot.WallCheck = v end})
    Wg.makeToggle(trigL, 5, {name="Spawn Prot Check", default=Settings.Triggerbot.SpawnProtCheck, callback=function(v) Settings.Triggerbot.SpawnProtCheck = v; if v then St.hoverSince = nil; St.lastTargetSeen = nil end end})
    Wg.makeToggle(trigL, 6, {name="Hold Key", default=Settings.Triggerbot.HoldEnabled, callback=function(v) Settings.Triggerbot.HoldEnabled = v end})
    Wg.makeKeybind(trigL, 7, {name="Trigger Key (Hold)", default=Settings.Triggerbot.HoldKey, callback=function(k) Settings.Triggerbot.HoldKey = k end, validate=function(k) return not keyInUse(k, "TriggerKey") end})

    Wg.makeSlider(trigR, 1, {name="Hold Delay", min=0, max=1, step=0.01, default=Settings.Triggerbot.RMBDelay, format=function(v) return string.format("%.2fs", v) end, callback=function(v) Settings.Triggerbot.RMBDelay = v end})
    Wg.makeSlider(trigR, 2, {name="Initial Delay", min=0, max=2, step=0.01, default=Settings.Triggerbot.InitialDelay, format=function(v) return string.format("%.2fs", v) end, callback=function(v) Settings.Triggerbot.InitialDelay = v end})
    Wg.makeSlider(trigR, 3, {name="Delay Between", min=0, max=1, step=0.01, default=Settings.Triggerbot.ShotDelay, format=function(v) return string.format("%.2fs", v) end, callback=function(v) Settings.Triggerbot.ShotDelay = v end})
    Wg.makeSlider(trigR, 4, {name="Distance", min=0, max=1500, default=Settings.Triggerbot.Distance, format=function(v) return math.floor(v).." studs" end, callback=function(v) Settings.Triggerbot.Distance = v end})
    Wg.makeDropdown(trigR, 5, {name="Trigger Part", options={"Head","Torso","Any"}, default=Settings.Triggerbot.TriggerPart, callback=function(v) Settings.Triggerbot.TriggerPart = v end})

    -- PLAYERS
    local playersPage = makePage("Players")
    local plCol = twoColumn(playersPage)
    local plL = plCol("Toggles", 1)
    local plR = plCol("Customize", 2)

    uiToggleRefs.EspEnabled = Wg.makeToggle(plL, 1, {name="Enabled", default=Settings.Players.Enabled, callback=function(v) Settings.Players.Enabled = v; if not v then St.clearESPByType(false); St.clearTracersByType(false) end end})
    uiToggleRefs.PlayerName = Wg.makeToggle(plL, 2, {name="Name", default=Settings.Players.ShowName, callback=function(v) Settings.Players.ShowName = v end})
    uiToggleRefs.ShowTeam = Wg.makeToggle(plL, 3, {name="Show Team", default=Settings.Players.ShowTeam, callback=function(v) Settings.Players.ShowTeam = v end})
    uiToggleRefs.PlayerBox = Wg.makeToggle(plL, 4, {name="Box", default=Settings.Players.Box, callback=function(v) Settings.Players.Box = v end})
    uiToggleRefs.PlayerTracers = Wg.makeToggle(plL, 5, {name="Tracers", default=Settings.Players.Tracers, callback=function(v) Settings.Players.Tracers = v; St.clearTracers() end})
    uiToggleRefs.PlayerChams = Wg.makeToggle(plL, 6, {name="Chams", default=Settings.Players.Chams, callback=function(v) Settings.Players.Chams = v end})
    uiToggleRefs.PlayerHealthBar = Wg.makeToggle(plL, 7, {name="Health Bar", default=Settings.Players.HealthBar, callback=function(v) Settings.Players.HealthBar = v end})
    Wg.makeToggle(plL, 8, {name="Team Check", default=Settings.Players.TeamCheck, callback=function(v) Settings.Players.TeamCheck = v; St.clearTracers() end})

    Wg.makeSlider(plR, 1, {name="ESP Range", min=50, max=1500, default=Settings.Players.Range, format=function(v) return math.floor(v).." studs" end, callback=function(v) Settings.Players.Range = v end})
    Wg.makeColorPicker(plR, 2, {name="Enemy Color", default=Settings.Players.EnemyColor, callback=function(v) Settings.Players.EnemyColor = v end})
    Wg.makeColorPicker(plR, 3, {name="Teammate Color", default=Settings.Players.TeammateColor, callback=function(v) Settings.Players.TeammateColor = v end})
    uiToggleRefs.RainbowEnemy = Wg.makeToggle(plR, 4, {name="Rainbow Enemy", default=Settings.Players.RainbowEnemy, callback=function(v) Settings.Players.RainbowEnemy = v end})
    uiToggleRefs.RainbowTeam = Wg.makeToggle(plR, 5, {name="Rainbow Team", default=Settings.Players.RainbowTeam, callback=function(v) Settings.Players.RainbowTeam = v end})

    -- NPCs
    local npcsPage = makePage("Npcs")
    local npcsCol = twoColumn(npcsPage)
    local npcsL = npcsCol("NPC Features", 1)
    local npcsR = npcsCol("Appearance", 2)
    uiToggleRefs.NpcESP = Wg.makeToggle(npcsL, 1, {name="NPC ESP", default=Settings.Npcs.ESP, callback=function(v) Settings.Npcs.ESP = v; St.targetCache = nil; if not v then St.clearESPByType(true); St.clearTracersByType(true) end end})
    uiToggleRefs.NpcAimbot = Wg.makeToggle(npcsL, 2, {name="NPC Aimbot", default=Settings.Npcs.Aimbot, callback=function(v) Settings.Npcs.Aimbot = v; St.targetCache = nil; if not v and St.aimLockedTarget and not St.aimLockedTarget.plr then St.aimLockedTarget = nil; St.aimLockedSince = 0 end end})
    uiToggleRefs.NpcRagebot = Wg.makeToggle(npcsL, 3, {name="NPC Ragebot", default=Settings.Npcs.Ragebot, callback=function(v) Settings.Npcs.Ragebot = v; St.targetCache = nil; if not v and RB.target and not RB.target.plr then RB.reset() end end})
    uiToggleRefs.NpcTriggerbot = Wg.makeToggle(npcsL, 4, {name="NPC Triggerbot", default=Settings.Npcs.Triggerbot, callback=function(v) Settings.Npcs.Triggerbot = v; St.targetCache = nil; if not v then St.hoverSince = nil; St.lastTargetSeen = nil end end})

    Wg.makeColorPicker(npcsR, 1, {name="NPC ESP Colour", default=Settings.Npcs.ESPColor, callback=function(v) Settings.Npcs.ESPColor = v end})
    uiToggleRefs.RainbowNPC = Wg.makeToggle(npcsR, 2, {name="Rainbow NPC", default=Settings.Npcs.RainbowNPC, callback=function(v) Settings.Npcs.RainbowNPC = v end})
    Wg.makeColorPicker(npcsR, 3, {name="Cursor Colour", default=Settings.Npcs.CursorColor, callback=function(v) Settings.Npcs.CursorColor = v; if St.cursorDot then St.cursorDot.BackgroundColor3 = v end end})
    uiToggleRefs.CursorRainbow = Wg.makeToggle(npcsR, 4, {name="Rainbow Cursor", default=Settings.Npcs.CursorRainbow, callback=function(v) Settings.Npcs.CursorRainbow = v end})
    uiToggleRefs.ShowCursor = Wg.makeToggle(npcsR, 5, {name="Show Cursor", default=Settings.Npcs.ShowCursor, callback=function(v) Settings.Npcs.ShowCursor = v end})

    -- WORLD
    local worldPage = makePage("World")
    local worldCol = twoColumn(worldPage)
    local worldL = worldCol("Atmosphere", 1)
    uiToggleRefs.Ambience = Wg.makeToggle(worldL, 1, {name="Ambience", default=Settings.World.Ambience.Enabled, callback=function(v) Settings.World.Ambience.Enabled = v end})
    Wg.makeColorPicker(worldL, 2, {name="Ambience Color", default=Settings.World.Ambience.Color, callback=function(v) Settings.World.Ambience.Color = v end})
    uiToggleRefs.Glow = Wg.makeToggle(worldL, 3, {name="Glow", default=Settings.World.Glow.Enabled, callback=function(v) Settings.World.Glow.Enabled = v end})
    Wg.makeColorPicker(worldL, 4, {name="Glow Color", default=Settings.World.Glow.Color, callback=function(v) Settings.World.Glow.Color = v end})
    Wg.makeSlider(worldL, 5, {name="Glow Intensity", min=0, max=3, step=0.05, default=Settings.World.Glow.Intensity, format=function(v) return string.format("%.2f", v) end, callback=function(v) Settings.World.Glow.Intensity = v end})
    uiToggleRefs.Brightness = Wg.makeToggle(worldL, 6, {name="Custom Brightness", default=Settings.World.Brightness.Enabled, callback=function(v) Settings.World.Brightness.Enabled = v end})
    Wg.makeSlider(worldL, 7, {name="Brightness", min=0, max=10, step=0.1, default=Settings.World.Brightness.Value, format=function(v) return string.format("%.1f", v) end, callback=function(v) Settings.World.Brightness.Value = v end})
    local skyList = getSkyboxList()
    if not table.find(skyList, Settings.World.Skybox) then Settings.World.Skybox = "Normal" end
    Wg.makeDropdown(worldL, 8, {name="Skybox", options=getSkyboxList, default=Settings.World.Skybox, callback=function(v) Settings.World.Skybox = v end})
    Wg.makeTextbox(worldL, 9, {name="Custom Sky ID", placeholder="12345678", default = Settings.World.CustomSkyID or "", callback=function(v) local norm = resolveAssetId(v) or ""; Settings.World.CustomSkyID = norm; if norm ~= "" then Settings.World.Skybox = "Custom" end; return norm end})

    local worldR = worldCol("Weather", 2)
    uiToggleRefs.Fog = Wg.makeToggle(worldR, 1, {name="Custom Fog", default=Settings.World.Fog.Enabled, callback=function(v) Settings.World.Fog.Enabled = v end})
    Wg.makeColorPicker(worldR, 2, {name="Fog Color", default=Settings.World.Fog.Color, callback=function(v) Settings.World.Fog.Color = v end})
    Wg.makeSlider(worldR, 3, {name="Fog Distance", min=50, max=5000, step=50, default=Settings.World.Fog.Distance, format=function(v) return math.floor(v).." studs" end, callback=function(v) Settings.World.Fog.Distance = v end})
    uiToggleRefs.Time = Wg.makeToggle(worldR, 4, {name="Custom Time", default=Settings.World.Time.Enabled, callback=function(v) Settings.World.Time.Enabled = v end})
    Wg.makeSlider(worldR, 5, {name="Time (24h)", min=0, max=24, step=0.1, default=Settings.World.Time.Value, format=function(v) local h = math.floor(v); local m = math.floor((v - h) * 60); return string.format("%02d:%02d", h, m) end, callback=function(v) Settings.World.Time.Value = v end})
    uiToggleRefs.Rainfall = Wg.makeToggle(worldR, 6, {name="Rainfall", default=Settings.World.Rain.Enabled, callback=function(v) Settings.World.Rain.Enabled = v end})
    Wg.makeSlider(worldR, 7, {name="Rain Intensity", min=0, max=200, default=Settings.World.Rain.Intensity, format=function(v) return math.floor(v).."%" end, callback=function(v) Settings.World.Rain.Intensity = v end})
    uiToggleRefs.Snowfall = Wg.makeToggle(worldR, 8, {name="Snowfall", default=Settings.World.Snow.Enabled, callback=function(v) Settings.World.Snow.Enabled = v end})
    Wg.makeSlider(worldR, 9, {name="Snow Intensity", min=0, max=200, default=Settings.World.Snow.Intensity, format=function(v) return math.floor(v).."%" end, callback=function(v) Settings.World.Snow.Intensity = v end})

    -- RAGEBOT
    local ragePage = makePage("Ragebot")
    local rg = fullPanel(ragePage, "Ragebot")
    uiToggleRefs.RagebotEnabled = Wg.makeToggle(rg, 1, {name="Enabled", default=Settings.Ragebot.Enabled, callback=function(v) Settings.Ragebot.Enabled = v; if not v then RB.reset() end end})
    Wg.makeDropdown(rg, 2, {name="Mode", options={"Above","Orbit","Behind","Infront","Below","Random"}, default=Settings.Ragebot.Mode, callback=function(v) Settings.Ragebot.Mode = v end})
    Wg.makeSlider(rg, 3, {name="Orbit Speed", min=0, max=50, default=Settings.Ragebot.OrbitSpeed, format=function(v) return math.floor(v).."x" end, callback=function(v) Settings.Ragebot.OrbitSpeed = v end})
    Wg.makeSlider(rg, 4, {name="Rage Distance", min=1, max=30, step=0.5, default=Settings.Ragebot.RageDistance, format=function(v) return string.format("%.1f", v) end, callback=function(v) Settings.Ragebot.RageDistance = v end})
    Wg.makeSlider(rg, 5, {name="Max Distance", min=100, max=1500, step=50, default=Settings.Ragebot.Distance, format=function(v) return math.floor(v).." studs" end, callback=function(v) Settings.Ragebot.Distance = v end})
    Wg.makeToggle(rg, 6, {name="Team Check", default=Settings.Ragebot.TeamCheck, callback=function(v) Settings.Ragebot.TeamCheck = v end})
    Wg.makeToggle(rg, 7, {name="Spawn Prot Check", default=Settings.Ragebot.SpawnProtCheck, callback=function(v) Settings.Ragebot.SpawnProtCheck = v; if v and RB.target and RB.target.plr and G.isSpawnProtected(RB.target.plr, RB.target.hum, RB.target.model) then RB.reset() end end})
    Wg.makeToggle(rg, 8, {name="Target NPCs", default=Settings.Ragebot.TargetNPCs, callback=function(v) Settings.Ragebot.TargetNPCs = v end})

    -- MOVEMENT
    local movePage = makePage("Movement")
    local mv = fullPanel(movePage, "Movement")
    uiToggleRefs.Fly = Wg.makeToggle(mv, 1, {name="Fly", default=Settings.Movement.Fly, callback=function(v) Settings.Movement.Fly = v end})
    Wg.makeSlider(mv, 2, {name="Fly Speed", min=10, max=500, default=Settings.Movement.FlySpeed, format=function(v) return math.floor(v).." spd" end, callback=function(v) Settings.Movement.FlySpeed = v end})
    uiToggleRefs.WalkSpeedEn = Wg.makeToggle(mv, 3, {name="WalkSpeed Override", default=Settings.Movement.WalkSpeedEn, callback=function(v) Settings.Movement.WalkSpeedEn = v end})
    Wg.makeSlider(mv, 4, {name="WalkSpeed", min=8, max=300, default=Settings.Movement.WalkSpeed, format=function(v) return tostring(math.floor(v)) end, callback=function(v) Settings.Movement.WalkSpeed = v end})
    uiToggleRefs.Noclip = Wg.makeToggle(mv, 5, {name="Noclip", default=Settings.Movement.Noclip, callback=function(v) Settings.Movement.Noclip = v end})
    uiToggleRefs.InfiniteJump = Wg.makeToggle(mv, 6, {name="Infinite Jump", default=Settings.Movement.InfiniteJump, callback=function(v) Settings.Movement.InfiniteJump = v end})
    uiToggleRefs.JumpHeightEn = Wg.makeToggle(mv, 7, {name="Jump Height Override", default=Settings.Movement.JumpHeightEn, callback=function(v) Settings.Movement.JumpHeightEn = v end})
    Wg.makeSlider(mv, 8, {name="Jump Height", min=0, max=100, step=0.1, default=Settings.Movement.JumpHeight, format=function(v) return string.format("%.1f studs", v) end, callback=function(v) Settings.Movement.JumpHeight = v end})
    uiToggleRefs.FreecamToggle = Wg.makeToggle(mv, 9, {name="Freecam", default=Settings.World.Freecam.Enabled, callback=function(v) Settings.World.Freecam.Enabled = v; if v then FC.activate() else FC.deactivate() end end})
    Wg.makeSlider(mv, 10, {name="Freecam Speed", min=10, max=300, step=5, default=Settings.World.Freecam.Speed, format=function(v) return math.floor(v).." spd" end, callback=function(v) Settings.World.Freecam.Speed = v end})

    -- KEYBINDS
    local keyPage = makePage("Keybinds")
    local kb = fullPanel(keyPage, "Keybinds")
    Wg.makeKeybind(kb, 1, {name="Aimbot Toggle", default=Settings.Keybinds.AimbotToggle, callback=function(k) Settings.Keybinds.AimbotToggle = k; PF.saveNow() end, validate=function(k) return not keyInUse(k, "AimbotToggle") end})
    Wg.makeKeybind(kb, 2, {name="Aim Key (Hold)", default=Settings.Keybinds.AimKey, callback=function(k) Settings.Keybinds.AimKey = k; PF.saveNow() end, validate=function(k) return not keyInUse(k, "AimKey") end})
    Wg.makeKeybind(kb, 3, {name="Triggerbot Toggle", default=Settings.Keybinds.TriggerbotToggle, callback=function(k) Settings.Keybinds.TriggerbotToggle = k; PF.saveNow() end, validate=function(k) return not keyInUse(k, "TriggerbotToggle") end})
    Wg.makeKeybind(kb, 4, {name="ESP Toggle", default=Settings.Keybinds.EspToggle, callback=function(k) Settings.Keybinds.EspToggle = k; PF.saveNow() end, validate=function(k) return not keyInUse(k, "EspToggle") end})
    Wg.makeKeybind(kb, 5, {name="Ragebot Toggle", default=Settings.Keybinds.RagebotToggle, callback=function(k) Settings.Keybinds.RagebotToggle = k; PF.saveNow() end, validate=function(k) return not keyInUse(k, "RagebotToggle") end})
    Wg.makeKeybind(kb, 6, {name="Silent Aim Key", default=Settings.Keybinds.SilentAimKey, callback=function(k) Settings.Keybinds.SilentAimKey = k; PF.saveNow() end, validate=function(k) return not keyInUse(k, "SilentAimKey") end})
    Wg.makeKeybind(kb, 7, {name="Menu Key", default=Settings.Keybinds.MenuKey, callback=function(k) Settings.Keybinds.MenuKey = k; PF.saveNow() end, validate=function(k) return not keyInUse(k, "MenuKey") end})
    Wg.makeKeybind(kb, 8, {name="Panic Key", default=Settings.Keybinds.PanicKey, callback=function(k) Settings.Keybinds.PanicKey = k; PF.saveNow() end, validate=function(k) return not keyInUse(k, "PanicKey") end})

    -- SIDEBAR
    local sectionCounter = 0
    local sidebarRows = {}
    local sidebarTweens = {}
    local hoveredSidebarRow = nil

    local function applySidebarRowVisual(name, hover)
        local entry = sidebarRows[name]
        if not entry then return end
        local active = (name == currentPage)
        local prior = sidebarTweens[name]
        if prior then
            for _, tw in ipairs(prior) do pcall(function() tw:Cancel() end) end
        end
        entry.label.Font = active and FontMed or Font
        local rowTween = Svc.TS:Create(entry.row, TweenInfo.new(0.13, Enum.EasingStyle.Quad), {
            BackgroundColor3 = active and T.hov or T.pn,
            BackgroundTransparency = active and 0 or 1,
        })
        local labelTween = Svc.TS:Create(entry.label, TweenInfo.new(0.13, Enum.EasingStyle.Quad), {
            TextColor3 = hover and (active and T.txt or T.dim:Lerp(T.txt, 0.5))
                or (active and T.txt or T.dim),
            Position = UDim2.fromOffset((hover and not active) and 12 or 10, 0),
        })
        sidebarTweens[name] = {rowTween, labelTween}
        rowTween:Play(); labelTween:Play()
    end

    local pageTransitionToken = 0
    local pageTweens = {}
    local function animatePageTo(name)
        local newPage = PAGES[name]
        if not newPage then return end
        H.closeAllDropdowns()
        for page, tween in pairs(pageTweens) do
            pcall(function() tween:Cancel() end)
            pageTweens[page] = nil
        end
        if name == currentPage then
            pageTransitionToken = pageTransitionToken + 1
            for pageName, page in pairs(PAGES) do
                page.Visible = page == newPage
                page.Position = UDim2.new(0, 0, 0, 0)
            end
            newPage.Visible = true
            newPage.Position = UDim2.new(0, 0, 0, 0)
            return
        end
        pageTransitionToken = pageTransitionToken + 1
        local token = pageTransitionToken
        local oldPage = PAGES[currentPage]
        for _, page in pairs(PAGES) do
            if page ~= oldPage and page ~= newPage then
                page.Visible = false
                page.Position = UDim2.new(0, 0, 0, 0)
            end
        end
        local Hgt = pageContainer.AbsoluteSize.Y
        if Hgt <= 1 then Hgt = 560 end
        if oldPage and oldPage ~= newPage then
            oldPage.Visible = true
            oldPage.Position = UDim2.new(0, 0, 0, 0)
            local oldTween = Svc.TS:Create(oldPage, TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut),
                {Position = UDim2.new(0, 0, 0, -Hgt)})
            pageTweens[oldPage] = oldTween
            oldTween:Play()
        end
        newPage.Position = UDim2.new(0, 0, 0, Hgt)
        newPage.Visible = true
        local newTween = Svc.TS:Create(newPage, TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut),
            {Position = UDim2.new(0, 0, 0, 0)})
        pageTweens[newPage] = newTween
        newTween:Play()
        currentPage = name
        Settings.UI.LastPage = name
        PF.queueSave()
        task.delay(0.34, function()
            if token ~= pageTransitionToken then return end
            if oldPage and oldPage ~= PAGES[currentPage] then
                oldPage.Visible = false
                oldPage.Position = UDim2.new(0, 0, 0, 0)
                pageTweens[oldPage] = nil
            end
            newPage.Position = UDim2.new(0, 0, 0, 0)
            pageTweens[newPage] = nil
        end)
    end

    local function addSection(title, items)
        sectionCounter = sectionCounter + 1
        local secH = 22 + (#items * 26)
        local sec = H.new("Frame", {
            Size=UDim2.new(1,0,0,secH), BackgroundTransparency=1,
            LayoutOrder=sectionCounter, Parent=sidebarScroll,
        })
        H.new("UIListLayout", {Padding=UDim.new(0,2), SortOrder=Enum.SortOrder.LayoutOrder, Parent=sec})
        local hdr = H.new("TextLabel", {
            Text=title, Font=FontBold, TextSize=14, TextColor3=T.txt,
            BackgroundTransparency=1, Size=UDim2.new(1,0,0,22),
            TextXAlignment=Enum.TextXAlignment.Left, LayoutOrder=0, Parent=sec,
        })
        H.pad(0,0,8,0,hdr)
        for i, item in ipairs(items) do
            local row = H.new("TextButton", {
                Text="", AutoButtonColor=false, Size=UDim2.new(1,0,0,24),
                BackgroundColor3=T.pn, BackgroundTransparency=1, LayoutOrder=i, Parent=sec,
            })
            H.corner(6, row)
            local lbl = H.new("TextLabel", {
                Text=item.name, Font=Font, TextSize=13, TextColor3=T.dim,
                BackgroundTransparency=1, Size=UDim2.new(1,-16,1,0),
                Position=UDim2.fromOffset(10,0), TextXAlignment=Enum.TextXAlignment.Left, Parent=row,
            })
            sidebarRows[item.name] = {row=row, label=lbl}
            row.MouseEnter:Connect(function()
                if hoveredSidebarRow and hoveredSidebarRow ~= item.name then
                    sidebarHoverState[hoveredSidebarRow] = false
                    applySidebarRowVisual(hoveredSidebarRow, false)
                end
                hoveredSidebarRow = item.name
                sidebarHoverState[item.name] = true
                applySidebarRowVisual(item.name, true)
            end)
            row.MouseLeave:Connect(function()
                if hoveredSidebarRow == item.name then
                    hoveredSidebarRow = nil
                end
                sidebarHoverState[item.name] = false
                applySidebarRowVisual(item.name, false)
            end)
            row.MouseButton1Click:Connect(function()
                if currentPage == item.name then return end
                animatePageTo(item.name)
                if repaintSidebarTheme then repaintSidebarTheme() end
            end)
        end
    end

    addSection("Combat", { {name="Silent Aim"}, {name="Aimbot"}, {name="Triggerbot"}, {name="Ragebot"} })
    addSection("Visuals", { {name="Players"}, {name="World"}, {name="Npcs"} })
    addSection("Movement", { {name="Movement"} })
    addSection("Misc", { {name="Keybinds"} })

    local startPage = Settings.UI.LastPage or "Aimbot"
    if not PAGES[startPage] then startPage = "Aimbot" end
    PAGES[startPage].Visible = true
    PAGES[startPage].Position = UDim2.new(0,0,0,0)
    currentPage = startPage
    Settings.UI.LastPage = startPage
    for name, entry in pairs(sidebarRows) do
        applySidebarRowVisual(name, false)
    end
    repaintSidebarTheme = function()
        for name, entry in pairs(sidebarRows) do
            applySidebarRowVisual(name, sidebarHoverState[name] == true)
        end
    end

    -- DRAGGING
    local dragging, dragStartMouse, startPos
    trackWindow(Svc.UIS.InputBegan:Connect(function(inp)
        if not St.menuVisible then return end
        if not St.gui or not St.gui.Enabled then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        local mp = inp.Position
        local tp = topBar.AbsolutePosition
        local ts = topBar.AbsoluteSize
        if mp.X >= tp.X and mp.X <= tp.X + ts.X and mp.Y >= tp.Y and mp.Y <= tp.Y + ts.Y then
            dragging = true
            dragStartMouse = Vector2.new(mp.X, mp.Y)
            startPos = root.Position
        end
    end))
    trackWindow(Svc.UIS.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local mp = Vector2.new(inp.Position.X, inp.Position.Y)
        local d = mp - dragStartMouse
        root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                   startPos.Y.Scale, startPos.Y.Offset + d.Y)
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
            St.rootStrokeTween = Svc.TS:Create(s, TweenInfo.new(0.2), {Color=T.acc})
            St.rootStrokeTween:Play()
        end
    end)
    root.MouseLeave:Connect(function()
        local s = root:FindFirstChildOfClass("UIStroke")
        if s then
            if St.rootStrokeTween then pcall(function() St.rootStrokeTween:Cancel() end) end
            St.rootStrokeTween = Svc.TS:Create(s, TweenInfo.new(0.2), {Color=T.st})
            St.rootStrokeTween:Play()
        end
    end)

    H.pruneThemeBindings()
    if St.firstWindowBuild then
        St.firstWindowBuild = false
        St.rootScale.Scale = 0.05
        Svc.TS:Create(St.rootScale, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Scale=1}):Play()
    end
end

-- ============================================================
-- MENU
-- ============================================================
local function openMenu()
    if not St.gui then return end
    St.gui.Enabled = true
    St.menuVisible = true
    if St.rootScale then
        St.rootScale.Scale = 0.05
        Svc.TS:Create(St.rootScale, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Scale=1}):Play()
    end
end
local function closeMenu()
    if not St.gui then return end
    St.menuVisible = false
    St.uiHovered = false
    if activeKeybindListener then pcall(activeKeybindListener.cancel) end
    H.closeAllDropdowns()
    if St.rootScale then
        Svc.TS:Create(St.rootScale, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Scale=0.05}):Play()
        task.delay(0.2, function() if not St.menuVisible then St.gui.Enabled = false end end)
    else
        St.gui.Enabled = false
    end
end

-- ============================================================
-- INPUT HANDLERS
-- ============================================================
track(Svc.UIS.InputBegan:Connect(function(inp, gpe)
    if activeKeybindListener then return end
    if St.uiHovered and inp.UserInputType == Enum.UserInputType.MouseButton1 then return end
    if gpe then return end

    if G.inputMatches(inp, Settings.Triggerbot.HoldKey) then
        St.triggerHoldHeld = true
        St.triggerHoldSince = tick()
    end
    if G.inputMatches(inp, Settings.Keybinds.AimKey) then
        St.aimingHeld = true
    end
    if G.inputMatches(inp, Settings.Keybinds.SilentAimKey) then
        St.saHeld = true
    end
    if G.inputMatches(inp, Settings.Keybinds.AimbotToggle) then
        local newVal = not Settings.Aimbot.Enabled
        if uiToggleRefs.AimbotEnabled then uiToggleRefs.AimbotEnabled(newVal) else Settings.Aimbot.Enabled = newVal end
        if not newVal then St.aimLockedTarget = nil; St.aimLockedSince = 0 end
        PF.queueSave(); return
    end
    if G.inputMatches(inp, Settings.Keybinds.TriggerbotToggle) then
        local newVal = not Settings.Triggerbot.Enabled
        if uiToggleRefs.TriggerbotEnabled then uiToggleRefs.TriggerbotEnabled(newVal) else Settings.Triggerbot.Enabled = newVal end
        PF.queueSave(); return
    end
    if G.inputMatches(inp, Settings.Keybinds.EspToggle) then
        local newVal = not Settings.Players.Enabled
        if uiToggleRefs.EspEnabled then uiToggleRefs.EspEnabled(newVal) else
            Settings.Players.Enabled = newVal
            if not newVal then St.clearESPByType(false); St.clearTracersByType(false) end
        end
        PF.queueSave(); return
    end
    if G.inputMatches(inp, Settings.Keybinds.RagebotToggle) then
        local newVal = not Settings.Ragebot.Enabled
        if uiToggleRefs.RagebotEnabled then uiToggleRefs.RagebotEnabled(newVal) else
            Settings.Ragebot.Enabled = newVal
            if not newVal then RB.reset() end
        end
        PF.queueSave(); return
    end

    if G.inputMatches(inp, Settings.Keybinds.MenuKey) then
        if St.menuVisible then closeMenu() else openMenu() end
        if St.fovGui then St.fovGui.Enabled = Settings.Aimbot.ShowFOV end
        return
    end
    if G.inputMatches(inp, Settings.Keybinds.PanicKey) then
        local now = tick()
        table.insert(St.panicTimes, now)
        while #St.panicTimes > 0 and now - St.panicTimes[1] > 1.5 do
            table.remove(St.panicTimes, 1)
        end
        if #St.panicTimes >= 3 then AeroUnload() end
        return
    end
end))

track(Svc.UIS.InputEnded:Connect(function(inp)
    if G.inputMatches(inp, Settings.Triggerbot.HoldKey) then
        St.triggerHoldHeld = false
    end
    if G.inputMatches(inp, Settings.Keybinds.AimKey) then
        St.aimingHeld = false
        St.aimLockedTarget = nil
        St.aimLockedSince = 0
    end
    if G.inputMatches(inp, Settings.Keybinds.SilentAimKey) then
        St.saHeld = false
    end
end))

-- ============================================================
-- PLAYER HOOKS
-- ============================================================
local function wirePlayerESP(plr)
    if plr == LP then return end
    track(plr.CharacterAdded:Connect(function() St.destroyESPFor(plr) end))
    track(plr.CharacterRemoving:Connect(function() St.destroyESPFor(plr) end))
end

for _, plr in ipairs(Svc.Players:GetPlayers()) do wirePlayerESP(plr) end
track(Svc.Players.PlayerAdded:Connect(function(plr)
    St.espCache[plr] = nil
    wirePlayerESP(plr)
end))
track(Svc.Players.PlayerRemoving:Connect(function(plr)
    St.destroyESPFor(plr)
    if St.tracers[plr] then St.destroyTracer(plr) end
    if St.aimLockedTarget and St.aimLockedTarget.plr == plr then
        St.aimLockedTarget = nil
        St.aimLockedSince = 0
    end
    if RB.target and RB.target.plr == plr then RB.target = nil end
end))

track(LP.CharacterAdded:Connect(function()
    St.clearESP(); St.clearTracers()
    St.aimLockedTarget = nil
    St.aimLockedSince = 0
    St.aimingHeld = false
    St.triggerHoldHeld = false
    St.hoverSince = nil; St.lastTargetSeen = nil
    RB.target = nil; RB.lockUntil = 0
    RB.savedCFrame = nil; RB.savedVelocity = nil; RB.active = false
    RB.savedPlatformStand = false
    St.savedJump = nil
    St.savedWalk = nil
    if St.cameraOwner == "ragebot" then St.releaseCamera() end
    cachedInset = nil
end))

local function hookCharacter(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        St.originalWalkSpeed = hum.WalkSpeed
        local conn
        conn = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if Settings.Movement.WalkSpeedEn and not FC.active and hum.WalkSpeed ~= Settings.Movement.WalkSpeed then
                hum.WalkSpeed = Settings.Movement.WalkSpeed
            end
        end)
        track(conn)
        if FC.active then
            FC.sCharacter=char; FC.sHumanoid=hum; FC.sSubject=hum
            FC.sWS=hum.WalkSpeed; FC.sJP=hum.JumpPower; FC.sJH=hum.JumpHeight
            hum.WalkSpeed=0
            pcall(function() hum.JumpPower=0 end)
            pcall(function() hum.JumpHeight=0 end)
        end
    end
    St.noclipSaved = {}
    St.savedJump = nil
    St.savedWalk = nil
end
if LP.Character then hookCharacter(LP.Character) end
track(LP.CharacterAdded:Connect(hookCharacter))

-- ============================================================
-- UNLOAD
-- ============================================================
function AeroUnload()
    if unloaded then return end
    unloaded = true
    SA.unhook()
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        if St.savedWalk then pcall(function() hum.WalkSpeed = St.savedWalk end) end
        if St.savedJump then pcall(function()
            hum.UseJumpPower = St.savedJump.UseJumpPower
            hum.JumpPower = St.savedJump.JumpPower
            hum.JumpHeight = St.savedJump.JumpHeight
        end) end
        if RB.savedPlatformStand ~= nil then pcall(function() hum.PlatformStand = RB.savedPlatformStand end) end
    end
    Settings.Movement.Fly = false
    Settings.Movement.WalkSpeedEn = false
    Settings.Movement.Noclip = false
    Settings.Movement.InfiniteJump = false
    Settings.Movement.JumpHeightEn = false
    Settings.World.Ambience.Enabled = false
    Settings.World.Fog.Enabled = false
    Settings.World.Glow.Enabled = false
    Settings.World.Brightness.Enabled = false
    Settings.World.Time.Enabled = false
    Settings.World.Skybox = "Normal"
    Settings.World.Snow.Enabled = false
    Settings.World.Rain.Enabled = false
    Settings.Npcs.ShowCursor = false
    WR.resetCache()
    pcall(WR.apply, true)
    pcall(FC.deactivate)

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
    if activeKeybindListener then pcall(activeKeybindListener.cancel) end
    for _, d in pairs(St.espCache) do St.destroyESP(d) end
    St.espCache = {}
    St.clearTracers()
    pcall(RB.reset)
    if Wthr.part then pcall(function() Wthr.part:Destroy() end) end
    Wthr.part, Wthr.snow, Wthr.rain, Wthr.rainSound = nil, nil, nil, nil
    for part, orig in pairs(St.noclipSaved) do
        if part.Parent and part:IsA("BasePart") then pcall(function() part.CanCollide = orig end) end
    end
    St.noclipSaved = {}
    St.panicTimes = {}
    if hum and St.originalWalkSpeed > 0 then pcall(function() hum.WalkSpeed = St.originalWalkSpeed end) end
    pcall(WSHook.remove)
    St.releaseCamera()
    pcall(function() Svc.RS:UnbindFromRenderStep(MAIN_BIND) end)
    if St.fovGui then pcall(function() St.fovGui:Destroy() end) end
    if St.espGui then pcall(function() St.espGui:Destroy() end) end
    if St.cursorGui then pcall(function() St.cursorGui:Destroy() end) end
    if St.hudGui then pcall(function() St.hudGui:Destroy() end) end
    if St.flyBV then pcall(function() St.flyBV:Destroy() end) end
    if St.gui then pcall(function() St.gui:Destroy() end) end
    if OverlayGui then pcall(function() OverlayGui:Destroy() end) end
    if St.saFovGui then pcall(function() St.saFovGui:Destroy() end) end
    print("[Aero] unloaded")
end

-- ============================================================
-- BOOT
-- ============================================================
pcall(PF.loadPresets)
local settingsCallOk, settingsLoaded = pcall(PF.loadAutoSettings)
if settingsCallOk and settingsLoaded then
    print("[Aero] loaded saved settings")
else
    print("[Aero] using default settings")
end

task.defer(function()
    pcall(WSHook.install)
    local ok, err = pcall(buildWindow)
    if ok then
        print("[Aero] loaded successfully")
        pcall(WR.apply)
        if Settings.SilentAim.Enabled then SA.hook() end
    else
        warn("[Aero] buildWindow failed: " .. tostring(err))
    end
end)
