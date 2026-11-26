-- GloryBound: Auto Train, Rebirth & Undetectable Kill
-- Loaded from GitHub via: loadstring(game:HttpGet("https://raw.githubusercontent.com/Biskus0/GloryBound/refs/heads/main/Loading.lua"))()
-- Designed for Delta Executor (Mobile)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

-- Aguarda os Remotes do jogo (com timeout seguro)
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
if not Remotes then
    warn("GloryBound Script: Remotes não encontrados. O jogo pode ter atualizado.")
    return
end

-- Estado do script
local state = {
    autoTrain = false,
    autoRebirth = false,
    autoKill = false,
    killAura = false,
    undetectable = true,
    connection = nil,
    killConnection = nil
}

-- Função para obter a HumanoidRootPart de um inimigo
local function getEnemyRoot(enemy)
    if not enemy or not enemy:IsA("Model") then return nil end
    local root = enemy:FindFirstChild("HumanoidRootPart")
    if not root then root = enemy:FindFirstChild("Torso") end
    if not root then root = enemy:FindFirstChild("UpperTorso") end
    return root
end

-- Função para verificar se um inimigo está vivo e é válido
local function isEnemyValid(enemy)
    if not enemy or not enemy.Parent then return false end
    local humanoid = enemy:FindFirstChild("Humanoid")
    if humanoid and humanoid.Health <= 0 then return false end
    return true
end

-- Função para obter a parte da cabeça do inimigo (para silent aim)
local function getHead(enemy)
    if not enemy or not enemy:IsA("Model") then return nil end
    local head = enemy:FindFirstChild("Head")
    if not head then head = enemy:FindFirstChild("UpperTorso") end
    return head
end

