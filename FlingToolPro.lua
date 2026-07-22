--// Fling Tool Pro - Interface Custom (Sem bibliotecas externas)
--// Funciona em qualquer executor mobile/PC
--// Criado em: 2026-07-22

--// ==================== SERVIÇOS ====================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--// ==================== CONFIGURAÇÕES ====================
local CONFIG = {
    RefreshInterval = 10,
    FlingDuration = 5,
    SpinSpeed = 50,
    ReturnDelay = 0.1,
    TargetName = "Sign",
    RequiredCount = 4,
}

--// ==================== ESTADO ====================
local State = {
    SelectedPlayer = nil,
    IsFlinging = false,
    IsOpen = true,
    Signs = {},
    OriginalPositions = {},
    OriginalParents = {},
    OriginalAnchors = {},
    Connections = {},
    FlingThread = nil,
}

--// ==================== FUNÇÕES AUXILIARES ====================
local function FindTargetFolder()
    local success, folder = pcall(function()
        return Workspace:WaitForChild("RegularLobby", 3):WaitForChild("MainLobby", 3):WaitForChild("Parts", 3)
    end)
    return success and folder or nil
end

local function FindSigns()
    local signs = {}
    local folder = FindTargetFolder()
    if not folder then
        warn("[AVISO] Pasta RegularLobby/MainLobby/Parts não encontrada!")
        return signs
    end
    for _, obj in ipairs(folder:GetChildren()) do
        if obj.Name == CONFIG.TargetName and #signs < CONFIG.RequiredCount then
            table.insert(signs, obj)
        end
    end
    return signs
end

local function SaveOriginalData(signs)
    State.OriginalPositions = {}
    State.OriginalParents = {}
    State.OriginalAnchors = {}
    for _, sign in ipairs(signs) do
        if sign and sign.Parent then
            State.OriginalPositions[sign] = sign.CFrame
            State.OriginalParents[sign] = sign.Parent
            State.OriginalAnchors[sign] = sign.Anchored
        end
    end
end

local function RestoreOriginalData()
    for sign, cframe in pairs(State.OriginalPositions) do
        if sign and sign.Parent then
            pcall(function()
                sign.Anchored = true
                sign.CFrame = cframe
                if State.OriginalParents[sign] and sign.Parent ~= State.OriginalParents[sign] then
                    sign.Parent = State.OriginalParents[sign]
                end
                sign.Anchored = State.OriginalAnchors[sign]
            end)
        end
    end
end

local function GetPlayerNames()
    local names = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(names, player.Name)
        end
    end
    table.sort(names)
    return names
end

local function GetPlayerByName(name)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name == name then
            return player
        end
    end
    return nil
end

local function GetPlayerPosition(player)
    if not player then return nil end
    local char = player.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp.Position end
    local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
    if torso then return torso.Position end
    local head = char:FindFirstChild("Head")
    if head then return head.Position end
    return nil
end

