-- SWILL // MM2 AUTO FARMER V11 // MANUAL DETECTION MODE
-- Позволяет пользователю указать элемент, по которому определять активность игры.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Глобальные переменные
local isRunning = false
local isEvading = false
local isGameActive = false
local currentNoclip = nil
local currentConnection = nil
local detectionTarget = nil   -- Объект, наличие которого говорит об активной игре
local debugMode = true

-- ========== ДЕТЕКЦИЯ АКТИВНОСТИ (по выбранному элементу или авто) ==========
local function isGameActuallyActive()
    -- Если пользователь выбрал элемент, проверяем его наличие и видимость
    if detectionTarget and detectionTarget.Parent and detectionTarget:IsDescendantOf(game) then
        -- Проверяем, что объект всё ещё существует и видим (если это GuiObject)
        local visible = true
        if detectionTarget:IsA("GuiObject") then
            visible = detectionTarget.Visible
            -- также проверяем видимость всех родителей
            local parent = detectionTarget.Parent
            while parent and parent:IsA("GuiObject") do
                if not parent.Visible then visible = false end
                parent = parent.Parent
            end
        end
        if visible then
            return true
        else
            return false
        end
    end
    
    -- Если элемент не выбран или исчез, пробуем автоопределение (V10)
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return false end
    
    -- 1. Таймер
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
    
    -- 2. Кнопка Reset
    local hasReset = false
    for _, obj in pairs(playerGui:GetDescendants()) do
        if obj:IsA("TextButton") and obj.Visible and obj.Text == "Reset" then
            hasReset = true
            break
        end
    end
    
    -- 3. Роль
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
    local active = indicators >= 2 and not isSpectating and isAlive and otherPlayers > 0
    
    if debugMode then
        print("[DEBUG] Timer:", hasTimer, "Reset:", hasReset, "Role:", hasRole)
        print("[DEBUG] Spectate:", isSpectating, "Alive:", isAlive, "Players:", otherPlayers)
        print("[DEBUG] Active:", active)
    end
    
    return active
end

-- ========== ФУНКЦИЯ ВЫБОРА ЭЛЕМЕНТА ==========
local function startElementSelection()
    local oldMouseIcon = LocalPlayer:GetMouse().Icon
    LocalPlayer:GetMouse().Icon = "rbxasset://SystemCursor/Crosshair"
    print("[SWILL] Режим выбора элемента. Наведите курсор на элемент (таймер, панель здоровья и т.п.) и нажмите любую клавишу.")
    
    local connection
    connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType == Enum.UserInputType.MouseButton1 then
            local mouse = LocalPlayer:GetMouse()
            local target = mouse.Target
            -- Если нажали на GuiObject, используем его
            if target and target:IsA("GuiObject") then
                detectionTarget = target
                print("[SWILL] Выбран элемент:", detectionTarget:GetFullName())
            else
                -- Если кликнули не по GUI, ищем под курсором GuiObject
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

-- ========== ОСТАЛЬНЫЕ ФУНКЦИИ (V10) ==========
-- (функции getGroundPosition, fixPositionIfFalling, getCoins, getNearestCoin, getNearbyPlayers, setNoclip, walkTo, stopMoving, evadeFromPlayer остаются без изменений, я их сокращу для экономии места)
local function getGroundPosition(p) ... end
local function fixPositionIfFalling() ... end
local function getCoins() ... end
local function getNearestCoin() ... end
local function getNearbyPlayers(r) ... end
local function setNoclip(state) ... end
local function walkTo(pos) ... end
local function stopMoving() ... end
local function evadeFromPlayer(pr) ... end

-- ========== ОСНОВНОЙ ЦИКЛ ==========
local function startFarmer()
    if currentConnection then return end
    isRunning = true
    print("[SWILL] Фармер активирован V11 (ручной выбор элемента детекции)")
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
            if targetCoin and distToCoin > 3 and heightDiff and heightDiff < 15 then
                walkTo(targetCoin.Position)
                if rootPart then rootPart.CFrame = CFrame.new(rootPart.Position, targetCoin.Position) end
            elseif targetCoin and distToCoin <= 3 then
                stopMoving()
                humanoid.WalkSpeed = 16
            else
                if #getCoins() > 0 then
                    local groundPos = getGroundPosition(rootPart.Position)
                    if groundPos then
                        walkTo(groundPos + Vector3.new(math.random(-20,20), 0, math.random(-20,20)))
                    else
                        walkTo(rootPart.Position + Vector3.new(math.random(-20,20), 0, math.random(-20,20)))
                    end
                else
                    stopMoving()
                end
            end
        end
    end)
end

local function stopFarmer()
    if currentConnection then currentConnection:Disconnect() end
    stopMoving()
    setNoclip(false)
    isRunning = false
    isEvading = false
    isGameActive = false
    print("[SWILL] Фармер остановлен")
end

-- ========== GUI ==========
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
title.Text = "SWILL FARMER V11"
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

-- Обновление статуса игры
spawn(function()
    while task.wait(0.5) do
        if screenGui and screenGui.Parent then
            local active = isGameActuallyActive()
            gameStatusText.Text = active and "ИГРА: АКТИВНА ▶" or "ИГРА: ЛОББИ/СПЕКТАТОР ⏸"
            gameStatusText.TextColor3 = active and Color3.fromRGB(100,255,100) or Color3.fromRGB(255,100,100)
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

print("[SWILL] V11 ЗАГРУЖЕН")
print("[SWILL] Если автоопределение не работает, нажмите 'ВЫБРАТЬ ЭЛЕМЕНТ' и кликните на таймер.")
print("[SWILL] После выбора бот будет ориентироваться на видимость этого элемента.")