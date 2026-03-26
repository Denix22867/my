local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local isRunning = false
local isEvading = false
local isGameActive = false
local currentNoclip = nil
local currentConnection = nil
local detectionTarget = nil
local fallingStartTime = 0
local currentTargetCoin = nil

local function isGameActuallyActive()
    if detectionTarget and detectionTarget.Parent and detectionTarget:IsDescendantOf(game) then
        local visible = true
        if detectionTarget:IsA("GuiObject") then
            visible = detectionTarget.Visible
            local parent = detectionTarget.Parent
            while parent and parent:IsA("GuiObject") do
                if not parent.Visible then visible = false end
                parent = parent.Parent
            end
        end
        if visible then return true else return false end
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
    print("[SWILL] Режим выбора элемента. Наведите курсор на элемент и нажмите любую клавишу.")
    
    local connection
    connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType == Enum.UserInputType.MouseButton1 then
            local mouse = LocalPlayer:GetMouse()
            local target = mouse.Target
            if target and target:IsA("GuiObject") then
                detectionTarget = target
                print("[SWILL] Выбран элемент:", detectionTarget:GetFullName())
            else
                local guiRoot = LocalPlayer:FindFirstChild("PlayerGui")
                if guiRoot then
                    for _, obj in pairs(guiRoot:GetDescendants()) do
                        if obj:IsA("GuiObject") and obj.AbsolutePosition and obj.AbsoluteSize then
                            local x, y = mouse.X, mouse.Y
                            if x >= obj.AbsolutePosition.X and x <= obj.AbsolutePosition.X + obj.AbsoluteSize.X and
                               y >= obj.AbsolutePosition.Y and y <= obj.AbsolutePosition.Y + obj.AbsoluteSize.Y then
                                detectionTarget = obj
                                print("[SWILL] Выбран элемент:", detectionTarget:GetFullName())
                                break
                            end
                        end
                    end
                end
            end
            if detectionTarget then
                print("[SWILL] Теперь бот будет считать игру активной, если этот элемент виден.")
            else
                print("[SWILL] Не удалось выбрать элемент. Попробуйте ещё раз.")
            end
            connection:Disconnect()
            LocalPlayer:GetMouse().Icon = oldMouseIcon
        end
    end)
end

local function getGroundPosition(position)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
    
    local rayOrigin = position + Vector3.new(0, 5, 0)
    local rayDirection = Vector3.new(0, -30, 0)
    local result = Workspace:Raycast(rayOrigin, rayDirection, rayParams)
    
    if result then
        return result.Position + Vector3.new(0, 3, 0)
    end
    return nil
end

local function isFalling()
    if not LocalPlayer.Character then return false end
    local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
    if not humanoid then return false end
    local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    
    local velocity = rootPart.AssemblyLinearVelocity
    if velocity.Y < -15 and humanoid.FloorMaterial == Enum.Material.Air then
        if fallingStartTime == 0 then fallingStartTime = tick() end
        return (tick() - fallingStartTime) > 0.5
    else
        fallingStartTime = 0
        return false
    end
end