--// ==================== FLING SYSTEM ====================
local function DoFlingCycle()
    if not State.SelectedPlayer or not State.IsFlinging then return end
    local signs = FindSigns()
    if #signs < CONFIG.RequiredCount then
        warn("[ERRO] Signs insuficientes (" .. #signs .. "/" .. CONFIG.RequiredCount .. ")")
        return
    end
    State.Signs = signs
    SaveOriginalData(signs)
    local targetPos = GetPlayerPosition(State.SelectedPlayer)
    if not targetPos then return end

    for i, sign in ipairs(signs) do
        pcall(function()
            sign.Anchored = true
            local offset = Vector3.new(
                (i == 1 and 3 or i == 2 and -3 or 0),
                (i == 3 and 3 or i == 4 and -3 or 0),
                (i == 1 and 0 or i == 2 and 0 or i == 3 and 3 or -3)
            )
            sign.CFrame = CFrame.new(targetPos + offset)
            sign.Parent = Workspace
        end)
    end

    local startTime = tick()
    local spinConnection
    spinConnection = RunService.Heartbeat:Connect(function()
        if not State.IsFlinging or tick() - startTime >= CONFIG.FlingDuration then
            pcall(function() spinConnection:Disconnect() end)
            return
        end
        local currentPos = GetPlayerPosition(State.SelectedPlayer)
        if not currentPos then return end
        local elapsed = tick() - startTime
        for i, sign in ipairs(signs) do
            pcall(function()
                if not sign or not sign.Parent then return end
                local angleX = elapsed * CONFIG.SpinSpeed * (i * 0.5 + 1)
                local angleY = elapsed * CONFIG.SpinSpeed * (i * 0.3 + 1.5)
                local angleZ = elapsed * CONFIG.SpinSpeed * (i * 0.7 + 0.8)
                local radius = 4 + math.sin(elapsed * 5) * 2
                local offset = Vector3.new(
                    math.cos(angleX) * radius,
                    math.sin(angleY) * radius * 0.5,
                    math.sin(angleZ) * radius
                )
                sign.CFrame = CFrame.new(currentPos + offset) * CFrame.Angles(angleX * 2, angleY * 2, angleZ * 2)
            end)
        end
    end)
    table.insert(State.Connections, spinConnection)

    task.delay(CONFIG.FlingDuration, function()
        for _, sign in ipairs(signs) do
            pcall(function()
                if State.OriginalParents[sign] then sign.Parent = State.OriginalParents[sign] end
            end)
        end
        task.wait(CONFIG.ReturnDelay)
        RestoreOriginalData()
    end)
end

local function StartFlingLoop()
    if State.FlingThread then return end
    State.FlingThread = task.spawn(function()
        while State.IsFlinging do
            if State.SelectedPlayer then DoFlingCycle() end
            task.wait(CONFIG.FlingDuration + CONFIG.ReturnDelay + 0.5)
        end
        State.FlingThread = nil
    end)
end

local function StopFlingLoop()
    State.IsFlinging = false
    State.FlingThread = nil
    for _, conn in ipairs(State.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    State.Connections = {}
    RestoreOriginalData()
end

--// ==================== INTERFACE CUSTOM ====================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FlingToolPro_GUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

if syn and syn.protect_gui then
    syn.protect_gui(ScreenGui)
end
ScreenGui.Parent = CoreGui

--// CORES E ESTILOS
local COLORS = {
    Background = Color3.fromRGB(18, 18, 22),
    Surface = Color3.fromRGB(28, 28, 35),
    SurfaceHover = Color3.fromRGB(38, 38, 48),
    Border = Color3.fromRGB(45, 45, 55),
    Accent = Color3.fromRGB(0, 170, 255),
    AccentDark = Color3.fromRGB(0, 120, 200),
    Text = Color3.fromRGB(230, 230, 240),
    TextDim = Color3.fromRGB(150, 150, 160),
    Red = Color3.fromRGB(255, 70, 70),
    Green = Color3.fromRGB(70, 255, 120),
    Yellow = Color3.fromRGB(255, 200, 50),
    Orange = Color3.fromRGB(255, 150, 50),
}

--// JANELA PRINCIPAL
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 380, 0, 420)
MainFrame.Position = UDim2.new(0.5, -190, 0.5, -210)
MainFrame.BackgroundColor3 = COLORS.Background
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = COLORS.Border
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

-- Gradiente de fundo sutil
local MainGradient = Instance.new("UIGradient")
MainGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 18, 25)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 12, 18)),
})
MainGradient.Rotation = 135
MainGradient.Parent = MainFrame

--// HEADER
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 48)
Header.BackgroundColor3 = COLORS.Surface
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 12)
HeaderCorner.Parent = Header

-- Fix bottom corners do header
local HeaderFix = Instance.new("Frame")
HeaderFix.Size = UDim2.new(1, 0, 0, 12)
HeaderFix.Position = UDim2.new(0, 0, 1, -12)
HeaderFix.BackgroundColor3 = COLORS.Surface
HeaderFix.BorderSizePixel = 0
HeaderFix.Parent = Header

-- Ícone
local IconLabel = Instance.new("TextLabel")
IconLabel.Size = UDim2.new(0, 36, 0, 36)
IconLabel.Position = UDim2.new(0, 12, 0, 6)
IconLabel.BackgroundTransparency = 1
IconLabel.Text = "⚔️"
IconLabel.TextSize = 22
IconLabel.Font = Enum.Font.GothamBold
IconLabel.Parent = Header

