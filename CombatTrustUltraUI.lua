-- Combat Trust UI Ultra
-- Standalone UI layer for an existing getgenv().CombatTrustProbe table.
-- This file does NOT recreate or modify the combat hooks themselves.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    return
end

local G = getgenv and getgenv() or _G
local Probe = G.CombatTrustProbe

if type(Probe) ~= "table" then
    warn("[Combat UI] CombatTrustProbe was not found. Run the core script first.")
    return
end

if G.CombatTrustUltraUI then
    pcall(function()
        G.CombatTrustUltraUI:Destroy()
    end)
end

local Theme = {
    Bg = Color3.fromRGB(9, 11, 17),
    Bg2 = Color3.fromRGB(14, 17, 25),
    Card = Color3.fromRGB(21, 25, 36),
    Card2 = Color3.fromRGB(29, 34, 48),
    Card3 = Color3.fromRGB(36, 42, 58),
    Border = Color3.fromRGB(55, 64, 84),
    Text = Color3.fromRGB(246, 248, 252),
    Muted = Color3.fromRGB(143, 154, 178),
    Green = Color3.fromRGB(67, 224, 139),
    Green2 = Color3.fromRGB(26, 82, 56),
    Amber = Color3.fromRGB(255, 187, 75),
    Amber2 = Color3.fromRGB(79, 58, 29),
    Blue = Color3.fromRGB(91, 151, 255),
    Blue2 = Color3.fromRGB(34, 52, 88),
    Red = Color3.fromRGB(239, 88, 104),
}

local function corner(o, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 10)
    c.Parent = o
    return c
end

local function stroke(o, color, transparency, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.Border
    s.Transparency = transparency or 0
    s.Thickness = thickness or 1
    s.Parent = o
    return s
end

local function tween(o, props, t)
    local tw = TweenService:Create(
        o,
        TweenInfo.new(t or 0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        props
    )
    tw:Play()
    return tw
end

local function safeCall(name, ...)
    local actions = rawget(Probe, "Actions")
    local fn = actions and actions[name]
    if type(fn) == "function" then
        local ok, result = pcall(fn, ...)
        if ok then
            return true, result
        end
    end
    return false
end

local function fallbackSave()
    if type(writefile) ~= "function" then
        return
    end

    local folder = "DefenseTrustProbe"
    local path = folder .. "/multiplayer_config.json"

    pcall(function()
        if type(makefolder) == "function" then
            if type(isfolder) ~= "function" or not isfolder(folder) then
                pcall(makefolder, folder)
            end
        end

        local payload = {
            Version = 3,
            PlayerTargeting = Probe.PlayerTargeting == true,
            TrustHooks = Probe.TrustHooks == true,
            TargetMode = Probe.TargetMode == "AUTO" and "AUTO" or "MANUAL",
            ManualTargetKey = type(Probe.ManualTargetKey) == "string" and Probe.ManualTargetKey or nil,
            PanelVisible = Probe.PanelVisible ~= false,
            CloseHitHook = Probe.CloseHitHook == true,
        }

        writefile(path, HttpService:JSONEncode(payload))
        Probe.ConfigStatus = "saved"
    end)
end

local saveSerial = 0
local function requestSave()
    local used = safeCall("QueueConfigSave")
    if used then
        return
    end

    saveSerial += 1
    local serial = saveSerial
    task.delay(0.2, function()
        if serial == saveSerial then
            fallbackSave()
        end
    end)
end

local function setBoolean(key, value)
    Probe[key] = value == true
    safeCall("SetBoolean", key, Probe[key])
    requestSave()
end

local function getRoster()
    return type(Probe.Roster) == "table" and Probe.Roster or {}
end

local function selectTarget(index)
    local roster = getRoster()
    local count = #roster
    if count == 0 then
        Probe.CurrentTarget = nil
        Probe.ManualTargetKey = nil
        return
    end

    index = ((index - 1) % count) + 1

    if safeCall("SelectRosterIndex", index) then
        return
    end

    Probe.TargetMode = "MANUAL"
    Probe.CurrentTarget = roster[index]
    Probe.ManualTargetKey = roster[index].Key
    requestSave()
end

local function currentRosterIndex()
    local roster = getRoster()
    local key = Probe.ManualTargetKey or (Probe.CurrentTarget and Probe.CurrentTarget.Key)
    if key == nil then
        return nil
    end

    for i, target in ipairs(roster) do
        if target.Key == key then
            return i
        end
    end
end

local function cycleTarget(dir)
    if safeCall("CycleTarget", dir) then
        return
    end

    local roster = getRoster()
    if #roster == 0 then
        return
    end

    selectTarget((currentRosterIndex() or 1) + dir)
end

local function toggleMode()
    if safeCall("ToggleTargetMode") then
        return
    end

    if Probe.TargetMode == "AUTO" then
        Probe.TargetMode = "MANUAL"
        Probe.ManualTargetKey = Probe.CurrentTarget and Probe.CurrentTarget.Key or Probe.ManualTargetKey
    else
        Probe.TargetMode = "AUTO"
    end

    requestSave()
end

local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("CombatTrustUltraUI")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "CombatTrustUltraUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = false
pcall(function()
    gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
end)
gui.Parent = playerGui
G.CombatTrustUltraUI = gui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0.94, 0, 0.82, 0)
panel.BackgroundColor3 = Theme.Bg
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Visible = Probe.PanelVisible ~= false
panel.Parent = gui
corner(panel, 18)
stroke(panel, Theme.Border, 0.1, 1)

local constraint = Instance.new("UISizeConstraint")
constraint.MinSize = Vector2.new(300, 380)
constraint.MaxSize = Vector2.new(540, 630)
constraint.Parent = panel

local trackedConnections = {}
local connectionsCleaned = false

local function trackConnection(connection)
    table.insert(trackedConnections, connection)
    return connection
end

local function cleanupConnections()
    if connectionsCleaned then
        return
    end
    connectionsCleaned = true

    for _, connection in ipairs(trackedConnections) do
        connection:Disconnect()
    end
    table.clear(trackedConnections)

    if G.CombatTrustUltraUI == gui then
        G.CombatTrustUltraUI = nil
    end
end

trackConnection(gui.Destroying:Connect(cleanupConnections))

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Theme.Bg2),
    ColorSequenceKeypoint.new(1, Theme.Bg),
})
gradient.Rotation = 90
gradient.Parent = panel

