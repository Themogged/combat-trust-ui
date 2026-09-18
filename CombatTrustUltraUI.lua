-- Combat Trust Ultra UI V2 Refactor Pro
-- Frontend-only controller for getgenv().CombatTrustProbe. No combat hooks live here.

-- SERVICES / REFERENCES
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

local Environment = getgenv and getgenv() or _G
local Probe = Environment.CombatTrustProbe
if type(Probe) ~= "table" then
    warn("[Combat Trust UI] CombatTrustProbe no existe. Ejecuta core.lua primero.")
    return
end
if Environment.CombatTrustUltraUI and type(Environment.CombatTrustUltraUI.Destroy) == "function" then
    pcall(function() Environment.CombatTrustUltraUI:Destroy() end)
end

-- THEME / CONSTANTS
local Theme = {
    Background = Color3.fromRGB(8, 10, 16), Surface = Color3.fromRGB(15, 18, 27),
    Surface2 = Color3.fromRGB(22, 27, 39), Hover = Color3.fromRGB(31, 37, 52),
    Border = Color3.fromRGB(55, 64, 84), Text = Color3.fromRGB(244, 247, 252),
    Muted = Color3.fromRGB(142, 153, 177), Accent = Color3.fromRGB(91, 151, 255),
    AccentSoft = Color3.fromRGB(32, 53, 91), Success = Color3.fromRGB(67, 224, 139),
    SuccessSoft = Color3.fromRGB(24, 72, 52), Warning = Color3.fromRGB(255, 187, 75),
    Danger = Color3.fromRGB(239, 88, 104), Selected = Color3.fromRGB(37, 61, 103),
}
local Constants = {
    ConfigFolder = "DefenseTrustProbe", ConfigPath = "DefenseTrustProbe/ui_config.json",
    RefreshInterval = 0.25, SaveDebounce = 0.35, DragThreshold = 8, EdgePadding = 10,
    AnimationFast = 0.15, AnimationNormal = 0.20, MaxNotifications = 3,
    MobileWidth = 500, TabletWidth = 900, Version = 2,
}
local Defaults = {
    Version = 2, Scale = 1, Transparency = 0, Animations = true, CompactMode = false,
    SnapToEdge = true, ShowDistance = true, ShowHealth = true, ShowUsername = true,
    ShowStats = true, MinimizedStyle = "COMPACT", PanelPosition = { X = 0.5, Y = 0.5 },
    BubblePosition = { X = 0.92, Y = 0.72 }, LastTab = "CONTROL", SortMode = "DISTANCE",
}

-- CONFIG
local function copyDefaults()
    local copy = {}
    for key, value in pairs(Defaults) do
        copy[key] = type(value) == "table" and { X = value.X, Y = value.Y } or value
    end
    return copy
end
local function finite(value) return type(value) == "number" and value == value and math.abs(value) < math.huge end
local function position(value, fallback)
    if type(value) ~= "table" or not finite(value.X) or not finite(value.Y) then return { X = fallback.X, Y = fallback.Y } end
    return { X = math.clamp(value.X, 0, 1), Y = math.clamp(value.Y, 0, 1) }
end
local function sanitize(source)
    source = type(source) == "table" and source or {}
    local result = copyDefaults()
    local allowedScale = { [0.8] = true, [0.9] = true, [1] = true, [1.1] = true, [1.2] = true }
    if allowedScale[source.Scale] then result.Scale = source.Scale end
    if finite(source.Transparency) then result.Transparency = math.clamp(source.Transparency, 0, 0.35) end
    for _, key in ipairs({ "Animations", "CompactMode", "SnapToEdge", "ShowDistance", "ShowHealth", "ShowUsername", "ShowStats" }) do
        if type(source[key]) == "boolean" then result[key] = source[key] end
    end
    if source.MinimizedStyle == "COMPACT" or source.MinimizedStyle == "INFO" then result.MinimizedStyle = source.MinimizedStyle end
    if source.LastTab == "CONTROL" or source.LastTab == "PLAYERS" or source.LastTab == "STATS" or source.LastTab == "SETTINGS" then result.LastTab = source.LastTab end
    if source.SortMode == "DISTANCE" or source.SortMode == "NAME" or source.SortMode == "HEALTH" then result.SortMode = source.SortMode end
    result.PanelPosition = position(source.PanelPosition, Defaults.PanelPosition)
    result.BubblePosition = position(source.BubblePosition, Defaults.BubblePosition)
    return result
end
local ConfigAvailable = type(readfile) == "function" and type(writefile) == "function"
local Settings = copyDefaults()
if ConfigAvailable then
    pcall(function()
        local shouldRead = type(isfile) ~= "function" or isfile(Constants.ConfigPath)
        if shouldRead then Settings = sanitize(HttpService:JSONDecode(readfile(Constants.ConfigPath))) end
    end)
end

-- CONTROLLER / CLEANUP
local Controller = { Alive = true, Generation = 1, Connections = {}, Tweens = {}, Components = {}, RosterCards = {}, Notifications = {} }
local VisualState = { ActiveTab = Settings.LastTab, Minimized = Probe.PanelVisible == false, SearchText = "", UnloadDeadline = 0 }
Environment.CombatTrustUltraUI = Controller
Probe.UI = Controller