-- Título
local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(0, 200, 0, 24)
TitleLabel.Position = UDim2.new(0, 50, 0, 4)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "FLING TOOL PRO"
TitleLabel.TextColor3 = COLORS.Text
TitleLabel.TextSize = 16
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = Header

-- Subtítulo
local SubTitle = Instance.new("TextLabel")
SubTitle.Size = UDim2.new(0, 200, 0, 16)
SubTitle.Position = UDim2.new(0, 50, 0, 26)
SubTitle.BackgroundTransparency = 1
SubTitle.Text = "Mobile Edition"
SubTitle.TextColor3 = COLORS.Accent
SubTitle.TextSize = 11
SubTitle.Font = Enum.Font.Gotham
SubTitle.TextXAlignment = Enum.TextXAlignment.Left
SubTitle.Parent = Header

-- Botão fechar (X)
local CloseBtn = Instance.new("TextButton")
CloseBtn.Name = "CloseBtn"
CloseBtn.Size = UDim2.new(0, 32, 0, 32)
CloseBtn.Position = UDim2.new(1, -40, 0, 8)
CloseBtn.BackgroundColor3 = COLORS.Red
CloseBtn.BackgroundTransparency = 0.8
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = COLORS.Text
CloseBtn.TextSize = 14
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = Header

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 8)
CloseCorner.Parent = CloseBtn

CloseBtn.MouseEnter:Connect(function()
    TweenService:Create(CloseBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.3}):Play()
end)
CloseBtn.MouseLeave:Connect(function()
    TweenService:Create(CloseBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.8}):Play()
end)

-- Botão minimizar (_)
local MinBtn = Instance.new("TextButton")
MinBtn.Name = "MinBtn"
MinBtn.Size = UDim2.new(0, 32, 0, 32)
MinBtn.Position = UDim2.new(1, -76, 0, 8)
MinBtn.BackgroundColor3 = COLORS.Yellow
MinBtn.BackgroundTransparency = 0.8
MinBtn.BorderSizePixel = 0
MinBtn.Text = "─"
MinBtn.TextColor3 = COLORS.Text
MinBtn.TextSize = 16
MinBtn.Font = Enum.Font.GothamBold
MinBtn.Parent = Header

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 8)
MinCorner.Parent = MinBtn

MinBtn.MouseEnter:Connect(function()
    TweenService:Create(MinBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.3}):Play()
end)
MinBtn.MouseLeave:Connect(function()
    TweenService:Create(MinBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.8}):Play()
end)

--// SCROLL AREA
local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Name = "ScrollFrame"
ScrollFrame.Size = UDim2.new(1, -20, 1, -58)
ScrollFrame.Position = UDim2.new(0, 10, 0, 54)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.ScrollBarImageColor3 = COLORS.Accent
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
ScrollFrame.Parent = MainFrame

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 10)
ListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Parent = ScrollFrame

local ListPadding = Instance.new("UIPadding")
ListPadding.PaddingTop = UDim.new(0, 8)
ListPadding.PaddingBottom = UDim.new(0, 8)
ListPadding.Parent = ScrollFrame

--// FUNÇÃO: Criar Seção
local function CreateSection(title)
    local section = Instance.new("Frame")
    section.Size = UDim2.new(1, -10, 0, 30)
    section.BackgroundTransparency = 1
    section.Parent = ScrollFrame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = title
    label.TextColor3 = COLORS.Accent
    label.TextSize = 13
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = section

    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 1)
    line.Position = UDim2.new(0, 0, 1, -2)
    line.BackgroundColor3 = COLORS.Border
    line.BorderSizePixel = 0
    line.Parent = section

    return section
end

