--!nocheck
-- ============================================================
-- Aero Lite — v4.1 (Fixed ESP / FOV centering, sounds removed)
-- Aimbot (hard lock) + Ragebot (Above, Skeleton priority) +
-- ESP (Name / HP text / HP bar / Box / Tracers / Chams) +
-- Fly / Noclip + FOV styles (Circle / Square / Cross / Dot)
-- ============================================================

print("[Aero Lite] booting...")

local Svc = {}
do
    local function s(name) local ok, v = pcall(game.GetService, game, name); if ok then return v end end
    Svc.Players  = s("Players")
    Svc.RS       = s("RunService")
    Svc.UIS      = s("UserInputService")
    Svc.TS       = s("TweenService")
    Svc.SS       = s("SoundService")
    Svc.WS       = s("Workspace")
    Svc.HS       = s("HttpService")
    Svc.Stats    = s("Stats")
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
    if ok and v then GuiParent = v end
end

local Camera = Svc.WS.CurrentCamera

local mouseMoveRel = nil
if type(mousemoverel) == "function" then mouseMoveRel = mousemoverel
elseif type(mouse_move_rel) == "function" then mouseMoveRel = mouse_move_rel
elseif type(syn) == "table" and type(syn.mousemoverel) == "function" then mouseMoveRel = syn.mousemoverel
elseif type(fluxus) == "table" and type(fluxus.mousemoverel) == "function" then mouseMoveRel = fluxus.mousemoverel
end

for _, parent in ipairs({PG, GuiParent}) do
    for _, n in ipairs({"AeroUI","AeroFOV","AeroESP","AeroHUD","AeroOverlay"}) do
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

local St, RB

local SETTINGS_FILE  = "AeroLiteSettings.json"
local SETTINGS_SCHEMA = 5
local AIM_SKIP_STUDS    = 3.0
local POINT_BLANK_STUDS = 1.5
local RAGE_ABOVE_DISTANCE = 4
local RAGE_MAX_DISTANCE   = 750

local function resolveAssetId(str)
    if type(str) ~= "string" then return nil end
    str = str:gsub("^%s+", ""):gsub("%s+$", "")
    if str == "" then return nil end
    if str:match("^rbxassetid://") or str:match("^rbxasset://") then return str end
    if str:match("^%d+$") then return "rbxassetid://" .. str end
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