function Controller:Connect(scope, signal, callback)
    local connection = signal:Connect(callback)
    self.Connections[scope] = self.Connections[scope] or {}
    table.insert(self.Connections[scope], connection)
    return connection
end
function Controller:DisconnectScope(scope)
    for _, connection in ipairs(self.Connections[scope] or {}) do pcall(function() connection:Disconnect() end) end
    self.Connections[scope] = nil
end
function Controller:Tween(object, properties, duration)
    local previous = self.Tweens[object]
    if previous then pcall(function() previous:Cancel() end) end
    if not Settings.Animations then
        for key, value in pairs(properties) do object[key] = value end
        return nil
    end
    local tween = TweenService:Create(object, TweenInfo.new(duration or Constants.AnimationFast, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), properties)
    self.Tweens[object] = tween
    tween:Play()
    return tween
end
function Controller:SaveSettings()
    if not self.Alive or not ConfigAvailable then return end
    pcall(function()
        if type(makefolder) == "function" and (type(isfolder) ~= "function" or not isfolder(Constants.ConfigFolder)) then
            pcall(makefolder, Constants.ConfigFolder)
        end
        writefile(Constants.ConfigPath, HttpService:JSONEncode(Settings))
    end)
end
function Controller:ScheduleSave()
    self.SaveToken = (self.SaveToken or 0) + 1
    local token, generation = self.SaveToken, self.Generation
    task.delay(Constants.SaveDebounce, function()
        if self.Alive and self.Generation == generation and self.SaveToken == token then self:SaveSettings() end
    end)
end

-- HELPERS / COMPONENT FACTORY
local function create(className, properties, parent)
    local object = Instance.new(className)
    for key, value in pairs(properties or {}) do object[key] = value end
    object.Parent = parent
    return object
end
local function corner(parent, radius) return create("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, parent) end
local function stroke(parent, color) return create("UIStroke", { Color = color or Theme.Border, Thickness = 1, Transparency = 0.15 }, parent) end
local function padding(parent, amount) return create("UIPadding", { PaddingTop = UDim.new(0, amount), PaddingBottom = UDim.new(0, amount), PaddingLeft = UDim.new(0, amount), PaddingRight = UDim.new(0, amount) }, parent) end
local Surfaces = setmetatable({}, { __mode = "k" })
local function surface(object, base) Surfaces[object] = base or 0; return object end
local function label(parent, text, size, color, font)
    return create("TextLabel", { BackgroundTransparency = 1, Text = text or "", TextColor3 = color or Theme.Text,
        Font = font or Enum.Font.Gotham, TextSize = size or 13, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd }, parent)
end
local function button(parent, text)
    local object = surface(create("TextButton", { AutoButtonColor = false, BackgroundColor3 = Theme.Surface2,
        BackgroundTransparency = 0, Text = text, TextColor3 = Theme.Text, Font = Enum.Font.GothamSemibold,
        TextSize = 12, Size = UDim2.new(0, 96, 0, 44) }, parent))
    corner(object, 10); stroke(object)
    return object
end
local function card(parent, height)
    local object = surface(create("Frame", { BackgroundColor3 = Theme.Surface, BackgroundTransparency = 0,
        Size = UDim2.new(1, 0, 0, height or 76) }, parent))
    corner(object, 12); stroke(object); padding(object, 12)
    return object
end
local function page(parent)
    local object = create("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Border, Visible = false }, parent)
    padding(object, 12)
    create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, object)
    return object
end
local function section(parent, text)
    local object = label(parent, text, 11, Theme.Muted, Enum.Font.GothamBold)
    object.Size = UDim2.new(1, 0, 0, 18)
    return object
end
local function targetData(target)
    if type(target) ~= "table" then return nil end
    local player = target.Player
    local model = target.Model or (player and player.Character)
    local humanoid = model and model:FindFirstChildOfClass("Humanoid")
    local distance = tonumber(target.Distance) or tonumber(target.DistanceStuds)
    return {
        Key = target.Key, DisplayName = (player and player.DisplayName) or target.DisplayName or target.Name or "Unknown",
        Username = (player and player.Name) or target.Username or target.Name or "Unknown", Distance = distance,
        Health = humanoid and humanoid.Health or tonumber(target.Health), MaxHealth = humanoid and humanoid.MaxHealth or tonumber(target.MaxHealth),
    }
end
local function action(name, ...)
    local actions, args = Probe.Actions, table.pack(...)
    if type(actions) == "table" and type(actions[name]) == "function" then
        local ok, result = pcall(function() return actions[name](table.unpack(args, 1, args.n)) end)
        if ok then return true, result end
        warn("[Combat Trust UI] Acción " .. name .. " falló: " .. tostring(result))
    end
    return false
end
local function setBoolean(name, value)
    if not action("SetBoolean", name, value) then Probe[name] = value end
end
local function viewport()
    local camera = workspace.CurrentCamera
    return camera and camera.ViewportSize or Vector2.new(800, 600)
end
local function normalizedFrom(object)
    local view, center = viewport(), object.AbsolutePosition + object.AbsoluteSize / 2
    return { X = math.clamp(center.X / view.X, 0, 1), Y = math.clamp(center.Y / view.Y, 0, 1) }
end
local function clampObject(object, normalized)
    local view, size = viewport(), object.AbsoluteSize
    local x = math.clamp(normalized.X * view.X - size.X / 2, Constants.EdgePadding, math.max(Constants.EdgePadding, view.X - size.X - Constants.EdgePadding))
    local y = math.clamp(normalized.Y * view.Y - size.Y / 2, Constants.EdgePadding, math.max(Constants.EdgePadding, view.Y - size.Y - Constants.EdgePadding))
    object.Position = UDim2.fromOffset(x, y)
end

-- ROOT / WINDOW / HEADER
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local old = PlayerGui:FindFirstChild("CombatTrustUltraUI")
if old then old:Destroy() end
local Gui = create("ScreenGui", { Name = "CombatTrustUltraUI", ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, PlayerGui)
local Panel = surface(create("Frame", { Name = "Panel", BackgroundColor3 = Theme.Background, Size = UDim2.fromOffset(430, 570), ClipsDescendants = true }, Gui))
corner(Panel, 14); stroke(Panel, Theme.Border)
local Scale = create("UIScale", { Scale = Settings.Scale }, Panel)
create("UISizeConstraint", { MinSize = Vector2.new(300, 390), MaxSize = Vector2.new(500, 650) }, Panel)
local Header = surface(create("Frame", { BackgroundColor3 = Theme.Surface, Size = UDim2.new(1, 0, 0, 66) }, Panel))
local Title = label(Header, "COMBAT TRUST", 16, Theme.Text, Enum.Font.GothamBold); Title.Position = UDim2.fromOffset(16, 11); Title.Size = UDim2.new(1, -196, 0, 21)
local Subtitle = label(Header, "ULTRA CONTROL  •  V2", 10, Theme.Muted, Enum.Font.GothamSemibold); Subtitle.Position = UDim2.fromOffset(16, 34); Subtitle.Size = UDim2.new(1, -196, 0, 18)
local Status = label(Header, "● READY", 11, Theme.Success, Enum.Font.GothamBold); Status.Position = UDim2.new(1, -190, 0, 23); Status.Size = UDim2.fromOffset(68, 20); Status.TextXAlignment = Enum.TextXAlignment.Right
local MinimizeButton = button(Header, "MIN"); MinimizeButton.Position = UDim2.new(1, -116, 0, 11); MinimizeButton.Size = UDim2.fromOffset(54, 44); MinimizeButton.BackgroundColor3 = Theme.AccentSoft; MinimizeButton.TextColor3 = Theme.Accent
local CloseButton = button(Header, "X"); CloseButton.Position = UDim2.new(1, -56, 0, 11); CloseButton.Size = UDim2.fromOffset(42, 44)

-- NAVIGATION
local Nav = surface(create("Frame", { BackgroundColor3 = Theme.Surface, Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 50) }, Panel))
padding(Nav, 6)
create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 4) }, Nav)
local Body = create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 116), Size = UDim2.new(1, 0, 1, -116), ClipsDescendants = true }, Panel)
local Pages, TabButtons = {}, {}
for _, tabName in ipairs({ "CONTROL", "PLAYERS", "STATS", "SETTINGS" }) do
    local tab = button(Nav, tabName); tab.Size = UDim2.new(0.25, -5, 1, 0); TabButtons[tabName] = tab
    Pages[tabName] = page(Body)
    Controller:Connect("Navigation", tab.Activated, function() Controller:SetTab(tabName) end)