--// FUNÇÃO: Criar Botão
local function CreateButton(text, desc, parent)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 42)
    btn.BackgroundColor3 = COLORS.Surface
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.Border
    stroke.Thickness = 1
    stroke.Parent = btn

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -12, 0, 20)
    label.Position = UDim2.new(0, 10, 0, 4)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = COLORS.Text
    label.TextSize = 13
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = btn

    if desc then
        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(1, -12, 0, 14)
        descLabel.Position = UDim2.new(0, 10, 0, 24)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = desc
        descLabel.TextColor3 = COLORS.TextDim
        descLabel.TextSize = 10
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.Parent = btn
    end

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = COLORS.SurfaceHover}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.15), {Color = COLORS.Accent}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = COLORS.Surface}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.15), {Color = COLORS.Border}):Play()
    end)
    btn.MouseButton1Down:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {Size = UDim2.new(1, -14, 0, 40)}):Play()
        btn.Position = UDim2.new(0, 7, 0, 1)
    end)
    btn.MouseButton1Up:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {Size = UDim2.new(1, -10, 0, 42)}):Play()
        btn.Position = UDim2.new(0, 5, 0, 0)
    end)

    return btn
end

--// FUNÇÃO: Criar Toggle
local function CreateToggle(text, desc, parent)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -10, 0, desc and 52 or 38)
    container.BackgroundColor3 = COLORS.Surface
    container.BorderSizePixel = 0
    container.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = container

    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.Border
    stroke.Thickness = 1
    stroke.Parent = container

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -70, 0, 18)
    label.Position = UDim2.new(0, 10, 0, desc and 6 or 10)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = COLORS.Text
    label.TextSize = 13
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container

    if desc then
        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(1, -70, 0, 14)
        descLabel.Position = UDim2.new(0, 10, 0, 26)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = desc
        descLabel.TextColor3 = COLORS.TextDim
        descLabel.TextSize = 10
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.Parent = container
    end

    -- Toggle switch
    local toggleBg = Instance.new("Frame")
    toggleBg.Name = "ToggleBg"
    toggleBg.Size = UDim2.new(0, 44, 0, 24)
    toggleBg.Position = UDim2.new(1, -54, 0.5, -12)
    toggleBg.BackgroundColor3 = COLORS.Border
    toggleBg.BorderSizePixel = 0
    toggleBg.Parent = container

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(1, 0)
    toggleCorner.Parent = toggleBg

    local toggleCircle = Instance.new("Frame")
    toggleCircle.Name = "Circle"
    toggleCircle.Size = UDim2.new(0, 18, 0, 18)
    toggleCircle.Position = UDim2.new(0, 3, 0.5, -9)
    toggleCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    toggleCircle.BorderSizePixel = 0
    toggleCircle.Parent = toggleBg

    local circleCorner = Instance.new("UICorner")
    circleCorner.CornerRadius = UDim.new(1, 0)
    circleCorner.Parent = toggleCircle

    local isOn = false
    local function SetToggle(value)
        isOn = value
        if value then
            TweenService:Create(toggleBg, TweenInfo.new(0.2), {BackgroundColor3 = COLORS.Green}):Play()
            TweenService:Create(toggleCircle, TweenInfo.new(0.2), {Position = UDim2.new(0, 23, 0.5, -9)}):Play()
            TweenService:Create(stroke, TweenInfo.new(0.2), {Color = COLORS.Green}):Play()
        else
            TweenService:Create(toggleBg, TweenInfo.new(0.2), {BackgroundColor3 = COLORS.Border}):Play()
            TweenService:Create(toggleCircle, TweenInfo.new(0.2), {Position = UDim2.new(0, 3, 0.5, -9)}):Play()
            TweenService:Create(stroke, TweenInfo.new(0.2), {Color = COLORS.Border}):Play()
        end
    end

    container.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            SetToggle(not isOn)
        end
    end)

    return {Frame = container, Set = SetToggle, Get = function() return isOn end}
end