-- Função de Auto Train (Mantida da versão anterior)
local function startAutoTrain()
    if state.connection then state.connection:Disconnect() end
    state.connection = task.spawn(function()
        while state.autoTrain do
            local delay = state.undetectable and math.random(50, 150)/100 or 0.5
            task.wait(delay)
            
            local trainRemote = Remotes:FindFirstChild("Train")
            if trainRemote then
                trainRemote:FireServer()
            else
                local VirtualUser = game:GetService("VirtualUser")
                VirtualUser:CaptureController()
                VirtualUser:ClickButton1(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
            end
        end
    end)
end

-- Função de Auto Rebirth (Mantida da versão anterior)
local function startAutoRebirth()
    task.spawn(function()
        while state.autoRebirth do
            local delay = state.undetectable and math.random(150, 300)/100 or 2
            task.wait(delay)
            
            local rebirthRemote = Remotes:FindFirstChild("Rebirth")
            if rebirthRemote then
                rebirthRemote:FireServer()
            end
        end
    end)
end

-- Função de Silent Aim (Auto Kill à distância)
local function startSilentAim()
    if state.killConnection then state.killConnection:Disconnect() end
    state.killConnection = RunService.RenderStepped:Connect(function()
        if not state.autoKill then return end
        
        local character = player.Character
        if not character then return end
        
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoidRootPart or not humanoid or humanoid.Health <= 0 then return end
        
        local closestEnemy = nil
        local shortestDistance = math.huge
        
        for _, enemy in pairs(workspace:GetChildren()) do
            if isEnemyValid(enemy) and enemy ~= character then
                local enemyRoot = getEnemyRoot(enemy)
                if enemyRoot then
                    local distance = (enemyRoot.Position - humanoidRootPart.Position).Magnitude
                    if distance < shortestDistance and distance < 500 then
                        shortestDistance = distance
                        closestEnemy = enemy
                    end
                end
            end
        end
        
        if closestEnemy then
            local head = getHead(closestEnemy)
            if head then
                -- "Silent" aim: move the camera/character to aim at the enemy
                -- This is a simplified version; a full silent aim would hook the mouse
                local aimPosition = head.Position
                local currentCFrame = workspace.CurrentCamera.CFrame
                local newCFrame = CFrame.new(currentCFrame.Position, aimPosition)
                workspace.CurrentCamera.CFrame = newCFrame
                
                -- Simulate a click/attack every render step (adjust as needed)
                -- In many executors, you can use VirtualUser
                local VirtualUser = game:GetService("VirtualUser")
                VirtualUser:CaptureController()
                VirtualUser:ClickButton1(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
            end
        end
    end)
end

-- Função de Kill Aura (Dano em área)
local function startKillAura()
    task.spawn(function()
        while state.killAura do
            local delay = state.undetectable and math.random(30, 100)/100 or 0.2
            task.wait(delay)
            
            local character = player.Character
            if not character then continue end
            local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
            if not humanoidRootPart then continue end
            
            for _, enemy in pairs(workspace:GetChildren()) do
                if isEnemyValid(enemy) and enemy ~= character then
                    local enemyRoot = getEnemyRoot(enemy)
                    if enemyRoot then
                        local distance = (enemyRoot.Position - humanoidRootPart.Position).Magnitude
                        if distance < 25 then -- Raio de 25 studs
                            -- Tenta disparar um remote de dano (ajuste o nome se necessário)
                            local damageRemote = Remotes:FindFirstChild("Damage") or Remotes:FindFirstChild("Attack")
                            if damageRemote then
                                damageRemote:FireServer(enemy)
                            else
                                -- Fallback: teleporta levemente para perto e ataca
                                -- (Isso é mais detectável, use com moderação)
                                enemyRoot.CFrame = humanoidRootPart.CFrame * CFrame.new(0, 0, -3)
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- Remove GUI antiga, se existir
local guiParent = (gethui and gethui()) or game:GetService("CoreGui")
if guiParent:FindFirstChild("GloryBound_Auto") then
    guiParent.GloryBound_Auto:Destroy()
end

-- Cria a interface
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GloryBound_Auto"
screenGui.ResetOnSpawn = false
screenGui.Parent = guiParent

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 240, 0, 240)
mainFrame.Position = UDim2.new(0.5, -120, 0.25, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
title.BorderSizePixel = 0
title.Text = "GloryBound Auto"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 18
title.Parent = mainFrame

local function createButton(text, yPos, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 30)
    btn.Position = UDim2.new(0.05, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.SourceSans
    btn.TextSize = 15
    btn.Parent = mainFrame
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local trainButton = createButton("Auto Train: OFF", 40, function()
    state.autoTrain = not state.autoTrain
    trainButton.Text = "Auto Train: " .. (state.autoTrain and "ON" or "OFF")
    trainButton.BackgroundColor3 = state.autoTrain and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(60, 60, 60)
    if state.autoTrain then startAutoTrain() end
end)

local rebirthButton = createButton("Auto Rebirth: OFF", 80, function()
    state.autoRebirth = not state.autoRebirth
    rebirthButton.Text = "Auto Rebirth: " .. (state.autoRebirth and "ON" or "OFF")
    rebirthButton.BackgroundColor3 = state.autoRebirth and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(60, 60, 60)
    if state.autoRebirth then startAutoRebirth() end
end)

local killButton = createButton("Auto Kill (Silent): OFF", 120, function()
    state.autoKill = not state.autoKill
    killButton.Text = "Auto Kill (Silent): " .. (state.autoKill and "ON" or "OFF")
    killButton.BackgroundColor3 = state.autoKill and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(60, 60, 60)
    if state.autoKill then startSilentAim() end
end)

local auraButton = createButton("Kill Aura: OFF", 160, function()
    state.killAura = not state.killAura
    auraButton.Text = "Kill Aura: " .. (state.killAura and "ON" or "OFF")
    auraButton.BackgroundColor3 = state.killAura and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(60, 60, 60)
    if state.killAura then startKillAura() end
end)

local undetectableButton = createButton("Undetectable: ON", 200, function()
    state.undetectable = not state.undetectable
    undetectableButton.Text = "Undetectable: " .. (state.undetectable and "ON" or "OFF")
    undetectableButton.BackgroundColor3 = state.undetectable and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(60, 60, 60)
end)
-- Inicializa o botão "Undetectable" como ON
undetectableButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