end

-- CONTROL TAB
local Control = Pages.CONTROL
section(Control, "CURRENT TARGET")
local TargetCard = card(Control, 124)
local TargetName = label(TargetCard, "NO TARGET", 18, Theme.Text, Enum.Font.GothamBold); TargetName.Size = UDim2.new(1, -100, 0, 25)
local TargetUser = label(TargetCard, "Waiting for opponent", 12, Theme.Muted); TargetUser.Position = UDim2.fromOffset(0, 28); TargetUser.Size = UDim2.new(1, -100, 0, 18)
local ModeChip = label(TargetCard, "AUTO MODE", 11, Theme.Accent, Enum.Font.GothamBold); ModeChip.Position = UDim2.new(1, -100, 0, 3); ModeChip.Size = UDim2.fromOffset(100, 18); ModeChip.TextXAlignment = Enum.TextXAlignment.Right
local TargetDistance = label(TargetCard, "", 11, Theme.Muted, Enum.Font.Code); TargetDistance.Position = UDim2.new(1, -120, 0, 31); TargetDistance.Size = UDim2.fromOffset(120, 18); TargetDistance.TextXAlignment = Enum.TextXAlignment.Right
local HealthText = label(TargetCard, "", 11, Theme.Muted, Enum.Font.Code); HealthText.Position = UDim2.fromOffset(0, 66); HealthText.Size = UDim2.new(1, 0, 0, 16)
local HealthBack = surface(create("Frame", { BackgroundColor3 = Theme.Hover, Position = UDim2.fromOffset(0, 91), Size = UDim2.new(1, 0, 0, 8) }, TargetCard)); corner(HealthBack, 4)
local HealthFill = create("Frame", { BackgroundColor3 = Theme.Success, Size = UDim2.fromScale(0, 1) }, HealthBack); corner(HealthFill, 4)
section(Control, "CORE CONTROLS")
local ToggleContainer = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 150) }, Control)
create("UIListLayout", { Padding = UDim.new(0, 8) }, ToggleContainer)
local ToggleRows = {}
local function addToggle(key, titleText)
    local row = card(ToggleContainer, 44)
    local text = label(row, titleText, 12, Theme.Text, Enum.Font.GothamSemibold); text.Size = UDim2.new(1, -80, 1, 0)
    local control = button(row, "OFF"); control.Position = UDim2.new(1, -66, 0, 0); control.Size = UDim2.fromOffset(66, 24)
    ToggleRows[key] = control
    Controller:Connect("Controls", control.Activated, function() setBoolean(key, Probe[key] ~= true); Controller:Refresh() end)