--// FUNÇÃO: Criar Dropdown
local function CreateDropdown(title, parent)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -10, 0, 40)
    container.BackgroundTransparency = 1
    container.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 16)
    label.BackgroundTransparency = 1
    label.Text = title
    label.TextColor3 = COLORS.TextDim
    label.TextSize = 11
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container

    local dropdownBtn = Instance.new("TextButton")
    dropdownBtn.Size = UDim2.new(1, 0, 0, 36)
    dropdownBtn.Position = UDim2.new(0, 0, 0, 18)
    dropdownBtn.BackgroundColor3 = COLORS.Surface
    dropdownBtn.BorderSizePixel = 0
    dropdownBtn.Text = "Selecione um player..."
    dropdownBtn.TextColor3 = COLORS.TextDim
    dropdownBtn.TextSize = 12
    dropdownBtn.Font = Enum.Font.Gotham
    dropdownBtn.AutoButtonColor = false
    dropdownBtn.Parent = container

    local ddCorner = Instance.new("UICorner")
    ddCorner.CornerRadius = UDim.new(0, 8)
    ddCorner.Parent = dropdownBtn

    local ddStroke = Instance.new("UIStroke")
    ddStroke.Color = COLORS.Border
    ddStroke.Thickness = 1
    ddStroke.Parent = dropdownBtn

    local arrow = Instance.new("TextLabel")
    arrow.Size = UDim2.new(0, 20, 1, 0)
    arrow.Position = UDim2.new(1, -24, 0, 0)
    arrow.BackgroundTransparency = 1
    arrow.Text = "▼"
    arrow.TextColor3 = COLORS.TextDim
    arrow.TextSize = 10
    arrow.Font = Enum.Font.GothamBold
    arrow.Parent = dropdownBtn

    -- Lista dropdown
    local listFrame = Instance.new("Frame")
    listFrame.Size = UDim2.new(1, 0, 0, 0)
    listFrame.Position = UDim2.new(0, 0, 0, 56)
    listFrame.BackgroundColor3 = COLORS.Surface
    listFrame.BorderSizePixel = 0
    listFrame.ClipsDescendants = true
    listFrame.Visible = false
    listFrame.ZIndex = 10
    listFrame.Parent = container

    local listCorner = Instance.new("UICorner")
    listCorner.CornerRadius = UDim.new(0, 8)
    listCorner.Parent = listFrame

    local listStroke = Instance.new("UIStroke")
    listStroke.Color = COLORS.Border
    listStroke.Thickness = 1
    listStroke.Parent = listFrame

    local listScroll = Instance.new("ScrollingFrame")
    listScroll.Size = UDim2.new(1, -8, 1, -8)
    listScroll.Position = UDim2.new(0, 4, 0, 4)
    listScroll.BackgroundTransparency = 1
    listScroll.BorderSizePixel = 0
    listScroll.ScrollBarThickness = 3
    listScroll.ScrollBarImageColor3 = COLORS.Accent
    listScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    listScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    listScroll.ZIndex = 11
    listScroll.Parent = listFrame

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 2)
    listLayout.Parent = listScroll

    local isOpen = false
    local selectedValue = nil
    local optionButtons = {}

    local function RefreshDropdown(values)
        for _, btn in ipairs(optionButtons) do
            btn:Destroy()
        end
        optionButtons = {}

        for _, val in ipairs(values) do
            local opt = Instance.new("TextButton")
            opt.Size = UDim2.new(1, 0, 0, 30)
            opt.BackgroundColor3 = COLORS.Surface
            opt.BorderSizePixel = 0
            opt.Text = val
            opt.TextColor3 = COLORS.Text
            opt.TextSize = 12
            opt.Font = Enum.Font.Gotham
            opt.AutoButtonColor = false
            opt.ZIndex = 12
            opt.Parent = listScroll

            local optCorner = Instance.new("UICorner")
            optCorner.CornerRadius = UDim.new(0, 6)
            optCorner.Parent = opt

            opt.MouseEnter:Connect(function()
                TweenService:Create(opt, TweenInfo.new(0.1), {BackgroundColor3 = COLORS.SurfaceHover}):Play()
            end)
            opt.MouseLeave:Connect(function()
                TweenService:Create(opt, TweenInfo.new(0.1), {BackgroundColor3 = COLORS.Surface}):Play()
            end)
            opt.MouseButton1Click:Connect(function()
                selectedValue = val
                dropdownBtn.Text = val
                dropdownBtn.TextColor3 = COLORS.Text
                TweenService:Create(ddStroke, TweenInfo.new(0.2), {Color = COLORS.Accent}):Play()
                isOpen = false
                TweenService:Create(listFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 0)}):Play()
                listFrame.Visible = false
                arrow.Text = "▼"
            end)

            table.insert(optionButtons, opt)
        end
    end

    dropdownBtn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        if isOpen then
            listFrame.Visible = true
            local height = math.min(#optionButtons * 32 + 8, 160)
            TweenService:Create(listFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, height)}):Play()
            arrow.Text = "▲"
        else
            TweenService:Create(listFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 0)}):Play()
            task.delay(0.2, function()
                if not isOpen then listFrame.Visible = false end
            end)
            arrow.Text = "▼"
        end
    end)

    dropdownBtn.MouseEnter:Connect(function()
        if not selectedValue then
            TweenService:Create(dropdownBtn, TweenInfo.new(0.15), {BackgroundColor3 = COLORS.SurfaceHover}):Play()
        end
    end)
    dropdownBtn.MouseLeave:Connect(function()
        TweenService:Create(dropdownBtn, TweenInfo.new(0.15), {BackgroundColor3 = COLORS.Surface}):Play()
    end)

    return {
        Frame = container,
        Refresh = RefreshDropdown,
        GetSelected = function() return selectedValue end,
        SetSelected = function(val)
            selectedValue = val
            dropdownBtn.Text = val or "Selecione um player..."
            dropdownBtn.TextColor3 = val and COLORS.Text or COLORS.TextDim
        end
    }
