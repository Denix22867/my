local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

local isRunning = false
local isEvading = false
local isGameActive = false
local currentConnection = nil
local savedElements = {}
local saveFile = "swill_elements.txt"
local currentFlyBV = nil
local currentTarget = nil
local lastTargetTime = 0

local function saveElements()
    if not writefile then return end
    local data = table.concat(savedElements, "\n")
    writefile(saveFile, data)
    print("[SWILL] Сохранено элементов:", #savedElements)
end

local function loadElements()
    if not readfile then return end
    local success, data = pcall(readfile, saveFile)
    if success and data then
        savedElements = {}
        for line in data:gmatch("[^\r\n]+") do
            if line ~= "" then
                table.insert(savedElements, line)
            end
        end
        print("[SWILL] Загружено элементов:", #savedElements)
    end
end

local function checkSavedElements()
    for _, path in ipairs(savedElements) do
        local obj = game
        for part in path:gmatch("[^%.]+") do
            obj = obj:FindFirstChild(part)
            if not obj then break end
        end
        if obj and obj:IsA("GuiObject") and obj.Visible then
            local parent = obj.Parent
            local visible = true
            while parent and parent:IsA("GuiObject") do
                if not parent.Visible then visible = false end
                parent = parent.Parent
            end
            if visible then return true end
        end
    end
    return false
end

local function isGameActuallyActive()
    if #savedElements > 0 then
        return checkSavedElements()
    end
    
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return false end
    
    local hasTimer = false
    for _, obj in pairs(playerGui:GetDescendants()) do
        if obj:IsA("TextLabel") and obj.Visible and string.match(obj.Text or "", "%d+:%d+") then
            hasTimer = true
            break
        end
        if obj:IsA("ImageLabel") then
            for _, child in pairs(obj:GetChildren()) do
                if child:IsA("TextLabel") and child.Visible and string.match(child.Text or "", "%d+:%d+") then
                    hasTimer = true
                    break
                end
            end
        end
    end
    
    local hasReset = false
    for _, obj in pairs(playerGui:GetDescendants()) do
        if obj:IsA("TextButton") and obj.Visible and obj.Text == "Reset" then
            hasReset = true
            break
        end
    end
    
    local hasRole = false
    for _, obj in pairs(playerGui:GetDescendants()) do
        if obj:IsA("TextLabel") and obj.Visible then
            local t = obj.Text or ""
            if t == "Innocent" or t == "Sheriff" or t == "Murderer" then
                hasRole = true
                break
            end
        end
    end
    
    local camera = workspace.CurrentCamera
    local isSpectating = camera and camera.CameraSubject and camera.CameraSubject ~= LocalPlayer.Character
    local isAlive = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") and LocalPlayer.Character.Humanoid.Health > 0
    local otherPlayers = 0
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then otherPlayers = otherPlayers + 1 end
    end
    
    local indicators = (hasTimer and 1 or 0) + (hasReset and 1 or 0) + (hasRole and 1 or 0)
    return indicators >= 2 and not isSpectating and isAlive and otherPlayers > 0
end

local function startElementSelection()
    local oldMouseIcon = LocalPlayer:GetMouse().Icon
    LocalPlayer:GetMouse().Icon = "rbxasset://SystemCursor/Crosshair"
    print("[SWILL] Режим выбора. Наведите курсор на элемент и нажмите клавишу. Добавлено будет до 10 элементов.")
    
    local connection
    local count = 0
    connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType == Enum.UserInputType.MouseButton1 then
            local mouse = LocalPlayer:GetMouse()
            local target = mouse.Target
            local selected = nil
            if target and target:IsA("GuiObject") then
                selected = target
            else
                local guiRoot = LocalPlayer:FindFirstChild("PlayerGui")
                if guiRoot then
                    for _, obj in pairs(guiRoot:GetDescendants()) do
                        if obj:IsA("GuiObject") and obj.AbsolutePosition and obj.AbsoluteSize then
                            local x, y = mouse.X, mouse.Y
                            if x >= obj.AbsolutePosition.X and x <= obj.AbsolutePosition.X + obj.AbsoluteSize.X and
                               y >= obj.AbsolutePosition.Y and y <= obj.AbsolutePosition.Y + obj.AbsoluteSize.Y then
                                selected = obj
                                break
                            end
                        end
                    end
                end
            end
            if selected then
                local path = selected:GetFullName()
                if not table.find(savedElements, path) then
                    table.insert(savedElements, path)
                    saveElements()
                    count = count + 1
                    print("[SWILL] Добавлен элемент:", path, "("..count.."/10)")
                    if count >= 10 then
                        print("[SWILL] Достигнут лимит (10). Выход из режима.")
                        connection:Disconnect()
                        LocalPlayer:GetMouse().Icon = oldMouseIcon
                    end
                else
                    print("[SWILL] Элемент уже есть в списке")
                end
            else
                print("[SWILL] Не удалось выбрать элемент")
                connection:Disconnect()
                LocalPlayer:GetMouse().Icon = oldMouseIcon
            end
        end
    end)
    
    task.wait(15)
    if connection.Connected then
        connection:Disconnect()
        LocalPlayer:GetMouse().Icon = oldMouseIcon
        print("[SWILL] Режим выбора завершён. Добавлено элементов:", count)
    end
end

local function clearElements()
    savedElements = {}
    saveElements()
    print("[SWILL] Список элементов очищен")
end

local function getCoins()
    local coins = {}
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") and v.Parent and v:FindFirstChild("TouchInterest") then
            local nameLower = (v.Name or ""):lower()
            if nameLower == "coin" or nameLower == "money" or string.find(nameLower, "coin") or
               (v.BrickColor == BrickColor.new("Bright yellow") and v.Size.X < 5) then
                table.insert(coins, v)
            end
        end
    end
    return coins
end

local function getNearestCoin()
    local coins = getCoins()
    if #coins == 0 then return nil end
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return nil end
    local rootPos = LocalPlayer.Character.HumanoidRootPart.Position
    local nearest, nearestDist = nil, 100
    for _, coin in pairs(coins) do
        local dist = (coin.Position - rootPos).Magnitude
        if dist < nearestDist then
            nearestDist = dist
            nearest = coin
        end
    end
    return nearest, nearestDist
end

local function getNearbyPlayers(radius)
    radius = radius or 50
    local nearby = {}
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return nearby end
    local rootPos = LocalPlayer.Character.HumanoidRootPart.Position
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local dist = (player.Character.HumanoidRootPart.Position - rootPos).Magnitude
            if dist < radius then
                table.insert(nearby, {player = player, rootPart = player.Character.HumanoidRootPart, distance = dist})
            end
        end
    end
    table.sort(nearby, function(a,b) return a.distance < b.distance end)
    return nearby
end

local function setNoclip(state)
    if not LocalPlayer.Character then return end
    for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = not state
        end
    end
end

local function stopFlying()
    if currentFlyBV then
        currentFlyBV:Destroy()
        currentFlyBV = nil
    end
    local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.PlatformStand = false
        humanoid.WalkSpeed = 16
    end
    currentTarget = nil
end

local function startFlying(targetPos)
    if not LocalPlayer.Character then return end
    local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    stopFlying()
    
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    local dir = (targetPos - rootPart.Position).Unit
    bv.Velocity = dir * 70
    bv.Parent = rootPart
    currentFlyBV = bv
    
    local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.PlatformStand = true
        humanoid.WalkSpeed = 0
    end
    
    currentTarget = targetPos
end

local function updateFlight(targetPos)
    if not LocalPlayer.Character then return end
    local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart or not currentFlyBV then return end
    
    local dir = (targetPos - rootPart.Position).Unit
    currentFlyBV.Velocity = dir * 70
    currentTarget = targetPos
end

local function evadeFromPlayer(playerRoot)
    if not LocalPlayer.Character then return end
    local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    local dir = (rootPart.Position - playerRoot.Position).Unit
    local evadePos = rootPart.Position + dir * 60
    evadePos = Vector3.new(evadePos.X, rootPart.Position.Y + 5, evadePos.Z)
    
    setNoclip(true)
    startFlying(evadePos)
    task.wait(1.2)
    stopFlying()
    setNoclip(false)
end

local function startFarmer()
    if currentConnection then return end
    isRunning = true
    print("[SWILL] Фармер активирован V15 (исправлен полёт и зависание)")
    
    currentConnection = RunService.Heartbeat:Connect(function()
        if not isRunning then return end
        
        local active = isGameActuallyActive()
        if active ~= isGameActive then
            isGameActive = active
            if not active then
                print("[SWILL] Игра не активна - бот остановлен")
                stopFlying()
                setNoclip(false)
            else
                print("[SWILL] Игра активна - бот работает")
            end
        end
        
        if not active then
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                LocalPlayer.Character.Humanoid.WalkSpeed = 16
                LocalPlayer.Character.Humanoid.PlatformStand = false
            end
            return
        end
        
        if not LocalPlayer.Character then return end
        local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
        local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not humanoid or not rootPart then return end
        
        local nearbyPlayers = getNearbyPlayers(45)
        
        if #nearbyPlayers > 0 and not isEvading then
            isEvading = true
            stopFlying()
            evadeFromPlayer(nearbyPlayers[1].rootPart)
            isEvading = false
            return
        end
        
        if #nearbyPlayers == 0 and not isEvading then
            setNoclip(true)
            local targetCoin, distToCoin = getNearestCoin()
            
            if targetCoin then
                local coinPos = targetCoin.Position
                local currentPos = rootPart.Position
                local dist = (coinPos - currentPos).Magnitude
                
                if dist > 3 then
                    if not currentFlyBV then
                        startFlying(coinPos)
                    else
                        updateFlight(coinPos)
                    end
                    rootPart.CFrame = CFrame.new(rootPart.Position, coinPos)
                else
                    stopFlying()
                end
            else
                stopFlying()
                if humanoid.WalkSpeed ~= 16 then
                    humanoid.WalkSpeed = 16
                    humanoid.PlatformStand = false
                end
            end
        end
    end)
end

local function stopFarmer()
    if currentConnection then
        currentConnection:Disconnect()
        currentConnection = nil
    end
    stopFlying()
    setNoclip(false)
    isRunning = false
    isEvading = false
    isGameActive = false
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.WalkSpeed = 16
        LocalPlayer.Character.Humanoid.PlatformStand = false
    end
    print("[SWILL] Фармер остановлен")
end

loadElements()

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SWILL_MM2_GUI"
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 280, 0, 220)
frame.Position = UDim2.new(0.5, -140, 0.8, 0)
frame.BackgroundColor3 = Color3.fromRGB(20,20,30)
frame.BackgroundTransparency = 0.15
frame.BorderSizePixel = 0
frame.Parent = screenGui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0,12)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,30)
title.Text = "SWILL FARMER V15"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Parent = frame