local header = Instance.new("Frame")
header.Name = "Header"
header.Active = true
header.Size = UDim2.new(1, 0, 0, 72)
header.BackgroundColor3 = Theme.Card
header.BorderSizePixel = 0
header.Parent = panel
corner(header, 18)

local fix = Instance.new("Frame")
fix.AnchorPoint = Vector2.new(0, 1)
fix.Position = UDim2.new(0, 0, 1, 0)
fix.Size = UDim2.new(1, 0, 0, 18)
fix.BackgroundColor3 = Theme.Card
fix.BorderSizePixel = 0
fix.Parent = header

local accent = Instance.new("Frame")
accent.Size = UDim2.new(1, 0, 0, 3)
accent.Position = UDim2.new(0, 0, 1, -3)
accent.BackgroundColor3 = Theme.Amber
accent.BorderSizePixel = 0
accent.Parent = header

local accentGrad = Instance.new("UIGradient")
accentGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Theme.Amber),
    ColorSequenceKeypoint.new(0.5, Theme.Green),
    ColorSequenceKeypoint.new(1, Theme.Blue),
})
accentGrad.Parent = accent

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(16, 10)
title.Size = UDim2.new(1, -180, 0, 27)
title.Font = Enum.Font.GothamBold
title.Text = "COMBAT TRUST"
title.TextColor3 = Theme.Text
title.TextSize = 17
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(16, 38)
subtitle.Size = UDim2.new(1, -180, 0, 18)
subtitle.Font = Enum.Font.GothamMedium
subtitle.Text = "ULTRA MOBILE CONTROL"
subtitle.TextColor3 = Theme.Muted
subtitle.TextSize = 9
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = header