end

--// FUNÇÃO: Criar Label de Status
local function CreateStatusLabel(parent)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 28)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    frame.BorderSizePixel = 0
    frame.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = "⏳ Aguardando..."
    label.TextColor3 = COLORS.Yellow
    label.TextSize = 11
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    return {
        Frame = frame,
        Set = function(text, color)
            label.Text = text
            label.TextColor3 = color or COLORS.Text
        end
    }
end

--// ==================== MONTAR INTERFACE ====================

CreateSection("  🎯 SELEÇÃO DE VÍTIMA")

local PlayerDropdown = CreateDropdown("Escolher Player", ScrollFrame)
PlayerDropdown.Refresh(GetPlayerNames())

local RefreshBtn = CreateButton("🔄 Atualizar Lista", "Atualiza a lista de players manualmente", ScrollFrame)

local SelectedStatus = CreateStatusLabel(ScrollFrame)
SelectedStatus.Set("❌ Nenhum player selecionado", COLORS.Red)

CreateSection("  ⚡ FUNÇÃO FLING")

local FlingToggle = CreateToggle("Ativar Fling", "Teleporta 4 Signs e gira rapidamente", ScrollFrame)

local InfoLabel = Instance.new("TextLabel")
InfoLabel.Size = UDim2.new(1, -10, 0, 30)
InfoLabel.BackgroundTransparency = 1
InfoLabel.Text = "ℹ️ Os objetos ficam 5s no player e retornam automaticamente"
InfoLabel.TextColor3 = COLORS.TextDim
InfoLabel.TextSize = 10
InfoLabel.Font = Enum.Font.Gotham
InfoLabel.TextWrapped = true
InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
InfoLabel.Parent = ScrollFrame

CreateSection("  📊 STATUS DO SISTEMA")

local SystemStatus = CreateStatusLabel(ScrollFrame)
SystemStatus.Set("⏳ Aguardando seleção...", COLORS.Yellow)

--// ==================== BOTÃO MOBILE FLUTUANTE ====================
local MobileGui = Instance.new("ScreenGui")
MobileGui.Name = "FlingTool_MobileBtn"
MobileGui.ResetOnSpawn = false
MobileGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

if syn and syn.protect_gui then
    syn.protect_gui(MobileGui)
end
MobileGui.Parent = CoreGui

local MobileBtn = Instance.new("TextButton")
MobileBtn.Name = "MobileToggle"
MobileBtn.Size = UDim2.new(0, 56, 0, 56)
MobileBtn.Position = UDim2.new(0, 16, 0.5, -28)
MobileBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
MobileBtn.BackgroundTransparency = 0.15
MobileBtn.BorderSizePixel = 0
MobileBtn.Text = "⚔️"
MobileBtn.TextSize = 26
MobileBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MobileBtn.Font = Enum.Font.GothamBold
MobileBtn.Parent = MobileGui

