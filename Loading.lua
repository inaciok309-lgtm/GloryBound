--[[
    GloryBound — v5
    Responsive UI + working remote discovery
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local VirtualUser       = game:GetService("VirtualUser")
local HttpService       = game:GetService("HttpService")

repeat task.wait() until Players.LocalPlayer
local LocalPlayer = Players.LocalPlayer

local CONFIG_FILE = "GloryBound_config.json"
local VERSION     = "v5.0"

local state = {
    autoTrain    = false,
    autoRebirth  = false,
    killAura     = false,
    silentAim    = false,
    undetectable = true,
}

-- ============================================================
-- REMOTE DISCOVERY
-- ============================================================
local allRemotes = {}
local working = {train = nil, rebirth = nil, attack = {}}

local function scanRemotes()
    allRemotes = {}
    local folder = ReplicatedStorage:FindFirstChild("Remotes")
    local containers = folder and {folder} or {ReplicatedStorage}
    for _, container in ipairs(containers) do
        for _, obj in ipairs(container:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                allRemotes[#allRemotes+1] = {
                    name = obj.Name,
                    remote = obj,
                    class = obj.ClassName,
                }
            end
        end
    end
    print(("[GB] === Remotes discovered: %d ==="):format(#allRemotes))
    for i, r in ipairs(allRemotes) do
        if i > 150 then print("[GB] ... (truncated)"); break end
        print(("  [%s] %s"):format(r.class, r.name))
    end
end
task.spawn(scanRemotes)

local CANDIDATES = {
    train   = {"Train","train","AutoTrain","StartTrain","Training","DoTrain",
               "TrainUp","AddTrain","Farm","farm","Grind"},
    rebirth = {"Rebirth","rebirth","AutoRebirth","DoRebirth","Reborn",
               "Prestige","Reincarnate","Reset"},
    attack  = {"Attack","attack","Hit","hit","Damage","damage","Strike",
               "strike","Punch","Kill","kill","Skill","Shoot","Fire","Combat"},
}

local function findRemote(kind)
    -- 1. exact match on candidate names
    for _, cand in ipairs(CANDIDATES[kind]) do
        for _, r in ipairs(allRemotes) do
            if r.name == cand then return r end
        end
    end
    -- 2. substring match
    for _, cand in ipairs(CANDIDATES[kind]) do
        local cl = cand:lower()
        for _, r in ipairs(allRemotes) do
            if r.name:lower():find(cl, 1, true) then return r end
        end
    end
    return nil
end

local function fireEntry(entry, ...)
    if not entry then return false end
    local args = table.pack(...)
    if entry.class == "RemoteEvent" then
        return (pcall(function()
            entry.remote:FireServer(table.unpack(args, 1, args.n))
        end))
    else
        task.spawn(function()
            pcall(function()
                entry.remote:InvokeServer(table.unpack(args, 1, args.n))
            end)
        end)
        return true
    end
end

local function refreshAttackList()
    working.attack = {}
    for _, r in ipairs(allRemotes) do
        if r.class == "RemoteEvent" then
            local lower = r.name:lower()
            for _, cand in ipairs(CANDIDATES.attack) do
                if lower:find(cand:lower(), 1, true) then
                    working.attack[#working.attack+1] = r
                    break
                end
            end
        end
    end
    if #working.attack > 0 then
        print(("[GB] attack remotes: %d"):format(#working.attack))
        for _, r in ipairs(working.attack) do print("  -> " .. r.name) end
    end
end
task.spawn(refreshAttackList)

-- ============================================================
-- HELPERS
-- ============================================================
local function getEnemies()
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                list[#list+1] = {player = plr, hrp = hrp, hum = hum}
            end
        end
    end
    return list
end

local function closestEnemy()
    local myChar = LocalPlayer.Character
    local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil end
    local best, bestD = nil, math.huge
    for _, e in ipairs(getEnemies()) do
        local d = (e.hrp.Position - myHRP.Position).Magnitude
        if d < bestD then bestD, best = d, e end
    end
    return best
end

local function jitterWait()
    if state.undetectable then
        task.wait(math.random(40, 140) / 1000)
    end
end

-- ============================================================
-- LOOPS
-- ============================================================
local loopsActive = true
local connections = {}
local function track(c) connections[#connections+1] = c; return c end

task.spawn(function()
    local lastWarn = 0
    while loopsActive do
        if state.autoTrain then
            if not working.train then
                working.train = findRemote("train")
                if working.train then
                    print("[GB] train remote: " .. working.train.name
                        .. " (" .. working.train.class .. ")")
                elseif os.clock() - lastWarn > 5 then
                    warn("[GB] no train remote found. Check the discovery list above.")
                    lastWarn = os.clock()
                end
            end
            if working.train then
                if not fireEntry(working.train) then
                    warn("[GB] train remote fire failed — rescanning")
                    working.train = nil
                end
            end
            jitterWait()
            task.wait(state.undetectable and 0.15 or 0.05)
        else
            task.wait(0.2)
        end
    end
end)

task.spawn(function()
    local lastWarn = 0
    while loopsActive do
        if state.autoRebirth then
            if not working.rebirth then
                working.rebirth = findRemote("rebirth")
                if working.rebirth then
                    print("[GB] rebirth remote: " .. working.rebirth.name)
                elseif os.clock() - lastWarn > 5 then
                    warn("[GB] no rebirth remote found.")
                    lastWarn = os.clock()
                end
            end
            if working.rebirth then
                if not fireEntry(working.rebirth) then
                    working.rebirth = nil
                end
            end
            jitterWait()
            task.wait(state.undetectable and 0.6 or 0.15)
        else
            task.wait(0.4)
        end
    end
end)

-- rescan remotes every 10s (game might load later)
task.spawn(function()
    while loopsActive do
        task.wait(10)
        if #allRemotes == 0 then
            scanRemotes()
        end
        refreshAttackList()
    end
end)

-- ============================================================
-- COMBAT
-- ============================================================
local lastAttack = 0
local combatConn = RunService.RenderStepped:Connect(function()
    if not (state.killAura or state.silentAim) then return end
    local target = closestEnemy()
    if not target then return end

    if state.silentAim then
        local cam = workspace.CurrentCamera
        if cam then
            local look = CFrame.new(cam.CFrame.Position, target.hrp.Position)
            cam.CFrame = cam.CFrame:Lerp(look, 0.35)
        end
    end

    if state.killAura then
        if os.clock() - lastAttack < 0.1 then return end
        lastAttack = os.clock()
        for _, r in ipairs(working.attack) do
            fireEntry(r, target.player)
        end
    end
end)

-- ============================================================
-- CONFIG
-- ============================================================
local function fileExists(name)
    if isfile then return isfile(name) end
    if readfile then return (pcall(readfile, name)) end
    return false
end

local function saveConfig()
    if not writefile then return end
    pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(state)) end)
end

local function loadConfig()
    if not readfile or not fileExists(CONFIG_FILE) then return end
    pcall(function()
        for k, v in pairs(HttpService:JSONDecode(readfile(CONFIG_FILE))) do
            if state[k] ~= nil then state[k] = v end
        end
    end)
end
loadConfig()

-- ============================================================
-- UI — responsive sizing (fixes covered buttons)
-- ============================================================
local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
local old = parentGui:FindFirstChild("GloryBoundUI")
if old then old:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GloryBoundUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = parentGui

-- palette
local C = {
    bg      = Color3.fromRGB(15, 15, 19),
    panel   = Color3.fromRGB(22, 22, 28),
    panel2  = Color3.fromRGB(28, 28, 36),
    stroke  = Color3.fromRGB(44, 44, 56),
    text    = Color3.fromRGB(235, 235, 242),
    dim     = Color3.fromRGB(140, 140, 155),
    accent  = Color3.fromRGB(126, 96, 255),
    green   = Color3.fromRGB(78, 214, 128),
    red     = Color3.fromRGB(220, 80, 100),
}

local function corner(p, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = p end
local function stroke(p, col, t)
    local s = Instance.new("UIStroke"); s.Color = col or C.stroke; s.Thickness = t or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = p
end

-- responsive dimensions
local cam = workspace.CurrentCamera
local vs = (cam and cam.ViewportSize) or Vector2.new(1280, 720)
local HEADER_H   = 44
local STATUS_H   = 24
local menuW      = math.min(520, vs.X - 24)
local menuH      = math.min(380, vs.Y - 24)
local sidebarW   = math.max(110, math.min(140, math.floor(menuW * 0.28)))

-- === MAIN ===
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, menuW, 0, menuH)
Main.Position = UDim2.new(0.5, 0, 0.5, 0)
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.BackgroundColor3 = C.bg
Main.BorderSizePixel = 0
Main.Active = true
Main.ClipsDescendants = true
Main.Parent = ScreenGui
corner(Main, 14); stroke(Main, C.stroke)

-- === HEADER ===
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, HEADER_H)
Header.BackgroundColor3 = C.panel
Header.BorderSizePixel = 0
Header.ZIndex = 5
Header.Parent = Main

local Dot = Instance.new("Frame")
Dot.Size = UDim2.new(0, 8, 0, 8)
Dot.Position = UDim2.new(0, 16, 0.5, -4)
Dot.BackgroundColor3 = C.accent
Dot.BorderSizePixel = 0
Dot.Parent = Header
corner(Dot, 99)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0, 150, 1, 0)
Title.Position = UDim2.new(0, 32, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "GloryBound"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextColor3 = C.text
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Ver = Instance.new("TextLabel")
Ver.Size = UDim2.new(0, 60, 1, 0)
Ver.Position = UDim2.new(0, 132, 0, 0)
Ver.BackgroundTransparency = 1
Ver.Text = VERSION
Ver.Font = Enum.Font.Gotham
Ver.TextSize = 10
Ver.TextColor3 = C.dim
Ver.TextXAlignment = Enum.TextXAlignment.Left
Ver.Parent = Header

-- === HEADER BUTTONS (dedicated container, high ZIndex) ===
local BTN = 30
local GAP = 6
local CONT_W = 4 + BTN + GAP + BTN + 4

local BtnCont = Instance.new("Frame")
BtnCont.Size = UDim2.new(0, CONT_W, 1, 0)
BtnCont.Position = UDim2.new(1, -CONT_W, 0, 0)
BtnCont.BackgroundTransparency = 1
BtnCont.ZIndex = 10
BtnCont.Parent = Header

local function makeHeaderBtn(xOff, text, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, BTN, 0, BTN)
    b.Position = UDim2.new(0, xOff, 0.5, -BTN/2)
    b.BackgroundColor3 = C.panel2
    b.Text = text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    b.TextColor3 = C.text
    b.AutoButtonColor = false
    b.ZIndex = 11
    b.Active = true
    b.Parent = BtnCont
    corner(b, 8)
    local busy = false
    local function fire()
        if busy then return end
        busy = true
        cb()
        task.delay(0.12, function() busy = false end)
    end
    b.Activated:Connect(fire)
    b.MouseButton1Click:Connect(fire)
    b.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch then fire() end
    end)
    return b
end

-- minimize with explicit state
local isMinimized = false
makeHeaderBtn(4, "—", function()
    isMinimized = not isMinimized
    TweenService:Create(Main, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {
        Size = UDim2.new(0, menuW, 0, isMinimized and HEADER_H or menuH)
    }):Play()
end)

makeHeaderBtn(4 + BTN + GAP, "×", function()
    ScreenGui:Destroy()
end)

-- drag
do
    local dragging, dragStart, startPos
    Header.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, i.Position, Main.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    track(UserInputService.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch then
            local d = i.Position - dragStart
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                      startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))
end

-- === SIDEBAR ===
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, sidebarW, 1, -(HEADER_H + STATUS_H))
Sidebar.Position = UDim2.new(0, 0, 0, HEADER_H)
Sidebar.BackgroundColor3 = C.panel
Sidebar.BorderSizePixel = 0
Sidebar.Parent = Main

local SideStroke = Instance.new("Frame")
SideStroke.Size = UDim2.new(0, 1, 1, 0)
SideStroke.Position = UDim2.new(1, -1, 0, 0)
SideStroke.BackgroundColor3 = C.stroke
SideStroke.BorderSizePixel = 0
SideStroke.Parent = Sidebar

local Tabs, TabPages = {}, {}

local function switchTab(name)
    for tn, refs in pairs(Tabs) do
        local on = (tn == name)
        TweenService:Create(refs.bg, TweenInfo.new(0.15), {
            BackgroundColor3 = on and C.panel2 or C.panel
        }):Play()
        refs.stripe.BackgroundTransparency = on and 0 or 1
        refs.label.TextColor3 = on and C.text or C.dim
    end
    for pn, p in pairs(TabPages) do p.Visible = (pn == name) end
end

local function makeTab(name, labelText, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -12, 0, 34)
    btn.Position = UDim2.new(0, 6, 0, 6 + (order - 1) * 38)
    btn.BackgroundColor3 = C.panel
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Active = true
    btn.Parent = Sidebar
    corner(btn, 8)

    local stripe = Instance.new("Frame")
    stripe.Size = UDim2.new(0, 3, 0, 16)
    stripe.Position = UDim2.new(0, 0, 0.5, -8)
    stripe.BackgroundColor3 = C.accent
    stripe.BackgroundTransparency = 1
    stripe.BorderSizePixel = 0
    stripe.Parent = btn
    corner(stripe, 99)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -18, 1, 0)
    label.Position = UDim2.new(0, 14, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextColor3 = C.dim
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = btn

    Tabs[name] = {bg = btn, stripe = stripe, label = label}

    local busy = false
    local function fire()
        if busy then return end
        busy = true
        switchTab(name)
        task.delay(0.05, function() busy = false end)
    end
    btn.Activated:Connect(fire)
    btn.MouseButton1Click:Connect(fire)
    btn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch then fire() end
    end)
end

-- === CONTENT ===
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -sidebarW, 1, -(HEADER_H + STATUS_H))
Content.Position = UDim2.new(0, sidebarW, 0, HEADER_H)
Content.BackgroundTransparency = 1
Content.Parent = Main

local function makePage(name)
    local p = Instance.new("ScrollingFrame")
    p.Size = UDim2.new(1, 0, 1, 0)
    p.BackgroundTransparency = 1
    p.BorderSizePixel = 0
    p.ScrollBarThickness = 3
    p.ScrollBarImageColor3 = C.accent
    p.CanvasSize = UDim2.new(0, 0, 0, 0)
    p.AutomaticCanvasSize = Enum.AutomaticSize.Y
    p.Visible = false
    p.Parent = Content
    TabPages[name] = p
    return p
end

-- forward declare
local updateStatus = function() end

local function makeSection(page, text, yPos)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -24, 0, 16)
    l.Position = UDim2.new(0, 12, 0, yPos)
    l.BackgroundTransparency = 1
    l.Text = string.upper(text)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 10
    l.TextColor3 = C.dim
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = page
end

local function makeToggleRow(page, labelText, key, yPos)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, -24, 0, 46)
    Row.Position = UDim2.new(0, 12, 0, yPos)
    Row.BackgroundColor3 = C.panel
    Row.BorderSizePixel = 0
    Row.Active = true
    Row.Parent = page
    corner(Row, 10); stroke(Row, C.stroke)

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 6, 0, 6)
    dot.Position = UDim2.new(0, 14, 0.5, -3)
    dot.BackgroundColor3 = C.dim
    dot.BorderSizePixel = 0
    dot.Parent = Row
    corner(dot, 99)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -100, 1, 0)
    lbl.Position = UDim2.new(0, 28, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 13
    lbl.TextColor3 = C.text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = Row

    local Track = Instance.new("Frame")
    Track.Size = UDim2.new(0, 40, 0, 22)
    Track.Position = UDim2.new(1, -52, 0.5, -11)
    Track.BackgroundColor3 = C.panel2
    Track.BorderSizePixel = 0
    Track.Parent = Row
    corner(Track, 99)

    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.new(0, 16, 0, 16)
    Knob.Position = UDim2.new(0, 3, 0.5, -8)
    Knob.BackgroundColor3 = C.text
    Knob.BorderSizePixel = 0
    Knob.Parent = Track
    corner(Knob, 99)

    local debounce = false
    local function apply(on, animate, skipSave)
        state[key] = on
        dot.BackgroundColor3 = on and C.green or C.dim
        local tw = TweenInfo.new(animate and 0.18 or 0, Enum.EasingStyle.Quart)
        TweenService:Create(Track, tw, {
            BackgroundColor3 = on and C.accent or C.panel2
        }):Play()
        TweenService:Create(Knob, tw, {
            Position = on and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        }):Play()
        if not skipSave then saveConfig() end
        updateStatus()
    end

    apply(state[key], false, true)

    Row.InputBegan:Connect(function(i)
        if debounce then return end
        if i.UserInputType == Enum.UserInputType.Touch
        or i.UserInputType == Enum.UserInputType.MouseButton1 then
            debounce = true
            apply(not state[key], true, false)
            task.delay(0.06, function() debounce = false end)
        end
    end)
end

-- === BUILD ===
makeTab("Farm",   "Farm",   1)
makeTab("Combat", "Combat", 2)
makeTab("Misc",   "Misc",   3)

local FarmPage   = makePage("Farm")
local CombatPage = makePage("Combat")
local MiscPage   = makePage("Misc")

makeSection(FarmPage, "Automation", 8)
makeToggleRow(FarmPage, "Auto Train",   "autoTrain",   30)
makeToggleRow(FarmPage, "Auto Rebirth", "autoRebirth", 82)

makeSection(CombatPage, "Targeting", 8)
makeToggleRow(CombatPage, "Kill Aura",  "killAura",  30)
makeToggleRow(CombatPage, "Silent Aim", "silentAim", 82)

makeSection(MiscPage, "Behavior", 8)
makeToggleRow(MiscPage, "Undetectable (jitter)", "undetectable", 30)

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, -24, 0, 40)
hint.Position = UDim2.new(0, 12, 0, 84)
hint.BackgroundTransparency = 1
hint.Text = "RightShift hides the menu.\nOpen the Delta console to see remote discovery."
hint.Font = Enum.Font.Gotham
hint.TextSize = 10
hint.TextColor3 = C.dim
hint.TextWrapped = true
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.TextYAlignment = Enum.TextYAlignment.Top
hint.Parent = MiscPage