local enemyBadge = Instance.new("TextLabel")
enemyBadge.AnchorPoint = Vector2.new(1, 0.5)
enemyBadge.Position = UDim2.new(1, -54, 0.5, -1)
enemyBadge.Size = UDim2.fromOffset(82, 31)
enemyBadge.BackgroundColor3 = Theme.Amber2
enemyBadge.BorderSizePixel = 0
enemyBadge.Font = Enum.Font.GothamBold
enemyBadge.Text = "0 ENEMIES"
enemyBadge.TextSize = 9
enemyBadge.TextColor3 = Theme.Amber
enemyBadge.Parent = header
corner(enemyBadge, 12)
stroke(enemyBadge, Theme.Amber, 0.7, 1)

local closeButton = Instance.new("TextButton")
closeButton.AnchorPoint = Vector2.new(1, 0.5)
closeButton.Position = UDim2.new(1, -11, 0.5, -1)
closeButton.Size = UDim2.fromOffset(34, 34)
closeButton.BackgroundColor3 = Theme.Card2
closeButton.BorderSizePixel = 0
closeButton.AutoButtonColor = false
closeButton.Font = Enum.Font.GothamBold
closeButton.Text = "—"
closeButton.TextSize = 15
closeButton.TextColor3 = Theme.Muted
closeButton.Parent = header
corner(closeButton, 10)

local floatingButton = Instance.new("TextButton")
floatingButton.AnchorPoint = Vector2.new(1, 1)
floatingButton.Position = UDim2.new(1, -18, 1, -24)
floatingButton.Size = UDim2.fromOffset(60, 60)
floatingButton.BackgroundColor3 = Theme.Card
floatingButton.BorderSizePixel = 0
floatingButton.AutoButtonColor = false
floatingButton.Font = Enum.Font.GothamBold
floatingButton.Text = "CT"
floatingButton.TextSize = 15
floatingButton.TextColor3 = Theme.Amber
floatingButton.Visible = Probe.PanelVisible == false
floatingButton.Parent = gui
corner(floatingButton, 18)
stroke(floatingButton, Theme.Amber, 0.3, 1)

local content = Instance.new("ScrollingFrame")
content.Name = "Content"
content.Position = UDim2.fromOffset(0, 72)
content.Size = UDim2.new(1, 0, 1, -72)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 3
content.ScrollBarImageColor3 = Theme.Border
content.CanvasSize = UDim2.new()
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.ScrollingDirection = Enum.ScrollingDirection.Y
content.Parent = panel

local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 12)
pad.PaddingRight = UDim.new(0, 12)
pad.PaddingTop = UDim.new(0, 14)
pad.PaddingBottom = UDim.new(0, 18)
pad.Parent = content

local contentLayout = Instance.new("UIListLayout")
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Padding = UDim.new(0, 10)
contentLayout.Parent = content

local function sectionLabel(textValue, order)
    local label = Instance.new("TextLabel")
    label.LayoutOrder = order
    label.Size = UDim2.new(1, 0, 0, 21)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.Text = textValue
    label.TextSize = 9
    label.TextColor3 = Theme.Muted
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = content
    return label
end

local targetCard = Instance.new("Frame")
targetCard.LayoutOrder = 1
targetCard.Size = UDim2.new(1, 0, 0, 72)
targetCard.BackgroundColor3 = Theme.Card
targetCard.BorderSizePixel = 0
targetCard.Parent = content
corner(targetCard, 13)
local targetStroke = stroke(targetCard, Theme.Border, 0.35, 1)

local targetDot = Instance.new("Frame")
targetDot.AnchorPoint = Vector2.new(0, 0.5)
targetDot.Position = UDim2.new(0, 13, 0.5, 0)
targetDot.Size = UDim2.fromOffset(10, 10)
targetDot.BackgroundColor3 = Theme.Muted
targetDot.BorderSizePixel = 0
targetDot.Parent = targetCard
corner(targetDot, 10)

local targetTitle = Instance.new("TextLabel")
targetTitle.BackgroundTransparency = 1
targetTitle.Position = UDim2.fromOffset(34, 10)
targetTitle.Size = UDim2.new(1, -48, 0, 24)
targetTitle.Font = Enum.Font.GothamBold
targetTitle.Text = "NO TARGET"
targetTitle.TextColor3 = Theme.Text
targetTitle.TextSize = 13
targetTitle.TextXAlignment = Enum.TextXAlignment.Left
targetTitle.TextTruncate = Enum.TextTruncate.AtEnd
targetTitle.Parent = targetCard