local MobCorner = Instance.new("UICorner")
MobCorner.CornerRadius = UDim.new(1, 0)
MobCorner.Parent = MobileBtn

local MobStroke = Instance.new("UIStroke")
MobStroke.Color = COLORS.Accent
MobStroke.Thickness = 2.5
MobStroke.Parent = MobileBtn

local MobGradient = Instance.new("UIGradient")
MobGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, COLORS.Accent),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 0, 255)),
})
MobGradient.Rotation = 45
MobGradient.Parent = MobStroke

local MobShadow = Instance.new("ImageLabel")
MobShadow.AnchorPoint = Vector2.new(0.5, 0.5)
MobShadow.BackgroundTransparency = 1
MobShadow.Position = UDim2.new(0.5, 0, 0.5, 0)
MobShadow.Size = UDim2.new(1, 36, 1, 36)
MobShadow.ZIndex = -1
MobShadow.Image = "rbxassetid://6015897843"
MobShadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
MobShadow.ImageTransparency = 0.5
MobShadow.ScaleType = Enum.ScaleType.Slice
MobShadow.SliceCenter = Rect.new(49, 49, 450, 450)
MobShadow.Parent = MobileBtn

-- Animações do botão mobile
MobileBtn.MouseEnter:Connect(function()
    TweenService:Create(MobileBtn, TweenInfo.new(0.2), {Size = UDim2.new(0, 62, 0, 62)}):Play()
end)
MobileBtn.MouseLeave:Connect(function()
    TweenService:Create(MobileBtn, TweenInfo.new(0.2), {Size = UDim2.new(0, 56, 0, 56)}):Play()
end)

--// ==================== LÓGICA DOS BOTÕES ====================

-- Fechar janela
CloseBtn.MouseButton1Click:Connect(function()
    TweenService:Create(MainFrame, TweenInfo.new(0.3), {Size = UDim2.new(0, 0, 0, 0)}):Play()
    task.delay(0.3, function()
        ScreenGui:Destroy()
        MobileGui:Destroy()
        StopFlingLoop()
        for _, conn in ipairs(State.Connections) do
            pcall(function() conn:Disconnect() end)
        end
    end)
end)

-- Minimizar janela
MinBtn.MouseButton1Click:Connect(function()
    State.IsOpen = not State.IsOpen
    if State.IsOpen then
        MainFrame.Visible = true
        TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), 
            {Size = UDim2.new(0, 380, 0, 420)}):Play()
        MobileBtn.Text = "✕"
        MobStroke.Color = COLORS.Red
    else
        TweenService:Create(MainFrame, TweenInfo.new(0.25), {Size = UDim2.new(0, 0, 0, 0)}):Play()
        task.delay(0.25, function()
            if not State.IsOpen then MainFrame.Visible = false end
        end)
        MobileBtn.Text = "⚔️"
        MobStroke.Color = COLORS.Accent
    end
end)

-- Botão mobile toggle
MobileBtn.MouseButton1Click:Connect(function()
    MinBtn.MouseButton1Click:Fire()
end)

-- Refresh manual
RefreshBtn.MouseButton1Click:Connect(function()
    local names = GetPlayerNames()
    PlayerDropdown.Refresh(names)
    -- Notificação visual temporária
    local oldText = RefreshBtn.Text
    RefreshBtn:FindFirstChildOfClass("TextLabel").Text = "✅ Lista Atualizada! (" .. #names .. ")"
    TweenService:Create(RefreshBtn, TweenInfo.new(0.2), {BackgroundColor3 = COLORS.Green}):Play()
    task.delay(1.5, function()
        RefreshBtn:FindFirstChildOfClass("TextLabel").Text = oldText
        TweenService:Create(RefreshBtn, TweenInfo.new(0.2), {BackgroundColor3 = COLORS.Surface}):Play()
    end)
end)