local statusText = Instance.new("TextLabel")
statusText.Size = UDim2.new(1,0,0,25)
statusText.Position = UDim2.new(0,0,0,32)
statusText.Text = "СТАТУС: ОСТАНОВЛЕН"
statusText.TextColor3 = Color3.fromRGB(255,100,100)
statusText.BackgroundTransparency = 1
statusText.Font = Enum.Font.Gotham
statusText.TextSize = 11
statusText.Parent = frame

local gameStatusText = Instance.new("TextLabel")
gameStatusText.Size = UDim2.new(1,0,0,20)
gameStatusText.Position = UDim2.new(0,0,0,55)
gameStatusText.Text = "ИГРА: ПРОВЕРКА..."
gameStatusText.TextColor3 = Color3.fromRGB(255,200,100)
gameStatusText.BackgroundTransparency = 1
gameStatusText.Font = Enum.Font.Gotham
gameStatusText.TextSize = 10
gameStatusText.Parent = frame

local selectButton = Instance.new("TextButton")
selectButton.Size = UDim2.new(0.8,0,0,30)
selectButton.Position = UDim2.new(0.1,0,0,85)
selectButton.Text = "➕ ДОБАВИТЬ ЭЛЕМЕНТ"
selectButton.TextColor3 = Color3.fromRGB(255,255,255)
selectButton.BackgroundColor3 = Color3.fromRGB(50,50,100)
selectButton.Font = Enum.Font.GothamBold
selectButton.TextSize = 12
selectButton.Parent = frame
local selectCorner = Instance.new("UICorner")
selectCorner.CornerRadius = UDim.new(0,8)
selectCorner.Parent = selectButton