local targetInfo = Instance.new("TextLabel")
targetInfo.BackgroundTransparency = 1
targetInfo.Position = UDim2.fromOffset(34, 36)
targetInfo.Size = UDim2.new(1, -48, 0, 20)
targetInfo.Font = Enum.Font.GothamMedium
targetInfo.Text = "Waiting for opponent"
targetInfo.TextColor3 = Theme.Muted
targetInfo.TextSize = 9
targetInfo.TextXAlignment = Enum.TextXAlignment.Left
targetInfo.Parent = targetCard

sectionLabel("PRIMARY", 2)

local stateContainer = Instance.new("Frame")
stateContainer.LayoutOrder = 3
stateContainer.Size = UDim2.new(1, 0, 0, 58)
stateContainer.BackgroundTransparency = 1
stateContainer.Parent = content

local stateGrid = Instance.new("UIGridLayout")
stateGrid.CellPadding = UDim2.fromOffset(8, 0)
stateGrid.CellSize = UDim2.new(0.5, -4, 1, 0)
stateGrid.FillDirectionMaxCells = 2
stateGrid.Parent = stateContainer

local stateButtons = {}

local function makeToggle(key, label, desc)
    local button = Instance.new("TextButton")
    button.BackgroundColor3 = Theme.Card
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Text = ""
    button.Parent = stateContainer
    corner(button, 12)
    local outline = stroke(button, Theme.Border, 0.4, 1)

    local labelObj = Instance.new("TextLabel")
    labelObj.BackgroundTransparency = 1
    labelObj.Position = UDim2.fromOffset(12, 8)
    labelObj.Size = UDim2.new(1, -64, 0, 20)
    labelObj.Font = Enum.Font.GothamBold
    labelObj.Text = label
    labelObj.TextSize = 10
    labelObj.TextColor3 = Theme.Text
    labelObj.TextXAlignment = Enum.TextXAlignment.Left
    labelObj.Parent = button

    local descObj = Instance.new("TextLabel")
    descObj.BackgroundTransparency = 1
    descObj.Position = UDim2.fromOffset(12, 29)
    descObj.Size = UDim2.new(1, -64, 0, 17)
    descObj.Font = Enum.Font.GothamMedium
    descObj.Text = desc
    descObj.TextSize = 8
    descObj.TextColor3 = Theme.Muted
    descObj.TextXAlignment = Enum.TextXAlignment.Left
    descObj.Parent = button

    local toggle = Instance.new("Frame")
    toggle.AnchorPoint = Vector2.new(1, 0.5)
    toggle.Position = UDim2.new(1, -10, 0.5, 0)
    toggle.Size = UDim2.fromOffset(40, 22)
    toggle.BackgroundColor3 = Theme.Card3
    toggle.BorderSizePixel = 0
    toggle.Parent = button
    corner(toggle, 20)

    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.Position = UDim2.new(0, 3, 0.5, 0)
    knob.Size = UDim2.fromOffset(16, 16)
    knob.BackgroundColor3 = Theme.Muted
    knob.BorderSizePixel = 0
    knob.Parent = toggle
    corner(knob, 20)

    stateButtons[key] = {
        Button = button,
        Stroke = outline,
        Toggle = toggle,
        Knob = knob,
    }

    button.Activated:Connect(function()
        setBoolean(key, not (Probe[key] == true))
    end)
end

makeToggle("PlayerTargeting", "PLAYER LOCK", "Target control")
makeToggle("TrustHooks", "TRUST HOOK", "Defense validation")

sectionLabel("TARGET CONTROL", 4)

local actionContainer = Instance.new("Frame")
actionContainer.LayoutOrder = 5
actionContainer.Size = UDim2.new(1, 0, 0, 102)
actionContainer.BackgroundTransparency = 1
actionContainer.Parent = content

local actionGrid = Instance.new("UIGridLayout")
actionGrid.CellPadding = UDim2.fromOffset(8, 8)
actionGrid.CellSize = UDim2.new(0.5, -4, 0, 47)
actionGrid.FillDirectionMaxCells = 2
actionGrid.Parent = actionContainer