-- Dropdown selection
local oldDropdownClick = PlayerDropdown.Frame:FindFirstChildOfClass("TextButton").MouseButton1Click
PlayerDropdown.Frame:FindFirstChildOfClass("TextButton").MouseButton1Click:Connect(function()
    -- Atualiza antes de abrir
    PlayerDropdown.Refresh(GetPlayerNames())
end)

-- Detecta seleção de player
local function CheckDropdownSelection()
    local selected = PlayerDropdown.GetSelected()
    if selected and selected ~= "" then
        State.SelectedPlayer = GetPlayerByName(selected)
        if State.SelectedPlayer then
            SelectedStatus.Set("✅ Selecionado: " .. State.SelectedPlayer.Name, COLORS.Green)
        end
    end
end

-- Toggle Fling
local flingToggleFrame = FlingToggle.Frame
flingToggleFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        task.wait(0.05)
        local isOn = FlingToggle.Get()

        if isOn and not State.SelectedPlayer then
            -- Bloqueia!
            FlingToggle.Set(false)
            SelectedStatus.Set("❌ Escolha um player primeiro!", COLORS.Red)
            TweenService:Create(SelectedStatus.Frame, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(60, 20, 20)}):Play()
            task.delay(1, function()
                TweenService:Create(SelectedStatus.Frame, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(25, 25, 30)}):Play()
                if not State.SelectedPlayer then
                    SelectedStatus.Set("❌ Nenhum player selecionado", COLORS.Red)
                end
            end)
            return
        end

        State.IsFlinging = isOn
        if isOn then
            SystemStatus.Set("🔥 FLING ATIVO - Atacando " .. State.SelectedPlayer.Name, COLORS.Red)
            StartFlingLoop()
        else
            SystemStatus.Set("⏳ Fling desativado", COLORS.Yellow)
            StopFlingLoop()
        end
    end
end)

--// ==================== LOOPS DE ATUALIZAÇÃO ====================

-- Atualiza lista a cada 10 segundos
task.spawn(function()
    while ScreenGui and ScreenGui.Parent do
        task.wait(CONFIG.RefreshInterval)
        if not State.IsFlinging then
            local names = GetPlayerNames()
            PlayerDropdown.Refresh(names)

            -- Verifica se player saiu
            if State.SelectedPlayer then
                local exists = false
                for _, p in ipairs(Players:GetPlayers()) do
                    if p == State.SelectedPlayer then exists = true break end
                end
                if not exists then
                    State.SelectedPlayer = nil
                    PlayerDropdown.SetSelected(nil)
                    SelectedStatus.Set("❌ Player saiu do servidor", COLORS.Red)
                    if State.IsFlinging then
                        FlingToggle.Set(false)
                        StopFlingLoop()
                    end
                end
            end
        end
    end
end)

-- Atualiza status visual
RunService.Heartbeat:Connect(function()
    CheckDropdownSelection()

    if State.SelectedPlayer then
        local char = State.SelectedPlayer.Character
        local status = char and "🟢 Online" or "🔴 Sem personagem"
        if not State.IsFlinging then
            SystemStatus.Set("⏳ Pronto para atacar " .. State.SelectedPlayer.Name .. " " .. status, COLORS.Accent)
        end
    else
        if not State.IsFlinging then
            SystemStatus.Set("⏳ Escolha um player no dropdown", COLORS.Yellow)
        end
    end
end)

-- Player saiu
Players.PlayerRemoving:Connect(function(player)
    if State.SelectedPlayer == player then
        State.SelectedPlayer = nil
        PlayerDropdown.SetSelected(nil)
        SelectedStatus.Set("❌ Player saiu do servidor", COLORS.Red)
        if State.IsFlinging then
            FlingToggle.Set(false)
            StopFlingLoop()
        end
    end
end)

--// ==================== ANIMAÇÃO DE ENTRADA ====================
MainFrame.Size = UDim2.new(0, 0, 0, 0)
TweenService:Create(MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), 
    {Size = UDim2.new(0, 380, 0, 420)}):Play()

print("[Fling Tool Pro] Interface custom carregada com sucesso!")
print("[Fling Tool Pro] Sem bibliotecas externas | 100% compatível com mobile")