end
addToggle("PlayerTargeting", "PLAYER LOCK")
addToggle("TrustHooks", "TRUST HOOK")
addToggle("CloseHitHook", "HIT HOOK")
local ActionBar = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48) }, Control)
create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center }, ActionBar)
local Previous = button(ActionBar, "PREV"); Previous.Size = UDim2.new(0.29, 0, 1, 0)
local Mode = button(ActionBar, "MODE"); Mode.Size = UDim2.new(0.36, 0, 1, 0)
local Next = button(ActionBar, "NEXT"); Next.Size = UDim2.new(0.29, 0, 1, 0)
Controller:Connect("Controls", Previous.Activated, function() action("CycleTarget", -1) end)
Controller:Connect("Controls", Next.Activated, function() action("CycleTarget", 1) end)
Controller:Connect("Controls", Mode.Activated, function() action("ToggleTargetMode") end)

-- PLAYERS TAB / ROSTER CONTROLLER
local PlayersPage = Pages.PLAYERS
section(PlayersPage, "PLAYER ROSTER")
local Search = surface(create("TextBox", { BackgroundColor3 = Theme.Surface, PlaceholderText = "SEARCH PLAYER", PlaceholderColor3 = Theme.Muted,
    Text = "", TextColor3 = Theme.Text, ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 13,
    Size = UDim2.new(1, 0, 0, 44), TextXAlignment = Enum.TextXAlignment.Left }, PlayersPage)); corner(Search, 10); stroke(Search); padding(Search, 12)
local SortBar = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42) }, PlayersPage)
create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }, SortBar)
local SortButtons = {}
for _, sortName in ipairs({ "DISTANCE", "NAME", "HEALTH" }) do
    local control = button(SortBar, sortName); control.Size = UDim2.new(1 / 3, -4, 1, 0); SortButtons[sortName] = control
    Controller:Connect("RosterStatic", control.Activated, function() Settings.SortMode = sortName; Controller.RosterSignature = nil; Controller:ScheduleSave(); Controller:RefreshRoster() end)
end
local RosterHost = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, PlayersPage)
create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, RosterHost)
Controller:Connect("RosterStatic", Search:GetPropertyChangedSignal("Text"), function() VisualState.SearchText = string.lower(Search.Text); Controller.RosterSignature = nil; Controller:RefreshRoster() end)

function Controller:RefreshRoster()
    if not self.Alive then return end
    local entries = {}
    for index, raw in ipairs(type(Probe.Roster) == "table" and Probe.Roster or {}) do
        local data = targetData(raw)
        if data and (VisualState.SearchText == "" or string.find(string.lower(data.DisplayName .. " " .. data.Username), VisualState.SearchText, 1, true)) then
            data.Raw, data.CoreIndex = raw, index; table.insert(entries, data)
        end
    end
    table.sort(entries, function(a, b)
        if Settings.SortMode == "NAME" then return string.lower(a.DisplayName) < string.lower(b.DisplayName) end
        if Settings.SortMode == "HEALTH" then return (a.Health or -1) > (b.Health or -1) end
        return (a.Distance or math.huge) < (b.Distance or math.huge)
    end)
    local parts = { Settings.SortMode, VisualState.SearchText }
    for _, item in ipairs(entries) do table.insert(parts, tostring(item.Key or item.Username) .. ":" .. item.CoreIndex) end
    local signature = table.concat(parts, "|")
    if signature ~= self.RosterSignature then
        self.RosterSignature = signature; self:DisconnectScope("RosterCards")
        for _, child in ipairs(RosterHost:GetChildren()) do if not child:IsA("UIListLayout") then child:Destroy() end end
        table.clear(self.RosterCards)
        if #entries == 0 then
            local empty = card(RosterHost, 72); local titleText = #(type(Probe.Roster) == "table" and Probe.Roster or {}) == 0 and "NO PLAYERS" or "NO MATCHES"
            local text = label(empty, titleText .. "\nWaiting for opponent", 12, Theme.Muted, Enum.Font.GothamSemibold); text.Size = UDim2.fromScale(1, 1); text.TextWrapped = true
        end
        for _, item in ipairs(entries) do
            local row = card(RosterHost, 74); row.LayoutOrder = item.CoreIndex
            local name = label(row, item.DisplayName, 14, Theme.Text, Enum.Font.GothamSemibold); name.Size = UDim2.new(1, -110, 0, 22)
            local username = label(row, "@" .. item.Username, 11, Theme.Muted); username.Position = UDim2.fromOffset(0, 23); username.Size = UDim2.new(1, -110, 0, 18)
            local metrics = label(row, "", 11, Theme.Muted, Enum.Font.Code); metrics.Position = UDim2.new(1, -110, 0, 14); metrics.Size = UDim2.fromOffset(110, 26); metrics.TextXAlignment = Enum.TextXAlignment.Right
            local hit = create("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 3 }, row)
            self:Connect("RosterCards", hit.Activated, function() action("SelectRosterIndex", item.CoreIndex); self:Refresh() end)
            self.RosterCards[item.CoreIndex] = { Root = row, Metrics = metrics, Username = username }
        end
    end
    for _, item in ipairs(entries) do
        local row = self.RosterCards[item.CoreIndex]
        if row then
            local selected = Probe.CurrentTarget == item.Raw or (Probe.CurrentTarget and Probe.CurrentTarget.Key == item.Key)
            row.Root.BackgroundColor3 = selected and Theme.Selected or Theme.Surface
            row.Username.Visible = Settings.ShowUsername
            local info = {}
            if Settings.ShowDistance and item.Distance then table.insert(info, string.format("%.1f STUDS", item.Distance)) end
            if Settings.ShowHealth and item.Health and item.MaxHealth and item.MaxHealth > 0 then table.insert(info, string.format("HP %.0f%%", item.Health / item.MaxHealth * 100)) end
            row.Metrics.Text = table.concat(info, "\n")
        end
    end
    for name, control in pairs(SortButtons) do control.BackgroundColor3 = name == Settings.SortMode and Theme.AccentSoft or Theme.Surface2 end
end

-- STATS TAB
local StatsPage = Pages.STATS
section(StatsPage, "LIVE STATS")
local StatsGrid = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 188) }, StatsPage)
create("UIGridLayout", { CellSize = UDim2.new(0.5, -5, 0, 88), CellPadding = UDim2.fromOffset(10, 10) }, StatsGrid)
local StatLabels = {}
for _, statName in ipairs({ "ENEMIES", "MODE", "PARRIES", "REDIRECTS" }) do
    local root = card(StatsGrid, 88); local titleLabel = label(root, statName, 10, Theme.Muted, Enum.Font.GothamBold); titleLabel.Size = UDim2.new(1, 0, 0, 18)
    local value = label(root, "0", 22, Theme.Text, Enum.Font.GothamBold); value.Position = UDim2.fromOffset(0, 25); value.Size = UDim2.new(1, 0, 0, 31); StatLabels[statName] = value