local function makeAction(textValue)
    local button = Instance.new("TextButton")
    button.BackgroundColor3 = Theme.Card
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Font = Enum.Font.GothamSemibold
    button.Text = textValue
    button.TextSize = 10
    button.TextColor3 = Theme.Text
    button.Parent = actionContainer
    corner(button, 11)
    local outline = stroke(button, Theme.Border, 0.38, 1)

    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            tween(button, {BackgroundColor3 = Theme.Card3}, 0.07)
        end
    end)

    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            tween(button, {BackgroundColor3 = Theme.Card}, 0.10)
        end
    end)

    return button, outline
end

local prevButton = makeAction("◀  PREVIOUS")
local modeButton = makeAction("MODE  MANUAL")
local hitButton, hitStroke = makeAction("HIT  ON")
local nextButton = makeAction("NEXT  ▶")

prevButton.Activated:Connect(function() cycleTarget(-1) end)
nextButton.Activated:Connect(function() cycleTarget(1) end)
modeButton.Activated:Connect(toggleMode)
hitButton.Activated:Connect(function()
    setBoolean("CloseHitHook", not (Probe.CloseHitHook == true))
end)

sectionLabel("ENEMY ROSTER", 6)

local rosterList = Instance.new("Frame")
rosterList.LayoutOrder = 7
rosterList.Size = UDim2.new(1, 0, 0, 0)
rosterList.AutomaticSize = Enum.AutomaticSize.Y
rosterList.BackgroundTransparency = 1
rosterList.Parent = content

local rosterLayout = Instance.new("UIListLayout")
rosterLayout.SortOrder = Enum.SortOrder.LayoutOrder
rosterLayout.Padding = UDim.new(0, 7)
rosterLayout.Parent = rosterList

local status = Instance.new("Frame")
status.LayoutOrder = 8
status.Size = UDim2.new(1, 0, 0, 44)
status.BackgroundColor3 = Theme.Card
status.BorderSizePixel = 0
status.Parent = content
corner(status, 11)

local statusText = Instance.new("TextLabel")
statusText.BackgroundTransparency = 1
statusText.Position = UDim2.fromOffset(12, 0)
statusText.Size = UDim2.new(1, -24, 1, 0)
statusText.Font = Enum.Font.Code
statusText.Text = "READY"
statusText.TextSize = 8
statusText.TextColor3 = Theme.Muted
statusText.TextXAlignment = Enum.TextXAlignment.Left
statusText.TextTruncate = Enum.TextTruncate.AtEnd
statusText.Parent = status

local rosterSig = ""
local function signature()
    local out = {}
    for i, target in ipairs(getRoster()) do
        out[i] = tostring(target.Key or target.Model or i)
    end
    out[#out + 1] = "selected=" .. tostring(
        Probe.CurrentTarget and Probe.CurrentTarget.Key or Probe.ManualTargetKey
    )
    return table.concat(out, "|")
end

local function clearRoster()
    for _, child in ipairs(rosterList:GetChildren()) do
        if child ~= rosterLayout then
            child:Destroy()
        end
    end
end

