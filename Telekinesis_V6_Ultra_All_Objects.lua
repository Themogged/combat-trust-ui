--[[
    TELEKINESIS V6 ULTRA ALL-OBJECTS — PROFESSIONAL REFACTOR
    PC + MOBILE UNIFICADO / REFACTOR PRO

    Basado en la V4.4 suministrada por el usuario.

    PRINCIPALES CAMBIOS
    - Re-ejecución segura mediante singleton + Destroy()
    - Connection manager y cleanup centralizado
    - Raycast moderno (workspace:Raycast + RaycastParams)
    - Escaneo del imán desacoplado del Heartbeat
    - Imán ATTRACT / REPEL + falloff + límite de objetos
    - Presets PRECISION / NORMAL / HEAVY / CHAOS
    - Rotación por grados/segundo + snap configurable
    - UI única responsive para PC / tablet / móvil
    - Pestañas CONTROL / SELECTION / MAGNET / ROTATION / SETTINGS
    - Inspector de objeto seleccionado
    - Ventana draggable y bubble minimizada draggable
    - Snap de bubble a bordes + posición persistente
    - Configuración persistente opcional (readfile/writefile)
    - Notificaciones internas ligeras
    - Selección física PART / ASSEMBLY / MODEL
    - SELECT ALL para todos los objetos físicos elegibles del workspace
    - Multi-select + HOLD / THROW / ANCHOR / UNANCHOR masivos
    - Soporte temporal para objetos anclados con restauración de estado
    - Imán por AssemblyRootPart para evitar duplicados
    - Imán compatible con assemblies, piezas sin colisión y objetos anclados
    - Highlight múltiple con límite visual para proteger rendimiento

    NOTA
    "All Objects" significa objetos físicos BasePart/assemblies/models del workspace.
    Personajes/jugadores continúan excluidos deliberadamente.
    Algunos objetos pueden seguir sin moverse si el servidor no concede ownership físico al cliente.
]]

--------------------------------------------------
-- SINGLETON / RE-EJECUCIÓN
--------------------------------------------------

local ENV = (getgenv and getgenv()) or _G

if ENV.TelekinesisUltraV6 and type(ENV.TelekinesisUltraV6.Destroy) == "function" then
    pcall(function()
        ENV.TelekinesisUltraV6:Destroy()
    end)
end
if ENV.TelekinesisUltraV5 and type(ENV.TelekinesisUltraV5.Destroy) == "function" then
    pcall(function() ENV.TelekinesisUltraV5:Destroy() end)
end

--------------------------------------------------
-- SERVICIOS
--------------------------------------------------

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera
local isMobile = UserInputService.TouchEnabled

--------------------------------------------------
-- CONSTANTES
--------------------------------------------------

local CONSTANTS = {
    VERSION = "6 ULTRA ALL-OBJECTS",
    CONFIG_FOLDER = "TelekinesisUltra",
    CONFIG_PATH = "TelekinesisUltra/v6_config.json",

    UI_REFRESH_INTERVAL = 0.15,
    POINTER_DRAG_THRESHOLD = 8,
    DRAG_THRESHOLD = 7,
    EDGE_PADDING = 10,

    TWEEN_FAST = 0.14,
    TWEEN_NORMAL = 0.20,

    RAY_DISTANCE = 1000,
    MAX_MAGNET_SURFACE_PASSES = 40,
    SELECT_ALL_YIELD_EVERY = 250,
    SELECTION_HIGHLIGHT_LIMIT = 48,
    LARGE_SELECTION_WARNING = 250,
    SELECTION_CLEANUP_INTERVAL = 0.75,
    INSPECTOR_REFRESH_INTERVAL = 0.20,
    MIN_ADAPTIVE_SCAN_INTERVAL = 0.06,
    MAX_ADAPTIVE_SCAN_INTERVAL = 0.18,
}

--------------------------------------------------
-- THEME
--------------------------------------------------

local THEME = {
    Background = Color3.fromRGB(14, 17, 23),
    Surface = Color3.fromRGB(23, 28, 37),
    Surface2 = Color3.fromRGB(31, 37, 49),
    SurfaceHover = Color3.fromRGB(39, 47, 61),
    Border = Color3.fromRGB(56, 66, 84),
    Text = Color3.fromRGB(242, 245, 250),
    Muted = Color3.fromRGB(150, 161, 181),
    Accent = Color3.fromRGB(72, 153, 255),
    AccentSoft = Color3.fromRGB(32, 61, 99),
    Success = Color3.fromRGB(65, 202, 124),
    SuccessSoft = Color3.fromRGB(28, 77, 54),
    Warning = Color3.fromRGB(244, 181, 68),
    Danger = Color3.fromRGB(235, 83, 93),
    DangerSoft = Color3.fromRGB(87, 34, 40),
    Purple = Color3.fromRGB(144, 108, 241),
}

--------------------------------------------------
-- CONFIG PRINCIPAL
--------------------------------------------------

local DEFAULT_CONFIG = {
    throwForce = 1000,
    throwForceMin = 100,
    throwForceMax = 4000,
    throwForceStepPC = 100,
    throwForceStepMobile = 200,

    magnetRadius = 30,
    magnetRadiusMin = 5,
    magnetRadiusMax = 200,
    magnetForce = 200,
    magnetForceMin = 50,
    magnetForceMax = 2000,
    magnetForceStep = 25,
    magnetRadiusStep = 2,
    magnetMode = "ATTRACT",
    magnetShape = "SPHERE",
    magnetCenter = "AIM POINT",
    magnetFalloff = true,
    magnetMaxObjects = 60,
    magnetAffectsAnchored = false,
    magnetIncludeTransparent = true,
    magnetRequireCanCollide = false,

    -- Selección / multi-object
    selectionScope = "ASSEMBLY", -- PART / ASSEMBLY / MODEL
    maxSelection = isMobile and 250 or 500, -- 0 = unlimited
    selectionRadius = 50,
    selectionType = "ALL PHYSICAL",
    selectionLocked = false,
    groupPivot = "CENTER",
    throwMode = "PARALLEL",
    massCompensation = true,

    holdDistanceDefault = 10,
    holdDistanceMin = 2,
    holdDistanceMax = 1000,
    distanceSpeed = 0.8,
    distanceKeySpeed = 0.4,
    holdResponse = 5,

    rotationSpeed = 120, -- grados/segundo; equivale aprox a 2° por frame a 60fps
    rotationSpeedMin = 30,
    rotationSpeedMax = 360,
    rotationSpeedStep = 30,
    rotationSnap = 0,
    rotationAxis = "Y",
    rotationSpace = "LOCAL",

    holdVelocityP = 12500,
    holdGyroP = 3000,
    rotationPositionP = 20000,
    rotationPositionD = 1250,

    preset = "NORMAL",

    uiScale = 1.0,
    uiTransparency = 0.05,
    animations = true,
    snapBubble = true,
    showHighlights = true,
    showPointer = true,
    panelX = 0.5,
    panelY = 0.50,
    bubbleX = 0.08,
    bubbleY = 0.22,
    activeTab = "CONTROL",
    performanceMode = "AUTO",
}

local CONFIG = {}
for key, value in pairs(DEFAULT_CONFIG) do
    CONFIG[key] = value
end

local PRESETS = {
    SOFT = {
        throwForce = 250,
        magnetForce = 90,
        magnetRadius = 15,
        holdResponse = 3,
        rotationSpeed = 60,
    },
    PRECISION = {
        throwForce = 450,
        magnetForce = 120,
        magnetRadius = 18,
        holdResponse = 3.5,
        rotationSpeed = 60,
    },
    NORMAL = {
        throwForce = 1000,
        magnetForce = 200,
        magnetRadius = 30,
        holdResponse = 5,
        rotationSpeed = 120,
    },
    HEAVY = {
        throwForce = 1800,
        magnetForce = 450,
        magnetRadius = 45,
        holdResponse = 6.5,
        rotationSpeed = 150,
    },
    CHAOS = {
        throwForce = 3400,
        magnetForce = 1000,
        magnetRadius = 70,
        holdResponse = 8,
        rotationSpeed = 240,
    },
}

local PRESET_ORDER = { "SOFT", "PRECISION", "NORMAL", "HEAVY", "CHAOS" }
local SNAP_ORDER = { 0, 5, 15, 30, 45, 90 }
local SCALE_ORDER = { 0.80, 0.90, 1.00, 1.10, 1.20 }
local TRANSPARENCY_ORDER = { 0.00, 0.05, 0.10, 0.20, 0.30 }
local MAX_OBJECTS_ORDER = { 25, 40, 60, 80, 120 }
local MAX_SELECTION_ORDER = { 100, 250, 500, 1000, 0 }
local SELECTION_RADIUS_ORDER = { 10, 25, 50, 100, 200 }
local SELECTION_TYPE_ORDER = { "PARTS", "MESHES", "UNIONS", "VEHICLE/SEATS", "ALL PHYSICAL" }

--------------------------------------------------
-- ESTADO
--------------------------------------------------

local STATE = {
    active = true,
    guiVisible = true,
    minimized = false,

    holding = false,
    target = nil,
    holdDistance = CONFIG.holdDistanceDefault,
    anchoredWhileHolding = false,

    magnetActive = false,
    magnetObjects = {},
    magnetCandidates = {},
    lastMagnetScan = 0,
    magnetScannedCount = 0,
    magnetAnchoredBackup = {},

    -- Selección física multi-object
    selectedRoots = {},
    selectionOrder = {},
    selectionCount = 0,
    selectionPrimary = nil,
    selectionBusy = false,
    selectionToken = 0,
    selectionProcessed = 0,
    selectionTotal = 0,
    selectionHolding = false,
    selectionControllers = {},
    selectionOffsets = {},
    selectionRotations = {},
    selectionAnchoredBackup = {},
    selectionAnchorOverride = nil,
    selectionCenter = nil,
    selectionHighlights = {},
    telekinesisAnchored = {},
    transientInstances = {},

    rotationMode = false,
    rotationPosition = nil,
    rotationAccumulatorX = 0,
    rotationAccumulatorY = 0,
    rotationAccumulatorZ = 0,
    rotationOriginalCFrame = nil,
    rotationKeys = {
        up = false,
        down = false,
        left = false,
        right = false,
    },

    holdQ = false,
    holdE = false,
    holdClose = false,
    holdFar = false,

    characterVisibilityBackup = {},
    characterFrozen = false,
    characterBackup = nil,

    pointerTouch = nil,
    pointerTouchStart = nil,
    pointerDragStarted = false,

    uiLastRefresh = 0,
    inspectorLastRefresh = 0,
    selectionLastCleanup = 0,
    startedAt = os.clock(),
}

--------------------------------------------------
-- CONNECTION MANAGER
--------------------------------------------------

local CONNECTIONS = {}
local ACTIVE_TWEENS = setmetatable({}, { __mode = "k" })
local TASK_GENERATION = 1
local cameraViewportConnection
local PLAYER_CHARACTER_CONNECTIONS = {}