end
local StatusCard = card(StatsPage, 56)
local ConfigText = label(StatusCard, "CONFIG: UNKNOWN", 11, Theme.Muted, Enum.Font.Code); ConfigText.Size = UDim2.new(0.65, 0, 1, 0)
local UptimeText = label(StatusCard, "UI 00:00", 11, Theme.Muted, Enum.Font.Code); UptimeText.Position = UDim2.new(0.65, 0, 0, 0); UptimeText.Size = UDim2.new(0.35, 0, 1, 0); UptimeText.TextXAlignment = Enum.TextXAlignment.Right
section(StatsPage, "RECENT ACTIVITY")
local ActivityHost = create("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) }, StatsPage)
create("UIListLayout", { Padding = UDim.new(0, 6) }, ActivityHost)
local StartedAt = os.clock()
function Controller:RefreshActivity()
    local timeline = type(Probe.Record) == "table" and Probe.Record.Timeline or nil
    local count = type(timeline) == "table" and #timeline or 0
    local last = count > 0 and tostring(timeline[count]) or ""
    local signature = tostring(count) .. ":" .. last
    if signature == self.ActivitySignature then return end
    self.ActivitySignature = signature
    for _, child in ipairs(ActivityHost:GetChildren()) do if not child:IsA("UIListLayout") then child:Destroy() end end
    if count == 0 then local empty = label(ActivityHost, "NO RECENT ACTIVITY", 11, Theme.Muted); empty.Size = UDim2.new(1, 0, 0, 32); return end
    for index = math.max(1, count - 19), count do
        local event = timeline[index]
        local text = type(event) == "table" and (event.Text or event.Event or event.Type) or tostring(event)
        if not text then
            local ok, encoded = pcall(function() return HttpService:JSONEncode(event) end)
            text = ok and encoded or "EVENT"
        end
        text = tostring(text)
        local row = surface(create("Frame", { BackgroundColor3 = Theme.Surface, Size = UDim2.new(1, 0, 0, 36) }, ActivityHost)); corner(row, 8); padding(row, 8)
        local item = label(row, text, 11, Theme.Muted, Enum.Font.Code); item.Size = UDim2.fromScale(1, 1)
    end
end

-- SETTINGS TAB
local SettingsPage = Pages.SETTINGS
section(SettingsPage, "VISUAL SETTINGS")
local SettingRefreshers = {}
local function segmented(parent, titleText, options, getter, setter)
    local root = card(parent, 84); local titleLabel = label(root, titleText, 11, Theme.Muted, Enum.Font.GothamBold); titleLabel.Size = UDim2.new(1, 0, 0, 18)
    local bar = create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 27), Size = UDim2.new(1, 0, 0, 34) }, root)
    create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5) }, bar)
    local controls = {}
    for _, option in ipairs(options) do
        local control = button(bar, option.Label); control.Size = UDim2.new(1 / #options, -4, 1, 0); controls[option.Value] = control
        Controller:Connect("Settings", control.Activated, function() setter(option.Value); Controller:ApplySettings(); Controller:ScheduleSave() end)
    end
    table.insert(SettingRefreshers, function() for value, control in pairs(controls) do control.BackgroundColor3 = getter() == value and Theme.AccentSoft or Theme.Surface2 end end)
end
segmented(SettingsPage, "UI SCALE", { {Label="80%",Value=0.8},{Label="90%",Value=0.9},{Label="100%",Value=1},{Label="110%",Value=1.1},{Label="120%",Value=1.2} }, function() return Settings.Scale end, function(v) Settings.Scale=v end)
segmented(SettingsPage, "TRANSPARENCY", { {Label="0%",Value=0},{Label="10%",Value=0.1},{Label="20%",Value=0.2},{Label="35%",Value=0.35} }, function() return Settings.Transparency end, function(v) Settings.Transparency=v end)
local SettingToggles = {}
local function settingToggle(key, titleText)
    local root = card(SettingsPage, 48); local titleLabel = label(root, titleText, 12, Theme.Text, Enum.Font.GothamSemibold); titleLabel.Size = UDim2.new(1, -75, 1, 0)
    local control = button(root, "OFF"); control.Position = UDim2.new(1, -66, 0, 0); control.Size = UDim2.fromOffset(66, 24); SettingToggles[key] = control
    Controller:Connect("Settings", control.Activated, function() Settings[key] = not Settings[key]; Controller:ApplySettings(); Controller:ScheduleSave() end)
end
for _, item in ipairs({ {"Animations","ANIMATIONS"},{"CompactMode","COMPACT MODE"},{"SnapToEdge","SNAP TO EDGE"},{"ShowDistance","SHOW DISTANCE"},{"ShowHealth","SHOW HEALTH"},{"ShowUsername","SHOW USERNAME"},{"ShowStats","SHOW STATS"} }) do settingToggle(item[1], item[2]) end
segmented(SettingsPage, "MINIMIZED STYLE", { {Label="COMPACT",Value="COMPACT"},{Label="INFO",Value="INFO"} }, function() return Settings.MinimizedStyle end, function(v) Settings.MinimizedStyle=v end)
local Reset = button(SettingsPage, "RESET UI SETTINGS"); Reset.Size = UDim2.new(1, 0, 0, 46)
local Unload = button(SettingsPage, "UNLOAD CORE"); Unload.Size = UDim2.new(1, 0, 0, 46); Unload.BackgroundColor3 = Theme.Danger
Controller:Connect("Settings", Reset.Activated, function()
    Settings = copyDefaults()
    VisualState.ActiveTab = Settings.LastTab; Controller:ApplySettings(); Controller:SetTab("CONTROL"); Controller:ScheduleSave(); Controller:Notify("UI SETTINGS RESET", Theme.Accent)
end)
Controller:Connect("Settings", Unload.Activated, function()
    if os.clock() > VisualState.UnloadDeadline then
        VisualState.UnloadDeadline = os.clock() + 3; Unload.Text = "CONFIRM?"; Controller:Notify("Tap again to unload core", Theme.Warning)
        local generation = Controller.Generation; task.delay(3, function() if Controller.Alive and Controller.Generation == generation then Unload.Text = "UNLOAD CORE" end end)
    elseif type(Probe.Unload) == "function" then Probe:Unload() end
end)

-- BUBBLE / NOTIFICATIONS
local Bubble = surface(create("TextButton", { Name = "Bubble", AutoButtonColor = false, BackgroundColor3 = Theme.Surface2,
    Text = "CT", TextColor3 = Theme.Text, Font = Enum.Font.GothamBold, TextSize = 13, Size = UDim2.fromOffset(54, 48), Visible = false }, Gui)); corner(Bubble, 14); stroke(Bubble, Theme.Accent)
local NotificationHost = create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(280, 180) }, Gui)
create("UIListLayout", { Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Top }, NotificationHost)
function Controller:Notify(text, color)
    if not self.Alive then return end
    while #self.Notifications >= Constants.MaxNotifications do local oldNotice = table.remove(self.Notifications, 1); if oldNotice then oldNotice:Destroy() end end
    local notice = surface(create("Frame", { BackgroundColor3 = Theme.Surface2, Size = UDim2.new(1, 0, 0, 46) }, NotificationHost)); corner(notice, 10); stroke(notice, color or Theme.Accent); padding(notice, 10)
    local message = label(notice, text, 12, Theme.Text, Enum.Font.GothamSemibold); message.Size = UDim2.fromScale(1, 1); table.insert(self.Notifications, notice)
    local generation = self.Generation; task.delay(2.6, function()
        if self.Alive and self.Generation == generation and notice.Parent then
            for index, item in ipairs(self.Notifications) do if item == notice then table.remove(self.Notifications, index); break end end
            notice:Destroy()
        end
    end)