local Settings = {
    Aimbot = { Enabled=false, WallCheck=true, TeamCheck=true, DeadCheck=true,
        SpawnProtCheck=true, TargetNPCs=true,
        AimPart="Head",
        MaxDistance=500,
        ShowFOV=true, FOVSize=120, FOVColor=Color3.fromRGB(120,90,240), FOVTransparency=0.6,
        Rainbow=false,
        FOVStyle="Circle",       -- [NEW] Circle / Square / Cross / Dot
    },
    Players = { Enabled=false, Chams=false, ShowName=true,
        ShowHealth=true, ShowDistance=true,
        TeamCheck=true, ShowTeam=true, Range=800,
        RainbowEnemy=false, RainbowTeam=false,
        ShowNPCs=true,
        EnemyColor=Color3.fromRGB(255,60,60), TeammateColor=Color3.fromRGB(60,220,120),
        -- [NEW] 2D overlay ESP
        ShowBox=false,
        ShowHealthBar=false,
        ShowTracers=false,
        TracerOrigin="Top",      -- Top / Center / Bottom
    },
    Npcs = { ESPColor=Color3.fromRGB(255,175,70), RainbowNPC=false },
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
    UI       = { Theme="Purple", ShowEnabled=true, LastPage="Aimbot", Position=nil },
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
    if not ok then warn("[Aero Lite] Failed to save settings") end
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
    if type(Settings.Aimbot.SpawnProtCheck) ~= "boolean" then Settings.Aimbot.SpawnProtCheck = true end
    if type(Settings.Aimbot.TargetNPCs) ~= "boolean" then Settings.Aimbot.TargetNPCs = true end
    if type(Settings.Aimbot.FOVStyle) ~= "string" then Settings.Aimbot.FOVStyle = "Circle" end
    if type(Settings.Players.ShowNPCs) ~= "boolean" then Settings.Players.ShowNPCs = true end
    if type(Settings.Players.ShowHealth) ~= "boolean" then Settings.Players.ShowHealth = true end
    if type(Settings.Players.ShowDistance) ~= "boolean" then Settings.Players.ShowDistance = true end
    if type(Settings.Players.ShowBox) ~= "boolean" then Settings.Players.ShowBox = false end
    if type(Settings.Players.ShowHealthBar) ~= "boolean" then Settings.Players.ShowHealthBar = false end
    if type(Settings.Players.ShowTracers) ~= "boolean" then Settings.Players.ShowTracers = false end
    if type(Settings.Players.TracerOrigin) ~= "string" then Settings.Players.TracerOrigin = "Top" end
    if type(Settings.Ragebot) ~= "table" then Settings.Ragebot = {} end
    if type(Settings.Ragebot.Enabled) ~= "boolean" then Settings.Ragebot.Enabled = false end
    local function ensureColor3(tbl, key, fallback)
        if not tbl then return end
        if typeof(tbl[key]) ~= "Color3" then tbl[key] = fallback end
    end
    ensureColor3(Settings.Players, "EnemyColor",    Color3.fromRGB(255,60,60))
    ensureColor3(Settings.Players, "TeammateColor", Color3.fromRGB(60,220,120))
    ensureColor3(Settings.Npcs,    "ESPColor",      Color3.fromRGB(255,175,70))
    ensureColor3(Settings.Aimbot,  "FOVColor",      Color3.fromRGB(120,90,240))
end

function PF.loadAutoSettings()
    local decoded = PF.readJSON(SETTINGS_FILE) or PF.readJSON(SETTINGS_FILE .. ".bak")
    if not decoded then return false end
    local restored = decoded.Settings
    if type(restored) ~= "table" then return false end
    local ok, err = pcall(function()
        restored = PF.deserializeVal(restored)
        for section, tbl in pairs(restored) do
            if type(tbl) == "table" and type(Settings[section]) == "table" then
                PF.merge(Settings[section], tbl)
            end
        end
        migrateSettings()
    end)
    if not ok then
        warn("[Aero Lite] Settings load error: " .. tostring(err))
        return false
    end
    return true
end

-- ============================================================
-- SOUNDS: REMOVED (per request)
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
    for _, name in ipairs({"UpperTorso", "Torso", "Chest", "Body"}) do
        local p = model:FindFirstChild(name)
        if p and p:IsA("BasePart") then return p end
    end
    for _, part in ipairs(model:GetChildren()) do
        if part:IsA("BasePart") then
            local n = part.Name:lower()
            if n == "torso" or n == "uppertorso" or n == "chest" or n == "body" then
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
            for _, n in ipairs({"AeroUI","AeroFOV","AeroESP","AeroHUD","AeroOverlay"}) do
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

St = {
    fovGui = nil, fovCircle = nil,
    espGui = nil,
    hudGui = nil, hudContainer = nil,
    flyBV = nil,
    espCache = {},
    aimingHeld = false,
    aimLockedTarget = nil,
    aimLockedPart = nil,
    aimLockedSince = 0,
    aimGain = 1.0,
    aimGainErrPrev = 0,
    panicTimes = {},
    gui = nil, root = nil, pageContainer = nil, rootScale = nil, rootStrokeTween = nil,
    noclipSaved = {},
    noclipLastTick = 0,
    npcCache = {},
    lastNpcScan = 0,
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
    uiHovered = false,
    ragebotAnchoredRoot = nil,
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

function St.clearAimState()
    St.aimLockedTarget = nil
    St.aimLockedPart = nil
    St.aimLockedSince = 0
end

function St.resetAimGain()
    St.aimGain = 1.0
    St.aimGainErrPrev = 0
end

-- FOV center is the viewport center (crosshair), NOT the mouse.
-- This matches aimCorrectStep's reference and the FOV circle position.
function St.getAimReference()
    if not Camera then return Vector2.zero end
    local vp = Camera.ViewportSize
    return Vector2.new(vp.X * 0.5, vp.Y * 0.5)
end

function St.getFOVCenter()
    return St.getAimReference()
end

-- ============================================================
-- FOV (centered, multi-style)
-- ============================================================
function St.buildFOV()
    if St.fovGui then pcall(function() St.fovGui:Destroy() end) end
    -- IgnoreGuiInset = false -> fromScale(0.5,0.5) sits at the visual center
    -- of the playable area, exactly matching Camera.ViewportSize/2.
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
    St.applyFOVStyle()
    St.updateFOV()
end

function St.applyFOVStyle()
    if not St.fovCircle then return end
    -- Clear previous style elements, keep UICorner
    for _, c in ipairs(St.fovCircle:GetChildren()) do
        if c:IsA("UIStroke") or (c.Name and c.Name:match("^FovStyle")) then
            c:Destroy()
        end
    end
    local corner = St.fovCircle:FindFirstChildOfClass("UICorner")
    if not corner then corner = H.corner(9999, St.fovCircle) end

    local style = Settings.Aimbot.FOVStyle or "Circle"
    local color = Settings.Aimbot.FOVColor
    local trans = Settings.Aimbot.FOVTransparency
    local size  = Settings.Aimbot.FOVSize

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
        local thick = 1.5
        H.new("Frame", {Name="FovStyleTop",    AnchorPoint=Vector2.new(0.5, 1),   Position=UDim2.new(0.5,0,0.5,-size),  Size=UDim2.fromOffset(thick, armLen), BackgroundColor3=color, BackgroundTransparency=trans, BorderSizePixel=0, Parent=St.fovCircle})
        H.new("Frame", {Name="FovStyleBottom", AnchorPoint=Vector2.new(0.5, 0),   Position=UDim2.new(0.5,0,0.5, size),  Size=UDim2.fromOffset(thick, armLen), BackgroundColor3=color, BackgroundTransparency=trans, BorderSizePixel=0, Parent=St.fovCircle})
        H.new("Frame", {Name="FovStyleLeft",   AnchorPoint=Vector2.new(1, 0.5),   Position=UDim2.new(0.5,-size,0.5,0),  Size=UDim2.fromOffset(armLen, thick), BackgroundColor3=color, BackgroundTransparency=trans, BorderSizePixel=0, Parent=St.fovCircle})
        H.new("Frame", {Name="FovStyleRight",  AnchorPoint=Vector2.new(0, 0.5),   Position=UDim2.new(0.5, size,0.5,0),  Size=UDim2.fromOffset(armLen, thick), BackgroundColor3=color, BackgroundTransparency=trans, BorderSizePixel=0, Parent=St.fovCircle})
    elseif style == "Dot" then
        corner.CornerRadius = UDim.new(0, 9999)
        local dotSize = math.max(4, size * 0.08)
        H.new("Frame", {Name="FovStyleDot", AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new(0.5,0,0.5,0),
            Size=UDim2.fromOffset(dotSize, dotSize), BackgroundColor3=color, BackgroundTransparency=trans,
            BorderSizePixel=0, Parent=St.fovCircle})
    end
end

function St.updateFOV()
    if not St.fovCircle or not St.fovGui then return end
    St.fovCircle.Size = UDim2.fromOffset(Settings.Aimbot.FOVSize*2, Settings.Aimbot.FOVSize*2)
    St.fovGui.Enabled = Settings.Aimbot.ShowFOV
    local stroke = St.fovCircle:FindFirstChild("FovStyleStroke")
    if stroke then
        if not Settings.Aimbot.Rainbow then stroke.Color = Settings.Aimbot.FOVColor end
        stroke.Transparency = Settings.Aimbot.FOVTransparency
    end
end

local HUD_FEATURES = {
    { key="Aimbot",  label="AIMBOT",  get=function() return Settings.Aimbot.Enabled end },
    { key="Ragebot", label="RAGEBOT", get=function() return Settings.Ragebot.Enabled end },
    { key="ESP",     label="ESP",     get=function() return Settings.Players.Enabled end },
    { key="Fly",     label="FLY",     get=function() return Settings.Movement.Fly end },
    { key="Noclip",  label="NOCLIP",  get=function() return Settings.Movement.Noclip end },
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
    local includeNPCs = Settings.Players.ShowNPCs or Settings.Aimbot.TargetNPCs or Settings.Ragebot.Enabled
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

function St.findBestTarget(cfg, partPicker)
    if not Camera then return nil end
    local center = St.getFOVCenter()
    local best, bestScore = nil, math.huge
    local checkSpawn = cfg.SpawnProtCheck and true or false
    for _, t in ipairs(St.getTargets()) do
        if not t.plr and not cfg.TargetNPCs then continue end
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
-- AIMBOT target selection (correction is in aimCorrectStep)
-- ============================================================
function St.aimStep(_dt)
    if unloaded or not Camera then return end
    if Settings.Ragebot.Enabled then
        St.clearAimState(); return
    end
    if not Settings.Aimbot.Enabled or not G.alive() or not St.aimingHeld then
        St.clearAimState(); return
    end

    local t
    if St.aimLockedTarget then
        local locked = St.aimLockedTarget
        local stillValid = true
        if not locked.plr and not Settings.Aimbot.TargetNPCs then
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
                local part = St.aimLockedPart
                if not (part and part.Parent) then
                    part = St.pickAimPartWith(locked, Settings.Aimbot.AimPart)
                    St.aimLockedPart = part
                end
                if not part then
                    stillValid = false
                else
                    local dist3 = (Camera.CFrame.Position - part.Position).Magnitude
                    if dist3 > Settings.Aimbot.MaxDistance then
                        stillValid = false
                    elseif Settings.Aimbot.WallCheck and not G.hasLOS(part.Position, locked.model) then
                        stillValid = false
                    end
                end
            end
        end
        if stillValid then
            t = locked
        else
            St.clearAimState()
        end
    end

    if not t then
        t = St.findBestTarget(Settings.Aimbot, function(tt)
            return St.pickAimPartWith(tt, Settings.Aimbot.AimBotPart or Settings.Aimbot.AimPart)
        end)
        if t then
            St.aimLockedTarget = t
            St.aimLockedPart = St.pickAimPartWith(t, Settings.Aimbot.AimPart)
            St.aimLockedSince = tick()
            St.resetAimGain()
        end
    end
end

-- ============================================================
-- ESP (ScreenGui now uses IgnoreGuiInset = false so WorldToViewportPoint
-- coords map directly to 2D element positions)
-- ============================================================
function St.ensureESPGui()
    if St.espGui and St.espGui.Parent then return end
    St.espGui = H.new("ScreenGui", {
        Name="AeroESP", ResetOnSpawn=false, IgnoreGuiInset=false,
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

function St.destroyESP(d)
    if not d then return end
    if d.nameTag then pcall(function() d.nameTag:Destroy() end) end
    if d.cham then pcall(function() d.cham:Destroy() end) end
    if d.box then pcall(function() d.box:Destroy() end) end
    if d.healthBar then pcall(function() d.healthBar:Destroy() end) end
    if d.tracer then pcall(function() d.tracer:Destroy() end) end
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
end

function St.hideESP(d)
    if d.nameTag then d.nameTag.Enabled = false end
    if d.cham then d.cham.Enabled = false end
    if d.box then d.box.Visible = false end
    if d.healthBar then d.healthBar.Visible = false end
    if d.tracer then d.tracer.Visible = false end
end

-- [NEW] Screen-space bounding box helper. Uses WorldToViewportPoint for all
-- 8 corners; takes min/max. Requires at least one corner in front of camera.
local function getScreenBBox(model)
    if not Camera or not model then return nil end
    local ok, cf, size = pcall(function()
        local c, s = model:GetBoundingBox()
        return c, s
    end)
    if not ok or not cf or not size then return nil end
    local hx, hy, hz = size.X/2, size.Y/2, size.Z/2
    local corners = {
        Vector3.new( hx,  hy,  hz), Vector3.new(-hx,  hy,  hz),
        Vector3.new( hx, -hy,  hz), Vector3.new(-hx, -hy,  hz),
        Vector3.new( hx,  hy, -hz), Vector3.new(-hx,  hy, -hz),
        Vector3.new( hx, -hy, -hz), Vector3.new(-hx, -hy, -hz),
    }
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local anyValid = false
    for _, c in ipairs(corners) do
        local worldPos = (cf * CFrame.new(c.X, c.Y, c.Z)).Position
        local sp = Camera:WorldToViewportPoint(worldPos)
        if sp.Z > 0 then
            anyValid = true
            if sp.X < minX then minX = sp.X end
            if sp.X > maxX then maxX = sp.X end
            if sp.Y < minY then minY = sp.Y end
            if sp.Y > maxY then maxY = sp.Y end
        end
    end
    if not anyValid then return nil end
    if maxX - minX < 1 or maxY - minY < 1 then return nil end
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
    St.ensureESPGui()
    if not Camera then return end

    local nameOn    = Settings.Players.ShowName
    local showHp    = Settings.Players.ShowHealth
    local showDist  = Settings.Players.ShowDistance
    local chamsOn   = Settings.Players.Chams
    local showTeam  = Settings.Players.ShowTeam
    local teamCheck = Settings.Players.TeamCheck
    local range     = Settings.Players.Range
    local rangeSq   = range * range
    local boxOn     = Settings.Players.ShowBox
    local hpBarOn   = Settings.Players.ShowHealthBar
    local tracerOn  = Settings.Players.ShowTracers
    local tracerOrigin = Settings.Players.TracerOrigin
    local vp = Camera.ViewportSize

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

        -- Nameplate / HP text / distance text
        if nameOn and d.nameTag then
            if not d.nameTag.Enabled then d.nameTag.Enabled = true end
            if d.nameTag.Adornee ~= root then d.nameTag.Adornee = root end
            local nameText = (plr and plr.Name) or (model.Name or "NPC")
            if d.name.Text ~= nameText then d.name.Text = nameText end
            if d.name.TextColor3 ~= col then d.name.TextColor3 = col end

            local distanceInt = math.floor(dist)
            local hpInt = nil
            if showHp then
                local hp, maxHp = G.healthInfo(plr, hum, model)
                if maxHp and maxHp > 0 then hpInt = math.floor(hp + 0.5) end
            end
            local parts = {}
            if showDist then parts[#parts+1] = distanceInt .. "m" end
            if hpInt ~= nil then parts[#parts+1] = hpInt .. " HP" end
            local subText = table.concat(parts, "  |  ")
            if d.sub.Text ~= subText then d.sub.Text = subText end
            local subVisible = (showDist or hpInt ~= nil)
            if d.sub.Visible ~= subVisible then d.sub.Visible = subVisible end
        elseif d.nameTag then
            if d.nameTag.Enabled then d.nameTag.Enabled = false end
        end

        -- Chams
        if chamsOn and d.cham then
            if not d.cham.Enabled then d.cham.Enabled = true end
            if d.cham.FillColor ~= col then d.cham.FillColor = col end
            if d.cham.Parent ~= model then d.cham.Parent = model end
        elseif d.cham then
            if d.cham.Enabled then d.cham.Enabled = false end
        end

        -- 2D overlays (box / health bar / tracer) - use WorldToViewportPoint directly
        local bbox = (boxOn or hpBarOn or tracerOn) and getScreenBBox(model) or nil

        -- Box
        if boxOn and bbox then
            if not d.box then
                d.box = H.new("Frame", {
                    BackgroundTransparency=1, BorderSizePixel=0, Visible=false,
                    ZIndex=2, Parent=St.espGui,
                })
                H.corner(2, d.box)
                d.boxStroke = H.new("UIStroke", {Thickness=1, ApplyStrokeMode=Enum.ApplyStrokeMode.Border, Parent=d.box})
                H.unbindTheme(d.boxStroke)
            end
            d.box.Visible = true
            d.box.Position = UDim2.fromOffset(bbox.x1, bbox.y1)
            d.box.Size = UDim2.fromOffset(bbox.w, bbox.h)
            d.boxStroke.Color = col
        elseif d.box then
            d.box.Visible = false
        end

        -- Health bar (attached to left of the box)
        if hpBarOn and bbox then
            if not d.healthBar then
                d.healthBar = H.new("Frame", {
                    BackgroundColor3=Color3.fromRGB(20,20,20), BorderSizePixel=0,
                    Visible=false, ZIndex=2, Parent=St.espGui,
                })
                H.new("UIStroke", {Thickness=1, ApplyStrokeMode=Enum.ApplyStrokeMode.Border,
                    Color=Color3.new(0,0,0), Parent=d.healthBar})
                d.healthBarFill = H.new("Frame", {
                    BackgroundColor3=Color3.fromRGB(60,220,100), BorderSizePixel=0,
                    Size=UDim2.fromScale(1, 1), Parent=d.healthBar,
                })
            end
            d.healthBar.Visible = true
            local barW = 3
            local barX = bbox.x1 - barW - 3
            d.healthBar.Position = UDim2.fromOffset(barX, bbox.y1)
            d.healthBar.Size = UDim2.fromOffset(barW, bbox.h)
            local hp, maxHp = G.healthInfo(plr, hum, model)
            local ratio = H.clamp(hp / math.max(maxHp, 1), 0, 1)
            d.healthBarFill.Size = UDim2.fromScale(1, ratio)
            d.healthBarFill.Position = UDim2.fromScale(0, 1 - ratio)
            d.healthBarFill.BackgroundColor3 = Color3.fromHSV(0.33 * ratio, 0.8, 1)
        elseif d.healthBar then
            d.healthBar.Visible = false
        end

        -- Tracer (origin depends on setting)
        if tracerOn and bbox then
            if not d.tracer then
                d.tracer = H.new("Frame", {
                    BackgroundColor3=Color3.new(1,1,1), BorderSizePixel=0,
                    AnchorPoint=Vector2.new(0.5, 0.5), Visible=false,
                    ZIndex=1, Parent=St.espGui,
                })
            end
            d.tracer.Visible = true
            local origin
            if tracerOrigin == "Center" then
                origin = Vector2.new(vp.X/2, vp.Y/2)
            elseif tracerOrigin == "Bottom" then
                origin = Vector2.new(vp.X/2, vp.Y)
            else
                origin = Vector2.new(vp.X/2, 0)
            end
            local targetX = (bbox.x1 + bbox.x2) / 2
            local targetY = bbox.y1
            local dx = targetX - origin.X
            local dy = targetY - origin.Y
            local len = math.sqrt(dx*dx + dy*dy)
            if len < 0.5 then
                d.tracer.Visible = false
            else
                local angle = math.deg(ATAN2(dy, dx))
                local midX = (origin.X + targetX) / 2
                local midY = (origin.Y + targetY) / 2
                d.tracer.Size = UDim2.fromOffset(len, 1)
                d.tracer.Position = UDim2.fromOffset(midX, midY)
                d.tracer.Rotation = angle
                d.tracer.BackgroundColor3 = col
            end
        elseif d.tracer then
            d.tracer.Visible = false
        end
    end

    for key, d in pairs(St.espCache) do
        if not seen[key] then
            St.destroyESP(d); St.espCache[key] = nil
        end
    end
end

-- ============================================================
-- MOVEMENT
-- ============================================================
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
        local anchored = St.ragebotAnchoredRoot
        if anchored.Parent and anchored.Anchored then
            pcall(function() anchored.Anchored = false end)
        end
        St.ragebotAnchoredRoot = nil
    end
end

-- ============================================================
-- RAGEBOT (unchanged)
-- ============================================================
RB = {
    target=nil, lockUntil=0,
    savedCFrame=nil, savedVelocity=nil,
    savedAutoRotate=true, savedWalkSpeed=nil, savedCharacter=nil,
    savedPlatformStand=false,
    savedMouseBehavior=nil,
    active=false,
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
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
    end
    RB.savedMouseBehavior = Svc.UIS.MouseBehavior
    RB.active = true
end
function RB.restore()
    local char = LP.Character
    local sameCharacter = char ~= nil and char == RB.savedCharacter
    if St.ragebotAnchoredRoot and St.ragebotAnchoredRoot.Parent then
        pcall(function() St.ragebotAnchoredRoot.Anchored = false end)
    end
    St.ragebotAnchoredRoot = nil
    if RB.savedMouseBehavior then
        pcall(function() Svc.UIS.MouseBehavior = RB.savedMouseBehavior end)
        RB.savedMouseBehavior = nil
    end
    if not sameCharacter then
        RB.savedCFrame=nil; RB.savedVelocity=nil; RB.savedWalkSpeed=nil; RB.savedCharacter=nil
        RB.savedPlatformStand=false; RB.active=false
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
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
    end
    RB.savedCFrame = nil; RB.savedVelocity = nil; RB.savedWalkSpeed = nil
    RB.savedCharacter = nil; RB.savedPlatformStand = false
    RB.active = false
end
function RB.reset()
    RB.target = nil; RB.lockUntil = 0
    if RB.active then RB.restore() end
    RB.savedCFrame = nil; RB.savedVelocity = nil; RB.savedCharacter = nil
end

local function rageNamePriority(model)
    if not model then return 50 end
    local n = tostring(model.Name or ""):lower()
    if n:find("explosive") then return -1 end
    if n:find("skeleton") then return 100 end
    return 50
end

function RB.findTarget()
    local myChar = LP.Character
    local myRoot = myChar and G.getRootPart(myChar)
    if not myRoot then return nil end
    local best, bestScore = nil, -math.huge
    for _, t in ipairs(St.getTargets()) do
        if not t.hum or t.hum.Health <= 0 or not t.model or not t.model.Parent then continue end
        if t.plr and G.sameTeam(LP, t.plr) then continue end
        if G.isSpawnProtected(t.plr, t.hum, t.model) then continue end
        local priority = rageNamePriority(t.model)
        if priority < 0 then continue end
        local head = G.getHeadPart(t.model)
        local root = t.root or G.getRootPart(t.model)
        if not head or not root then continue end
        local d = (head.Position - myRoot.Position).Magnitude
        if d > RAGE_MAX_DISTANCE then continue end
        local score = priority * 100000 - d
        if score > bestScore then
            bestScore = score
            best = t
        end
    end
    return best
end

function St.rageStep()
    if unloaded or not Camera then return end
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
        if St.ragebotAnchoredRoot and St.ragebotAnchoredRoot.Parent then
            pcall(function() St.ragebotAnchoredRoot.Anchored = false end)
        end
        St.ragebotAnchoredRoot = nil
    end
    if not RB.active then RB.save() end
    myHum.PlatformStand = true
    myHum.AutoRotate = false

    local lockedValid = RB.target
        and RB.lockUntil > now
        and RB.target.hum and RB.target.hum.Health > 0
        and RB.target.model and RB.target.model.Parent
        and RB.target.root and RB.target.root.Parent
        and (RB.target.root.Position - myRoot.Position).Magnitude <= RAGE_MAX_DISTANCE
        and (rageNamePriority(RB.target.model) >= 0)
        and not G.isSpawnProtected(RB.target.plr, RB.target.hum, RB.target.model)
    local t = lockedValid and RB.target or RB.findTarget()
    if t ~= RB.target then
        RB.target = t
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

    local abovePos = targetRoot.Position + Vector3.new(0, RAGE_ABOVE_DISTANCE, 0)
    local delta = head.Position - abovePos
    local lookDir
    if delta.Magnitude < 0.001 then
        lookDir = Vector3.new(0, -1, 0)
    else
        lookDir = delta.Unit
    end
    local horizontalLook = Vector3.new(lookDir.X, 0, lookDir.Z)
    if horizontalLook.Magnitude < 0.001 then
        horizontalLook = Vector3.new(1, 0, 0)
    else
        horizontalLook = horizontalLook.Unit
    end
    local goalCFrame = CFrame.lookAt(abovePos, head.Position, horizontalLook)

    if charModel.PivotTo then
        pcall(function() charModel:PivotTo(goalCFrame) end)
    else
        myRoot.CFrame = goalCFrame
    end

    myRoot.AssemblyLinearVelocity = Vector3.zero
    myRoot.AssemblyAngularVelocity = Vector3.zero
    if not myRoot.Anchored then
        myRoot.Anchored = true
    end
    St.ragebotAnchoredRoot = myRoot

    if not St.menuVisible then
        if Svc.UIS.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
            pcall(function() Svc.UIS.MouseBehavior = Enum.MouseBehavior.LockCenter end)
        end
    else
        if RB.savedMouseBehavior and Svc.UIS.MouseBehavior ~= RB.savedMouseBehavior then
            pcall(function() Svc.UIS.MouseBehavior = RB.savedMouseBehavior end)
        end
    end
end

function St.updateStatsLabel()
    if not St.statsLabel or not St.statsLabel.Parent then return end
    local ping = G.getPing()
    local pingStr = ping and (tostring(ping) .. "ms") or "--"
    local fpsStr = tostring(St.currentFps or 0)
    St.statsLabel.Text = "Ping: " .. pingStr .. "  FPS: " .. fpsStr
end

local mainStarted = false
local lastHUD, lastStatsTick = 0,0
local errLogged = {}
local function safeCall(name, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and not errLogged[name] then
        errLogged[name] = true
        warn("[Aero Lite] " .. name .. " error: " .. tostring(err))
    end
end

local function mainStep(dt)
    if unloaded then return end
    if not mainStarted then mainStarted = true; print("[Aero Lite] main loop running") end
    if Svc.WS.CurrentCamera ~= Camera then
        Camera = Svc.WS.CurrentCamera
        cachedInset = nil
    end
    if not Camera then return end
    St.fpsFrames = (St.fpsFrames or 0) + 1

    if Settings.Aimbot.Rainbow or Settings.Players.RainbowEnemy or Settings.Players.RainbowTeam
       or Settings.Npcs.RainbowNPC then
        rainbowTick(dt)
        if Settings.Aimbot.Rainbow and St.fovCircle then
            local rc = rainbowColor()
            local stroke = St.fovCircle:FindFirstChild("FovStyleStroke")
            if stroke then stroke.Color = rc end
            for _, c in ipairs(St.fovCircle:GetChildren()) do
                if c.Name and c.Name:match("^FovStyle") and c:IsA("Frame") then
                    c.BackgroundColor3 = rc
                end
            end
        end
    end

    safeCall("aimStep", St.aimStep, dt)
    safeCall("moveStep", St.moveStep)
    safeCall("rageStep", St.rageStep)

    local now = tick()
    safeCall("esp", St.updateESP)
    if now - lastHUD > 0.05 then lastHUD = now; safeCall("hud", St.updateHUD) end
    if now - lastStatsTick >= 1 then
        St.currentFps = St.fpsFrames
        St.fpsFrames = 0
        lastStatsTick = now
        safeCall("statsLabel", St.updateStatsLabel)
    end
end

local MAIN_BIND = "AeroLiteMainStep"
local AIM_CORRECT_BIND = "AeroLiteAimCorrect"

local function aimCorrectStep()
    if unloaded then return end
    if not Settings.Aimbot.Enabled then return end
    if Settings.Ragebot.Enabled then return end
    if not St.aimingHeld then return end
    if not Camera then return end
    if not mouseMoveRel then return end

    local t = St.aimLockedTarget
    if not (t and t.model and t.model.Parent) then return end
    if not (t.hum and t.hum.Health > 0) then return end

    local part = St.aimLockedPart
    if not (part and part.Parent) then
        part = St.pickAimPartWith(t, Settings.Aimbot.AimPart)
        St.aimLockedPart = part
    end
    if not part then return end

    local screenPos = Camera:WorldToViewportPoint(part.Position)
    if screenPos.Z <= 0 then return end

    local aimRef = St.getAimReference()
    local dx = screenPos.X - aimRef.X
    local dy = screenPos.Y - aimRef.Y

    local currentErr = math.sqrt(dx*dx + dy*dy)
    if currentErr < 0.1 then return end

    if St.aimGainErrPrev > 2 and currentErr > 2 then
        local improvement = St.aimGainErrPrev - currentErr
        if improvement > 1 then
            St.aimGain = math.min(St.aimGain * 1.05, 20.0)
        elseif improvement < -1 then
            St.aimGain = math.max(St.aimGain * 0.92, 0.5)
        end
    end

    local md = Svc.UIS:GetMouseDelta()
    local predX = H.clamp(md.X, -500, 500)
    local predY = H.clamp(md.Y, -500, 500)

    local applyX = dx * St.aimGain - predX
    local applyY = dy * St.aimGain - predY

    St.aimGainErrPrev = currentErr

    if math.abs(applyX) < 0.01 and math.abs(applyY) < 0.01 then return end

    pcall(mouseMoveRel, applyX, applyY)
end

pcall(function() Svc.RS:UnbindFromRenderStep(MAIN_BIND) end)
pcall(function() Svc.RS:BindToRenderStep(MAIN_BIND, Enum.RenderPriority.Camera.Value + 50, mainStep) end)
pcall(function() Svc.RS:UnbindFromRenderStep(AIM_CORRECT_BIND) end)
pcall(function() Svc.RS:BindToRenderStep(
    AIM_CORRECT_BIND,
    Enum.RenderPriority.Camera.Value + 100,
    aimCorrectStep
))
print("[Aero Lite] runtime bound")

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

function Wg.makeDropdown(parent, order, opts)
    local value = opts.default or opts.options[1]
    local row = H.new("Frame", {
        Size=UDim2.new(1,0,0,44), BackgroundTransparency=1, LayoutOrder=order, Parent=parent,
    })
    H.new("TextLabel", {
        Text=opts.name, Font=FontBold, TextSize=13, TextColor3=T.txt,
        BackgroundTransparency=1, Size=UDim2.new(1,0,0,18),
        TextXAlignment=Enum.TextXAlignment.Left, Parent=row,
    })
    local box = H.new("TextButton", {
        Text="", AutoButtonColor=false, Position=UDim2.fromOffset(0,20),
        Size=UDim2.new(1,0,0,24), BackgroundColor3=T.sb, BorderSizePixel=0, Parent=row,
    })
    H.corner(6, box); H.stroke(T.st,1,box)
    local lbl = H.new("TextLabel", {
        Text=tostring(value), Font=FontMed, TextSize=12, TextColor3=T.txt,
        BackgroundTransparency=1, Size=UDim2.new(1,-24,1,0), Position=UDim2.fromOffset(8,0),
        TextXAlignment=Enum.TextXAlignment.Left, Parent=box,
    })
    H.new("TextLabel", {
        Text="v", Font=FontBold, TextSize=12, TextColor3=T.dim, BackgroundTransparency=1,
        AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,-8,0.5,0),
        Size=UDim2.fromOffset(12,16), Parent=box,
    })
    local listFrame, closeToken = nil, 0
    local function closeList()
        if not listFrame then return end
        local f = listFrame; listFrame = nil; closeToken = closeToken + 1
        local token = closeToken
        for i = #openLists, 1, -1 do if openLists[i].frame == f then table.remove(openLists, i) end end
        local w = f.AbsoluteSize.X
        Svc.TS:Create(f, TweenInfo.new(0.15), {Size=UDim2.fromOffset(w, 0)}):Play()
        task.delay(0.15, function() if token == closeToken then f:Destroy() end end)
    end
    box.MouseButton1Click:Connect(function()
        if listFrame then closeList(); return end
        H.closeAllDropdowns()
        local rowH = 26
        local fullH = #opts.options * rowH + 8
        local boxAbs = box.AbsolutePosition
        local boxSize = box.AbsoluteSize
        local overlayAbs = OverlayGui.AbsolutePosition
        local overlaySize = OverlayGui.AbsoluteSize
        local listX = boxAbs.X - overlayAbs.X
        local listY = boxAbs.Y - overlayAbs.Y + boxSize.Y + 2
        if listY + fullH > overlaySize.Y then
            listY = boxAbs.Y - overlayAbs.Y - fullH - 2
            if listY < 4 then listY = 4 end
        end
        listFrame = H.new("Frame", {
            BackgroundColor3=T.sb, BorderSizePixel=0, ZIndex=100,
            Position=UDim2.fromOffset(listX, listY), Size=UDim2.fromOffset(boxSize.X, 0),
            ClipsDescendants=true, Parent=OverlayGui,
        })
        H.corner(6, listFrame); H.stroke(T.st,1,listFrame)
        local sl = H.new("ScrollingFrame", {
            Size=UDim2.fromScale(1,1), BackgroundTransparency=1, ScrollBarThickness=3,
            ScrollBarImageColor3=T.st, CanvasSize=UDim2.new(),
            AutomaticCanvasSize=Enum.AutomaticSize.Y, ZIndex=101, Parent=listFrame,
        })
        H.new("UIListLayout", {Padding=UDim.new(0,2), SortOrder=Enum.SortOrder.LayoutOrder, Parent=sl})
        H.pad(4,4,4,4, sl)
        for i, opt in ipairs(opts.options) do
            local r = H.new("TextButton", {
                Text=tostring(opt), Font=FontMed, TextSize=12, TextColor3=T.txt,
                AutoButtonColor=false, BackgroundColor3=(opt == value) and T.hov or T.pn,
                Size=UDim2.new(1,-4,0,rowH-2), LayoutOrder=i, ZIndex=102, Parent=sl,
            })
            H.corner(4, r)
            r.MouseButton1Click:Connect(function()
                value = opt; lbl.Text = tostring(opt)
                if opts.callback then opts.callback(opt) end
                PF.queueSave()
                closeList()
            end)
        end
        Svc.TS:Create(listFrame, TweenInfo.new(0.18), {Size=UDim2.fromOffset(boxSize.X, fullH)}):Play()
        table.insert(openLists, { frame = listFrame, close = closeList })
    end)
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
    local function highlight(sel)
        for j, s in ipairs(swatches) do
            Svc.TS:Create(s, TweenInfo.new(0.15), {Size = UDim2.fromOffset(j==sel and 15 or 12, j==sel and 15 or 12)}):Play()
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

-- ============================================================
-- WINDOW
-- ============================================================
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

    -- Aimbot page
    local aimbotPage = makePage("Aimbot")
    local col = twoColumn(aimbotPage)
    local aimL = col("Aimbot", 1)
    uiToggleRefs.AimbotEnabled = Wg.makeToggle(aimL, 1, {name="Enabled", default=Settings.Aimbot.Enabled,
        callback=function(v)
            Settings.Aimbot.Enabled = v
            if not v then St.clearAimState(); St.resetAimGain() end
        end})
    Wg.makeToggle(aimL, 2, {name="Wall Check", default=Settings.Aimbot.WallCheck,
        callback=function(v) Settings.Aimbot.WallCheck = v end})
    Wg.makeToggle(aimL, 3, {name="Team Check", default=Settings.Aimbot.TeamCheck,
        callback=function(v) Settings.Aimbot.TeamCheck = v end})
    Wg.makeToggle(aimL, 4, {name="Dead Check", default=Settings.Aimbot.DeadCheck,
        callback=function(v) Settings.Aimbot.DeadCheck = v end})
    Wg.makeToggle(aimL, 5, {name="Spawn Prot Check", default=Settings.Aimbot.SpawnProtCheck,
        callback=function(v)
            Settings.Aimbot.SpawnProtCheck = v
            if v then St.clearAimState() end
        end})
    Wg.makeToggle(aimL, 6, {name="Target NPCs", default=Settings.Aimbot.TargetNPCs,
        callback=function(v)
            Settings.Aimbot.TargetNPCs = v
            St.targetCache = nil
            if not v and St.aimLockedTarget and not St.aimLockedTarget.plr then
                St.clearAimState()
            end
        end})
    Wg.makeSlider(aimL, 7, {name="Max Distance", min=0, max=1500, default=Settings.Aimbot.MaxDistance,
        format=function(v) return math.floor(v).." studs" end,
        callback=function(v) Settings.Aimbot.MaxDistance = v end})

    local aimR = col("FOV", 2)
    Wg.makeToggle(aimR, 1, {name="Show FOV", default=Settings.Aimbot.ShowFOV,
        callback=function(v) Settings.Aimbot.ShowFOV = v; St.updateFOV() end})
    Wg.makeSlider(aimR, 2, {name="FOV Size", min=20, max=500, default=Settings.Aimbot.FOVSize,
        format=function(v) return math.floor(v).." px" end,
        callback=function(v) Settings.Aimbot.FOVSize = v; St.updateFOV() end})
    Wg.makeSlider(aimR, 3, {name="FOV Transparency", min=0, max=100,
        default=math.floor(Settings.Aimbot.FOVTransparency*100),
        format=function(v) return math.floor(v).."%" end,
        callback=function(v) Settings.Aimbot.FOVTransparency = v/100; St.updateFOV() end})
    Wg.makeColorPicker(aimR, 4, {name="FOV Color", default=Settings.Aimbot.FOVColor,
        callback=function(v) Settings.Aimbot.FOVColor = v; St.applyFOVStyle(); St.updateFOV() end})
    Wg.makeToggle(aimR, 5, {name="Rainbow FOV", default=Settings.Aimbot.Rainbow,
        callback=function(v)
            Settings.Aimbot.Rainbow = v
            if not v then St.applyFOVStyle(); St.updateFOV() end
        end})
    Wg.makeDropdown(aimR, 6, {name="FOV Style", options={"Circle","Square","Cross","Dot"},
        default=Settings.Aimbot.FOVStyle,
        callback=function(v) Settings.Aimbot.FOVStyle = v; St.applyFOVStyle(); St.updateFOV() end})

    -- Ragebot page
    local ragePage = makePage("Ragebot")
    local rg = fullPanel(ragePage, "Ragebot")
    uiToggleRefs.RagebotEnabled = Wg.makeToggle(rg, 1, {name="Enabled", default=Settings.Ragebot.Enabled,
        callback=function(v) Settings.Ragebot.Enabled = v; if not v then RB.reset() end end})
    H.new("TextLabel", {
        Text = "Above mode • Range 750 studs • Distance 4 studs\nFlat facing down • Mouse + body locked • Camera stays free\nPrioritises Skeleton • Skips Explosive",
        Font = Font, TextSize = 11, TextColor3 = T.dim,
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48),
        LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true, Parent = rg,
    })

    -- Players page
    local playersPage = makePage("Players")
    local plCol = twoColumn(playersPage)
    local plL = plCol("Toggles", 1)
    local plR = plCol("Customize", 2)

    uiToggleRefs.EspEnabled = Wg.makeToggle(plL, 1, {name="Enabled", default=Settings.Players.Enabled,
        callback=function(v)
            Settings.Players.Enabled = v
            if not v then St.clearESPByType(false) end
        end})
    Wg.makeToggle(plL, 2, {name="Show NPCs", default=Settings.Players.ShowNPCs,
        callback=function(v)
            Settings.Players.ShowNPCs = v
            St.targetCache = nil
            if not v then St.clearESPByType(true) end
        end})
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

    Wg.makeSlider(plR, 1, {name="ESP Range", min=50, max=1500, default=Settings.Players.Range,
        format=function(v) return math.floor(v).." studs" end,
        callback=function(v) Settings.Players.Range = v end})
    Wg.makeColorPicker(plR, 2, {name="Enemy Color", default=Settings.Players.EnemyColor,
        callback=function(v) Settings.Players.EnemyColor = v end})
    Wg.makeColorPicker(plR, 3, {name="Teammate Color", default=Settings.Players.TeammateColor,
        callback=function(v) Settings.Players.TeammateColor = v end})
    Wg.makeToggle(plR, 4, {name="Rainbow Enemy", default=Settings.Players.RainbowEnemy,
        callback=function(v) Settings.Players.RainbowEnemy = v end})
    Wg.makeToggle(plR, 5, {name="Rainbow Team", default=Settings.Players.RainbowTeam,
        callback=function(v) Settings.Players.RainbowTeam = v end})
    Wg.makeDropdown(plR, 6, {name="Tracer Origin", options={"Top","Center","Bottom"},
        default=Settings.Players.TracerOrigin,
        callback=function(v) Settings.Players.TracerOrigin = v end})

    -- Movement page
    local movePage = makePage("Movement")
    local mv = fullPanel(movePage, "Movement")
    uiToggleRefs.Fly = Wg.makeToggle(mv, 1, {name="Fly", default=Settings.Movement.Fly,
        callback=function(v) Settings.Movement.Fly = v end})
    Wg.makeSlider(mv, 2, {name="Fly Speed", min=10, max=500, default=Settings.Movement.FlySpeed,
        format=function(v) return math.floor(v).." spd" end,
        callback=function(v) Settings.Movement.FlySpeed = v end})
    uiToggleRefs.Noclip = Wg.makeToggle(mv, 3, {name="Noclip", default=Settings.Movement.Noclip,
        callback=function(v) Settings.Movement.Noclip = v end})

    local unloadRow = H.new("TextButton", {
        Text="", AutoButtonColor=false, BackgroundColor3=T.pn,
        Size=UDim2.new(1,0,0,32), LayoutOrder=4, Parent = mv,
    })
    H.corner(6,unloadRow); H.gradient(unloadRow, 0, 0.4)
    local unloadLbl = H.new("TextLabel", {
        Text="Unload Script", Font=FontBold, TextSize=13,
        TextColor3=Color3.fromRGB(240,80,80), BackgroundTransparency=1,
        Size=UDim2.fromScale(1,1), Parent=unloadRow,
    })
    local unloadArmed = false
    unloadRow.MouseButton1Click:Connect(function()
        if not unloadArmed then
            unloadArmed = true; unloadLbl.Text = "Click again to confirm"
            task.delay(1.5, function() if unloadArmed then unloadArmed = false; unloadLbl.Text = "Unload Script" end end)
        else AeroUnload() end
    end)

    -- Keybinds page
    local keyPage = makePage("Keybinds")
    local kb = fullPanel(keyPage, "Keybinds")

    local function keybindRow(name, keyEnum, order)
        local row = H.new("Frame", {
            Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1,
            LayoutOrder = order, Parent = kb,
        })
        H.new("TextLabel", {
            Text = name, Font = Font, TextSize = 13, TextColor3 = T.dim,
            BackgroundTransparency = 1, Size = UDim2.new(0.55, 0, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
        })
        local box = H.new("Frame", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.new(0.4, 0, 0, 24), BackgroundColor3 = T.sb,
            BorderSizePixel = 0, Parent = row,
        })
        H.corner(6, box); H.stroke(T.st, 1, box)
        H.new("TextLabel", {
            Text = G.keyName(keyEnum), Font = FontMed, TextSize = 12,
            TextColor3 = T.txt, BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1), Parent = box,
        })
    end

    keybindRow("Aimbot Toggle",   Settings.Keybinds.AimbotToggle,  1)
    keybindRow("Aim Key (Hold)",  Settings.Keybinds.AimKey,        2)
    keybindRow("ESP Toggle",      Settings.Keybinds.EspToggle,     3)
    keybindRow("Ragebot Toggle",  Settings.Keybinds.RagebotToggle, 4)
    keybindRow("Menu Key",        Settings.Keybinds.MenuKey,       5)
    keybindRow("Panic Key (x3)",  Settings.Keybinds.PanicKey,      6)

    H.new("TextLabel", {
        Text = "Press the Panic key 3 times within 1.5 seconds to unload the script.",
        Font = Font, TextSize = 11, TextColor3 = T.dim,
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20),
        LayoutOrder = 7, TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true, Parent = kb,
    })

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
                if hoveredSidebarRow == item.name then hoveredSidebarRow = nil end
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

    addSection("Combat", { {name="Aimbot"}, {name="Ragebot"} })
    addSection("Visuals", { {name="Players"} })
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
    H.closeAllDropdowns()
    if St.rootScale then
        Svc.TS:Create(St.rootScale, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Scale=0.05}):Play()
        task.delay(0.2, function() if not St.menuVisible then St.gui.Enabled = false end end)
    else
        St.gui.Enabled = false
    end
end

-- ============================================================
-- BINDS
-- ============================================================
track(Svc.UIS.InputBegan:Connect(function(inp, gpe)
    if St.uiHovered and inp.UserInputType == Enum.UserInputType.MouseButton1 then return end
    if gpe then return end

    if G.inputMatches(inp, Settings.Keybinds.AimKey) then
        St.aimingHeld = true
    end
    if G.inputMatches(inp, Settings.Keybinds.AimbotToggle) then
        local newVal = not Settings.Aimbot.Enabled
        if uiToggleRefs.AimbotEnabled then uiToggleRefs.AimbotEnabled(newVal) else Settings.Aimbot.Enabled = newVal end
        if not newVal then St.clearAimState(); St.resetAimGain() end
        PF.queueSave(); return
    end
    if G.inputMatches(inp, Settings.Keybinds.EspToggle) then
        local newVal = not Settings.Players.Enabled
        if uiToggleRefs.EspEnabled then uiToggleRefs.EspEnabled(newVal) else
            Settings.Players.Enabled = newVal
            if not newVal then St.clearESPByType(false) end
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
    if G.inputMatches(inp, Settings.Keybinds.AimKey) then
        St.aimingHeld = false
        St.clearAimState()
    end
end))

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
    if St.aimLockedTarget and St.aimLockedTarget.plr == plr then
        St.clearAimState()
    end
    if RB.target and RB.target.plr == plr then RB.target = nil end
end))

track(LP.CharacterAdded:Connect(function()
    St.clearESP()
    St.clearAimState()
    St.resetAimGain()
    St.aimingHeld = false
    RB.target = nil; RB.lockUntil = 0
    RB.savedCFrame = nil; RB.savedVelocity = nil; RB.active = false
    RB.savedPlatformStand = false
    RB.savedMouseBehavior = nil
    if St.ragebotAnchoredRoot and St.ragebotAnchoredRoot.Parent then
        pcall(function() St.ragebotAnchoredRoot.Anchored = false end)
    end
    St.ragebotAnchoredRoot = nil
    if St.cameraOwner == "ragebot" then St.releaseCamera() end
    cachedInset = nil
end))

local function hookCharacter(char)
    char:WaitForChild("Humanoid", 5)
    St.noclipSaved = {}
end
if LP.Character then hookCharacter(LP.Character) end
track(LP.CharacterAdded:Connect(hookCharacter))

function AeroUnload()
    if unloaded then return end
    unloaded = true
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
    if St.fovGui then pcall(function() St.fovGui:Destroy() end) end
    if St.espGui then pcall(function() St.espGui:Destroy() end) end
    if St.hudGui then pcall(function() St.hudGui:Destroy() end) end
    if St.flyBV then pcall(function() St.flyBV:Destroy() end) end
    if St.gui then pcall(function() St.gui:Destroy() end) end
    if OverlayGui then pcall(function() OverlayGui:Destroy() end) end
    print("[Aero Lite] unloaded")
end

local settingsCallOk, settingsLoaded = pcall(PF.loadAutoSettings)
if settingsCallOk and settingsLoaded then
    print("[Aero Lite] loaded saved settings")
else
    print("[Aero Lite] using default settings")
end

task.defer(function()
    local ok, err = pcall(buildWindow)
    if ok then
        print("[Aero Lite] loaded successfully")
    else
        warn("[Aero Lite] buildWindow failed: " .. tostring(err))
    end
end)