local function trackConnection(connection)
    if connection then
        CONNECTIONS[#CONNECTIONS + 1] = connection
    end
    return connection
end

local function connect(signal, callback)
    return trackConnection(signal:Connect(callback))
end

local function disconnectAllConnections()
    for _, connection in ipairs(CONNECTIONS) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(CONNECTIONS)
    for knownPlayer, connection in pairs(PLAYER_CHARACTER_CONNECTIONS) do
        pcall(function() connection:Disconnect() end)
        PLAYER_CHARACTER_CONNECTIONS[knownPlayer] = nil
    end
end

local function cancelAllTweens()
    for object, activeTween in pairs(ACTIVE_TWEENS) do
        pcall(function() activeTween:Cancel() end)
        ACTIVE_TWEENS[object] = nil
    end
end

local function trackTransient(instance, lifetime)
    STATE.transientInstances[instance] = true
    Debris:AddItem(instance, lifetime)
    local generation = TASK_GENERATION
    task.delay(lifetime + 0.05, function()
        if generation == TASK_GENERATION then STATE.transientInstances[instance] = nil end
    end)
    return instance
end

--------------------------------------------------
-- CONFIG STORAGE
--------------------------------------------------

local configStorageAvailable = type(readfile) == "function" and type(writefile) == "function"
local saveSerial = 0

local function sanitizeNumber(value, minimum, maximum, fallback)
    if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
        return fallback
    end
    return math.clamp(value, minimum, maximum)
end

local function loadConfig()
    if not configStorageAvailable then
        return
    end

    local ok, decoded = pcall(function()
        if type(isfile) == "function" and not isfile(CONSTANTS.CONFIG_PATH) then
            return nil
        end
        return HttpService:JSONDecode(readfile(CONSTANTS.CONFIG_PATH))
    end)

    if not ok or type(decoded) ~= "table" then
        return
    end

    for key, defaultValue in pairs(DEFAULT_CONFIG) do
        local incoming = decoded[key]
        if type(incoming) == type(defaultValue) then
            CONFIG[key] = incoming
        end
    end

    CONFIG.throwForce = sanitizeNumber(CONFIG.throwForce, CONFIG.throwForceMin, CONFIG.throwForceMax, 1000)
    CONFIG.magnetForce = sanitizeNumber(CONFIG.magnetForce, CONFIG.magnetForceMin, CONFIG.magnetForceMax, 200)
    CONFIG.magnetRadius = sanitizeNumber(CONFIG.magnetRadius, CONFIG.magnetRadiusMin, CONFIG.magnetRadiusMax, 30)
    CONFIG.rotationSpeed = sanitizeNumber(CONFIG.rotationSpeed, CONFIG.rotationSpeedMin, CONFIG.rotationSpeedMax, 120)
    CONFIG.maxSelection = math.floor(sanitizeNumber(CONFIG.maxSelection, 0, 5000, isMobile and 250 or 500))
    CONFIG.selectionRadius = sanitizeNumber(CONFIG.selectionRadius, 5, 500, 50)
    CONFIG.uiScale = sanitizeNumber(CONFIG.uiScale, 0.75, 1.25, 1)
    CONFIG.uiTransparency = sanitizeNumber(CONFIG.uiTransparency, 0, 0.35, 0.05)
    CONFIG.panelX = sanitizeNumber(CONFIG.panelX, 0, 1, 0.5)
    CONFIG.panelY = sanitizeNumber(CONFIG.panelY, 0, 1, 0.5)
    CONFIG.bubbleX = sanitizeNumber(CONFIG.bubbleX, 0, 1, 0.08)
    CONFIG.bubbleY = sanitizeNumber(CONFIG.bubbleY, 0, 1, 0.22)

    if CONFIG.magnetMode ~= "ATTRACT" and CONFIG.magnetMode ~= "REPEL" and CONFIG.magnetMode ~= "ORBIT" then
        CONFIG.magnetMode = "ATTRACT"
    end
    if CONFIG.magnetShape ~= "SPHERE" and CONFIG.magnetShape ~= "BOX" then CONFIG.magnetShape = "SPHERE" end
    if CONFIG.magnetCenter ~= "AIM POINT" and CONFIG.magnetCenter ~= "PLAYER" and CONFIG.magnetCenter ~= "ACTIVE TARGET" then CONFIG.magnetCenter = "AIM POINT" end

    if CONFIG.selectionScope ~= "PART"
        and CONFIG.selectionScope ~= "ASSEMBLY"
        and CONFIG.selectionScope ~= "MODEL" then
        CONFIG.selectionScope = "ASSEMBLY"
    end

    if not table.find(SELECTION_TYPE_ORDER, CONFIG.selectionType) then CONFIG.selectionType = "ALL PHYSICAL" end
    if CONFIG.groupPivot ~= "CENTER" and CONFIG.groupPivot ~= "ACTIVE" and CONFIG.groupPivot ~= "AVERAGE" then CONFIG.groupPivot = "CENTER" end
    if CONFIG.throwMode ~= "PARALLEL" and CONFIG.throwMode ~= "RADIAL" then CONFIG.throwMode = "PARALLEL" end
    if CONFIG.rotationAxis ~= "X" and CONFIG.rotationAxis ~= "Y" and CONFIG.rotationAxis ~= "Z" then CONFIG.rotationAxis = "Y" end
    if CONFIG.rotationSpace ~= "LOCAL" and CONFIG.rotationSpace ~= "WORLD" then CONFIG.rotationSpace = "LOCAL" end

    if not PRESETS[CONFIG.preset] then
        CONFIG.preset = "NORMAL"
    end

    if CONFIG.activeTab ~= "CONTROL"
        and CONFIG.activeTab ~= "SELECTION"
        and CONFIG.activeTab ~= "MAGNET"
        and CONFIG.activeTab ~= "ROTATION"
        and CONFIG.activeTab ~= "SETTINGS" then
        CONFIG.activeTab = "CONTROL"
    end
end

local function saveConfigNow()
    if not configStorageAvailable then
        return false
    end

    local payload = {
        Version = 6,
        throwForce = CONFIG.throwForce,
        magnetRadius = CONFIG.magnetRadius,
        magnetForce = CONFIG.magnetForce,
        magnetMode = CONFIG.magnetMode,
        magnetShape = CONFIG.magnetShape,
        magnetCenter = CONFIG.magnetCenter,
        magnetFalloff = CONFIG.magnetFalloff,
        magnetMaxObjects = CONFIG.magnetMaxObjects,
        magnetAffectsAnchored = CONFIG.magnetAffectsAnchored,
        magnetIncludeTransparent = CONFIG.magnetIncludeTransparent,
        magnetRequireCanCollide = CONFIG.magnetRequireCanCollide,
        selectionScope = CONFIG.selectionScope,
        maxSelection = CONFIG.maxSelection,
        selectionRadius = CONFIG.selectionRadius,
        selectionType = CONFIG.selectionType,
        selectionLocked = CONFIG.selectionLocked,
        groupPivot = CONFIG.groupPivot,
        throwMode = CONFIG.throwMode,
        massCompensation = CONFIG.massCompensation,
        holdResponse = CONFIG.holdResponse,
        rotationSpeed = CONFIG.rotationSpeed,
        rotationSnap = CONFIG.rotationSnap,
        rotationAxis = CONFIG.rotationAxis,
        rotationSpace = CONFIG.rotationSpace,
        preset = CONFIG.preset,
        uiScale = CONFIG.uiScale,
        uiTransparency = CONFIG.uiTransparency,
        animations = CONFIG.animations,
        snapBubble = CONFIG.snapBubble,
        showHighlights = CONFIG.showHighlights,
        showPointer = CONFIG.showPointer,
        panelX = CONFIG.panelX,
        panelY = CONFIG.panelY,
        bubbleX = CONFIG.bubbleX,
        bubbleY = CONFIG.bubbleY,
        activeTab = CONFIG.activeTab,
        performanceMode = CONFIG.performanceMode,
    }

    local ok = pcall(function()
        if type(isfolder) == "function" and type(makefolder) == "function" then
            if not isfolder(CONSTANTS.CONFIG_FOLDER) then
                makefolder(CONSTANTS.CONFIG_FOLDER)
            end
        elseif type(makefolder) == "function" then
            pcall(makefolder, CONSTANTS.CONFIG_FOLDER)
        end
        writefile(CONSTANTS.CONFIG_PATH, HttpService:JSONEncode(payload))
    end)

    return ok
end

local function queueSaveConfig()
    saveSerial += 1
    local serial = saveSerial
    local generation = TASK_GENERATION
    task.delay(0.35, function()
        if STATE.active and generation == TASK_GENERATION and serial == saveSerial then
            saveConfigNow()
        end
    end)
end

loadConfig()
STATE.holdDistance = CONFIG.holdDistanceDefault

--------------------------------------------------
-- PERSONAJE
--------------------------------------------------

local function getCharacter()
    return player.Character
end

local function getHumanoid()
    local character = getCharacter()
    return character and character:FindFirstChildOfClass("Humanoid") or nil
end

local function getRootPart()
    local character = getCharacter()
    return character and character:FindFirstChild("HumanoidRootPart") or nil
end

local CHARACTER_MODELS = {}
local PLAYER_CHARACTERS = {}

local function registerCharacter(character)
    if character then CHARACTER_MODELS[character] = true end
end

local function unregisterCharacter(character)
    if character then CHARACTER_MODELS[character] = nil end
end

local function registerPlayerCharacter(knownPlayer, character)
    unregisterCharacter(PLAYER_CHARACTERS[knownPlayer])
    PLAYER_CHARACTERS[knownPlayer] = character
    registerCharacter(character)
end

local function watchPlayer(knownPlayer)
    registerPlayerCharacter(knownPlayer, knownPlayer.Character)
    if PLAYER_CHARACTER_CONNECTIONS[knownPlayer] then PLAYER_CHARACTER_CONNECTIONS[knownPlayer]:Disconnect() end
    PLAYER_CHARACTER_CONNECTIONS[knownPlayer] = knownPlayer.CharacterAdded:Connect(function(character) registerPlayerCharacter(knownPlayer, character) end)
end

for _, knownPlayer in ipairs(Players:GetPlayers()) do watchPlayer(knownPlayer) end
connect(Players.PlayerAdded, watchPlayer)
connect(Players.PlayerRemoving, function(leavingPlayer)
    unregisterCharacter(PLAYER_CHARACTERS[leavingPlayer])
    PLAYER_CHARACTERS[leavingPlayer] = nil
    local connection = PLAYER_CHARACTER_CONNECTIONS[leavingPlayer]
    if connection then connection:Disconnect(); PLAYER_CHARACTER_CONNECTIONS[leavingPlayer] = nil end
end)

local function isPlayerPart(part)
    if not part then
        return false
    end
    local current = part
    while current and current ~= workspace do
        if CHARACTER_MODELS[current] then return true end
        current = current.Parent
    end
    return false
end

local GUI_PARENT
local raycastNormal
local getAimRay

local function isEligiblePhysicalPart(part)
    return part ~= nil
        and part:IsA("BasePart")
        and part:IsDescendantOf(workspace)
        and not isPlayerPart(part)
end

local function getAssemblyRoot(part)
    if not isEligiblePhysicalPart(part) then
        return nil
    end

    local root
    pcall(function()
        root = part.AssemblyRootPart
    end)

    if root and isEligiblePhysicalPart(root) then
        return root
    end

    return part
end

local function getAssemblyParts(root)
    if not root or not root:IsA("BasePart") then
        return {}
    end

    local parts = {}
    local seen = {}

    local ok, connected = pcall(function()
        return root:GetConnectedParts(true)
    end)

    if ok and type(connected) == "table" then
        for _, part in ipairs(connected) do
            if isEligiblePhysicalPart(part) and not seen[part] then
                seen[part] = true
                parts[#parts + 1] = part
            end
        end
    end

    if isEligiblePhysicalPart(root) and not seen[root] then
        parts[#parts + 1] = root
    end

    return parts
end

local function findPhysicalModel(part)
    if not part then
        return nil
    end

    local current = part:FindFirstAncestorOfClass("Model")
    while current and current ~= workspace do
        if Players:GetPlayerFromCharacter(current) then
            return nil
        end

        local hasPhysicalPart = false
        for _, child in ipairs(current:GetDescendants()) do
            if child:IsA("BasePart") and isEligiblePhysicalPart(child) then
                hasPhysicalPart = true
                break
            end
        end

        if hasPhysicalPart then
            return current
        end

        current = current.Parent and current.Parent:FindFirstAncestorOfClass("Model") or nil
    end

    return nil
end

local function collectRootsFromPart(part, scope)
    local roots = {}
    local seen = {}

    local function addRoot(candidate, preservePart)
        local root = preservePart and candidate or getAssemblyRoot(candidate)
        if root and not seen[root] then
            seen[root] = true
            roots[#roots + 1] = root
        end
    end

    if not isEligiblePhysicalPart(part) then
        return roots
    end

    if scope == "PART" then
        addRoot(part, true)
    elseif scope == "MODEL" then
        local model = findPhysicalModel(part)
        if model then
            for _, descendant in ipairs(model:GetDescendants()) do
                if descendant:IsA("BasePart") and isEligiblePhysicalPart(descendant) then
                    addRoot(descendant)
                end
            end
        else
            addRoot(part)
        end
    else
        addRoot(part)
    end

    return roots
end

local function clearSelectionHighlights()
    for _, highlight in ipairs(STATE.selectionHighlights) do
        pcall(function()
            highlight:Destroy()
        end)
    end
    table.clear(STATE.selectionHighlights)
end

local function refreshSelectionHighlights()
    clearSelectionHighlights()

    if not CONFIG.showHighlights then
        return
    end

    local shown = 0
    local visualLimit = CONSTANTS.SELECTION_HIGHLIGHT_LIMIT
    if CONFIG.performanceMode == "LOW" or (CONFIG.performanceMode == "AUTO" and isMobile) then visualLimit = math.min(24, visualLimit)
    elseif CONFIG.performanceMode == "QUALITY" then visualLimit = math.min(64, math.max(visualLimit, 64)) end
    for _, root in ipairs(STATE.selectionOrder) do
        if shown >= visualLimit then
            break
        end
        if root and root:IsDescendantOf(workspace) then
            local highlight = Instance.new("Highlight")
            highlight.Name = "TelekinesisSelectionV6"
            local primary = root == STATE.selectionPrimary
            highlight.FillColor = primary and THEME.Accent or THEME.Purple
            highlight.OutlineColor = primary and THEME.Success or THEME.Accent
            highlight.FillTransparency = primary and 0.68 or 0.82
            highlight.OutlineTransparency = 0.15
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.Adornee = root
            highlight.Parent = GUI_PARENT
            STATE.selectionHighlights[#STATE.selectionHighlights + 1] = highlight
            shown += 1
        end
    end
end

local function clearSelection()
    if STATE.selectionHolding then
        return false
    end

    table.clear(STATE.selectedRoots)
    table.clear(STATE.selectionOrder)
    STATE.selectionCount = 0
    STATE.selectionPrimary = nil
    STATE.selectionCenter = nil
    clearSelectionHighlights()
    return true
end

local function setSelection(roots, primary)
    if STATE.selectionHolding then
        return false
    end

    clearSelection()

    for _, root in ipairs(roots or {}) do
        root = CONFIG.selectionScope == "PART" and root or getAssemblyRoot(root)
        if root and not STATE.selectedRoots[root] then
            STATE.selectedRoots[root] = true
            STATE.selectionOrder[#STATE.selectionOrder + 1] = root
        end
    end

    STATE.selectionCount = #STATE.selectionOrder
    STATE.selectionPrimary = (CONFIG.selectionScope == "PART" and primary or getAssemblyRoot(primary)) or STATE.selectionOrder[1]
    refreshSelectionHighlights()
    return STATE.selectionCount > 0
end

local function getSelectionCenter()
    if CONFIG.groupPivot == "ACTIVE" and STATE.selectionPrimary and STATE.selectionPrimary:IsDescendantOf(workspace) then
        return STATE.selectionPrimary.Position
    end
    local sum = Vector3.zero
    local count = 0
    local minimum, maximum

    for _, root in ipairs(STATE.selectionOrder) do
        if root and root:IsDescendantOf(workspace) then
            sum += root.Position
            count += 1
            minimum = minimum and Vector3.new(math.min(minimum.X, root.Position.X), math.min(minimum.Y, root.Position.Y), math.min(minimum.Z, root.Position.Z)) or root.Position
            maximum = maximum and Vector3.new(math.max(maximum.X, root.Position.X), math.max(maximum.Y, root.Position.Y), math.max(maximum.Z, root.Position.Z)) or root.Position
        end
    end

    if count == 0 then
        return nil
    end

    if CONFIG.groupPivot == "CENTER" and minimum and maximum then return (minimum + maximum) * 0.5 end
    return sum / count
end

local function pruneSelection()
    if STATE.selectionHolding then
        return
    end

    local newOrder = {}
    local newSet = {}
    local changed = false

    for _, root in ipairs(STATE.selectionOrder) do
        if root and root:IsDescendantOf(workspace) and isEligiblePhysicalPart(root) then
            newOrder[#newOrder + 1] = root
            newSet[root] = true
        else
            changed = true
        end
    end

    if changed then
        STATE.selectionOrder = newOrder
        STATE.selectedRoots = newSet
        STATE.selectionCount = #newOrder
        if not STATE.selectionPrimary or not newSet[STATE.selectionPrimary] then
            STATE.selectionPrimary = newOrder[1]
        end
        refreshSelectionHighlights()
    end
end

local function selectAimedObject(force)
    if CONFIG.selectionLocked and not force then return false end
    local hit = raycastNormal()
    if not hit or not isEligiblePhysicalPart(hit) then
        return false
    end

    local roots = collectRootsFromPart(hit, CONFIG.selectionScope)
    if #roots == 0 then
        return false
    end

    setSelection(roots, getAssemblyRoot(hit))
    return true
end

local function matchesSelectionType(part)
    local filter = CONFIG.selectionType
    if filter == "ALL PHYSICAL" then return true end
    if filter == "MESHES" then return part:IsA("MeshPart") end
    if filter == "UNIONS" then return part:IsA("UnionOperation") end
    if filter == "VEHICLE/SEATS" then return part:IsA("Seat") or part:IsA("VehicleSeat") end
    return part:IsA("Part") or part:IsA("WedgePart") or part:IsA("TrussPart") or part:IsA("SpawnLocation")
end

local function addEligibleRoot(roots, seen, object)
    if not object:IsA("BasePart") or not isEligiblePhysicalPart(object) or not matchesSelectionType(object) then return false end
    local resolved = collectRootsFromPart(object, CONFIG.selectionScope)
    local added = false
    for _, root in ipairs(resolved) do
        if root and not seen[root] then
            seen[root] = true
            roots[#roots + 1] = root
            added = true
        end
    end
    return added
end

local function cancelSelectionScan()
    if STATE.selectionBusy then
        STATE.selectionToken += 1
        STATE.selectionBusy = false
        return true
    end
    return false
end

local function selectAllObjectsAsync(onDone)
    if STATE.selectionBusy or STATE.selectionHolding then
        return
    end

    STATE.selectionBusy = true
    STATE.selectionToken += 1
    local token = STATE.selectionToken
    local generation = TASK_GENERATION

    task.spawn(function()
        local roots = {}
        local seen = {}
        local descendants = workspace:GetDescendants()
        local processed = 0
        local limit = CONFIG.maxSelection
        STATE.selectionTotal = #descendants
        STATE.selectionProcessed = 0

        for _, object in ipairs(descendants) do
            if not STATE.active or generation ~= TASK_GENERATION or token ~= STATE.selectionToken then
                break
            end

            processed += 1
            STATE.selectionProcessed = processed
            addEligibleRoot(roots, seen, object)
            if limit > 0 and #roots >= limit then break end

            if processed % CONSTANTS.SELECT_ALL_YIELD_EVERY == 0 then
                task.wait()
            end
        end

        if STATE.active and generation == TASK_GENERATION and token == STATE.selectionToken then
            setSelection(roots, roots[1])
        end

        if token == STATE.selectionToken then STATE.selectionBusy = false end
        if onDone and STATE.active and generation == TASK_GENERATION and token == STATE.selectionToken then
            pcall(onDone, #roots)
        end
    end)
end

local function selectNearbyAsync(onDone)
    if STATE.selectionBusy or STATE.selectionHolding then return end
    local ray = getAimRay()
    local _, aimedPosition = raycastNormal()
    local center = STATE.selectionPrimary and STATE.selectionPrimary.Position
        or aimedPosition
        or (ray.Origin + ray.Direction.Unit * math.min(25, CONFIG.selectionRadius))
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = getCharacter() and { getCharacter() } or {}
    params.MaxParts = CONFIG.maxSelection > 0 and CONFIG.maxSelection * 3 or 0
    local nearby = workspace:GetPartBoundsInRadius(center, CONFIG.selectionRadius, params)
    STATE.selectionBusy = true; STATE.selectionToken += 1
    local token, generation = STATE.selectionToken, TASK_GENERATION
    task.spawn(function()
        local roots, seen = {}, {}
        STATE.selectionTotal = #nearby
        for index, object in ipairs(nearby) do
            if not STATE.active or token ~= STATE.selectionToken or generation ~= TASK_GENERATION then break end
            STATE.selectionProcessed = index
            addEligibleRoot(roots, seen, object)
            if CONFIG.maxSelection > 0 and #roots >= CONFIG.maxSelection then break end
            if index % CONSTANTS.SELECT_ALL_YIELD_EVERY == 0 then task.wait() end
        end
        if STATE.active and token == STATE.selectionToken and generation == TASK_GENERATION then setSelection(roots, roots[1]) end
        if token == STATE.selectionToken then STATE.selectionBusy = false end
        if onDone and token == STATE.selectionToken then pcall(onDone, #roots) end
    end)
end

local function invertSelectionAsync(onDone)
    if STATE.selectionBusy or STATE.selectionHolding then return end
    local previous = STATE.selectedRoots
    STATE.selectionBusy = true; STATE.selectionToken += 1
    local token, generation = STATE.selectionToken, TASK_GENERATION
    task.spawn(function()
        local roots, seen, descendants = {}, {}, workspace:GetDescendants()
        STATE.selectionTotal = #descendants
        for index, object in ipairs(descendants) do
            if not STATE.active or token ~= STATE.selectionToken or generation ~= TASK_GENERATION then break end
            STATE.selectionProcessed = index
            if object:IsA("BasePart") and isEligiblePhysicalPart(object) and matchesSelectionType(object) then
                for _, root in ipairs(collectRootsFromPart(object, CONFIG.selectionScope)) do
                    if not previous[root] and not seen[root] then seen[root] = true; roots[#roots + 1] = root end
                end
            end
            if CONFIG.maxSelection > 0 and #roots >= CONFIG.maxSelection then break end
            if index % CONSTANTS.SELECT_ALL_YIELD_EVERY == 0 then task.wait() end
        end
        if STATE.active and token == STATE.selectionToken and generation == TASK_GENERATION then setSelection(roots, roots[1]) end
        if token == STATE.selectionToken then STATE.selectionBusy = false end
        if onDone and token == STATE.selectionToken then pcall(onDone, #roots) end
    end)
end

--------------------------------------------------
-- GUI PARENT
--------------------------------------------------

local function getGuiParent()
    if type(gethui) == "function" then
        local ok, result = pcall(gethui)
        if ok and result then
            return result
        end
    end

    local ok, result = pcall(function()
        return CoreGui
    end)
    if ok and result then
        return result
    end

    return player:WaitForChild("PlayerGui")
end

GUI_PARENT = getGuiParent()

for _, oldName in ipairs({ "TelekinesisUI", "TelekinesisMobile", "TelekinesisUltraV5", "TelekinesisUltraV6", "TelekinesisMagnetVisualV5", "TelekinesisMagnetVisualV6" }) do
    local old = GUI_PARENT:FindFirstChild(oldName)
    if old then
        pcall(function()
            old:Destroy()
        end)
    end
end

--------------------------------------------------
-- FÍSICA BASE
--------------------------------------------------

local bodyVelocity = Instance.new("BodyVelocity")
bodyVelocity.Name = "TelekinesisVelocityV6"
bodyVelocity.MaxForce = Vector3.new(1, 1, 1) * 1e5
bodyVelocity.P = CONFIG.holdVelocityP
bodyVelocity.Velocity = Vector3.zero

local bodyGyro = Instance.new("BodyGyro")
bodyGyro.Name = "TelekinesisGyroV6"
bodyGyro.MaxTorque = Vector3.new(1, 1, 1) * 1e6
bodyGyro.P = CONFIG.holdGyroP

local rotationPositionLock = Instance.new("BodyPosition")
rotationPositionLock.Name = "TelekinesisRotationPositionV6"
rotationPositionLock.MaxForce = Vector3.new(1, 1, 1) * 1e7
rotationPositionLock.P = CONFIG.rotationPositionP
rotationPositionLock.D = CONFIG.rotationPositionD
rotationPositionLock.Position = Vector3.zero

local function disconnectPhysics()
    bodyVelocity.Parent = nil
    bodyGyro.Parent = nil
end

local function connectPhysics(target)
    if not target then
        return
    end
    bodyVelocity.Parent = target
    bodyGyro.Parent = target
end

--------------------------------------------------
-- HIGHLIGHTS
--------------------------------------------------

local highlightHolding = Instance.new("Highlight")
highlightHolding.Name = "TelekinesisHoldingV6"
highlightHolding.FillColor = THEME.Success
highlightHolding.OutlineColor = THEME.Success
highlightHolding.FillTransparency = 0.62
highlightHolding.OutlineTransparency = 0
highlightHolding.DepthMode = Enum.HighlightDepthMode.Occluded
highlightHolding.Enabled = false
highlightHolding.Parent = GUI_PARENT

local highlightLooking = Instance.new("Highlight")
highlightLooking.Name = "TelekinesisLookingV6"
highlightLooking.FillColor = THEME.Accent
highlightLooking.OutlineColor = THEME.Accent
highlightLooking.FillTransparency = 0.68
highlightLooking.OutlineTransparency = 0
highlightLooking.DepthMode = Enum.HighlightDepthMode.Occluded
highlightLooking.Enabled = false
highlightLooking.Parent = GUI_PARENT

--------------------------------------------------
-- IMÁN VISUAL
--------------------------------------------------

local usingDrawing = type(Drawing) == "table"
    and type(Drawing.new) == "function"

local magnetCircle
local circleGui
local circleFrame
local surfacePosition = Vector3.zero
local actualMagnetRadius = CONFIG.magnetRadius

if usingDrawing then
    local ok, drawing = pcall(function()
        return Drawing.new("Circle")
    end)
    if ok and drawing then
        magnetCircle = drawing
        magnetCircle.Visible = false
        magnetCircle.Transparency = 1
        magnetCircle.Color = THEME.Accent
        magnetCircle.Thickness = 2
        magnetCircle.Filled = false
    else
        usingDrawing = false
    end
end

if not usingDrawing then
    circleGui = Instance.new("ScreenGui")
    circleGui.Name = "TelekinesisMagnetVisualV6"
    circleGui.ResetOnSpawn = false
    circleGui.IgnoreGuiInset = true
    circleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    circleGui.Enabled = true
    circleGui.Parent = GUI_PARENT

    circleFrame = Instance.new("Frame")
    circleFrame.Name = "Ring"
    circleFrame.BackgroundTransparency = 1
    circleFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    circleFrame.Position = UDim2.fromOffset(-1000, -1000)
    circleFrame.Size = UDim2.fromOffset(100, 100)
    circleFrame.Visible = false
    circleFrame.ZIndex = 250
    circleFrame.Parent = circleGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = circleFrame

    local stroke = Instance.new("UIStroke")
    stroke.Name = "RingStroke"
    stroke.Thickness = 2
    stroke.Color = THEME.Accent
    stroke.Transparency = 0
    stroke.Parent = circleFrame
end

--------------------------------------------------
-- RAYCAST MODERNO
--------------------------------------------------

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local function refreshRaycastFilter(extra)
    local ignore = {}
    local character = getCharacter()
    if character then
        ignore[#ignore + 1] = character
    end
    if extra then
        for _, item in ipairs(extra) do
            ignore[#ignore + 1] = item
        end
    end
    raycastParams.FilterDescendantsInstances = ignore
end

local UI = {}

getAimRay = function()
    camera = workspace.CurrentCamera or camera

    if isMobile and UI.fakePointer then
        local position = UI.fakePointer.AbsolutePosition
        local size = UI.fakePointer.AbsoluteSize
        local x = position.X + size.X * 0.5
        local y = position.Y + size.Y * 0.5
        return camera:ScreenPointToRay(x, y)
    end

    return camera:ScreenPointToRay(mouse.X, mouse.Y)
end

raycastNormal = function()
    refreshRaycastFilter()
    local ray = getAimRay()
    local result = workspace:Raycast(ray.Origin, ray.Direction.Unit * CONSTANTS.RAY_DISTANCE, raycastParams)
    if result then
        return result.Instance, result.Position, result.Normal
    end
    return nil, nil, nil
end

local function raycastForMagnet()
    local ray = getAimRay()
    local ignore = {}
    local character = getCharacter()
    if character then
        ignore[#ignore + 1] = character
    end

    for _ = 1, CONSTANTS.MAX_MAGNET_SURFACE_PASSES do
        refreshRaycastFilter(ignore)
        local result = workspace:Raycast(ray.Origin, ray.Direction.Unit * CONSTANTS.RAY_DISTANCE, raycastParams)
        if not result then
            return nil, nil, nil
        end

        local hit = result.Instance
        if isPlayerPart(hit)
            or (hit:IsA("BasePart") and not hit.Anchored) then
            ignore[#ignore + 1] = hit
        else
            return hit, result.Position, result.Normal
        end
    end

    return nil, nil, nil
end

--------------------------------------------------
-- PERSONAJE: VISIBILIDAD / FREEZE
--------------------------------------------------

local function hideCharacter()
    local character = getCharacter()
    if not character or next(STATE.characterVisibilityBackup) ~= nil then
        return
    end

    for _, object in ipairs(character:GetDescendants()) do
        if object:IsA("BasePart") then
            STATE.characterVisibilityBackup[object] = object.LocalTransparencyModifier
            object.LocalTransparencyModifier = 1
        elseif object:IsA("Decal") or object:IsA("Texture") then
            STATE.characterVisibilityBackup[object] = object.Transparency
            object.Transparency = 1
        end
    end
end

local function showCharacter()
    for object, transparency in pairs(STATE.characterVisibilityBackup) do
        if object and object:IsDescendantOf(workspace) then
            if object:IsA("BasePart") then
                object.LocalTransparencyModifier = transparency
            elseif object:IsA("Decal") or object:IsA("Texture") then
                object.Transparency = transparency
            end
        end
    end
    STATE.characterVisibilityBackup = {}
end

local function freezeCharacter()
    if STATE.characterFrozen then
        return
    end

    local humanoid = getHumanoid()
    local root = getRootPart()
    if not humanoid or not root then
        return
    end

    STATE.characterBackup = {
        WalkSpeed = humanoid.WalkSpeed,
        JumpPower = humanoid.JumpPower,
        JumpHeight = humanoid.JumpHeight,
        AutoRotate = humanoid.AutoRotate,
        RootAnchored = root.Anchored,
    }

    STATE.characterFrozen = true
    humanoid.WalkSpeed = 0
    humanoid.JumpPower = 0
    humanoid.JumpHeight = 0
    humanoid.AutoRotate = false
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    root.Anchored = true
end

local function unfreezeCharacter()
    if not STATE.characterFrozen then
        return
    end

    local humanoid = getHumanoid()
    local root = getRootPart()
    local backup = STATE.characterBackup

    STATE.characterFrozen = false
    STATE.characterBackup = nil

    if humanoid and backup then
        humanoid.WalkSpeed = backup.WalkSpeed
        humanoid.JumpPower = backup.JumpPower
        humanoid.JumpHeight = backup.JumpHeight
        humanoid.AutoRotate = backup.AutoRotate
    end

    if root and backup then
        root.Anchored = backup.RootAnchored
    end
end

--------------------------------------------------
-- UI HELPERS
--------------------------------------------------

local function makeCorner(object, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 12)
    corner.Parent = object
    return corner
end

local function makeStroke(object, transparency, color)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or THEME.Border
    stroke.Transparency = transparency == nil and 0.25 or transparency
    stroke.Thickness = 1
    stroke.Parent = object
    return stroke
end

local function makePadding(object, padding)
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, padding)
    pad.PaddingRight = UDim.new(0, padding)
    pad.PaddingTop = UDim.new(0, padding)
    pad.PaddingBottom = UDim.new(0, padding)
    pad.Parent = object
    return pad
end

local function tween(object, duration, properties)
    local previous = ACTIVE_TWEENS[object]
    if previous then pcall(function() previous:Cancel() end) end
    if not CONFIG.animations then
        for key, value in pairs(properties) do
            object[key] = value
        end
        return nil
    end

    local tw = TweenService:Create(
        object,
        TweenInfo.new(duration or CONSTANTS.TWEEN_FAST, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        properties
    )
    tw:Play()
    ACTIVE_TWEENS[object] = tw
    return tw
end

local function clamp01(value)
    return math.clamp(value, 0, 1)
end

local function cycleValue(array, current, direction)
    local nearestIndex = 1
    local nearestDistance = math.huge
    for index, value in ipairs(array) do
        local distance = type(value) == "number" and math.abs(value - current) or (value == current and 0 or 1)
        if distance < nearestDistance then
            nearestDistance = distance
            nearestIndex = index
        end
    end
    local count = #array
    local nextIndex = ((nearestIndex - 1 + direction) % count) + 1
    return array[nextIndex]
end

--------------------------------------------------
-- ROOT UI
--------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "TelekinesisUltraV6"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function()
    gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
end)
gui.Parent = GUI_PARENT
UI.gui = gui

local window = Instance.new("Frame")
window.Name = "Window"
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Position = UDim2.fromScale(CONFIG.panelX, CONFIG.panelY)
window.Size = UDim2.fromOffset(520, 520)
window.BackgroundColor3 = THEME.Background
window.BackgroundTransparency = CONFIG.uiTransparency
window.BorderSizePixel = 0
window.ClipsDescendants = true
window.Parent = gui
UI.window = window
makeCorner(window, 16)
makeStroke(window, 0.12)

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(280, 340)
sizeConstraint.MaxSize = Vector2.new(560, 620)
sizeConstraint.Parent = window

local uiScale = Instance.new("UIScale")
uiScale.Scale = CONFIG.uiScale
uiScale.Parent = window
UI.uiScale = uiScale

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 58)
header.BackgroundColor3 = THEME.Surface
header.BackgroundTransparency = math.clamp(CONFIG.uiTransparency * 0.65, 0, 0.25)
header.BorderSizePixel = 0
header.Active = true
header.Parent = window
UI.header = header

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(16, 8)
title.Size = UDim2.new(1, -150, 0, 24)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = THEME.Text
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "TELEKINESIS ULTRA"
title.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(16, 31)
subtitle.Size = UDim2.new(1, -150, 0, 18)
subtitle.Font = Enum.Font.Code
subtitle.TextSize = 10
subtitle.TextColor3 = THEME.Muted
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Text = "V6 • ALL-OBJECTS • PRO ENGINE"
subtitle.Parent = header

local statusChip = Instance.new("TextLabel")
statusChip.Name = "Status"
statusChip.Size = UDim2.fromOffset(68, 28)
statusChip.Position = UDim2.new(1, -116, 0, 15)
statusChip.BackgroundColor3 = THEME.SuccessSoft
statusChip.BorderSizePixel = 0
statusChip.Font = Enum.Font.GothamBold
statusChip.TextSize = 10
statusChip.TextColor3 = THEME.Success
statusChip.Text = "● READY"
statusChip.Parent = header
makeCorner(statusChip, 14)

local minimizeButton = Instance.new("TextButton")
minimizeButton.Name = "Minimize"
minimizeButton.Size = UDim2.fromOffset(48, 34)
minimizeButton.Position = UDim2.new(1, -56, 0, 12)
minimizeButton.BackgroundColor3 = THEME.Surface2
minimizeButton.BorderSizePixel = 0
minimizeButton.AutoButtonColor = false
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.TextSize = 10
minimizeButton.TextColor3 = THEME.Text
minimizeButton.Text = "MIN"
minimizeButton.Parent = header
makeCorner(minimizeButton, 10)
makeStroke(minimizeButton, 0.35)

local headerDragHandle = Instance.new("Frame")
headerDragHandle.Name = "DragHandle"
headerDragHandle.Size = UDim2.new(1, -120, 1, 0)
headerDragHandle.BackgroundTransparency = 1
headerDragHandle.Active = true
headerDragHandle.ZIndex = 2
headerDragHandle.Parent = header

--------------------------------------------------
-- INSPECTOR
--------------------------------------------------

local inspector = Instance.new("Frame")
inspector.Name = "Inspector"
inspector.Position = UDim2.fromOffset(12, 68)
inspector.Size = UDim2.new(1, -24, 0, 80)
inspector.BackgroundColor3 = THEME.Surface
inspector.BackgroundTransparency = CONFIG.uiTransparency
inspector.BorderSizePixel = 0
inspector.Parent = window
makeCorner(inspector, 12)
makeStroke(inspector, 0.35)

local inspectorTitle = Instance.new("TextLabel")
inspectorTitle.BackgroundTransparency = 1
inspectorTitle.Position = UDim2.fromOffset(12, 8)
inspectorTitle.Size = UDim2.new(1, -24, 0, 18)
inspectorTitle.Font = Enum.Font.GothamBold
inspectorTitle.TextSize = 11
inspectorTitle.TextColor3 = THEME.Muted
inspectorTitle.TextXAlignment = Enum.TextXAlignment.Left
inspectorTitle.Text = "TARGET INSPECTOR"
inspectorTitle.Parent = inspector

local inspectorName = Instance.new("TextLabel")
inspectorName.BackgroundTransparency = 1
inspectorName.Position = UDim2.fromOffset(12, 27)
inspectorName.Size = UDim2.new(1, -24, 0, 22)
inspectorName.Font = Enum.Font.GothamBold
inspectorName.TextSize = 15
inspectorName.TextColor3 = THEME.Text
inspectorName.TextXAlignment = Enum.TextXAlignment.Left
inspectorName.TextTruncate = Enum.TextTruncate.AtEnd
inspectorName.Text = "NO OBJECT SELECTED"
inspectorName.Parent = inspector
UI.inspectorName = inspectorName

local inspectorDetail = Instance.new("TextLabel")
inspectorDetail.BackgroundTransparency = 1
inspectorDetail.Position = UDim2.fromOffset(12, 51)
inspectorDetail.Size = UDim2.new(1, -24, 0, 18)
inspectorDetail.Font = Enum.Font.Code
inspectorDetail.TextSize = 10
inspectorDetail.TextColor3 = THEME.Muted
inspectorDetail.TextXAlignment = Enum.TextXAlignment.Left
inspectorDetail.TextTruncate = Enum.TextTruncate.AtEnd
inspectorDetail.Text = "Aim at an unanchored object"
inspectorDetail.Parent = inspector
UI.inspectorDetail = inspectorDetail

--------------------------------------------------
-- TAB BAR
--------------------------------------------------

local tabBar = Instance.new("Frame")
tabBar.Name = "TabBar"
tabBar.Position = UDim2.fromOffset(12, 158)
tabBar.Size = UDim2.new(1, -24, 0, 42)
tabBar.BackgroundTransparency = 1
tabBar.Parent = window

local tabLayout = Instance.new("UIGridLayout")
tabLayout.CellPadding = UDim2.fromOffset(6, 0)
tabLayout.CellSize = UDim2.new(0.2, -5, 1, 0)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabBar

local tabs = { "CONTROL", "SELECTION", "MAGNET", "ROTATION", "SETTINGS" }
local tabButtons = {}
local pages = {}

local content = Instance.new("Frame")
content.Name = "Content"
content.Position = UDim2.fromOffset(12, 208)
content.Size = UDim2.new(1, -24, 1, -220)
content.BackgroundTransparency = 1
content.ClipsDescendants = true
content.Parent = window

for index, tabName in ipairs(tabs) do
    local button = Instance.new("TextButton")
    button.Name = tabName
    button.LayoutOrder = index
    button.BackgroundColor3 = THEME.Surface
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Font = Enum.Font.GothamBold
    button.TextSize = 10
    button.TextColor3 = THEME.Muted
    button.Text = tabName
    button.Parent = tabBar
    makeCorner(button, 10)
    makeStroke(button, 0.45)
    tabButtons[tabName] = button

    local page = Instance.new("ScrollingFrame")
    page.Name = tabName .. "Page"
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = THEME.Border
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new()
    page.Visible = false
    page.Parent = content
    makePadding(page, 2)

    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 8)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = page

    pages[tabName] = page
end

--------------------------------------------------
-- COMPONENT FACTORY
--------------------------------------------------

local function createSectionTitle(parent, text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -4, 0, 24)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 11
    label.TextColor3 = THEME.Muted
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = text
    label.Parent = parent
    return label
end

local function createButton(parent, text, color, height)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -4, 0, height or 46)
    button.BackgroundColor3 = color or THEME.Surface
    button.BackgroundTransparency = CONFIG.uiTransparency
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Font = Enum.Font.GothamBold
    button.TextSize = 12
    button.TextColor3 = THEME.Text
    button.Text = text
    button.Parent = parent
    makeCorner(button, 11)
    makeStroke(button, 0.35)
    return button
end

local function createRow(parent, height)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -4, 0, height or 48)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local layout = Instance.new("UIGridLayout")
    layout.CellPadding = UDim2.fromOffset(8, 0)
    layout.CellSize = UDim2.new(0.5, -4, 1, 0)
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = row

    return row
end

local function createRowButton(row, text, color)
    local button = Instance.new("TextButton")
    button.BackgroundColor3 = color or THEME.Surface
    button.BackgroundTransparency = CONFIG.uiTransparency
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Font = Enum.Font.GothamBold
    button.TextSize = 11
    button.TextColor3 = THEME.Text
    button.Text = text
    button.Parent = row
    makeCorner(button, 11)
    makeStroke(button, 0.35)
    return button
end

local function createStepper(parent, labelText, getValue, onMinus, onPlus)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -4, 0, 54)
    frame.BackgroundColor3 = THEME.Surface
    frame.BackgroundTransparency = CONFIG.uiTransparency
    frame.BorderSizePixel = 0
    frame.Parent = parent
    makeCorner(frame, 11)
    makeStroke(frame, 0.35)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.fromOffset(12, 5)
    titleLabel.Size = UDim2.new(1, -120, 0, 18)
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.TextSize = 10
    titleLabel.TextColor3 = THEME.Muted
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = labelText
    titleLabel.Parent = frame

    local valueLabel = Instance.new("TextLabel")
    valueLabel.BackgroundTransparency = 1
    valueLabel.Position = UDim2.fromOffset(12, 23)
    valueLabel.Size = UDim2.new(1, -120, 0, 24)
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 15
    valueLabel.TextColor3 = THEME.Text
    valueLabel.TextXAlignment = Enum.TextXAlignment.Left
    valueLabel.Text = tostring(getValue())
    valueLabel.Parent = frame

    local minus = Instance.new("TextButton")
    minus.Size = UDim2.fromOffset(44, 38)
    minus.Position = UDim2.new(1, -100, 0.5, -19)
    minus.BackgroundColor3 = THEME.Surface2
    minus.BorderSizePixel = 0
    minus.AutoButtonColor = false
    minus.Font = Enum.Font.GothamBold
    minus.TextSize = 18
    minus.TextColor3 = THEME.Text
    minus.Text = "−"
    minus.Parent = frame
    makeCorner(minus, 9)

    local plus = Instance.new("TextButton")
    plus.Size = UDim2.fromOffset(44, 38)
    plus.Position = UDim2.new(1, -50, 0.5, -19)
    plus.BackgroundColor3 = THEME.Surface2
    plus.BorderSizePixel = 0
    plus.AutoButtonColor = false
    plus.Font = Enum.Font.GothamBold
    plus.TextSize = 18
    plus.TextColor3 = THEME.Text
    plus.Text = "+"
    plus.Parent = frame
    makeCorner(plus, 9)

    connect(minus.Activated, function()
        onMinus()
        valueLabel.Text = tostring(getValue())
    end)

    connect(plus.Activated, function()
        onPlus()
        valueLabel.Text = tostring(getValue())
    end)

    return {
        Frame = frame,
        Value = valueLabel,
        Refresh = function()
            valueLabel.Text = tostring(getValue())
        end,
    }
end

local function createToggle(parent, labelText, getValue, onToggle)
    local button = createButton(parent, "", THEME.Surface, 48)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(12, 0)
    label.Size = UDim2.new(1, -100, 1, 0)
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 12
    label.TextColor3 = THEME.Text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = labelText
    label.Parent = button

    local chip = Instance.new("TextLabel")
    chip.Size = UDim2.fromOffset(58, 28)
    chip.Position = UDim2.new(1, -70, 0.5, -14)
    chip.BorderSizePixel = 0
    chip.Font = Enum.Font.GothamBold
    chip.TextSize = 10
    chip.Parent = button
    makeCorner(chip, 14)

    local function refresh()
        local enabled = getValue() == true
        chip.Text = enabled and "ON" or "OFF"
        chip.BackgroundColor3 = enabled and THEME.SuccessSoft or THEME.Surface2
        chip.TextColor3 = enabled and THEME.Success or THEME.Muted
    end

    connect(button.Activated, function()
        onToggle()
        refresh()
    end)

    refresh()

    return {
        Button = button,
        Refresh = refresh,
    }
end

--------------------------------------------------
-- TOASTS
--------------------------------------------------

local toastContainer = Instance.new("Frame")
toastContainer.Name = "Toasts"
toastContainer.AnchorPoint = Vector2.new(1, 0)
toastContainer.Position = UDim2.new(1, -12, 0, 12)
toastContainer.Size = UDim2.fromOffset(250, 150)
toastContainer.BackgroundTransparency = 1
toastContainer.Parent = gui

local toastLayout = Instance.new("UIListLayout")
toastLayout.Padding = UDim.new(0, 6)
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.Parent = toastContainer

local toastQueue = {}

local function notify(titleText, detailText, duration)
    if not STATE.active then
        return
    end

    while #toastQueue >= 3 do
        local oldest = table.remove(toastQueue, 1)
        if oldest and oldest.Parent then oldest:Destroy() end
    end

    local toast = Instance.new("Frame")
    toast.Size = UDim2.new(1, 0, 0, detailText and detailText ~= "" and 58 or 42)
    toast.BackgroundColor3 = THEME.Surface
    toast.BackgroundTransparency = 0.03
    toast.BorderSizePixel = 0
    toast.Parent = toastContainer
    toastQueue[#toastQueue + 1] = toast
    makeCorner(toast, 10)
    makeStroke(toast, 0.30)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.fromOffset(10, 6)
    titleLabel.Size = UDim2.new(1, -20, 0, 18)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 11
    titleLabel.TextColor3 = THEME.Text
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = titleText
    titleLabel.Parent = toast

    if detailText and detailText ~= "" then
        local detail = Instance.new("TextLabel")
        detail.BackgroundTransparency = 1
        detail.Position = UDim2.fromOffset(10, 27)
        detail.Size = UDim2.new(1, -20, 0, 20)
        detail.Font = Enum.Font.Code
        detail.TextSize = 9
        detail.TextColor3 = THEME.Muted
        detail.TextXAlignment = Enum.TextXAlignment.Left
        detail.TextTruncate = Enum.TextTruncate.AtEnd
        detail.Text = detailText
        detail.Parent = toast
    end

    toast.BackgroundTransparency = 1
    tween(toast, CONSTANTS.TWEEN_FAST, { BackgroundTransparency = 0.03 })

    local generation = TASK_GENERATION
    task.delay(duration or 1.7, function()
        if STATE.active and generation == TASK_GENERATION and toast and toast.Parent then
            local tw = tween(toast, CONSTANTS.TWEEN_FAST, { BackgroundTransparency = 1 })
            task.delay(CONSTANTS.TWEEN_FAST + 0.03, function()
                if generation == TASK_GENERATION and toast and toast.Parent then
                    toast:Destroy()
                end
                for index, item in ipairs(toastQueue) do if item == toast then table.remove(toastQueue, index); break end end
            end)
            if not tw and toast and toast.Parent then
                toast:Destroy()
            end
        end
    end)
end

--------------------------------------------------
-- CORE ACTIONS
--------------------------------------------------

local function restoreMagnetPhysics()
    for object in pairs(STATE.magnetObjects) do
        if object and object:IsDescendantOf(workspace) then
            local velocity = object:FindFirstChild("TelekinesisMagnetBV6")
            if velocity then
                velocity:Destroy()
            end
        end
    end

    for part, wasAnchored in pairs(STATE.magnetAnchoredBackup) do
        if part and part:IsDescendantOf(workspace) then
            pcall(function()
                part.Anchored = wasAnchored
            end)
        end
    end

    STATE.magnetObjects = {}
    STATE.magnetCandidates = {}
    STATE.magnetScannedCount = 0
    STATE.magnetAnchoredBackup = {}
end

local function clearSelectionControllers(restoreAnchored)
    for root, controller in pairs(STATE.selectionControllers) do
        if controller then
            pcall(function()
                if controller.Velocity then
                    controller.Velocity:Destroy()
                end
            end)
            pcall(function()
                if controller.Gyro then
                    controller.Gyro:Destroy()
                end
            end)
        end
    end
    STATE.selectionControllers = {}

    if restoreAnchored then
        for part, wasAnchored in pairs(STATE.selectionAnchoredBackup) do
            if part and part:IsDescendantOf(workspace) then
                pcall(function()
                    part.Anchored = wasAnchored
                end)
            end
        end
    end

    STATE.selectionAnchoredBackup = {}
    STATE.selectionOffsets = {}
    STATE.selectionRotations = {}
    STATE.selectionCenter = nil
    STATE.selectionHolding = false
    STATE.selectionAnchorOverride = nil
end

local function prepareRootForMotion(root)
    for _, part in ipairs(getAssemblyParts(root)) do
        if STATE.selectionAnchoredBackup[part] == nil then
            STATE.selectionAnchoredBackup[part] = part.Anchored
        end
        part.Anchored = false
    end
end

local function startSelectionHold()
    if not STATE.active or STATE.magnetActive or STATE.rotationMode then
        return false
    end

    if STATE.selectionCount <= 0 then
        if not selectAimedObject() then
            return false
        end
    end

    local center = getSelectionCenter()
    if not center then
        return false
    end

    clearSelectionControllers(false)
    STATE.selectionHolding = true
    STATE.holding = true
    STATE.target = STATE.selectionPrimary or STATE.selectionOrder[1]
    STATE.selectionCenter = center
    STATE.selectionAnchorOverride = nil
    STATE.anchoredWhileHolding = false
    STATE.holdDistance = (camera.CFrame.Position - center).Magnitude

    for _, root in ipairs(STATE.selectionOrder) do
        if root and root:IsDescendantOf(workspace) then
            prepareRootForMotion(root)

            STATE.selectionOffsets[root] = root.Position - center
            STATE.selectionRotations[root] = root.CFrame - root.Position

            local velocity = Instance.new("BodyVelocity")
            velocity.Name = "TelekinesisGroupVelocityV6"
            velocity.MaxForce = Vector3.new(1, 1, 1) * 1e7
            velocity.P = CONFIG.holdVelocityP
            velocity.Velocity = Vector3.zero
            velocity.Parent = root

            local gyro = Instance.new("BodyGyro")
            gyro.Name = "TelekinesisGroupGyroV6"
            gyro.MaxTorque = Vector3.new(1, 1, 1) * 1e8
            gyro.P = CONFIG.holdGyroP
            gyro.CFrame = root.CFrame
            gyro.Parent = root

            STATE.selectionControllers[root] = {
                Velocity = velocity,
                Gyro = gyro,
            }
        end
    end

    if STATE.selectionCount >= CONSTANTS.LARGE_SELECTION_WARNING then
        notify("LARGE SELECTION", tostring(STATE.selectionCount) .. " assemblies may be heavy on mobile", 2.2)
    else
        notify("GROUP HOLD", tostring(STATE.selectionCount) .. " object(s)", 1.1)
    end

    return true
end

local function releaseSelectionHold(stopVelocity)
    if not STATE.selectionHolding then
        return
    end

    for _, root in ipairs(STATE.selectionOrder) do
        if root and root:IsDescendantOf(workspace) and stopVelocity ~= false then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end

    local restoreOriginal = STATE.selectionAnchorOverride == nil
    local leaveAnchored = STATE.selectionAnchorOverride == true
    local leaveUnanchored = STATE.selectionAnchorOverride == false

    local backup = STATE.selectionAnchoredBackup
    clearSelectionControllers(false)

    for part, wasAnchored in pairs(backup) do
        if part and part:IsDescendantOf(workspace) then
            if leaveAnchored then
                part.Anchored = true
                part:SetAttribute("TelekinesisAnchored", true)
            elseif leaveUnanchored then
                part.Anchored = false
                part:SetAttribute("TelekinesisAnchored", nil)
            elseif restoreOriginal then
                part.Anchored = wasAnchored
            end
        end
    end

    STATE.selectionAnchoredBackup = {}
    STATE.holding = false
    STATE.target = nil
    STATE.anchoredWhileHolding = false
    STATE.selectionAnchorOverride = nil
end

local function updateSelectionHold()
    if not STATE.selectionHolding then
        return
    end

    local ray = getAimRay()
    local desiredCenter = ray.Origin + ray.Direction.Unit * STATE.holdDistance
    STATE.selectionCenter = desiredCenter

    for root, controller in pairs(STATE.selectionControllers) do
        if root and root:IsDescendantOf(workspace) and controller and controller.Velocity then
            local offset = STATE.selectionOffsets[root] or Vector3.zero
            local desired = desiredCenter + offset
            controller.Velocity.Velocity = (desired - root.Position) * CONFIG.holdResponse

            if controller.Gyro then
                controller.Gyro.CFrame = STATE.selectionRotations[root] or root.CFrame
            end
        end
    end
end

local function setSelectedAnchored(value)
    if STATE.selectionCount <= 0 then
        return 0
    end

    local changed = 0
    for _, root in ipairs(STATE.selectionOrder) do
        if root and root:IsDescendantOf(workspace) then
            for _, part in ipairs(getAssemblyParts(root)) do
                if STATE.telekinesisAnchored[part] == nil then STATE.telekinesisAnchored[part] = part.Anchored end
                part.Anchored = value
                part:SetAttribute("TelekinesisAnchored", value and true or nil)
                if value then
                    part.AssemblyLinearVelocity = Vector3.zero
                    part.AssemblyAngularVelocity = Vector3.zero
                end
                changed += 1
            end
        end
    end

    if STATE.selectionHolding then
        STATE.selectionAnchorOverride = value
        STATE.anchoredWhileHolding = value

        if value then
            for _, controller in pairs(STATE.selectionControllers) do
                pcall(function()
                    if controller.Velocity then controller.Velocity:Destroy() end
                    if controller.Gyro then controller.Gyro:Destroy() end
                end)
            end
            STATE.selectionControllers = {}
        else
            local center = getSelectionCenter()
            STATE.selectionCenter = center
            for _, root in ipairs(STATE.selectionOrder) do
                if root and root:IsDescendantOf(workspace) then
                    STATE.selectionOffsets[root] = center and (root.Position - center) or Vector3.zero
                    local velocity = Instance.new("BodyVelocity")
                    velocity.Name = "TelekinesisGroupVelocityV6"
                    velocity.MaxForce = Vector3.new(1, 1, 1) * 1e7
                    velocity.P = CONFIG.holdVelocityP
                    velocity.Parent = root
                    local gyro = Instance.new("BodyGyro")
                    gyro.Name = "TelekinesisGroupGyroV6"
                    gyro.MaxTorque = Vector3.new(1, 1, 1) * 1e8
                    gyro.P = CONFIG.holdGyroP
                    gyro.CFrame = root.CFrame
                    gyro.Parent = root
                    STATE.selectionControllers[root] = { Velocity = velocity, Gyro = gyro }
                end
            end
        end
    end

    return changed
end

local function throwSelected()
    if STATE.selectionCount <= 0 then
        return false
    end

    if STATE.selectionHolding then
        -- preserve current unanchored state for the throw
        local backup = STATE.selectionAnchoredBackup
        clearSelectionControllers(false)
        STATE.selectionAnchoredBackup = backup
        STATE.selectionHolding = false
    end

    local ray = getAimRay()
    local center = getSelectionCenter() or ray.Origin
    local count = 0

    for _, root in ipairs(STATE.selectionOrder) do
        if root and root:IsDescendantOf(workspace) then
            for _, part in ipairs(getAssemblyParts(root)) do
                if STATE.telekinesisAnchored[part] == nil then STATE.telekinesisAnchored[part] = part.Anchored end
                part.Anchored = false
                part:SetAttribute("TelekinesisAnchored", nil)
            end

            local velocity = Instance.new("BodyVelocity")
            velocity.Name = "TelekinesisMassThrowV6"
            velocity.MaxForce = Vector3.new(1, 1, 1) * 1e8
            velocity.P = CONFIG.holdVelocityP
            local direction = ray.Direction.Unit
            if CONFIG.throwMode == "RADIAL" then
                local radial = root.Position - center
                if radial.Magnitude > 0.01 then direction = radial.Unit end
            end
            local massScale = 1
            if CONFIG.massCompensation then
                local mass = math.max(root.AssemblyMass, 0.1)
                massScale = math.clamp(math.sqrt(mass / 10), 0.65, 2.25)
            end
            velocity.Velocity = direction * CONFIG.throwForce * massScale
            velocity.Parent = root
            trackTransient(velocity, 0.45)
            count += 1
        end
    end

    STATE.holding = false
    STATE.target = nil
    STATE.anchoredWhileHolding = false
    STATE.selectionAnchoredBackup = {}
    notify("MASS THROW", tostring(count) .. " object(s)", 1.2)
    return true
end

local function releaseHeldObject(stopVelocity)
    if STATE.selectionHolding then
        releaseSelectionHold(stopVelocity)
        STATE.rotationMode = false
        STATE.rotationPosition = nil
        STATE.rotationAccumulatorX = 0
        STATE.rotationAccumulatorY = 0
        rotationPositionLock.Parent = nil
        showCharacter()
        unfreezeCharacter()
        return
    end

    local target = STATE.target
    STATE.holding = false
    STATE.target = nil
    STATE.anchoredWhileHolding = false
    STATE.rotationMode = false
    STATE.rotationPosition = nil
    STATE.rotationAccumulatorX = 0
    STATE.rotationAccumulatorY = 0
    rotationPositionLock.Parent = nil
    disconnectPhysics()
    showCharacter()
    unfreezeCharacter()

    if stopVelocity ~= false and target and target:IsDescendantOf(workspace) then
        target.AssemblyLinearVelocity = Vector3.zero
        target.AssemblyAngularVelocity = Vector3.zero
    end
end

local function grabOrRelease()
    if not STATE.active or STATE.magnetActive or STATE.rotationMode then
        return
    end

    if STATE.holding or STATE.selectionHolding then
        releaseHeldObject(true)
        notify("RELEASED", "Selection released", 1)
        return
    end

    if STATE.selectionCount == 0 then
        if not selectAimedObject() then
            notify("NO TARGET", "Aim at a physical object", 1.2)
            return
        end
    end

    if not startSelectionHold() then
        notify("NO TARGET", "Could not control selection", 1.2)
    end
end

local function throwObject()
    if not STATE.active or STATE.magnetActive or STATE.rotationMode then
        return
    end

    if STATE.selectionCount > 0 then
        throwSelected()
        return
    end

    if not STATE.holding or not STATE.target then
        notify("NO TARGET", "Grab an object first", 1.2)
        return
    end
end

local function toggleAnchored()
    if not STATE.active or STATE.magnetActive or STATE.rotationMode then
        return
    end

    if STATE.selectionCount > 0 then
        local shouldAnchor = not STATE.anchoredWhileHolding
        local changed = setSelectedAnchored(shouldAnchor)
        STATE.anchoredWhileHolding = shouldAnchor
        notify(shouldAnchor and "ANCHORED" or "UNANCHORED", tostring(changed) .. " part(s)", 1)
        return
    end

    if not STATE.holding or not STATE.target then
        notify("NO TARGET", "Select an object first", 1.2)
        return
    end
end

local function updateDistance(delta)
    if STATE.rotationMode then
        return
    end

    if STATE.magnetActive then
        CONFIG.magnetRadius = math.clamp(
            CONFIG.magnetRadius + delta,
            CONFIG.magnetRadiusMin,
            CONFIG.magnetRadiusMax
        )
        queueSaveConfig()
        return
    end

    if not STATE.holding then
        return
    end

    STATE.holdDistance = math.clamp(
        STATE.holdDistance + delta,
        CONFIG.holdDistanceMin,
        CONFIG.holdDistanceMax
    )
end

local function changeThrowForce(amount)
    CONFIG.throwForce = math.clamp(
        CONFIG.throwForce + amount,
        CONFIG.throwForceMin,
        CONFIG.throwForceMax
    )
    queueSaveConfig()
end

local function changeMagnetForce(amount)
    CONFIG.magnetForce = math.clamp(
        CONFIG.magnetForce + amount,
        CONFIG.magnetForceMin,
        CONFIG.magnetForceMax
    )
    queueSaveConfig()
end

local function changeMagnetRadius(amount)
    CONFIG.magnetRadius = math.clamp(
        CONFIG.magnetRadius + amount,
        CONFIG.magnetRadiusMin,
        CONFIG.magnetRadiusMax
    )
    queueSaveConfig()
end

local function applyPreset(name)
    local preset = PRESETS[name]
    if not preset then
        return
    end

    for key, value in pairs(preset) do
        CONFIG[key] = value
    end
    CONFIG.preset = name
    queueSaveConfig()
    notify("PRESET " .. name, "Physics profile applied", 1.2)
end

local function cyclePreset(direction)
    local currentIndex = table.find(PRESET_ORDER, CONFIG.preset) or 2
    local nextIndex = ((currentIndex - 1 + direction) % #PRESET_ORDER) + 1
    applyPreset(PRESET_ORDER[nextIndex])
end

local function activateMagnet()
    if not STATE.active then
        return
    end
    if STATE.holding or STATE.selectionHolding then
        notify("MAGNET BLOCKED", "Release the held selection first", 1.4)
        return
    end
    if STATE.rotationMode then
        return
    end

    STATE.magnetActive = true
    STATE.lastMagnetScan = 0
    notify("MAGNET ON", CONFIG.magnetMode, 1)
end

local function deactivateMagnet()
    STATE.magnetActive = false
    restoreMagnetPhysics()
    notify("MAGNET OFF", "", 0.8)
end

local function toggleMagnet()
    if STATE.magnetActive then
        deactivateMagnet()
    else
        activateMagnet()
    end
end

local function toggleMagnetMode()
    CONFIG.magnetMode = cycleValue({ "ATTRACT", "REPEL", "ORBIT" }, CONFIG.magnetMode, 1)
    queueSaveConfig()
    notify("MAGNET MODE", CONFIG.magnetMode, 1)
end

local function massAnchorMagnet()
    if not STATE.active or not STATE.magnetActive then
        return
    end

    local count = 0
    for object in pairs(STATE.magnetObjects) do
        if object and object:IsDescendantOf(workspace) then
            for _, part in ipairs(getAssemblyParts(object)) do
                if STATE.telekinesisAnchored[part] == nil then
                    local original = STATE.magnetAnchoredBackup[part]
                    STATE.telekinesisAnchored[part] = original == nil and part.Anchored or original
                end
                part.Anchored = true
                part:SetAttribute("TelekinesisAnchored", true)
                STATE.magnetAnchoredBackup[part] = nil
                count += 1
            end

            local velocity = object:FindFirstChild("TelekinesisMagnetBV6")
            if velocity then
                velocity:Destroy()
            end
        end
    end

    STATE.magnetObjects = {}
    STATE.magnetCandidates = {}
    STATE.magnetAnchoredBackup = {}
    notify("MASS ANCHOR", tostring(count) .. " part(s)", 1.2)
end

local function resetRotationKeys()
    STATE.rotationKeys.up = false
    STATE.rotationKeys.down = false
    STATE.rotationKeys.left = false
    STATE.rotationKeys.right = false
end

local function enterRotationMode()
    if STATE.selectionCount > 1 then
        notify("ROTATION", "Multi-selection rotation is disabled; use PART/ASSEMBLY or select one object", 2)
        return
    end
    if not STATE.holding or not STATE.target then
        notify("ROTATION BLOCKED", "Grab one object first", 1.3)
        return
    end
    if STATE.anchoredWhileHolding then
        notify("ROTATION BLOCKED", "Unanchor the object first", 1.3)
        return
    end

    local target = STATE.target

    if STATE.selectionHolding then
        local controller = STATE.selectionControllers[target]
        if controller then
            pcall(function()
                if controller.Velocity then controller.Velocity:Destroy() end
                if controller.Gyro then controller.Gyro:Destroy() end
            end)
        end
        STATE.selectionControllers = {}
    end

    STATE.rotationMode = true
    STATE.rotationPosition = target.Position
    STATE.rotationOriginalCFrame = target.CFrame
    STATE.rotationAccumulatorX = 0
    STATE.rotationAccumulatorY = 0
    STATE.rotationAccumulatorZ = 0
    resetRotationKeys()

    bodyVelocity.Parent = nil
    bodyGyro.Parent = nil
    rotationPositionLock.Position = STATE.rotationPosition
    rotationPositionLock.Parent = target
    target.AssemblyLinearVelocity = Vector3.zero
    target.AssemblyAngularVelocity = Vector3.zero

    freezeCharacter()
    hideCharacter()
    notify("ROTATION MODE", tostring(CONFIG.rotationSpeed) .. " deg/s", 1.2)
end

local function exitRotationMode()
    if not STATE.rotationMode then
        return
    end

    local target = STATE.target
    STATE.rotationMode = false
    STATE.rotationPosition = nil
    STATE.rotationOriginalCFrame = nil
    STATE.rotationAccumulatorX = 0
    STATE.rotationAccumulatorY = 0
    resetRotationKeys()
    rotationPositionLock.Parent = nil
    showCharacter()
    unfreezeCharacter()

    if target and target:IsDescendantOf(workspace) and not STATE.anchoredWhileHolding then
        if STATE.selectionHolding then
            local center = getSelectionCenter() or target.Position
            STATE.selectionCenter = center
            STATE.selectionOffsets[target] = target.Position - center
            STATE.selectionRotations[target] = target.CFrame - target.Position

            local velocity = Instance.new("BodyVelocity")
            velocity.Name = "TelekinesisGroupVelocityV6"
            velocity.MaxForce = Vector3.new(1, 1, 1) * 1e7
            velocity.P = CONFIG.holdVelocityP
            velocity.Parent = target

            local gyro = Instance.new("BodyGyro")
            gyro.Name = "TelekinesisGroupGyroV6"
            gyro.MaxTorque = Vector3.new(1, 1, 1) * 1e8
            gyro.P = CONFIG.holdGyroP
            gyro.CFrame = target.CFrame
            gyro.Parent = target

            STATE.selectionControllers[target] = {
                Velocity = velocity,
                Gyro = gyro,
            }
        else
            connectPhysics(target)
            bodyGyro.CFrame = target.CFrame
        end
    end

    notify("ROTATION ENDED", "", 0.8)
end

local function toggleRotationMode()
    if STATE.rotationMode then
        exitRotationMode()
    else
        enterRotationMode()
    end
end

local function applyRotationStep(target, horizontalDegrees, verticalDegrees)
    local degrees = horizontalDegrees - verticalDegrees
    if degrees == 0 then return end
    local rotation
    if CONFIG.rotationAxis == "X" then rotation = CFrame.Angles(math.rad(degrees), 0, 0)
    elseif CONFIG.rotationAxis == "Z" then rotation = CFrame.Angles(0, 0, math.rad(degrees))
    else rotation = CFrame.Angles(0, math.rad(degrees), 0) end
    if CONFIG.rotationSpace == "WORLD" then
        local position = target.Position
        target.CFrame = CFrame.new(position) * rotation * (target.CFrame - position)
    else
        target.CFrame = target.CFrame * rotation
    end
end

local function resetRotation()
    if STATE.rotationMode and STATE.target and STATE.rotationOriginalCFrame then
        STATE.target.CFrame = STATE.rotationOriginalCFrame
        STATE.rotationPosition = STATE.rotationOriginalCFrame.Position
        return true
    end
    return false
end

local function updateRotation(dt)
    if not STATE.rotationMode or not STATE.target then
        return
    end

    local target = STATE.target
    if not target:IsDescendantOf(workspace) then
        releaseHeldObject(false)
        return
    end

    if STATE.rotationPosition then
        rotationPositionLock.Position = STATE.rotationPosition
    end

    local horizontal = (STATE.rotationKeys.right and 1 or 0) - (STATE.rotationKeys.left and 1 or 0)
    local vertical = (STATE.rotationKeys.up and 1 or 0) - (STATE.rotationKeys.down and 1 or 0)

    if horizontal == 0 and vertical == 0 then
        target.AssemblyLinearVelocity = Vector3.zero
        target.AssemblyAngularVelocity = Vector3.zero
        return
    end

    local stepDegrees = CONFIG.rotationSpeed * dt
    local snap = CONFIG.rotationSnap

    if snap <= 0 then
        applyRotationStep(target, horizontal * stepDegrees, vertical * stepDegrees)
    else
        STATE.rotationAccumulatorY += horizontal * stepDegrees
        STATE.rotationAccumulatorX += vertical * stepDegrees

        local hStep = 0
        local vStep = 0

        while math.abs(STATE.rotationAccumulatorY) >= snap do
            local direction = STATE.rotationAccumulatorY > 0 and 1 or -1
            hStep += snap * direction
            STATE.rotationAccumulatorY -= snap * direction
        end

        while math.abs(STATE.rotationAccumulatorX) >= snap do
            local direction = STATE.rotationAccumulatorX > 0 and 1 or -1
            vStep += snap * direction
            STATE.rotationAccumulatorX -= snap * direction
        end

        applyRotationStep(target, hStep, vStep)
    end

    target.AssemblyLinearVelocity = Vector3.zero
    target.AssemblyAngularVelocity = Vector3.zero
end

--------------------------------------------------
-- MAGNET ENGINE OPTIMIZADO
--------------------------------------------------

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude
overlapParams.RespectCanCollide = false

local function refreshOverlapFilter()
    local character = getCharacter()
    overlapParams.FilterDescendantsInstances = character and { character } or {}
    overlapParams.MaxParts = math.max(CONFIG.magnetMaxObjects * 3, 60)
end

local function scanMagnetCandidates()
    refreshOverlapFilter()

    local radius = CONFIG.magnetRadius
    local nearby
    local ok = pcall(function()
        if CONFIG.magnetShape == "BOX" then
            nearby = workspace:GetPartBoundsInBox(CFrame.new(surfacePosition), Vector3.new(radius * 2, radius * 2, radius * 2), overlapParams)
        else
            nearby = workspace:GetPartBoundsInRadius(surfacePosition, radius, overlapParams)
        end
    end)

    if not ok or type(nearby) ~= "table" then
        nearby = workspace:GetPartBoundsInBox(
            CFrame.new(surfacePosition),
            Vector3.new(radius * 2, radius * 2, radius * 2),
            overlapParams
        )
    end

    local candidates = {}
    local seenRoots = {}
    local count = 0

    for _, object in ipairs(nearby) do
        if count >= CONFIG.magnetMaxObjects then
            break
        end

        local filterPassed = (CONFIG.magnetIncludeTransparent or object.Transparency < 1)
            and (not CONFIG.magnetRequireCanCollide or object.CanCollide)
        if filterPassed and isEligiblePhysicalPart(object) and object ~= STATE.target then
            local root = getAssemblyRoot(object)
            if root and not seenRoots[root] then
                local distance = (surfacePosition - root.Position).Magnitude
                if (CONFIG.magnetShape == "BOX" or distance <= radius) and distance > 0.01 then
                    seenRoots[root] = true
                    candidates[root] = distance
                    count += 1
                end
            end
        end
    end

    STATE.magnetCandidates = candidates
    STATE.magnetScannedCount = count
end

local function prepareMagnetRoot(root)
    if not CONFIG.magnetAffectsAnchored then
        return not root.Anchored
    end

    for _, part in ipairs(getAssemblyParts(root)) do
        if STATE.magnetAnchoredBackup[part] == nil then
            STATE.magnetAnchoredBackup[part] = part.Anchored
        end
        part.Anchored = false
    end

    return true
end

local function restoreMagnetRootAnchors(root)
    if not root then
        return
    end

    for _, part in ipairs(getAssemblyParts(root)) do
        local wasAnchored = STATE.magnetAnchoredBackup[part]
        if wasAnchored ~= nil then
            if part and part:IsDescendantOf(workspace) then
                part.Anchored = wasAnchored
            end
            STATE.magnetAnchoredBackup[part] = nil
        end
    end
end

local function updateMagnetPhysics()
    local newObjects = {}

    for object, distance in pairs(STATE.magnetCandidates) do
        if object and object:IsDescendantOf(workspace) and prepareMagnetRoot(object) then
            local offset = surfacePosition - object.Position
            local magnitude = offset.Magnitude

            if magnitude > 0.01 and magnitude <= CONFIG.magnetRadius * 1.15 then
                local direction = offset.Unit
                if CONFIG.magnetMode == "REPEL" then
                    direction = -direction
                elseif CONFIG.magnetMode == "ORBIT" then
                    local tangent = Vector3.new(-offset.Z, 0, offset.X)
                    direction = tangent.Magnitude > 0.01 and (tangent.Unit + offset.Unit * 0.25).Unit or direction
                end

                local force = CONFIG.magnetForce * (CONFIG.magnetRadius / 30) ^ 1.35
                if CONFIG.magnetFalloff then
                    local ratio = math.clamp(distance / math.max(CONFIG.magnetRadius, 0.01), 0, 1)
                    force *= math.clamp(1 - ratio * 0.70, 0.25, 1)
                end

                local velocity = object:FindFirstChild("TelekinesisMagnetBV6")
                if not velocity then
                    velocity = Instance.new("BodyVelocity")
                    velocity.Name = "TelekinesisMagnetBV6"
                    velocity.MaxForce = Vector3.new(1, 1, 1) * 1e7
                    velocity.P = 15000
                    velocity.Parent = object
                end

                velocity.Velocity = direction * force
                newObjects[object] = true
            end
        end
    end

    for object in pairs(STATE.magnetObjects) do
        if not newObjects[object] then
            local velocity = object and object:FindFirstChild("TelekinesisMagnetBV6")
            if velocity then
                velocity:Destroy()
            end
            restoreMagnetRootAnchors(object)
        end
    end

    STATE.magnetObjects = newObjects
end

--------------------------------------------------
-- UI PAGES
--------------------------------------------------

local controlPage = pages.CONTROL
createSectionTitle(controlPage, "PRIMARY")

local grabButton = createButton(controlPage, "GRAB OBJECT", THEME.SuccessSoft, 52)
local actionRow = createRow(controlPage, 48)
local throwButton = createRowButton(actionRow, "THROW", THEME.DangerSoft)
local anchorButton = createRowButton(actionRow, "ANCHOR", THEME.Surface2)

local distanceStepper = createStepper(
    controlPage,
    "HOLD DISTANCE",
    function()
        return string.format("%.1f studs", STATE.holdDistance)
    end,
    function()
        updateDistance(-1)
    end,
    function()
        updateDistance(1)
    end
)

local forceStepper = createStepper(
    controlPage,
    "THROW FORCE",
    function()
        return tostring(math.floor(CONFIG.throwForce))
    end,
    function()
        changeThrowForce(-(isMobile and CONFIG.throwForceStepMobile or CONFIG.throwForceStepPC))
    end,
    function()
        changeThrowForce(isMobile and CONFIG.throwForceStepMobile or CONFIG.throwForceStepPC)
    end
)

local presetButton = createButton(controlPage, "PRESET: " .. CONFIG.preset, THEME.AccentSoft, 46)

local selectionPage = pages.SELECTION
createSectionTitle(selectionPage, "MULTI / ALL OBJECTS")
local scopeButton = createButton(selectionPage, "SCOPE: " .. CONFIG.selectionScope, THEME.AccentSoft, 46)

local selectionRow = createRow(selectionPage, 48)
local selectAimedButton = createRowButton(selectionRow, "SELECT AIMED", THEME.Surface2)
local selectAllButton = createRowButton(selectionRow, "SELECT ALL", THEME.Purple)

local selectionHoldRow = createRow(selectionPage, 48)
local holdSelectedButton = createRowButton(selectionHoldRow, "HOLD SELECTED", THEME.SuccessSoft)
local clearSelectionButton = createRowButton(selectionHoldRow, "CLEAR", THEME.Surface2)

local selectionActionRow = createRow(selectionPage, 48)
local throwSelectedButton = createRowButton(selectionActionRow, "THROW ALL", THEME.DangerSoft)
local anchorSelectedButton = createRowButton(selectionActionRow, "ANCHOR ALL", THEME.Warning)

local selectionActionRow2 = createRow(selectionPage, 48)
local unanchorSelectedButton = createRowButton(selectionActionRow2, "UNANCHOR ALL", THEME.Surface2)
local refreshSelectionButton = createRowButton(selectionActionRow2, "RESELECT AIM", THEME.AccentSoft)

local selectionInfo = Instance.new("TextLabel")
selectionInfo.Size = UDim2.new(1, -4, 0, 58)
selectionInfo.BackgroundColor3 = THEME.Surface
selectionInfo.BackgroundTransparency = CONFIG.uiTransparency
selectionInfo.BorderSizePixel = 0
selectionInfo.Font = Enum.Font.Code
selectionInfo.TextSize = 10
selectionInfo.TextColor3 = THEME.Muted
selectionInfo.TextXAlignment = Enum.TextXAlignment.Left
selectionInfo.TextYAlignment = Enum.TextYAlignment.Top
selectionInfo.TextWrapped = true
selectionInfo.Text = ""
selectionInfo.Parent = selectionPage
makeCorner(selectionInfo, 11)
makeStroke(selectionInfo, 0.35)
makePadding(selectionInfo, 10)
UI.selectionInfo = selectionInfo

local advancedSelectionRow = createRow(selectionPage, 48)
local selectNearbyButton = createRowButton(advancedSelectionRow, "SELECT NEARBY", THEME.AccentSoft)
local invertSelectionButton = createRowButton(advancedSelectionRow, "INVERT", THEME.Purple)
local cancelSelectionButton = createButton(selectionPage, "CANCEL SCAN", THEME.DangerSoft, 44)
cancelSelectionButton.Visible = false
local selectionRadiusButton = createButton(selectionPage, "RADIUS: " .. CONFIG.selectionRadius, THEME.Surface2, 44)
local selectionTypeButton = createButton(selectionPage, "FILTER: " .. CONFIG.selectionType, THEME.Surface2, 44)
local maxSelectionButton = createButton(selectionPage, "MAX SELECTION: " .. (CONFIG.maxSelection == 0 and "UNLIMITED" or CONFIG.maxSelection), THEME.Surface2, 44)
local selectionLockToggle = createToggle(selectionPage, "LOCK SELECTION", function() return CONFIG.selectionLocked end, function()
    CONFIG.selectionLocked = not CONFIG.selectionLocked
    queueSaveConfig()
end)
local pivotButton = createButton(selectionPage, "GROUP PIVOT: " .. CONFIG.groupPivot, THEME.Surface2, 44)
local throwModeButton = createButton(selectionPage, "THROW MODE: " .. CONFIG.throwMode, THEME.Surface2, 44)
local massCompensationToggle = createToggle(selectionPage, "MASS COMPENSATION", function() return CONFIG.massCompensation end, function()
    CONFIG.massCompensation = not CONFIG.massCompensation
    queueSaveConfig()
end)

createSectionTitle(controlPage, "QUICK INFO")
local controlInfo = Instance.new("TextLabel")
controlInfo.Size = UDim2.new(1, -4, 0, 72)
controlInfo.BackgroundColor3 = THEME.Surface
controlInfo.BackgroundTransparency = CONFIG.uiTransparency
controlInfo.BorderSizePixel = 0
controlInfo.Font = Enum.Font.Code
controlInfo.TextSize = 10
controlInfo.TextColor3 = THEME.Muted
controlInfo.TextXAlignment = Enum.TextXAlignment.Left
controlInfo.TextYAlignment = Enum.TextYAlignment.Top
controlInfo.TextWrapped = true
controlInfo.Text = ""
controlInfo.Parent = controlPage
makeCorner(controlInfo, 11)
makeStroke(controlInfo, 0.35)
makePadding(controlInfo, 10)
UI.controlInfo = controlInfo

local magnetPage = pages.MAGNET
createSectionTitle(magnetPage, "MAGNET ENGINE")
local magnetToggleButton = createButton(magnetPage, "MAGNET: OFF", THEME.Surface, 52)
local magnetModeButton = createButton(magnetPage, "MODE: " .. CONFIG.magnetMode, THEME.AccentSoft, 46)
local magnetShapeButton = createButton(magnetPage, "SHAPE: " .. CONFIG.magnetShape, THEME.Surface2, 44)
local magnetCenterButton = createButton(magnetPage, "CENTER: " .. CONFIG.magnetCenter, THEME.Surface2, 44)

local magnetForceStepper = createStepper(
    magnetPage,
    "MAGNET FORCE",
    function()
        return tostring(math.floor(CONFIG.magnetForce))
    end,
    function()
        changeMagnetForce(-CONFIG.magnetForceStep)
    end,
    function()
        changeMagnetForce(CONFIG.magnetForceStep)
    end
)

local magnetRadiusStepper = createStepper(
    magnetPage,
    "MAGNET RADIUS",
    function()
        return tostring(math.floor(CONFIG.magnetRadius)) .. " studs"
    end,
    function()
        changeMagnetRadius(-CONFIG.magnetRadiusStep)
    end,
    function()
        changeMagnetRadius(CONFIG.magnetRadiusStep)
    end
)

local magnetOptionsRow = createRow(magnetPage, 48)
local falloffButton = createRowButton(magnetOptionsRow, CONFIG.magnetFalloff and "FALLOFF: ON" or "FALLOFF: OFF", THEME.Surface2)
local maxObjectsButton = createRowButton(magnetOptionsRow, "MAX: " .. CONFIG.magnetMaxObjects, THEME.Surface2)
local magnetAnchoredButton = createButton(
    magnetPage,
    CONFIG.magnetAffectsAnchored and "ANCHORED OBJECTS: ON" or "ANCHORED OBJECTS: OFF",
    THEME.Surface2,
    46
)
local magnetTransparentToggle = createToggle(magnetPage, "INCLUDE TRANSPARENT", function() return CONFIG.magnetIncludeTransparent end, function()
    CONFIG.magnetIncludeTransparent = not CONFIG.magnetIncludeTransparent; queueSaveConfig()
end)
local magnetCollideToggle = createToggle(magnetPage, "REQUIRE CAN COLLIDE", function() return CONFIG.magnetRequireCanCollide end, function()
    CONFIG.magnetRequireCanCollide = not CONFIG.magnetRequireCanCollide; queueSaveConfig()
end)
local massAnchorButton = createButton(magnetPage, "ANCHOR ALL TRACKED", THEME.Warning, 46)

local magnetInfo = Instance.new("TextLabel")
magnetInfo.Size = UDim2.new(1, -4, 0, 58)
magnetInfo.BackgroundColor3 = THEME.Surface
magnetInfo.BackgroundTransparency = CONFIG.uiTransparency
magnetInfo.BorderSizePixel = 0
magnetInfo.Font = Enum.Font.Code
magnetInfo.TextSize = 10
magnetInfo.TextColor3 = THEME.Muted
magnetInfo.TextXAlignment = Enum.TextXAlignment.Left
magnetInfo.TextYAlignment = Enum.TextYAlignment.Top
magnetInfo.TextWrapped = true
magnetInfo.Parent = magnetPage
makeCorner(magnetInfo, 11)
makeStroke(magnetInfo, 0.35)
makePadding(magnetInfo, 10)
UI.magnetInfo = magnetInfo

local rotatePage = pages.ROTATION
createSectionTitle(rotatePage, "ROTATION CONTROL")
local rotationToggleButton = createButton(rotatePage, "ENTER ROTATION", THEME.Purple, 50)

local rotationPad = Instance.new("Frame")
rotationPad.Size = UDim2.new(1, -4, 0, 150)
rotationPad.BackgroundColor3 = THEME.Surface
rotationPad.BackgroundTransparency = CONFIG.uiTransparency
rotationPad.BorderSizePixel = 0
rotationPad.Parent = rotatePage
makeCorner(rotationPad, 11)
makeStroke(rotationPad, 0.35)

local function createPadButton(text, position)
    local button = Instance.new("TextButton")
    button.Size = UDim2.fromOffset(58, 48)
    button.Position = position
    button.BackgroundColor3 = THEME.Surface2
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Font = Enum.Font.GothamBold
    button.TextSize = 18
    button.TextColor3 = THEME.Text
    button.Text = text
    button.Parent = rotationPad
    makeCorner(button, 10)
    return button
end

local rotateUp = createPadButton("▲", UDim2.new(0.5, -29, 0, 10))
local rotateLeft = createPadButton("◀", UDim2.new(0.5, -94, 0, 62))
local rotateRight = createPadButton("▶", UDim2.new(0.5, 36, 0, 62))
local rotateDown = createPadButton("▼", UDim2.new(0.5, -29, 0, 92))

local rotationSpeedStepper = createStepper(
    rotatePage,
    "ROTATION SPEED",
    function()
        return tostring(math.floor(CONFIG.rotationSpeed)) .. " deg/s"
    end,
    function()
        CONFIG.rotationSpeed = math.clamp(CONFIG.rotationSpeed - CONFIG.rotationSpeedStep, CONFIG.rotationSpeedMin, CONFIG.rotationSpeedMax)
        queueSaveConfig()
    end,
    function()
        CONFIG.rotationSpeed = math.clamp(CONFIG.rotationSpeed + CONFIG.rotationSpeedStep, CONFIG.rotationSpeedMin, CONFIG.rotationSpeedMax)
        queueSaveConfig()
    end
)

local snapButton = createButton(rotatePage, "SNAP: " .. (CONFIG.rotationSnap == 0 and "OFF" or tostring(CONFIG.rotationSnap) .. "°"), THEME.Surface2, 46)
local rotationAxisButton = createButton(rotatePage, "AXIS: " .. CONFIG.rotationAxis, THEME.Surface2, 44)
local rotationSpaceButton = createButton(rotatePage, "SPACE: " .. CONFIG.rotationSpace, THEME.Surface2, 44)
local resetRotationButton = createButton(rotatePage, "RESET ROTATION", THEME.Warning, 44)

local settingsPage = pages.SETTINGS
createSectionTitle(settingsPage, "VISUAL / UX")

local highlightsToggle = createToggle(settingsPage, "HIGHLIGHTS", function()
    return CONFIG.showHighlights
end, function()
    CONFIG.showHighlights = not CONFIG.showHighlights
    refreshSelectionHighlights()
    queueSaveConfig()
end)

local pointerToggle = createToggle(settingsPage, "MOBILE POINTER", function()
    return CONFIG.showPointer
end, function()
    CONFIG.showPointer = not CONFIG.showPointer
    queueSaveConfig()
end)

local animationsToggle = createToggle(settingsPage, "ANIMATIONS", function()
    return CONFIG.animations
end, function()
    CONFIG.animations = not CONFIG.animations
    queueSaveConfig()
end)

local snapBubbleToggle = createToggle(settingsPage, "SNAP BUBBLE TO EDGE", function()
    return CONFIG.snapBubble
end, function()
    CONFIG.snapBubble = not CONFIG.snapBubble
    queueSaveConfig()
end)

local scaleButton = createButton(settingsPage, "UI SCALE: " .. math.floor(CONFIG.uiScale * 100) .. "%", THEME.Surface2, 46)
local transparencyButton = createButton(settingsPage, "TRANSPARENCY: " .. math.floor(CONFIG.uiTransparency * 100) .. "%", THEME.Surface2, 46)
local performanceButton = createButton(settingsPage, "PERFORMANCE: " .. CONFIG.performanceMode, THEME.Surface2, 46)
local resetSettingsButton = createButton(settingsPage, "RESET UI SETTINGS", THEME.Warning, 46)
local resetAllButton = createButton(settingsPage, "RESET ALL SETTINGS", THEME.DangerSoft, 46)
local unloadButton = createButton(settingsPage, "UNLOAD TELEKINESIS V6", THEME.DangerSoft, 48)

--------------------------------------------------
-- MOBILE POINTER
--------------------------------------------------

if isMobile then
    local fakePointer = Instance.new("Frame")
    fakePointer.Name = "FakePointer"
    fakePointer.Size = UDim2.fromOffset(34, 34)
    fakePointer.Position = UDim2.new(0.5, -17, 0.40, -17)
    fakePointer.BackgroundColor3 = THEME.Accent
    fakePointer.BackgroundTransparency = 0.35
    fakePointer.BorderSizePixel = 0
    fakePointer.Active = true
    fakePointer.ZIndex = 300
    fakePointer.Parent = gui
    makeCorner(fakePointer, 17)
    makeStroke(fakePointer, 0.18, Color3.new(1, 1, 1))

    local dot = Instance.new("Frame")
    dot.Size = UDim2.fromOffset(6, 6)
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.Position = UDim2.fromScale(0.5, 0.5)
    dot.BackgroundColor3 = Color3.new(1, 1, 1)
    dot.BorderSizePixel = 0
    dot.Parent = fakePointer
    makeCorner(dot, 3)

    UI.fakePointer = fakePointer
end

--------------------------------------------------
-- MINIMIZED BUBBLE
--------------------------------------------------

local bubble = Instance.new("TextButton")
bubble.Name = "Bubble"
bubble.AnchorPoint = Vector2.new(0.5, 0.5)
bubble.Position = UDim2.fromScale(CONFIG.bubbleX, CONFIG.bubbleY)
bubble.Size = UDim2.fromOffset(72, 46)
bubble.BackgroundColor3 = THEME.Surface
bubble.BorderSizePixel = 0
bubble.AutoButtonColor = false
bubble.Font = Enum.Font.GothamBold
bubble.TextSize = 12
bubble.TextColor3 = THEME.Text
bubble.Text = "TK • V6"
bubble.Visible = false
bubble.ZIndex = 500
bubble.Parent = gui
makeCorner(bubble, 23)
makeStroke(bubble, 0.15, THEME.Accent)
UI.bubble = bubble

--------------------------------------------------
-- UI MODE / RESPONSIVE
--------------------------------------------------

local function updateStoredPositionFromAbsolute(object, isBubble)
    local viewport = camera.ViewportSize
    if viewport.X <= 0 or viewport.Y <= 0 then
        return
    end
    local center = object.AbsolutePosition + object.AbsoluteSize * 0.5
    local x = clamp01(center.X / viewport.X)
    local y = clamp01(center.Y / viewport.Y)
    if isBubble then
        CONFIG.bubbleX = x
        CONFIG.bubbleY = y
    else
        CONFIG.panelX = x
        CONFIG.panelY = y
    end
    queueSaveConfig()
end

local function clampObjectToViewport(object, edgePadding)
    local viewport = camera.ViewportSize
    local size = object.AbsoluteSize
    local pos = object.AbsolutePosition
    local padding = edgePadding or CONSTANTS.EDGE_PADDING

    local minX = padding
    local minY = padding
    local maxX = math.max(minX, viewport.X - size.X - padding)
    local maxY = math.max(minY, viewport.Y - size.Y - padding)

    local x = math.clamp(pos.X, minX, maxX)
    local y = math.clamp(pos.Y, minY, maxY)

    object.AnchorPoint = Vector2.zero
    object.Position = UDim2.fromOffset(x, y)
end

local function restoreNormalizedPosition(object, x, y)
    object.AnchorPoint = Vector2.new(0.5, 0.5)
    object.Position = UDim2.fromScale(x, y)
end

local function applyResponsiveLayout()
    camera = workspace.CurrentCamera or camera
    local viewport = camera.ViewportSize
    local scale = math.max(CONFIG.uiScale, 0.01)
    local availableWidth = viewport.X * (isMobile and 0.94 or 0.78) / scale
    local availableHeight = viewport.Y * (isMobile and 0.82 or 0.80) / scale
    local width = math.min(540, math.max(280, availableWidth))
    local height = math.min(590, math.max(340, availableHeight))
    window.Size = UDim2.fromOffset(width, height)
    uiScale.Scale = CONFIG.uiScale

    local generation = TASK_GENERATION
    task.defer(function()
        if not STATE.active or generation ~= TASK_GENERATION then
            return
        end
        clampObjectToViewport(window, CONSTANTS.EDGE_PADDING)
        clampObjectToViewport(bubble, CONSTANTS.EDGE_PADDING)
    end)
end

local function setTab(tabName)
    if not pages[tabName] then
        return
    end
    CONFIG.activeTab = tabName

    for name, page in pairs(pages) do
        local selected = name == tabName
        page.Visible = selected
        local button = tabButtons[name]
        button.BackgroundColor3 = selected and THEME.AccentSoft or THEME.Surface
        button.TextColor3 = selected and THEME.Accent or THEME.Muted
    end

    queueSaveConfig()
end

local function setInterfaceVisible(visible)
    STATE.guiVisible = visible
    STATE.minimized = not visible

    if visible then
        bubble.Visible = false
        window.Visible = true
        window.BackgroundTransparency = 1
        tween(window, CONSTANTS.TWEEN_FAST, { BackgroundTransparency = CONFIG.uiTransparency })
    else
        window.Visible = false
        bubble.Visible = true
        clampObjectToViewport(bubble, CONSTANTS.EDGE_PADDING)
    end

    if UI.fakePointer then
        UI.fakePointer.Visible = visible and CONFIG.showPointer
    end
end

local function toggleInterface()
    setInterfaceVisible(not STATE.guiVisible)
end

--------------------------------------------------
-- DRAG CONTROLLER
--------------------------------------------------

local function makeDraggable(object, dragHandle, onTap, isBubble)
    local dragging = false
    local activeInput = nil
    local startInputPosition = nil
    local startObjectPosition = nil
    local moved = false

    connect(dragHandle.InputBegan, function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        dragging = true
        activeInput = input
        startInputPosition = input.Position
        startObjectPosition = object.AbsolutePosition
        moved = false
    end)

    connect(UserInputService.InputChanged, function(input)
        if not dragging or not startInputPosition then
            return
        end

        local validChange = input == activeInput
            or input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch

        if not validChange then
            return
        end

        local delta = input.Position - startInputPosition
        if delta.Magnitude >= CONSTANTS.DRAG_THRESHOLD then
            moved = true
        end

        if moved then
            object.AnchorPoint = Vector2.zero
            object.Position = UDim2.fromOffset(
                startObjectPosition.X + delta.X,
                startObjectPosition.Y + delta.Y
            )
            clampObjectToViewport(object, CONSTANTS.EDGE_PADDING)
        end
    end)

    connect(UserInputService.InputEnded, function(input)
        if not dragging or input ~= activeInput then
            return
        end

        dragging = false
        activeInput = nil

        if moved then
            clampObjectToViewport(object, CONSTANTS.EDGE_PADDING)

            if isBubble and CONFIG.snapBubble then
                local viewport = camera.ViewportSize
                local size = object.AbsoluteSize
                local pos = object.AbsolutePosition
                local centerX = pos.X + size.X * 0.5
                local targetX
                if centerX < viewport.X * 0.5 then
                    targetX = CONSTANTS.EDGE_PADDING
                else
                    targetX = viewport.X - size.X - CONSTANTS.EDGE_PADDING
                end
                tween(object, CONSTANTS.TWEEN_NORMAL, {
                    Position = UDim2.fromOffset(targetX, pos.Y),
                })
                local generation = TASK_GENERATION
                task.delay(CONSTANTS.TWEEN_NORMAL + 0.02, function()
                    if STATE.active and generation == TASK_GENERATION and object.Parent then
                        updateStoredPositionFromAbsolute(object, true)
                    end
                end)
            else
                updateStoredPositionFromAbsolute(object, isBubble)
            end
        elseif onTap then
            onTap()
        end
    end)
end

makeDraggable(window, headerDragHandle, nil, false)
makeDraggable(bubble, bubble, function()
    setInterfaceVisible(true)
end, true)

--------------------------------------------------
-- MOBILE POINTER DRAG
--------------------------------------------------

if UI.fakePointer then
    connect(UI.fakePointer.InputBegan, function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        STATE.pointerTouch = input
        STATE.pointerTouchStart = input.Position
        STATE.pointerDragStarted = false
    end)

    connect(UserInputService.InputChanged, function(input)
        if input ~= STATE.pointerTouch or not STATE.pointerTouchStart then
            return
        end

        local delta = input.Position - STATE.pointerTouchStart
        if not STATE.pointerDragStarted and delta.Magnitude < CONSTANTS.POINTER_DRAG_THRESHOLD then
            return
        end
        STATE.pointerDragStarted = true

        local viewport = camera.ViewportSize
        local x = math.clamp(input.Position.X, 18, viewport.X - 18)
        local y = math.clamp(input.Position.Y, 18, viewport.Y - 18)
        UI.fakePointer.Position = UDim2.fromOffset(x - 17, y - 17)
    end)

    connect(UserInputService.InputEnded, function(input)
        if input == STATE.pointerTouch then
            STATE.pointerTouch = nil
            STATE.pointerTouchStart = nil
            STATE.pointerDragStarted = false
        end
    end)
end

--------------------------------------------------
-- BUTTON BINDINGS
--------------------------------------------------

for _, tabName in ipairs(tabs) do
    connect(tabButtons[tabName].Activated, function()
        setTab(tabName)
    end)
end

connect(minimizeButton.Activated, function()
    setInterfaceVisible(false)
end)

connect(grabButton.Activated, grabOrRelease)
connect(throwButton.Activated, throwObject)
connect(anchorButton.Activated, toggleAnchored)
connect(presetButton.Activated, function()
    cyclePreset(1)
end)

local SCOPE_ORDER = { "PART", "ASSEMBLY", "MODEL" }

connect(scopeButton.Activated, function()
    if STATE.selectionHolding then notify("BUSY", "Release selection before changing scope", 1.2); return end
    clearSelection()
    CONFIG.selectionScope = cycleValue(SCOPE_ORDER, CONFIG.selectionScope, 1)
    scopeButton.Text = "SCOPE: " .. CONFIG.selectionScope
    queueSaveConfig()
end)

connect(selectAimedButton.Activated, function()
    if selectAimedObject(true) then
        notify("SELECTED", tostring(STATE.selectionCount) .. " object(s)", 1)
    else
        notify("NO TARGET", "Aim at a physical object", 1.2)
    end
end)

connect(refreshSelectionButton.Activated, function()
    if selectAimedObject(true) then
        notify("RESELECTED", tostring(STATE.selectionCount) .. " object(s)", 1)
    end
end)

connect(selectAllButton.Activated, function()
    if STATE.selectionBusy then cancelSelectionScan(); notify("SELECTION CANCELED", "", 0.8); return end
    selectAllObjectsAsync(function(count)
        notify("SELECT ALL", tostring(count) .. " physical object(s)", 1.8)
    end)
end)

connect(cancelSelectionButton.Activated, function()
    if cancelSelectionScan() then notify("SELECTION CANCELED", "", 0.8) end
end)
connect(selectNearbyButton.Activated, function()
    selectNearbyAsync(function(count) notify("SELECT NEARBY", tostring(count) .. " object(s)", 1.2) end)
end)
connect(invertSelectionButton.Activated, function()
    invertSelectionAsync(function(count) notify("INVERTED", tostring(count) .. " object(s)", 1.2) end)
end)
connect(selectionRadiusButton.Activated, function()
    CONFIG.selectionRadius = cycleValue(SELECTION_RADIUS_ORDER, CONFIG.selectionRadius, 1); queueSaveConfig()
end)
connect(selectionTypeButton.Activated, function()
    CONFIG.selectionType = cycleValue(SELECTION_TYPE_ORDER, CONFIG.selectionType, 1); queueSaveConfig()
end)
connect(maxSelectionButton.Activated, function()
    CONFIG.maxSelection = cycleValue(MAX_SELECTION_ORDER, CONFIG.maxSelection, 1); queueSaveConfig()
end)
connect(pivotButton.Activated, function()
    CONFIG.groupPivot = cycleValue({ "CENTER", "ACTIVE", "AVERAGE" }, CONFIG.groupPivot, 1); queueSaveConfig()
end)
connect(throwModeButton.Activated, function()
    CONFIG.throwMode = CONFIG.throwMode == "PARALLEL" and "RADIAL" or "PARALLEL"; queueSaveConfig()
end)

connect(clearSelectionButton.Activated, function()
    if clearSelection() then
        notify("SELECTION CLEARED", "", 0.8)
    else
        notify("BUSY", "Release held selection first", 1.2)
    end
end)

connect(holdSelectedButton.Activated, function()
    if STATE.selectionHolding then
        releaseSelectionHold(true)
        notify("GROUP RELEASED", "", 0.8)
    elseif not startSelectionHold() then
        notify("NO SELECTION", "Select one or more objects first", 1.2)
    end
end)

connect(throwSelectedButton.Activated, function()
    if not throwSelected() then
        notify("NO SELECTION", "Select one or more objects first", 1.2)
    end
end)

connect(anchorSelectedButton.Activated, function()
    local changed = setSelectedAnchored(true)
    if changed > 0 then
        notify("ANCHOR ALL", tostring(changed) .. " part(s)", 1)
    else
        notify("NO SELECTION", "", 1)
    end
end)

connect(unanchorSelectedButton.Activated, function()
    local changed = setSelectedAnchored(false)
    if changed > 0 then
        notify("UNANCHOR ALL", tostring(changed) .. " part(s)", 1)
    else
        notify("NO SELECTION", "", 1)
    end
end)

connect(magnetToggleButton.Activated, toggleMagnet)
connect(magnetModeButton.Activated, toggleMagnetMode)
connect(magnetShapeButton.Activated, function()
    CONFIG.magnetShape = CONFIG.magnetShape == "SPHERE" and "BOX" or "SPHERE"; queueSaveConfig()
end)
connect(magnetCenterButton.Activated, function()
    CONFIG.magnetCenter = cycleValue({ "AIM POINT", "PLAYER", "ACTIVE TARGET" }, CONFIG.magnetCenter, 1); queueSaveConfig()
end)
connect(falloffButton.Activated, function()
    CONFIG.magnetFalloff = not CONFIG.magnetFalloff
    queueSaveConfig()
end)
connect(maxObjectsButton.Activated, function()
    CONFIG.magnetMaxObjects = cycleValue(MAX_OBJECTS_ORDER, CONFIG.magnetMaxObjects, 1)
    queueSaveConfig()
end)
connect(magnetAnchoredButton.Activated, function()
    CONFIG.magnetAffectsAnchored = not CONFIG.magnetAffectsAnchored
    magnetAnchoredButton.Text = CONFIG.magnetAffectsAnchored and "ANCHORED OBJECTS: ON" or "ANCHORED OBJECTS: OFF"
    queueSaveConfig()
end)
connect(massAnchorButton.Activated, massAnchorMagnet)

connect(rotationToggleButton.Activated, toggleRotationMode)
connect(snapButton.Activated, function()
    CONFIG.rotationSnap = cycleValue(SNAP_ORDER, CONFIG.rotationSnap, 1)
    queueSaveConfig()
end)
connect(rotationAxisButton.Activated, function()
    CONFIG.rotationAxis = cycleValue({ "X", "Y", "Z" }, CONFIG.rotationAxis, 1); queueSaveConfig()
end)
connect(rotationSpaceButton.Activated, function()
    CONFIG.rotationSpace = CONFIG.rotationSpace == "LOCAL" and "WORLD" or "LOCAL"; queueSaveConfig()
end)
connect(resetRotationButton.Activated, function()
    local restored = resetRotation()
    notify(restored and "ROTATION RESET" or "ROTATION BLOCKED", restored and "Original orientation restored" or "Enter rotation mode first", 1.1)
end)

local function bindHoldButton(button, field)
    local activeInput
    connect(button.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            activeInput = input
            STATE.rotationKeys[field] = true
        end
    end)
    connect(button.InputEnded, function(input)
        if input == activeInput then
            activeInput = nil
            STATE.rotationKeys[field] = false
        end
    end)
end

bindHoldButton(rotateUp, "up")
bindHoldButton(rotateDown, "down")
bindHoldButton(rotateLeft, "left")
bindHoldButton(rotateRight, "right")

connect(scaleButton.Activated, function()
    CONFIG.uiScale = cycleValue(SCALE_ORDER, CONFIG.uiScale, 1)
    uiScale.Scale = CONFIG.uiScale
    scaleButton.Text = "UI SCALE: " .. math.floor(CONFIG.uiScale * 100) .. "%"
    queueSaveConfig()
end)

connect(transparencyButton.Activated, function()
    CONFIG.uiTransparency = cycleValue(TRANSPARENCY_ORDER, CONFIG.uiTransparency, 1)
    transparencyButton.Text = "TRANSPARENCY: " .. math.floor(CONFIG.uiTransparency * 100) .. "%"
    window.BackgroundTransparency = CONFIG.uiTransparency
    inspector.BackgroundTransparency = CONFIG.uiTransparency
    queueSaveConfig()
end)

connect(performanceButton.Activated, function()
    CONFIG.performanceMode = cycleValue({ "AUTO", "QUALITY", "BALANCED", "LOW" }, CONFIG.performanceMode, 1)
    queueSaveConfig()
end)

connect(resetSettingsButton.Activated, function()
    CONFIG.uiScale = DEFAULT_CONFIG.uiScale
    CONFIG.uiTransparency = DEFAULT_CONFIG.uiTransparency
    CONFIG.animations = DEFAULT_CONFIG.animations
    CONFIG.snapBubble = DEFAULT_CONFIG.snapBubble
    CONFIG.showHighlights = DEFAULT_CONFIG.showHighlights
    CONFIG.showPointer = DEFAULT_CONFIG.showPointer
    CONFIG.panelX = DEFAULT_CONFIG.panelX
    CONFIG.panelY = DEFAULT_CONFIG.panelY
    CONFIG.bubbleX = DEFAULT_CONFIG.bubbleX
    CONFIG.bubbleY = DEFAULT_CONFIG.bubbleY
    CONFIG.activeTab = "CONTROL"

    restoreNormalizedPosition(window, CONFIG.panelX, CONFIG.panelY)
    restoreNormalizedPosition(bubble, CONFIG.bubbleX, CONFIG.bubbleY)
    uiScale.Scale = CONFIG.uiScale
    window.BackgroundTransparency = CONFIG.uiTransparency
    scaleButton.Text = "UI SCALE: " .. math.floor(CONFIG.uiScale * 100) .. "%"
    transparencyButton.Text = "TRANSPARENCY: " .. math.floor(CONFIG.uiTransparency * 100) .. "%"
    setTab("CONTROL")
    queueSaveConfig()
    notify("UI RESET", "Visual settings restored", 1.2)
end)

local resetAllConfirmUntil = 0
connect(resetAllButton.Activated, function()
    if os.clock() > resetAllConfirmUntil then
        resetAllConfirmUntil = os.clock() + 3
        resetAllButton.Text = "CONFIRM RESET ALL?"
        notify("CONFIRM", "Tap again within 3 seconds", 1.5)
        return
    end
    if STATE.selectionHolding then releaseSelectionHold(true) end
    if STATE.magnetActive then deactivateMagnet() end
    clearSelection()
    for key, value in pairs(DEFAULT_CONFIG) do CONFIG[key] = value end
    STATE.holdDistance = CONFIG.holdDistanceDefault
    restoreNormalizedPosition(window, CONFIG.panelX, CONFIG.panelY)
    restoreNormalizedPosition(bubble, CONFIG.bubbleX, CONFIG.bubbleY)
    applyResponsiveLayout(); setTab("CONTROL"); queueSaveConfig()
    resetAllButton.Text = "RESET ALL SETTINGS"
    notify("ALL SETTINGS RESET", "Defaults restored", 1.3)
end)

--------------------------------------------------
-- UI REFRESH
--------------------------------------------------

local function refreshHighlights()
    local allowed = CONFIG.showHighlights and STATE.guiVisible and STATE.active
    if not allowed then
        highlightHolding.Enabled = false
        highlightLooking.Enabled = false
        for _, highlight in ipairs(STATE.selectionHighlights) do
            highlight.Enabled = false
        end
        return
    end

    for _, highlight in ipairs(STATE.selectionHighlights) do
        highlight.Enabled = true
    end

    if STATE.holding and STATE.target then
        highlightHolding.Enabled = true
        highlightHolding.Adornee = STATE.target
        highlightLooking.Enabled = false
        highlightLooking.Adornee = nil
        return
    end

    highlightHolding.Enabled = false
    highlightHolding.Adornee = nil

    local hit = raycastNormal()
    if hit
        and hit:IsA("BasePart")
        and not isPlayerPart(hit) then
        highlightLooking.Enabled = true
        highlightLooking.Adornee = hit
    else
        highlightLooking.Enabled = false
        highlightLooking.Adornee = nil
    end
end

local function refreshInspector()
    if STATE.selectionCount > 0 then
        local primary = STATE.selectionPrimary
        local name = primary and primary:IsDescendantOf(workspace) and primary.Name or "SELECTION"
        local center = getSelectionCenter()
        local distance = center and (camera.CFrame.Position - center).Magnitude or 0
        local totalMass, anchored = 0, 0
        local models = {}
        for _, root in ipairs(STATE.selectionOrder) do
            if root and root:IsDescendantOf(workspace) then
                totalMass += root.AssemblyMass
                if root.Anchored then anchored += 1 end
                local model = root:FindFirstAncestorOfClass("Model")
                if model and not CHARACTER_MODELS[model] then models[model] = true end
            end
        end
        local modelCount = 0; for _ in pairs(models) do modelCount += 1 end
        UI.inspectorName.Text = string.format("%d OBJECT(S) SELECTED", STATE.selectionCount)
        UI.inspectorDetail.Text = string.format(
            "%s • %s • %.1f studs • mass %.1f • %d anchored / %d free • %d models%s",
            CONFIG.selectionScope,
            name,
            distance,
            totalMass,
            anchored,
            math.max(0, STATE.selectionCount - anchored),
            modelCount,
            STATE.selectionHolding and " • HOLDING" or ""
        )
        return
    end

    local hit, position = raycastNormal()
    if hit and hit:IsA("BasePart") and not isPlayerPart(hit) then
        local root = getAssemblyRoot(hit)
        local distance = position and (camera.CFrame.Position - position).Magnitude or 0
        local mass = 0
        pcall(function()
            mass = root.AssemblyMass
        end)
        UI.inspectorName.Text = hit.Name
        UI.inspectorDetail.Text = string.format(
            "%s • %s • %.1f studs • mass %.1f • %s • size %.1f,%.1f,%.1f",
            hit.ClassName,
            CONFIG.selectionScope,
            distance,
            mass,
            root.Anchored and "ANCHORED" or "FREE",
            hit.Size.X, hit.Size.Y, hit.Size.Z
        )
    else
        UI.inspectorName.Text = "NO OBJECT SELECTED"
        UI.inspectorDetail.Text = "Aim at any physical object"
    end
end

local function refreshUI()
    grabButton.Text = STATE.holding and "RELEASE SELECTION" or "GRAB / HOLD"
    grabButton.BackgroundColor3 = STATE.holding and THEME.DangerSoft or THEME.SuccessSoft

    anchorButton.Text = STATE.anchoredWhileHolding and "UNANCHOR" or "ANCHOR"
    presetButton.Text = "PRESET: " .. CONFIG.preset
    scopeButton.Text = "SCOPE: " .. CONFIG.selectionScope
    selectAllButton.Text = STATE.selectionBusy and "CANCEL" or "SELECT ALL"
    cancelSelectionButton.Visible = STATE.selectionBusy
    holdSelectedButton.Text = STATE.selectionHolding and "RELEASE SELECTED" or "HOLD SELECTED"
    clearSelectionButton.Text = "CLEAR (" .. STATE.selectionCount .. ")"
    selectionRadiusButton.Text = "RADIUS: " .. CONFIG.selectionRadius .. " STUDS"
    selectionTypeButton.Text = "FILTER: " .. CONFIG.selectionType
    maxSelectionButton.Text = "MAX SELECTION: " .. (CONFIG.maxSelection == 0 and "UNLIMITED" or CONFIG.maxSelection)
    pivotButton.Text = "GROUP PIVOT: " .. CONFIG.groupPivot
    throwModeButton.Text = "THROW MODE: " .. CONFIG.throwMode

    magnetToggleButton.Text = STATE.magnetActive and "MAGNET: ON" or "MAGNET: OFF"
    magnetToggleButton.BackgroundColor3 = STATE.magnetActive and THEME.SuccessSoft or THEME.Surface
    magnetModeButton.Text = "MODE: " .. CONFIG.magnetMode
    magnetShapeButton.Text = "SHAPE: " .. CONFIG.magnetShape
    magnetCenterButton.Text = "CENTER: " .. CONFIG.magnetCenter
    falloffButton.Text = CONFIG.magnetFalloff and "FALLOFF: ON" or "FALLOFF: OFF"
    maxObjectsButton.Text = "MAX: " .. CONFIG.magnetMaxObjects
    magnetAnchoredButton.Text = CONFIG.magnetAffectsAnchored and "ANCHORED OBJECTS: ON" or "ANCHORED OBJECTS: OFF"

    rotationToggleButton.Text = STATE.rotationMode and "EXIT ROTATION" or "ENTER ROTATION"
    snapButton.Text = "SNAP: " .. (CONFIG.rotationSnap == 0 and "OFF" or tostring(CONFIG.rotationSnap) .. "°")
    rotationAxisButton.Text = "AXIS: " .. CONFIG.rotationAxis
    rotationSpaceButton.Text = "SPACE: " .. CONFIG.rotationSpace
    performanceButton.Text = "PERFORMANCE: " .. CONFIG.performanceMode
    if os.clock() > resetAllConfirmUntil then resetAllButton.Text = "RESET ALL SETTINGS" end

    distanceStepper.Refresh()
    forceStepper.Refresh()
    magnetForceStepper.Refresh()
    magnetRadiusStepper.Refresh()
    rotationSpeedStepper.Refresh()

    highlightsToggle.Refresh()
    pointerToggle.Refresh()
    animationsToggle.Refresh()
    snapBubbleToggle.Refresh()
    selectionLockToggle.Refresh()
    massCompensationToggle.Refresh()
    magnetTransparentToggle.Refresh()
    magnetCollideToggle.Refresh()

    UI.selectionInfo.Text = string.format(
        "Scope: %s • Selected: %d%s\n%s • %s • players excluded",
        CONFIG.selectionScope,
        STATE.selectionCount,
        STATE.selectionBusy and string.format(" • %d/%d", STATE.selectionProcessed, STATE.selectionTotal) or "",
        CONFIG.selectionType,
        CONFIG.selectionLocked and "LOCKED" or "EDITABLE"
    )

    UI.controlInfo.Text = string.format(
        "Preset: %s\nThrow: %d • Hold: %.1f studs\nF throw • R anchor • T magnet • C rotate • Select via UI",
        CONFIG.preset,
        CONFIG.throwForce,
        STATE.holdDistance
    )

    UI.magnetInfo.Text = string.format(
        "%s • %d tracked / %d max\n%s • %s • Force %d • Radius %d",
        CONFIG.magnetMode,
        STATE.magnetScannedCount,
        CONFIG.magnetMaxObjects,
        CONFIG.magnetShape,
        CONFIG.magnetCenter,
        CONFIG.magnetForce,
        CONFIG.magnetRadius
    )

    if UI.fakePointer then
        UI.fakePointer.Visible = STATE.guiVisible and CONFIG.showPointer
    end

    bubble.Text = STATE.magnetActive
        and ("TK • " .. CONFIG.magnetMode)
        or (STATE.selectionCount > 1 and ("TK • " .. STATE.selectionCount) or (STATE.holding and "TK • HOLD" or "TK • V6"))

    local now = os.clock()
    if now - STATE.inspectorLastRefresh >= CONSTANTS.INSPECTOR_REFRESH_INTERVAL then
        STATE.inspectorLastRefresh = now
        refreshInspector()
    end
    refreshHighlights()
end

--------------------------------------------------
-- INPUT PC
--------------------------------------------------

local function pointInsideGuiObject(point, object)
    if not object or not object.Visible then
        return false
    end
    local pos = object.AbsolutePosition
    local size = object.AbsoluteSize
    return point.X >= pos.X
        and point.X <= pos.X + size.X
        and point.Y >= pos.Y
        and point.Y <= pos.Y + size.Y
end

local function pointerOverTelekinesisUI()
    local point = UserInputService:GetMouseLocation()
    return pointInsideGuiObject(point, window)
        or pointInsideGuiObject(point, bubble)
end

connect(UserInputService.InputBegan, function(input, gameProcessed)
    if not STATE.active or gameProcessed or UserInputService:GetFocusedTextBox() then
        return
    end

    if input.UserInputType == Enum.UserInputType.Keyboard then
        local key = input.KeyCode

        if STATE.rotationMode then
            if key == Enum.KeyCode.C then
                exitRotationMode()
                return
            elseif key == Enum.KeyCode.W or key == Enum.KeyCode.Up then
                STATE.rotationKeys.up = true
                return
            elseif key == Enum.KeyCode.S or key == Enum.KeyCode.Down then
                STATE.rotationKeys.down = true
                return
            elseif key == Enum.KeyCode.A or key == Enum.KeyCode.Left then
                STATE.rotationKeys.left = true
                return
            elseif key == Enum.KeyCode.D or key == Enum.KeyCode.Right then
                STATE.rotationKeys.right = true
                return
            end
            return
        end

        if key == Enum.KeyCode.Q then
            STATE.holdQ = true
        elseif key == Enum.KeyCode.E then
            STATE.holdE = true
        elseif key == Enum.KeyCode.R then
            if STATE.magnetActive then
                massAnchorMagnet()
            else
                toggleAnchored()
            end
        elseif key == Enum.KeyCode.F then
            throwObject()
        elseif key == Enum.KeyCode.C then
            toggleRotationMode()
        elseif key == Enum.KeyCode.T then
            toggleMagnet()
        elseif key == Enum.KeyCode.Z then
            if STATE.magnetActive then
                changeMagnetForce(-CONFIG.magnetForceStep)
            else
                changeThrowForce(-CONFIG.throwForceStepPC)
            end
        elseif key == Enum.KeyCode.X then
            if STATE.magnetActive then
                changeMagnetForce(CONFIG.magnetForceStep)
            else
                changeThrowForce(CONFIG.throwForceStepPC)
            end
        elseif key == Enum.KeyCode.RightControl then
            toggleInterface()
        elseif key == Enum.KeyCode.LeftControl then
            notify("CONTROLS", "Click grab • F throw • Q/E distance • R anchor • T magnet • C rotate", 3)
        end
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not isMobile then
        if not pointerOverTelekinesisUI() then
            grabOrRelease()
        end
    end
end)

connect(UserInputService.InputEnded, function(input)
    if not STATE.active then
        return
    end

    if input.UserInputType == Enum.UserInputType.Keyboard then
        local key = input.KeyCode
        if key == Enum.KeyCode.Q then
            STATE.holdQ = false
        elseif key == Enum.KeyCode.E then
            STATE.holdE = false
        elseif key == Enum.KeyCode.W or key == Enum.KeyCode.Up then
            STATE.rotationKeys.up = false
        elseif key == Enum.KeyCode.S or key == Enum.KeyCode.Down then
            STATE.rotationKeys.down = false
        elseif key == Enum.KeyCode.A or key == Enum.KeyCode.Left then
            STATE.rotationKeys.left = false
        elseif key == Enum.KeyCode.D or key == Enum.KeyCode.Right then
            STATE.rotationKeys.right = false
        end
    end
end)

--------------------------------------------------
-- RENDER LOOP
--------------------------------------------------

connect(RunService.RenderStepped, function(dt)
    if not STATE.active then
        return
    end

    updateRotation(dt)
    if STATE.magnetActive and not STATE.rotationMode then
        local desiredCenter
        if CONFIG.magnetCenter == "PLAYER" then
            local root = getRootPart(); desiredCenter = root and root.Position or nil
        elseif CONFIG.magnetCenter == "ACTIVE TARGET" then
            local active = STATE.selectionPrimary or STATE.target; desiredCenter = active and active:IsDescendantOf(workspace) and active.Position or nil
        end
        local position
        if not desiredCenter then _, position = raycastForMagnet(); desiredCenter = position end
        if desiredCenter then
            surfacePosition = surfacePosition:Lerp(desiredCenter, 0.35)
        else
            local ray = getAimRay()
            surfacePosition = surfacePosition:Lerp(ray.Origin + ray.Direction.Unit * 15, 0.15)
        end

        actualMagnetRadius += (CONFIG.magnetRadius - actualMagnetRadius) * 0.25

        local percent = (CONFIG.magnetForce - CONFIG.magnetForceMin)
            / math.max(CONFIG.magnetForceMax - CONFIG.magnetForceMin, 1)

        local hue = CONFIG.magnetMode == "ATTRACT" and (0.58 + percent * 0.18) or (CONFIG.magnetMode == "ORBIT" and 0.78 or 0.0)
        local colorScale = Color3.fromHSV(hue % 1, 0.9, 1)

        if usingDrawing and magnetCircle then
            local viewportPosition, onScreen = camera:WorldToViewportPoint(surfacePosition)
            magnetCircle.Visible = STATE.guiVisible and onScreen
            magnetCircle.Position = Vector2.new(viewportPosition.X, viewportPosition.Y)
            magnetCircle.Radius = actualMagnetRadius
            magnetCircle.Color = colorScale
        elseif circleFrame then
            local viewportPosition, onScreen = camera:WorldToViewportPoint(surfacePosition)
            circleFrame.Visible = STATE.guiVisible and onScreen
            circleFrame.Position = UDim2.fromOffset(viewportPosition.X, viewportPosition.Y)
            circleFrame.Size = UDim2.fromOffset(actualMagnetRadius * 2, actualMagnetRadius * 2)
            local stroke = circleFrame:FindFirstChild("RingStroke")
            if stroke then
                stroke.Color = colorScale
            end
        end
    else
        if magnetCircle then
            magnetCircle.Visible = false
        end
        if circleFrame then
            circleFrame.Visible = false
        end
    end

    if STATE.holding and not STATE.rotationMode and not STATE.magnetActive then
        if STATE.holdClose or STATE.holdQ then
            updateDistance(-(STATE.holdQ and CONFIG.distanceKeySpeed or CONFIG.distanceSpeed))
        end
        if STATE.holdFar or STATE.holdE then
            updateDistance(STATE.holdE and CONFIG.distanceKeySpeed or CONFIG.distanceSpeed)
        end
    elseif STATE.magnetActive and not STATE.rotationMode then
        if STATE.holdQ then
            changeMagnetRadius(-CONFIG.magnetRadiusStep)
        end
        if STATE.holdE then
            changeMagnetRadius(CONFIG.magnetRadiusStep)
        end
    end
end)

--------------------------------------------------
-- HEARTBEAT LOOP
--------------------------------------------------

connect(RunService.Heartbeat, function()
    if not STATE.active then
        return
    end

    if STATE.selectionHolding and not STATE.rotationMode then
        updateSelectionHold()
    elseif STATE.holding and STATE.target then
        local target = STATE.target
        if not target:IsDescendantOf(workspace) then
            releaseHeldObject(false)
        elseif STATE.rotationMode then
            target.AssemblyLinearVelocity = Vector3.zero
            target.AssemblyAngularVelocity = Vector3.zero
            if STATE.rotationPosition then
                rotationPositionLock.Position = STATE.rotationPosition
            end
        elseif not STATE.anchoredWhileHolding then
            local ray = getAimRay()
            local desiredPosition = ray.Origin + ray.Direction.Unit * STATE.holdDistance
            bodyVelocity.Velocity = (desiredPosition - target.Position) * CONFIG.holdResponse
            bodyGyro.CFrame = target.CFrame
        else
            target.AssemblyLinearVelocity = Vector3.zero
            target.AssemblyAngularVelocity = Vector3.zero
        end
    end

    if STATE.magnetActive and not STATE.rotationMode then
        local now = os.clock()
        local loadRatio = STATE.magnetScannedCount / math.max(CONFIG.magnetMaxObjects, 1)
        local scanInterval = CONSTANTS.MIN_ADAPTIVE_SCAN_INTERVAL
            + (CONSTANTS.MAX_ADAPTIVE_SCAN_INTERVAL - CONSTANTS.MIN_ADAPTIVE_SCAN_INTERVAL) * loadRatio
        if CONFIG.performanceMode == "QUALITY" then scanInterval = CONSTANTS.MIN_ADAPTIVE_SCAN_INTERVAL
        elseif CONFIG.performanceMode == "LOW" then scanInterval = CONSTANTS.MAX_ADAPTIVE_SCAN_INTERVAL end
        if now - STATE.lastMagnetScan >= scanInterval then
            STATE.lastMagnetScan = now
            scanMagnetCandidates()
        end
        updateMagnetPhysics()
    elseif next(STATE.magnetObjects) ~= nil then
        restoreMagnetPhysics()
    end

    local now = os.clock()
    if now - STATE.selectionLastCleanup >= CONSTANTS.SELECTION_CLEANUP_INTERVAL then
        STATE.selectionLastCleanup = now
        pruneSelection()
    end
    if now - STATE.uiLastRefresh >= CONSTANTS.UI_REFRESH_INTERVAL then
        STATE.uiLastRefresh = now
        refreshUI()
    end
end)

--------------------------------------------------
-- RESPAWN / VIEWPORT
--------------------------------------------------

connect(player.CharacterAdded, function()
    STATE.characterFrozen = false
    STATE.characterBackup = nil
    STATE.characterVisibilityBackup = {}
    STATE.rotationMode = false
    STATE.rotationPosition = nil
    resetRotationKeys()
    rotationPositionLock.Parent = nil
    STATE.target = nil
    STATE.holding = false
    pcall(clearSelectionControllers, true)
    pcall(clearSelection)
    disconnectPhysics()
    restoreMagnetPhysics()
end)

local function bindCameraViewport()
    if cameraViewportConnection then cameraViewportConnection:Disconnect(); cameraViewportConnection = nil end
    if camera then
        cameraViewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsiveLayout)
    end
end
bindCameraViewport()

connect(workspace:GetPropertyChangedSignal("CurrentCamera"), function()
    camera = workspace.CurrentCamera or camera
    bindCameraViewport()
    applyResponsiveLayout()
end)

--------------------------------------------------
-- PUBLIC API / DESTROY
--------------------------------------------------

local API = {
    Version = CONSTANTS.VERSION,
    State = STATE,
    Config = CONFIG,
}

function API:Minimize()
    if STATE.active then
        setInterfaceVisible(false)
    end
end

function API:Restore()
    if STATE.active then
        setInterfaceVisible(true)
    end
end

function API:Toggle()
    if STATE.active then
        toggleInterface()
    end
end

function API:ToggleUI() self:Toggle() end

function API:Grab()
    grabOrRelease()
end

function API:Throw()
    throwObject()
end

function API:ToggleMagnet()
    toggleMagnet()
end

function API:SetPreset(name)
    if PRESETS[name] then
        applyPreset(name)
        return true
    end
    return false
end

function API:SelectAimed()
    return selectAimedObject(true)
end

function API:SelectAll()
    selectAllObjectsAsync()
end

function API:SelectNearby() selectNearbyAsync() end
function API:InvertSelection() invertSelectionAsync() end
function API:CancelSelectionScan() return cancelSelectionScan() end

function API:ClearSelection()
    return clearSelection()
end

function API:HoldSelection()
    return startSelectionHold()
end

function API:ReleaseSelection()
    if STATE.selectionHolding then releaseSelectionHold(true); return true end
    return false
end

function API:ThrowSelection()
    return throwSelected()
end

function API:AnchorSelection() return setSelectedAnchored(true) end
function API:UnanchorSelection() return setSelectedAnchored(false) end

function API:SetSelectionScope(scope)
    if scope == "PART" or scope == "ASSEMBLY" or scope == "MODEL" then
        CONFIG.selectionScope = scope
        queueSaveConfig()
        return true
    end
    return false
end

function API:Destroy()
    if not STATE.active then
        return
    end

    STATE.active = false
    TASK_GENERATION += 1
    STATE.selectionToken += 1
    STATE.selectionBusy = false
    saveSerial += 1

    pcall(saveConfigNow)
    pcall(deactivateMagnet)
    pcall(releaseHeldObject, true)
    pcall(clearSelectionControllers, true)
    pcall(clearSelectionHighlights)
    pcall(showCharacter)
    pcall(unfreezeCharacter)
    pcall(disconnectPhysics)
    pcall(disconnectAllConnections)
    if cameraViewportConnection then pcall(function() cameraViewportConnection:Disconnect() end); cameraViewportConnection = nil end
    pcall(cancelAllTweens)

    for instance in pairs(STATE.transientInstances) do
        pcall(function() instance:Destroy() end)
    end
    table.clear(STATE.transientInstances)

    for part, originalAnchored in pairs(STATE.telekinesisAnchored) do
        if part and part:IsDescendantOf(workspace) then pcall(function() part.Anchored = originalAnchored end) end
    end
    table.clear(STATE.telekinesisAnchored)

    pcall(function()
        bodyVelocity:Destroy()
    end)
    pcall(function()
        bodyGyro:Destroy()
    end)
    pcall(function()
        rotationPositionLock:Destroy()
    end)
    pcall(function()
        highlightHolding:Destroy()
    end)
    pcall(function()
        highlightLooking:Destroy()
    end)
    pcall(function()
        if magnetCircle then
            magnetCircle:Remove()
        end
    end)
    pcall(function()
        if circleGui then
            circleGui:Destroy()
        end
    end)
    pcall(function()
        gui:Destroy()
    end)

    if ENV.TelekinesisUltraV6 == API then ENV.TelekinesisUltraV6 = nil end
    if ENV.TelekinesisUltraV5 == API then ENV.TelekinesisUltraV5 = nil end
end

ENV.TelekinesisUltraV6 = API

local unloadConfirmUntil = 0
connect(unloadButton.Activated, function()
    local now = os.clock()
    if now <= unloadConfirmUntil then
        API:Destroy()
        return
    end

    unloadConfirmUntil = now + 3
    unloadButton.Text = "CONFIRM UNLOAD?"
    notify("CONFIRM", "Tap unload again within 3 seconds", 2)
    local generation = TASK_GENERATION
    task.delay(3.1, function()
        if STATE.active and generation == TASK_GENERATION and os.clock() > unloadConfirmUntil then
            unloadButton.Text = "UNLOAD TELEKINESIS V6"
        end
    end)
end)

--------------------------------------------------
-- INIT
--------------------------------------------------

restoreNormalizedPosition(window, CONFIG.panelX, CONFIG.panelY)
restoreNormalizedPosition(bubble, CONFIG.bubbleX, CONFIG.bubbleY)
applyResponsiveLayout()
setTab(CONFIG.activeTab)
setInterfaceVisible(true)
refreshUI()

notify("TELEKINESIS V6", "Ultra All-Objects engine ready", 1.8)

print("[Telekinesis V6 Ultra All-Objects] loaded • professional selection • adaptive magnet • safe cleanup")