local function renderRoster(force)
    local sig = signature()
    if not force and sig == rosterSig then
        return
    end
    rosterSig = sig
    clearRoster()

    local roster = getRoster()

    if #roster == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, 0, 0, 52)
        empty.BackgroundColor3 = Theme.Card
        empty.BorderSizePixel = 0
        empty.Font = Enum.Font.GothamMedium
        empty.Text = "No enemy players detected"
        empty.TextSize = 9
        empty.TextColor3 = Theme.Muted
        empty.Parent = rosterList
        corner(empty, 11)
        return
    end

    for index, target in ipairs(roster) do
        local row = Instance.new("TextButton")
        row.LayoutOrder = index
        row.Size = UDim2.new(1, 0, 0, 52)
        row.BackgroundColor3 = Theme.Card
        row.BorderSizePixel = 0
        row.AutoButtonColor = false
        row.Text = ""
        row.Parent = rosterList
        corner(row, 11)
        local rowStroke = stroke(row, Theme.Border, 0.45, 1)

        local player = target.Player
        local model = target.Model
        local display = player and player.DisplayName or (model and model.Name) or "Unknown"
        local username = player and player.Name or (model and model.Name) or "unknown"

        local nameLabel = Instance.new("TextLabel")
        nameLabel.BackgroundTransparency = 1
        nameLabel.Position = UDim2.fromOffset(12, 7)
        nameLabel.Size = UDim2.new(1, -100, 0, 20)
        nameLabel.Font = Enum.Font.GothamSemibold
        nameLabel.Text = tostring(display)
        nameLabel.TextSize = 10
        nameLabel.TextColor3 = Theme.Text
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.Parent = row

        local info = Instance.new("TextLabel")
        info.BackgroundTransparency = 1
        info.Position = UDim2.fromOffset(12, 27)
        info.Size = UDim2.new(1, -100, 0, 17)
        info.Font = Enum.Font.GothamMedium
        info.Text = "@" .. tostring(username)
        info.TextSize = 8
        info.TextColor3 = Theme.Muted
        info.TextXAlignment = Enum.TextXAlignment.Left
        info.Parent = row

        local dist = Instance.new("TextLabel")
        dist.AnchorPoint = Vector2.new(1, 0.5)
        dist.Position = UDim2.new(1, -11, 0.5, 0)
        dist.Size = UDim2.fromOffset(72, 26)
        dist.BackgroundColor3 = Theme.Card2
        dist.BorderSizePixel = 0
        dist.Font = Enum.Font.GothamBold
        dist.TextSize = 8
        dist.TextColor3 = Theme.Muted
        dist.Text = string.format("%.1f studs", tonumber(target.Distance) or 0)
        dist.Parent = row
        corner(dist, 8)

        local selected = Probe.CurrentTarget and Probe.CurrentTarget.Key == target.Key
        if selected then
            row.BackgroundColor3 = Theme.Blue2
            rowStroke.Color = Theme.Blue
            rowStroke.Transparency = 0.40
            dist.TextColor3 = Theme.Blue
        end

        row.Activated:Connect(function()
            selectTarget(index)
            renderRoster(true)
        end)
    end
end

local lastBooleanStates = {}

local function refresh()
    local roster = getRoster()
    local count = #roster

    enemyBadge.Text = tostring(count) .. (count == 1 and " ENEMY" or " ENEMIES")

    for key, data in pairs(stateButtons) do
        local enabled = Probe[key] == true

        if lastBooleanStates[key] ~= enabled then
            lastBooleanStates[key] = enabled

            if enabled then
                tween(data.Toggle, {BackgroundColor3 = Theme.Green2})
                tween(data.Knob, {
                    Position = UDim2.new(1, -19, 0.5, 0),
                    BackgroundColor3 = Theme.Green
                })
                data.Stroke.Color = Theme.Green
                data.Stroke.Transparency = 0.55
            else
                tween(data.Toggle, {BackgroundColor3 = Theme.Card3})
                tween(data.Knob, {
                    Position = UDim2.new(0, 3, 0.5, 0),
                    BackgroundColor3 = Theme.Muted
                })
                data.Stroke.Color = Theme.Border
                data.Stroke.Transparency = 0.40
            end
        end
    end

    modeButton.Text = "MODE  " .. tostring(Probe.TargetMode or "MANUAL")

    if Probe.CloseHitHook == true then
        hitButton.Text = "HIT  ON"
        hitButton.TextColor3 = Theme.Green
        hitStroke.Color = Theme.Green
    else
        hitButton.Text = "HIT  OFF"
        hitButton.TextColor3 = Theme.Muted
        hitStroke.Color = Theme.Border
    end

    local target = Probe.CurrentTarget
    if target then
        local name = target.Player and target.Player.DisplayName
            or (target.Model and target.Model.Name)
            or "TARGET"

        targetTitle.Text = tostring(name)
        targetInfo.Text = string.format(
            "%s mode  •  %.1f studs",
            tostring(Probe.TargetMode or "MANUAL"),
            tonumber(target.Distance) or 0
        )

        targetDot.BackgroundColor3 = Theme.Green
        targetStroke.Color = Theme.Green
        targetStroke.Transparency = 0.65
    else
        targetTitle.Text = "NO TARGET"
        targetInfo.Text = "Waiting for opponent"
        targetDot.BackgroundColor3 = Theme.Muted
        targetStroke.Color = Theme.Border
        targetStroke.Transparency = 0.35
    end

    local counts = type(Probe.Counts) == "table" and Probe.Counts or {}
    statusText.Text = string.format(
        "CONFIG • %s     PARRIES • %s     HITS • %s",
        tostring(Probe.ConfigStatus or "n/a"),
        tostring(counts.TrustParries or 0),
        tostring(counts.RedirectedHitboxes or 0)
    )

    renderRoster(false)