-- === STATUS BAR ===
local StatusBar = Instance.new("Frame")
StatusBar.Size = UDim2.new(1, -sidebarW, 0, STATUS_H)
StatusBar.Position = UDim2.new(0, sidebarW, 1, -STATUS_H)
StatusBar.BackgroundColor3 = C.panel
StatusBar.BorderSizePixel = 0
StatusBar.Parent = Main

local StatusLeft = Instance.new("TextLabel")
StatusLeft.Size = UDim2.new(0, math.floor(menuW * 0.55), 1, 0)
StatusLeft.Position = UDim2.new(0, 10, 0, 0)
StatusLeft.BackgroundTransparency = 1
StatusLeft.Text = "Ready"
StatusLeft.Font = Enum.Font.Gotham
StatusLeft.TextSize = 10
StatusLeft.TextColor3 = C.dim
StatusLeft.TextXAlignment = Enum.TextXAlignment.Left
StatusLeft.TextTruncate = Enum.TextTruncate.AtEnd
StatusLeft.Parent = StatusBar

local StatusRight = Instance.new("TextLabel")
StatusRight.Size = UDim2.new(0, 150, 1, 0)
StatusRight.Position = UDim2.new(1, -160, 0, 0)
StatusRight.BackgroundTransparency = 1
StatusRight.Text = "0 FPS · -- ms"
StatusRight.Font = Enum.Font.Gotham
StatusRight.TextSize = 10
StatusRight.TextColor3 = C.dim
StatusRight.TextXAlignment = Enum.TextXAlignment.Right
StatusRight.Parent = StatusBar

updateStatus = function()
    local active = {}
    for k, v in pairs(state) do
        if v and k ~= "undetectable" then active[#active+1] = k end
    end
    StatusLeft.Text = #active == 0 and "Ready"
        or ("Active: " .. table.concat(active, ", "))
end
updateStatus()

task.spawn(function()
    local last, frames = os.clock(), 0
    local ping = 0
    task.spawn(function()
        while loopsActive do
            local ok, p = pcall(function() return LocalPlayer:GetNetworkPing() * 1000 end)
            if ok and p then ping = p end
            task.wait(2)
        end
    end)
    while loopsActive do
        frames = frames + 1
        if os.clock() - last >= 1 then
            local fps = math.floor(frames / (os.clock() - last))
            StatusRight.Text = ("%d FPS · %d ms"):format(fps, math.floor(ping))
            frames, last = 0, os.clock()
        end
        task.wait(0.1)
    end
end)

track(UserInputService.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.RightShift then
        Main.Visible = not Main.Visible
    end
end))

switchTab("Farm")

ScreenGui.Destroying:Connect(function()
    loopsActive = false
    if combatConn then combatConn:Disconnect() end
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
end)