end

-- PUBLIC UI API / RESPONSIVE
function Controller:SetTab(name)
    if not Pages[name] then return end
    pcall(function() Search:ReleaseFocus() end)
    VisualState.ActiveTab, Settings.LastTab = name, name
    for tabName, tabPage in pairs(Pages) do
        tabPage.Visible = tabName == name
        TabButtons[tabName].BackgroundColor3 = tabName == name and Theme.AccentSoft or Theme.Surface2
    end
    local activePage = Pages[name]
    if Settings.Animations then
        activePage.Position = UDim2.fromOffset(7, 0)
        self:Tween(activePage, { Position = UDim2.fromOffset(0, 0) }, Constants.AnimationFast)
    else
        activePage.Position = UDim2.fromOffset(0, 0)
    end
    self:ScheduleSave()
end
function Controller:ApplySettings()
    for object, base in pairs(Surfaces) do if object.Parent then object.BackgroundTransparency = math.clamp(base + Settings.Transparency, 0, 0.75) end end
    for key, control in pairs(SettingToggles) do
        local enabled = Settings[key] == true; control.Text = enabled and "ON" or "OFF"; control.BackgroundColor3 = enabled and Theme.SuccessSoft or Theme.Surface2; control.TextColor3 = enabled and Theme.Success or Theme.Muted
    end
    for _, refresh in ipairs(SettingRefreshers) do refresh() end
    Bubble.Size = Settings.MinimizedStyle == "INFO" and UDim2.fromOffset(112, 48) or UDim2.fromOffset(54, 48)
    self:ApplyResponsiveLayout(); self:Refresh()