local clearButton = Instance.new("TextButton")
clearButton.Size = UDim2.new(0.38,0,0,30)
clearButton.Position = UDim2.new(0.1,0,0,120)
clearButton.Text = "🗑 ОЧИСТИТЬ"
clearButton.TextColor3 = Color3.fromRGB(255,255,255)
clearButton.BackgroundColor3 = Color3.fromRGB(100,50,50)
clearButton.Font = Enum.Font.GothamBold
clearButton.TextSize = 12
clearButton.Parent = frame
local clearCorner = Instance.new("UICorner")
clearCorner.CornerRadius = UDim.new(0,8)
clearCorner.Parent = clearButton

local listButton = Instance.new("TextButton")
listButton.Size = UDim2.new(0.38,0,0,30)
listButton.Position = UDim2.new(0.52,0,0,120)
listButton.Text = "📋 СПИСОК"
listButton.TextColor3 = Color3.fromRGB(255,255,255)
listButton.BackgroundColor3 = Color3.fromRGB(50,100,50)
listButton.Font = Enum.Font.GothamBold
listButton.TextSize = 12
listButton.Parent = frame
local listCorner = Instance.new("UICorner")
listCorner.CornerRadius = UDim.new(0,8)
listCorner.Parent = listButton

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0.8,0,0,35)
toggleButton.Position = UDim2.new(0.1,0,0,165)
toggleButton.Text = "▶ СТАРТ"
toggleButton.TextColor3 = Color3.fromRGB(255,255,255)
toggleButton.BackgroundColor3 = Color3.fromRGB(0,120,0)
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 14
toggleButton.Parent = frame
local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0,8)
toggleCorner.Parent = toggleButton