end

local function setVisible(value)
    Probe.PanelVisible = value == true
    panel.Visible = Probe.PanelVisible
    floatingButton.Visible = not Probe.PanelVisible
    requestSave()
end

closeButton.Activated:Connect(function()
    setVisible(false)
end)

floatingButton.Activated:Connect(function()
    setVisible(true)
end)

local dragging = false
local dragStart = Vector2.zero
local startOffset = Vector2.zero
local dragInput

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragInput = input
        dragStart = input.Position
        startOffset = Vector2.new(panel.Position.X.Offset, panel.Position.Y.Offset)
    end
end)

trackConnection(UserInputService.InputChanged:Connect(function(input)
    if not dragging then
        return
    end

    local isMouse = input.UserInputType == Enum.UserInputType.MouseMovement
    local isActiveTouch = input.UserInputType == Enum.UserInputType.Touch and input == dragInput
    if not isMouse and not isActiveTouch then
        return
    end

    local cam = workspace.CurrentCamera
    if not cam then
        return
    end

    local delta = input.Position - dragStart
    local viewport = cam.ViewportSize
    local panelSize = panel.AbsoluteSize

    local maxX = math.max(0, (viewport.X - panelSize.X) / 2 - 8)
    local maxY = math.max(0, (viewport.Y - panelSize.Y) / 2 - 8)

    panel.Position = UDim2.new(
        0.5,
        math.clamp(startOffset.X + delta.X, -maxX, maxX),
        0.5,
        math.clamp(startOffset.Y + delta.Y, -maxY, maxY)
    )
end))

trackConnection(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input == dragInput then
        dragging = false
        dragInput = nil
    end
end))

local function responsive()
    local cam = workspace.CurrentCamera
    if not cam then
        return
    end

    local size = cam.ViewportSize
    local availableWidth = math.max(1, size.X - 16)
    local availableHeight = math.max(1, size.Y - 24)
    local minWidth = math.min(300, availableWidth)
    local minHeight = math.min(380, availableHeight)

    constraint.MinSize = Vector2.new(minWidth, minHeight)
    constraint.MaxSize = Vector2.new(
        math.max(minWidth, math.min(540, availableWidth)),
        math.max(minHeight, math.min(630, availableHeight))
    )

    if size.X < 650 then
        panel.Size = UDim2.new(0.94, 0, 0.82, 0)
        actionGrid.FillDirectionMaxCells = 2
        actionGrid.CellSize = UDim2.new(0.5, -4, 0, 47)
        actionContainer.Size = UDim2.new(1, 0, 0, 102)
    else
        panel.Size = UDim2.fromOffset(520, math.min(610, size.Y - 70))
        actionGrid.FillDirectionMaxCells = 4
        actionGrid.CellSize = UDim2.new(0.25, -6, 0, 47)
        actionContainer.Size = UDim2.new(1, 0, 0, 47)
    end

    if size.X < 385 then
        subtitle.Visible = false
        title.Position = UDim2.fromOffset(15, 0)
        title.Size = UDim2.new(1, -165, 1, 0)
        title.TextSize = 14
        enemyBadge.Size = UDim2.fromOffset(70, 29)
        enemyBadge.TextSize = 8
    else
        subtitle.Visible = true
        title.Position = UDim2.fromOffset(16, 10)
        title.Size = UDim2.new(1, -180, 0, 27)
        title.TextSize = 17
        enemyBadge.Size = UDim2.fromOffset(82, 31)
        enemyBadge.TextSize = 9
    end
end

responsive()

if workspace.CurrentCamera then
    trackConnection(
        workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(responsive)
    )
end

task.spawn(function()
    while gui.Parent and Probe.Alive ~= false do
        refresh()
        task.wait(0.25)
    end
end)

refresh()

print("[Combat UI] Ultra UI loaded.")