end
function Controller:ApplyResponsiveLayout()
    if not self.Alive then return end
    local view = viewport()
    local width = view.X < Constants.MobileWidth and math.min(360, view.X - 20) or (view.X < Constants.TabletWidth and math.min(410, view.X - 24) or 430)
    local height = math.min(view.Y - 24, view.X < Constants.MobileWidth and 540 or 570)
    Panel.Size = UDim2.fromOffset(math.max(300, width), math.max(390, height))
    local fitScale = math.min((view.X - Constants.EdgePadding * 2) / math.max(1, Panel.Size.X.Offset), (view.Y - Constants.EdgePadding * 2) / math.max(1, Panel.Size.Y.Offset))
    Scale.Scale = math.max(0.65, math.min(Settings.Scale, fitScale))
    local spacing = Settings.CompactMode and 7 or 10
    for _, tabPage in pairs(Pages) do
        local layout = tabPage:FindFirstChildOfClass("UIListLayout"); if layout then layout.Padding = UDim.new(0, spacing) end
    end
    ToggleContainer.Size = UDim2.new(1, 0, 0, Settings.CompactMode and 138 or 150)
    clampObject(Panel, Settings.PanelPosition); clampObject(Bubble, Settings.BubblePosition)
end
local function setPanelVisible(value)
    if not action("SetBoolean", "PanelVisible", value) then Probe.PanelVisible = value end
end
function Controller:Minimize()
    if not self.Alive or VisualState.Minimized then return end
    VisualState.Minimized = true; setPanelVisible(false)
    Panel.Visible = false; Bubble.Visible = true
    clampObject(Bubble, Settings.BubblePosition)
    Bubble.BackgroundTransparency = 1
    self:Tween(Bubble, { BackgroundTransparency = math.clamp(Settings.Transparency, 0, 0.75) }, Constants.AnimationFast)
    self:Refresh()
end
function Controller:Restore()
    if not self.Alive or not VisualState.Minimized then return end
    VisualState.Minimized = false; setPanelVisible(true)
    Bubble.Visible = false; Panel.Visible = true; self:ApplyResponsiveLayout()
    if Settings.Animations then
        local targetScale = Scale.Scale
        Scale.Scale = targetScale * 0.96
        self:Tween(Scale, { Scale = targetScale }, Constants.AnimationFast)
    end
end
function Controller:Toggle() if VisualState.Minimized then self:Restore() else self:Minimize() end end

-- DRAG CONTROLLER (one connection set; direct movement, tween only on snap)
local function bindDrag(scope, object, onTap, onFinish, snap)
    local active, moved, startInput, startPosition
    Controller:Connect(scope, object.InputBegan, function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        active, moved, startInput, startPosition = true, false, input.Position, object.Position
    end)
    Controller:Connect(scope, UIS.InputChanged, function(input)
        if not active or (input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseMovement) then return end
        local delta = input.Position - startInput
        if delta.Magnitude >= Constants.DragThreshold then moved = true end
        if moved then object.Position = UDim2.fromOffset(startPosition.X.Offset + delta.X, startPosition.Y.Offset + delta.Y); clampObject(object, normalizedFrom(object)) end
    end)
    Controller:Connect(scope, UIS.InputEnded, function(input)
        if not active or (input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1) then return end
        active = false
        if not moved and onTap then onTap() end
        if moved and snap and Settings.SnapToEdge then
            local view, size, current = viewport(), object.AbsoluteSize, normalizedFrom(object)
            local x = current.X < 0.5 and Constants.EdgePadding or view.X - size.X - Constants.EdgePadding
            local y = math.clamp(object.AbsolutePosition.Y, Constants.EdgePadding, view.Y - size.Y - Constants.EdgePadding)
            Controller:Tween(object, { Position = UDim2.fromOffset(x, y) }, Constants.AnimationNormal)
            current = { X = (x + size.X / 2) / view.X, Y = (y + size.Y / 2) / view.Y }
            if onFinish then onFinish(current) end
        elseif moved and onFinish then onFinish(normalizedFrom(object)) end
    end)