local function fixPositionIfFalling()
    if not isFalling() then return end
    if not LocalPlayer.Character then return end
    local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    local groundPos = getGroundPosition(rootPart.Position)
    if groundPos then
        local yDiff = math.abs(rootPart.Position.Y - groundPos.Y)
        if yDiff > 8 then
            rootPart.CFrame = CFrame.new(groundPos)
            if LocalPlayer.Character.Humanoid then
                LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Landed)
            end
            task.wait(0.2)
        end
    else
        rootPart.CFrame = CFrame.new(0, 15, 0)
        task.wait(0.2)
    end
    fallingStartTime = 0
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
    if #coins == 0 then return nil, nil end
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return nil, nil end
    
    local rootPos = LocalPlayer.Character.HumanoidRootPart.Position
    local nearest, nearestDist = nil, 100
    local nearestHeightDiff = 0
    
    for _, coin in pairs(coins) do
        local dist = (coin.Position - rootPos).Magnitude
        local heightDiff = math.abs(coin.Position.Y - rootPos.Y)
        if dist < nearestDist and heightDiff < 15 then
            nearestDist = dist
            nearest = coin
            nearestHeightDiff = heightDiff
        end
    end
    return nearest, nearestDist, nearestHeightDiff
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
    if state then
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
        if currentNoclip then currentNoclip:Disconnect() end
        currentNoclip = RunService.Stepped:Connect(function()
            if LocalPlayer.Character then
                for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    else
        if currentNoclip then
            currentNoclip:Disconnect()
            currentNoclip = nil
        end
        if LocalPlayer.Character then
            for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
    end
end

local function walkTo(position)
    if not LocalPlayer.Character then return false end
    local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
    if not humanoid then return false end
    
    local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if rootPart and math.abs(position.Y - rootPart.Position.Y) > 4 then
        position = Vector3.new(position.X, rootPart.Position.Y, position.Z)
    end
    
    humanoid.WalkSpeed = 24
    humanoid:MoveTo(position)
    humanoid.AutoRotate = true
    return true
end

local function stopMoving()
    if not LocalPlayer.Character then return end
    local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid:MoveTo(Vector3.new(9e9,9e9,9e9))
        task.wait()
        humanoid:MoveTo(LocalPlayer.Character.HumanoidRootPart.Position)
        humanoid.WalkSpeed = 16
    end
end

local function evadeFromPlayer(playerRoot)
    if not LocalPlayer.Character then return end
    local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
    local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then return end
    
    local direction = (rootPart.Position - playerRoot.Position).Unit
    local evadePos = rootPart.Position + direction * 45
    evadePos = Vector3.new(evadePos.X, rootPart.Position.Y, evadePos.Z)
    
    setNoclip(true)
    local oldSpeed = humanoid.WalkSpeed
    humanoid.WalkSpeed = 50
    humanoid:MoveTo(evadePos)
    task.wait(1.5)
    humanoid.WalkSpeed = oldSpeed
    setNoclip(false)
end

local function startFarmer()
    if currentConnection then return end
    isRunning = true
    print("[SWILL] Фармер активирован V13 - исправлена остановка движения")
    
    currentConnection = RunService.Heartbeat:Connect(function()
        if not isRunning then return end
        
        local active = isGameActuallyActive()
        if active ~= isGameActive then
            isGameActive = active
            if not active then
                print("[SWILL] Игра не активна - бот остановлен")
                stopMoving()
                setNoclip(false)
            else
                print("[SWILL] Игра активна - бот работает")
            end
        end
        
        if not active then
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                LocalPlayer.Character.Humanoid.WalkSpeed = 16
            end
            return
        end
        
        if not LocalPlayer.Character then return end
        local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
        local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not humanoid or not rootPart then return end
        
        fixPositionIfFalling()
        
        local nearbyPlayers = getNearbyPlayers(40)
        
        if #nearbyPlayers > 0 and not isEvading then
            isEvading = true
            stopMoving()
            evadeFromPlayer(nearbyPlayers[1].rootPart)
            isEvading = false
            return
        end
        
        if #nearbyPlayers == 0 and not isEvading then
            setNoclip(false)
            local targetCoin, distToCoin, heightDiff = getNearestCoin()
            
            if targetCoin and distToCoin > 2.5 and heightDiff and heightDiff < 15 then
                walkTo(targetCoin.Position)
                if rootPart then
                    rootPart.CFrame = CFrame.new(rootPart.Position, targetCoin.Position)
                end
            elseif targetCoin and distToCoin <= 2.5 then
                if humanoid.WalkSpeed > 16 then
                    humanoid.WalkSpeed = 16
                end
                if humanoid.MoveDirection.Magnitude > 0 then
                    stopMoving()
                end
            else
                if #getCoins() > 0 then
                    local groundPos = getGroundPosition(rootPart.Position)
                    if groundPos then
                        local randomPos = groundPos + Vector3.new(math.random(-20,20), 0, math.random(-20,20))
                        walkTo(randomPos)
                    else
                        local randomPos = rootPart.Position + Vector3.new(math.random(-20,20), 0, math.random(-20,20))
                        randomPos = Vector3.new(randomPos.X, rootPart.Position.Y, randomPos.Z)
                        walkTo(randomPos)
                    end
                else
                    if humanoid.WalkSpeed > 16 then
                        humanoid.WalkSpeed = 16
                    end
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
    stopMoving()
    setNoclip(false)
    isRunning = false
    isEvading = false
    isGameActive = false
    fallingStartTime = 0
    print("[SWILL] Фармер остановлен")
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SWILL_MM2_GUI"
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 260, 0, 180)
frame.Position = UDim2.new(0.5, -130, 0.8, 0)
frame.BackgroundColor3 = Color3.fromRGB(20,20,30)
frame.BackgroundTransparency = 0.15
frame.BorderSizePixel = 0
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0,12)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,30)
title.Text = "SWILL FARMER V13"
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
selectButton.Text = "🔍 ВЫБРАТЬ ЭЛЕМЕНТ"
selectButton.TextColor3 = Color3.fromRGB(255,255,255)
selectButton.BackgroundColor3 = Color3.fromRGB(50,50,100)
selectButton.Font = Enum.Font.GothamBold
selectButton.TextSize = 12
selectButton.Parent = frame
local selectCorner = Instance.new("UICorner")
selectCorner.CornerRadius = UDim.new(0,8)
selectCorner.Parent = selectButton

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0.8,0,0,35)
toggleButton.Position = UDim2.new(0.1,0,0,125)
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

print("[SWILL] V13 ЗАГРУЖЕН - БОЛЬШЕ НЕ ЗАМИРАЕТ")
print("[SWILL] Постоянное движение к монетам, убраны задержки")
