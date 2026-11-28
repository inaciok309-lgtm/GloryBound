--[[
    GloryBound — Modern UI Rebuild
    Self-contained. No external loadstring.
    Target: Delta Executor (Mobile)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- ============ STATE ============
local state = {
    autoTrain = false,
    autoRebirth = false,
    killAura = false,
    silentAim = false,
    undetectable = true,
}

-- ============ REMOTES ============
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local TrainRemote = Remotes and Remotes:FindFirstChild("Train")
local RebirthRemote = Remotes and Remotes:FindFirstChild("Rebirth")

-- ============ HELPERS ============
local function getEnemies()
    local enemies = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                table.insert(enemies, {player = plr, hrp = hrp, hum = hum})
            end
        end
    end
    return enemies
end

local function closestEnemy()
    local best, bestDist = nil, math.huge
    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil end
    for _, e in ipairs(getEnemies()) do
        local d = (e.hrp.Position - myHRP.Position).Magnitude
        if d < bestDist then
            bestDist, best = d, e
        end
    end
    return best
end

local function humanDelay()
    if state.undetectable then
        task.wait(math.random(50, 150) / 1000)
    end
end

-- ============ LOOPS ============
task.spawn(function()
    while true do
        if state.autoTrain then
            if TrainRemote then
                pcall(function() TrainRemote:FireServer() end)
            else
                -- fallback: simulate click
                pcall(function()
                    local vu = game:GetService("VirtualUser")
                    vu:CaptureController()
                    vu:ClickButton1(Vector2.new(Mouse.X, Mouse.Y))
                end)
            end
            humanDelay()
            task.wait(0.1)
        else
            task.wait(0.25)
        end
    end
end)

task.spawn(function()
    while true do
        if state.autoRebirth and RebirthRemote then
            pcall(function() RebirthRemote:FireServer() end)
            humanDelay()
            task.wait(0.5)
        else
            task.wait(0.5)
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if state.killAura or state.silentAim then
        local target = closestEnemy()
        if target then
            if state.silentAim then
                -- snap mouse aim
                local cam = workspace.CurrentCamera
                if cam then
                    local look = CFrame.new(cam.CFrame.Position, target.hrp.Position)
                    cam.CFrame = cam.CFrame:Lerp(look, 0.35)
                end
            end
            if state.killAura then
                if target.hum then
                    target.hum.Health = 0
                end
                if target.hrp then
                    target.hrp.CFrame = target.hrp.CFrame * CFrame.Angles(0, math.rad(90), 0)
                end
            end
        end
    end
end)

-- ============ UI ============
local old = CoreGui:FindFirstChild("GloryBoundUI")
if old then old:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GloryBoundUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 320, 0, 420)
Main.Position = UDim2.new(0.5, -160, 0.5, -210)
Main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 14)
UICorner.Parent = Main

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(45, 45, 55)
UIStroke.Thickness = 1
UIStroke.Parent = Main

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 52)
Header.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
Header.BorderSizePixel = 0
Header.Parent = Main
local HCorner = Instance.new("UICorner")
HCorner.CornerRadius = UDim.new(0, 14)
HCorner.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -60, 1, 0)
Title.Position = UDim2.new(0, 20, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "GloryBound"
Title.TextColor3 = Color3.fromRGB(240, 240, 245)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Accent = Instance.new("Frame")
Accent.Size = UDim2.new(0, 6, 0, 24)
Accent.Position = UDim2.new(0, 10, 0.5, -12)
Accent.BackgroundColor3 = Color3.fromRGB(120, 90, 255)
Accent.BorderSizePixel = 0
Accent.Parent = Header
local ACorner = Instance.new("UICorner")
ACorner.CornerRadius = UDim.new(1, 0)
ACorner.Parent = Accent

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(0, 60, 0, 18)
Status.Position = UDim2.new(1, -70, 0, 8)
Status.BackgroundTransparency = 1
Status.Text = "ready"
Status.TextColor3 = Color3.fromRGB(80, 220, 140)
Status.Font = Enum.Font.Gotham
Status.TextSize = 11
Status.TextXAlignment = Enum.TextXAlignment.Right
Status.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -36, 0, 12)
CloseBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 16
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = Header
local CCorner = Instance.new("UICorner")
CCorner.CornerRadius = UDim.new(0, 8)
CCorner.Parent = CloseBtn
CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- ============ FEATURE ROWS ============
local List = Instance.new("Frame")
List.Size = UDim2.new(1, -24, 1, -72)
List.Position = UDim2.new(0, 12, 0, 60)
List.BackgroundTransparency = 1
List.Parent = Main

local function makeRow(yOffset, label, key)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 46)
    Row.Position = UDim2.new(0, 0, 0, yOffset)
    Row.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
    Row.BorderSizePixel = 0
    Row.Parent = List
    local rCorner = Instance.new("UICorner")
    rCorner.CornerRadius = UDim.new(0, 10)
    rCorner.Parent = Row

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -80, 1, 0)
    Label.Position = UDim2.new(0, 16, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = label
    Label.TextColor3 = Color3.fromRGB(220, 220, 230)
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 14
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Row

    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Size = UDim2.new(0, 44, 0, 24)
    ToggleBtn.Position = UDim2.new(1, -60, 0.5, -12)
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
    ToggleBtn.Text = ""
    ToggleBtn.AutoButtonColor = false
    ToggleBtn.Parent = Row
    local tCorner = Instance.new("UICorner")
    tCorner.CornerRadius = UDim.new(1, 0)
    tCorner.Parent = ToggleBtn

    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.new(0, 18, 0, 18)
    Knob.Position = UDim2.new(0, 3, 0.5, -9)
    Knob.BackgroundColor3 = Color3.fromRGB(200, 200, 210)
    Knob.BorderSizePixel = 0
    Knob.Parent = ToggleBtn
    local kCorner = Instance.new("UICorner")
    kCorner.CornerRadius = UDim.new(1, 0)
    kCorner.Parent = Knob

    local onColor = Color3.fromRGB(120, 90, 255)
    local offColor = Color3.fromRGB(45, 45, 58)

    local function setState(on)
        state[key] = on
        TweenService:Create(ToggleBtn, TweenInfo.new(0.18), {
            BackgroundColor3 = on and onColor or offColor
        }):Play()
        TweenService:Create(Knob, TweenInfo.new(0.18), {
            Position = on and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        }):Play()
    end

    ToggleBtn.MouseButton1Click:Connect(function()
        setState(not state[key])
        Status.Text = state[key] and (label .. " on") or "ready"
    end)

    -- touch support
    ToggleBtn.TouchTap:Connect(function()
        setState(not state[key])
        Status.Text = state[key] and (label .. " on") or "ready"
    end)

    return Row
end

makeRow(0,   "Auto Train",   "autoTrain")
makeRow(54,  "Auto Rebirth", "autoRebirth")
makeRow(108, "Kill Aura",    "killAura")
makeRow(162, "Silent Aim",   "silentAim")
makeRow(216, "Undetectable", "undetectable")