end
bindDrag("PanelDrag", Header, nil, function(value) Settings.PanelPosition = value; Controller:ScheduleSave() end, false)
bindDrag("BubbleDrag", Bubble, function() Controller:Restore() end, function(value) Settings.BubblePosition = value; Controller:ScheduleSave() end, true)
Controller:Connect("Static", MinimizeButton.Activated, function() Controller:Minimize() end)
Controller:Connect("Static", CloseButton.Activated, function() Controller:Destroy() end)

-- REFRESH CONTROLLER
function Controller:Refresh()
    if not self.Alive then return end
    if Probe.Alive == false then self:Destroy(); return end
    Status.Text, Status.TextColor3 = "● READY", Theme.Success
    local roster = type(Probe.Roster) == "table" and Probe.Roster or {}
    local data = targetData(Probe.CurrentTarget)
    TargetName.Text = data and data.DisplayName or "NO TARGET"
    TargetUser.Text = data and (Settings.ShowUsername and "@" .. data.Username or "Target acquired") or "Waiting for opponent"
    ModeChip.Text = (Probe.TargetMode == "AUTO" and "AUTO" or "MANUAL") .. " MODE"
    Mode.Text = "MODE " .. (Probe.TargetMode == "AUTO" and "AUTO" or "MANUAL")
    TargetDistance.Text = data and Settings.ShowDistance and data.Distance and string.format("%.1f STUDS", data.Distance) or ""
    local healthVisible = data and Settings.ShowHealth and data.Health and data.MaxHealth and data.MaxHealth > 0
    HealthText.Visible, HealthBack.Visible = healthVisible == true, healthVisible == true
    if healthVisible then
        local ratio = math.clamp(data.Health / data.MaxHealth, 0, 1); HealthText.Text = string.format("HP %.0f / %.0f", data.Health, data.MaxHealth)
        HealthFill.Size = UDim2.fromScale(ratio, 1); HealthFill.BackgroundColor3 = ratio > 0.5 and Theme.Success or (ratio > 0.25 and Theme.Warning or Theme.Danger)
    end
    for key, control in pairs(ToggleRows) do local enabled = Probe[key] == true; control.Text = enabled and "ON" or "OFF"; control.BackgroundColor3 = enabled and Theme.SuccessSoft or Theme.Surface2; control.TextColor3 = enabled and Theme.Success or Theme.Muted end
    Bubble.Text = Settings.MinimizedStyle == "INFO" and ("CT • " .. (Probe.TargetMode == "AUTO" and "AUTO" or tostring(#roster))) or "CT"
    StatLabels.ENEMIES.Text = tostring(#roster); StatLabels.MODE.Text = Probe.TargetMode == "AUTO" and "AUTO" or "MANUAL"
    local counts = type(Probe.Counts) == "table" and Probe.Counts or {}
    StatLabels.PARRIES.Text = tostring(counts.TrustParries or counts.Parries or 0); StatLabels.REDIRECTS.Text = tostring(counts.HitRedirects or counts.Redirects or 0)
    StatsGrid.Visible = Settings.ShowStats
    ConfigText.Text = "CONFIG: " .. string.upper(tostring(Probe.ConfigStatus or "unknown"))
    local elapsed = math.floor(os.clock() - StartedAt); UptimeText.Text = string.format("UI %02d:%02d", math.floor(elapsed / 60), elapsed % 60)
    self:RefreshRoster(); self:RefreshActivity()
end
function Controller:Destroy()
    if not self.Alive then return end
    self:SaveSettings(); self.Alive = false; self.Generation += 1
    local scopes = {}
    for scope in pairs(self.Connections) do table.insert(scopes, scope) end
    for _, scope in ipairs(scopes) do self:DisconnectScope(scope) end
    for object, tween in pairs(self.Tweens) do pcall(function() tween:Cancel() end); self.Tweens[object] = nil end
    if Probe.UI == self then Probe.UI = nil end
    if Environment.CombatTrustUltraUI == self then Environment.CombatTrustUltraUI = nil end
    if Gui and Gui.Parent then Gui:Destroy() end
    table.clear(self.Components); table.clear(self.RosterCards); table.clear(self.Notifications)
end

local function bindCamera()
    Controller:DisconnectScope("Camera")
    local camera = workspace.CurrentCamera
    if camera then Controller:Connect("Camera", camera:GetPropertyChangedSignal("ViewportSize"), function() Controller:ApplyResponsiveLayout() end) end
end
Controller:Connect("Static", workspace:GetPropertyChangedSignal("CurrentCamera"), function() bindCamera(); Controller:ApplyResponsiveLayout() end)
bindCamera()
Controller:SetTab(VisualState.ActiveTab)
Controller:ApplySettings()
if VisualState.Minimized then Panel.Visible = false; Bubble.Visible = true else Panel.Visible = true; Bubble.Visible = false end
Controller:Refresh()
Controller:Notify(ConfigAvailable and "ULTRA UI V2 READY" or "READY • SETTINGS SESSION ONLY", ConfigAvailable and Theme.Success or Theme.Warning)

local generation = Controller.Generation
task.spawn(function()
    while Controller.Alive and Controller.Generation == generation do
        task.wait(Constants.RefreshInterval)
        if Controller.Alive and Controller.Generation == generation then Controller:Refresh() end
    end
end)

print("[Combat Trust UI] Ultra UI V2 initialized")