spawn(function()
    while task.wait(0.5) do
        if screenGui and screenGui.Parent then
            local active = isGameActuallyActive()
            if active then
                gameStatusText.Text = "ИГРА: АКТИВНА ▶"
                gameStatusText.TextColor3 = Color3.fromRGB(100,255,100)
            else
                gameStatusText.Text = "ИГРА: ЛОББИ/СПЕКТАТОР ⏸"
                gameStatusText.TextColor3 = Color3.fromRGB(255,100,100)
            end
        else
            break
        end
    end
end)

selectButton.MouseButton1Click:Connect(startElementSelection)
clearButton.MouseButton1Click:Connect(clearElements)
listButton.MouseButton1Click:Connect(function()
    if #savedElements == 0 then
        print("[SWILL] Список элементов пуст")
    else
        print("[SWILL] Сохранённые элементы:")
        for i, path in ipairs(savedElements) do
            print(i .. ". " .. path)
        end
    end
end)

toggleButton.MouseButton1Click:Connect(function()
    if not isRunning then
        startFarmer()
        toggleButton.Text = "⏸ СТОП"
        toggleButton.BackgroundColor3 = Color3.fromRGB(180,0,0)
        statusText.Text = "СТАТУС: АКТИВЕН"
        statusText.TextColor3 = Color3.fromRGB(100,255,100)
    else
        stopFarmer()
        toggleButton.Text = "▶ СТАРТ"
        toggleButton.BackgroundColor3 = Color3.fromRGB(0,120,0)
        statusText.Text = "СТАТУС: ОСТАНОВЛЕН"
        statusText.TextColor3 = Color3.fromRGB(255,100,100)
    end
end)

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    if isRunning then
        stopFarmer()
        task.wait(0.5)
        startFarmer()
    end
end)

print("[SWILL] V15 ЗАГРУЖЕН")
print("[SWILL] - Плавный полёт к монетам (BodyVelocity)")
print("[SWILL] - Автоматическая остановка при сборе")
print("[SWILL] - Сохранение элементов игры")
print("[SWILL] - Исправлено зависание персонажа")
