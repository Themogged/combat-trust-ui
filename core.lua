-- Combat Trust core
-- Backend only: configuration, targeting, hooks, heartbeat, hotkeys and cleanup.

--[[
    Place_100484168444874 multiplayer defense-trust probe

    Contains multiplayer targeting, the exact two defense trust hooks from the
    supplied working script, and a close-range outgoing hitbox-origin trust probe.
    Targeting supports enemy-only rosters,
    sticky/manual selection, automatic nearest selection, and cycling.

    Controls:
      Numpad 1  toggle player lock
      Numpad 2  previous opponent
      Numpad 3  next opponent
      Numpad 4  toggle defense trust hooks
      Numpad 5  toggle manual/automatic targeting
      Numpad 7  toggle close-range hitbox trust hook
      Home      show/hide Ultra UI
      Numpad 0 or End  unload
]]

-- CLEAN PREVIOUS INSTANCE

if getgenv().CombatTrustProbe then
    pcall(function()
        getgenv().CombatTrustProbe:Unload()
    end)
end

-- SERVICES

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    error("[Combat Core] LocalPlayer is unavailable", 0)
end

local function requireChild(parent, name, path)
    local child = parent:FindFirstChild(name) or parent:WaitForChild(name, 15)
    if not child then
        error("[Combat Core] Missing required instance: " .. path .. "." .. name, 0)
    end
    return child
end

local Remotes = requireChild(ReplicatedStorage, "Remotes", "ReplicatedStorage")
local PlayerCharacter = requireChild(Remotes, "PlayerCharacter", "ReplicatedStorage.Remotes")
local Request = requireChild(PlayerCharacter, "Request", "PlayerCharacter")
local ResolveImpact = requireChild(Request, "ResolveImpact", "PlayerCharacter.Request")
local RequestHitboxOnImpact = requireChild(Request, "RequestHitboxOnImpact", "PlayerCharacter.Request")

-- CONFIG

local CONFIG_FOLDER = "DefenseTrustProbe"
local CONFIG_PATH = CONFIG_FOLDER .. "/multiplayer_config.json"
local configStorageAvailable = type(readfile) == "function" and type(writefile) == "function"
local loadedConfig = {}
local configStatus = configStorageAvailable and "defaults" or "unavailable"

if configStorageAvailable then
    local ok, result = pcall(function()
        if type(isfile) == "function" and not isfile(CONFIG_PATH) then
            return nil
        end
        return HttpService:JSONDecode(readfile(CONFIG_PATH))
    end)
    if ok and type(result) == "table" then
        loadedConfig = result
        configStatus = "loaded"
    elseif not ok then
        configStatus = "load error"
    end
end

local function savedBoolean(key, fallback)
    return type(loadedConfig[key]) == "boolean" and loadedConfig[key] or fallback
end

local loadedTargetMode = loadedConfig.TargetMode == "AUTO" and "AUTO" or "MANUAL"
local loadedTargetKey = type(loadedConfig.ManualTargetKey) == "string" and loadedConfig.ManualTargetKey or nil

-- STATE

local Probe = {
    Alive = true,
    PlayerTargeting = savedBoolean("PlayerTargeting", true),
    TrustHooks = savedBoolean("TrustHooks", true),
    TargetMode = loadedTargetMode,
    ManualTargetKey = loadedTargetKey,
    PanelVisible = savedBoolean("PanelVisible", true),
    CloseHitHook = savedBoolean("CloseHitHook", true),
    CloseHitRange = 9,
    ConfigStatus = configStatus,
    CurrentTarget = nil,
    Roster = {},
    Connections = {},
    Counts = {
        TrustParries = 0,
        RedirectedHitboxes = 0,
    },
    Record = {
        TrustParries = 0,
        Timeline = {},
    },
    CombatIntel = {
        CounterWindowUntil = 0,
    },
}
getgenv().CombatTrustProbe = Probe

local function log(message)
    print("[defense trust probe] " .. message)
end

local function recordEvent(kind, detail)
    local timeline = Probe.Record.Timeline
    timeline[#timeline + 1] = {
        Time = os.clock(),
        Kind = kind,
        Detail = detail,
    }
    if #timeline > 80 then
        table.remove(timeline, 1)
    end
end

local function saveConfig()
    if not configStorageAvailable then
        Probe.ConfigStatus = "unavailable"
        return false
    end
    local manualKey = type(Probe.ManualTargetKey) == "string" and Probe.ManualTargetKey or nil
    local payload = {
        Version = 2,
        PlayerTargeting = Probe.PlayerTargeting,
        TrustHooks = Probe.TrustHooks,
        TargetMode = Probe.TargetMode,
        ManualTargetKey = manualKey,
        PanelVisible = Probe.PanelVisible,
        CloseHitHook = Probe.CloseHitHook,
    }
    local ok, err = pcall(function()
        if type(isfolder) == "function" and type(makefolder) == "function" then
            if not isfolder(CONFIG_FOLDER) then
                makefolder(CONFIG_FOLDER)
            end
        elseif type(makefolder) == "function" then
            pcall(makefolder, CONFIG_FOLDER)
        end
        writefile(CONFIG_PATH, HttpService:JSONEncode(payload))
    end)
    Probe.ConfigStatus = ok and "saved" or "save error"
    if not ok then
        log("config save failed: " .. tostring(err))
    end
    return ok
end

local configSaveSerial = 0
local function queueConfigSave()
    configSaveSerial += 1
    local serial = configSaveSerial
    task.delay(0.2, function()
        if Probe.Alive and serial == configSaveSerial then
            saveConfig()
        end
    end)
end

-- CONTROLLERS

local GameManager
local CharacterController
local TargetLockController
local MatchController
local lastControllerWarning = -math.huge

local function logControllerIssue(detail)
    local now = os.clock()
    if now - lastControllerWarning >= 5 then
        lastControllerWarning = now
        log("controllers unavailable: " .. tostring(detail))
    end
end

local function refreshControllers()
    if GameManager and CharacterController and TargetLockController and MatchController then
        return true
    end

    if not GameManager then
        local managerModule = ReplicatedStorage:FindFirstChild("GameManager")
        if not managerModule then
            logControllerIssue("GameManager module not found")
            return false
        end

        local ok, manager = pcall(require, managerModule)
        if not ok then
            logControllerIssue(manager)
            return false
        end
        GameManager = manager
    end

    local ok = pcall(function()
        CharacterController = GameManager:GetController("CharacterController")
        TargetLockController = GameManager:GetController("TargetLockController")
        MatchController = GameManager:GetController("MatchController")
    end)
    if not ok then
        logControllerIssue("one or more controllers could not be resolved")
        return false
    end
    return CharacterController ~= nil
end

local function getHandler()
    if not refreshControllers() then
        return nil
    end

    if CharacterController.LoadedCharacterHandler then
        return CharacterController.LoadedCharacterHandler
    end

    local ok, handler = pcall(function()
        return CharacterController:GetLocalCharacterHandler()
    end)
    if ok and handler then
        return handler
    end

    local camera = workspace.CurrentCamera
    local subject = camera and camera.CameraSubject or nil
    local subjectModel = subject and (subject:IsA("Humanoid") and subject.Parent or subject:FindFirstAncestorWhichIsA("Model")) or nil
    if subjectModel then
        local subjectOk, subjectHandler = pcall(function()
            return CharacterController:GetCharacterHandler(subjectModel)
        end)
        if subjectOk and subjectHandler then
            return subjectHandler
        end
    end

    for _, model in CollectionService:GetTagged("CustomCharacter") do
        if model:GetAttribute("UserId") == LocalPlayer.UserId then
            local modelOk, modelHandler = pcall(function()
                return CharacterController:GetCharacterHandler(model)
            end)
            if modelOk and modelHandler then
                return modelHandler
            end
        end
    end
    return nil
end

-- TARGETING

local function getRoot()
    local handler = getHandler()
    if handler and handler.Root and handler.Root:IsDescendantOf(workspace) then
        return handler.Root
    end
    local character = LocalPlayer.Character
    return character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart) or nil
end

local function getTargetPart(model)
    if not model then
        return nil
    end
    return model:FindFirstChild("HumanoidRootPart")
        or model.PrimaryPart
        or model:FindFirstChild("UpperTorso")
        or model:FindFirstChild("Torso")
end

local function isLocalModel(model, part, localRoot)
    if model == LocalPlayer.Character or model:GetAttribute("UserId") == LocalPlayer.UserId then
        return true
    end
    local handler = getHandler()
    return (handler and (model == handler.Model or model == handler.OriginalModel))
        or (part and localRoot and part == localRoot)
end

local function isEnemyModel(model, player)
    if MatchController and type(MatchController.IsCharacterEnemyOfLocalPlayer) == "function" then
        local ok, enemy = pcall(function()
            return MatchController:IsCharacterEnemyOfLocalPlayer(model)
        end)
        if ok then
            return enemy == true
        end
    end
    if player and LocalPlayer.Team and player.Team then
        return player.Team ~= LocalPlayer.Team
    end
    return player ~= LocalPlayer
end

local function targetKey(model, player)
    local userId = player and player.UserId or model:GetAttribute("UserId")
    return userId and ("user:" .. tostring(userId)) or model
end

local function collectEnemyRoster()
    local localRoot = getRoot()
    if not localRoot then
        return {}
    end

    local roster = {}
    local bestByKey = {}
    local function consider(model, player, preferred)
        if not model or not model:IsDescendantOf(workspace) or model:GetAttribute("IsDead") == true then
            return
        end
        local part = getTargetPart(model)
        if not part or not part:IsDescendantOf(workspace) or isLocalModel(model, part, localRoot) then
            return
        end
        if not isEnemyModel(model, player) then
            return
        end
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health <= 0 then
            return
        end

        local key = targetKey(model, player)
        local target = {
            Key = key,
            Model = model,
            Player = player,
            Part = part,
            Humanoid = humanoid,
            Distance = (part.Position - localRoot.Position).Magnitude,
            Preferred = preferred == true,
        }
        local current = bestByKey[key]
        if not current or (target.Preferred and not current.Preferred) or target.Distance < current.Distance then
            bestByKey[key] = target
        end
    end

    for _, model in CollectionService:GetTagged("CustomCharacter") do
        local userId = model:GetAttribute("UserId")
        local player = userId and Players:GetPlayerByUserId(userId) or nil
        if player and player ~= LocalPlayer then
            consider(model, player, true)
        end
    end
    for _, player in Players:GetPlayers() do
        if player ~= LocalPlayer then
            consider(player.Character, player, false)
        end
    end
    for _, target in bestByKey do
        table.insert(roster, target)
    end
    table.sort(roster, function(left, right)
        return left.Distance < right.Distance
    end)
    return roster
end

local function findRosterIndex(key)
    for index, target in Probe.Roster do
        if target.Key == key then
            return index
        end
    end
    return nil
end

local function selectRosterIndex(index)
    local count = #Probe.Roster
    if count == 0 then
        Probe.ManualTargetKey = nil
        Probe.CurrentTarget = nil
        return
    end
    index = ((index - 1) % count) + 1
    Probe.TargetMode = "MANUAL"
    Probe.ManualTargetKey = Probe.Roster[index].Key
    Probe.CurrentTarget = Probe.Roster[index]
    local player = Probe.CurrentTarget.Player
    log("manual target: " .. (player and player.Name or Probe.CurrentTarget.Model.Name))
    queueConfigSave()
end

local function cycleTarget(direction)
    local count = #Probe.Roster
    if count == 0 then
        log("no enemy players available to cycle")
        return
    end
    local currentIndex = findRosterIndex(Probe.ManualTargetKey)
        or (Probe.CurrentTarget and findRosterIndex(Probe.CurrentTarget.Key))
        or 1
    selectRosterIndex(currentIndex + direction)
end

local function toggleTargetMode()
    if Probe.TargetMode == "AUTO" then
        Probe.TargetMode = "MANUAL"
        Probe.ManualTargetKey = Probe.CurrentTarget and Probe.CurrentTarget.Key or Probe.ManualTargetKey
    else
        Probe.TargetMode = "AUTO"
    end
    log("target mode " .. Probe.TargetMode)
    queueConfigSave()
end

local function resolveSelectedTarget()
    local roster = Probe.Roster
    if #roster == 0 then
        return nil
    end
    if Probe.TargetMode == "AUTO" then
        return roster[1]
    end
    local index = findRosterIndex(Probe.ManualTargetKey)
    if not index then
        index = 1
        Probe.ManualTargetKey = roster[1].Key
        queueConfigSave()
    end
    return roster[index]
end


-- TARGET CLEANUP

local function clearTarget()
    if TargetLockController then
        pcall(function()
            TargetLockController:SetTarget(nil)
        end)
    end
    Probe.CurrentTarget = nil
end

-- PROBE API AND CLEANUP STATE

local resolutionHookTarget
local resolutionHookOriginal
local resolutionHookInstalled = false
local oldNamecall
local namecallHookInstalled = false
local oldHitNamecall
local hitNamecallHookInstalled = false

local mutableBooleans = {
    PlayerTargeting = true,
    TrustHooks = true,
    PanelVisible = true,
    CloseHitHook = true,
}

Probe.Actions = {
    ToggleTargetMode = toggleTargetMode,
    CycleTarget = cycleTarget,
    SelectRosterIndex = selectRosterIndex,
    QueueConfigSave = queueConfigSave,
    SetBoolean = function(key, value)
        if not Probe.Alive or mutableBooleans[key] ~= true then
            return false
        end

        Probe[key] = value == true
        log(key .. " " .. (Probe[key] and "enabled" or "disabled"))
        queueConfigSave()
        return true
    end,
}

function Probe:Unload()
    if not self.Alive then
        return
    end

    self.Alive = false
    saveConfig()
    self.PlayerTargeting = false
    self.TrustHooks = false
    self.CloseHitHook = false

    for _, connection in self.Connections do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(self.Connections)

    pcall(clearTarget)
    table.clear(self.Roster)

    if resolutionHookInstalled and resolutionHookTarget and resolutionHookOriginal then
        if type(restorefunction) == "function" then
            pcall(restorefunction, resolutionHookTarget)
        elseif type(hookfunction) == "function" then
            pcall(hookfunction, resolutionHookTarget, resolutionHookOriginal)
        end
        resolutionHookInstalled = false
    end

    if hitNamecallHookInstalled and oldHitNamecall then
        pcall(function()
            hookmetamethod(game, "__namecall", oldHitNamecall)
        end)
        hitNamecallHookInstalled = false
    end

    if namecallHookInstalled and oldNamecall then
        pcall(function()
            hookmetamethod(game, "__namecall", oldNamecall)
        end)
        namecallHookInstalled = false
    end

    local environment = getgenv()
    local ui = environment.CombatTrustUltraUI or self.UI
    if ui then
        pcall(function()
            ui:Destroy()
        end)
    end
    if environment.CombatTrustUltraUI == ui then
        environment.CombatTrustUltraUI = nil
    end
    self.UI = nil

    if type(self.Actions) == "table" then
        table.clear(self.Actions)
    end
    if environment.CombatTrustProbe == self then
        environment.CombatTrustProbe = nil
    end

    log("unloaded")
end

-- TRUST HOOKS

-- Trust hook 1: make the game's own impact computation observe a parry state.
-- This preserves the normal Parry resultData/staggerProperties shape, allowing
-- the test to show whether the server trusts a client-computed Parry outcome.
local function installImpactResolutionHook()
    if resolutionHookInstalled or not Probe.TrustHooks
        or type(hookfunction) ~= "function" or type(newcclosure) ~= "function" then
        return
    end
    local handler = getHandler()
    local manager = handler and handler.ActionManager
    local targetFunction = manager and manager._computeImpactResolution
    if type(targetFunction) ~= "function" then
        return
    end
    resolutionHookTarget = targetFunction
    local replacement
    replacement = newcclosure(function(self, impactData)
        local liveHandler = getHandler()
        if not Probe.Alive or not Probe.TrustHooks or self ~= (liveHandler and liveHandler.ActionManager) then
            return resolutionHookOriginal(self, impactData)
        end
        local characterHandler = self.CharacterHandler
        local previousParry = characterHandler.IsParrying
        local previousBlock = characterHandler.IsBlocking
        characterHandler.IsParrying = true
        characterHandler.IsBlocking = true
        local results = table.pack(resolutionHookOriginal(self, impactData))
        characterHandler.IsParrying = previousParry
        characterHandler.IsBlocking = previousBlock
        local resolution = results[1]
        if type(resolution) == "table" and resolution.result == "Parry" then
            Probe.Counts.TrustParries += 1
            Probe.Record.TrustParries += 1
            Probe.CombatIntel.CounterWindowUntil = os.clock() + 0.9
            recordEvent("trust_hook_parry", "native impact computation returned Parry")
        end
        return table.unpack(results, 1, results.n)
    end)
    local ok, original = pcall(hookfunction, targetFunction, replacement)
    if ok and type(original) == "function" then
        resolutionHookOriginal = original
        resolutionHookInstalled = true
        log("defense trust hook installed on _computeImpactResolution")
    end
end

-- Trust hook 2: outgoing-result fallback. If the computation hook cannot make
-- a valid defensive result, rewrite the result string at the final RemoteEvent.
if type(hookmetamethod) == "function" and type(getnamecallmethod) == "function" and type(newcclosure) == "function" then
    local ok, original = pcall(function()
        return hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if Probe.Alive and Probe.TrustHooks and self == ResolveImpact and method == "FireServer" then
                local args = { ... }
                local originalResult = args[2]
                if originalResult ~= "Parry" and originalResult ~= "Dodge" then
                    args[2] = "Parry"
                    Probe.Counts.TrustParries += 1
                    Probe.Record.TrustParries += 1
                    Probe.CombatIntel.CounterWindowUntil = os.clock() + 0.9
                    recordEvent("trust_hook_forced", tostring(originalResult) .. " -> Parry")
                    log("TRUST HOOK: rewrote impact result " .. tostring(originalResult) .. " -> Parry")
                end
                return oldNamecall(self, table.unpack(args))
            end
            return oldNamecall(self, ...)
        end))
    end)
    if ok and type(original) == "function" then
        oldNamecall = original
        namecallHookInstalled = true
    else
        warn("[Combat Core] ResolveImpact hook unavailable: " .. tostring(original))
    end
end

-- HITBOX HOOK

-- Close-range outgoing hitbox trust probe. The game asks the attacking client
-- to return a root CFrame, timestamp, and server-issued request token through
-- RequestHitboxOnImpact. For a locked enemy inside the normal Katana envelope,
-- this hook redirects only that reported origin so the hitbox covers the target.
-- The original timestamp and token remain untouched.
if type(hookmetamethod) == "function" and type(getnamecallmethod) == "function" and type(newcclosure) == "function" then
    local ok, original = pcall(function()
        return hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if Probe.Alive and Probe.CloseHitHook and self == RequestHitboxOnImpact and method == "FireServer" then
                local args = { ... }
                local target = Probe.CurrentTarget
                local localRoot = getRoot()
                local targetPart = target and target.Part or nil
                if localRoot and targetPart and targetPart:IsDescendantOf(workspace) and typeof(args[1]) == "CFrame" then
                    local offset = targetPart.Position - localRoot.Position
                    local distance = offset.Magnitude
                    if distance > 0.05 and distance <= Probe.CloseHitRange then
                        local direction = offset.Unit
                        local reportedOrigin = targetPart.Position - direction * 2.75
                        args[1] = CFrame.lookAt(reportedOrigin, targetPart.Position)
                        Probe.Counts.RedirectedHitboxes += 1
                        local targetName = target.Player and target.Player.Name or target.Model.Name
                        recordEvent(
                            "hitbox_origin_redirect",
                            string.format("%s at %.2f studs; token preserved", targetName, distance)
                        )
                        log(string.format(
                            "HITBOX TRUST: redirected server-requested origin to %s at %.2f studs",
                            targetName,
                            distance
                        ))
                        return oldHitNamecall(self, table.unpack(args))
                    end
                end
            end
            return oldHitNamecall(self, ...)
        end))
    end)
    if ok and type(original) == "function" then
        oldHitNamecall = original
        hitNamecallHookInstalled = true
    else
        warn("[Combat Core] RequestHitboxOnImpact hook unavailable: " .. tostring(original))
    end
end

-- HEARTBEAT

local lastLogicUpdate = 0
local LOGIC_INTERVAL = 0.15

table.insert(Probe.Connections, RunService.Heartbeat:Connect(function()
    if not Probe.Alive then
        return
    end

    local now = os.clock()
    if now - lastLogicUpdate < LOGIC_INTERVAL then
        return
    end
    lastLogicUpdate = now

    installImpactResolutionHook()
    Probe.Roster = collectEnemyRoster()

    if Probe.PlayerTargeting then
        local target = resolveSelectedTarget()
        Probe.CurrentTarget = target
        if target and TargetLockController then
            pcall(function()
                TargetLockController:SetTarget(target.Part)
            end)
        elseif not target and TargetLockController then
            pcall(function()
                TargetLockController:SetTarget(nil)
            end)
        end
    elseif Probe.CurrentTarget then
        clearTarget()
    end

end))

-- INPUT

table.insert(Probe.Connections, UserInputService.InputBegan:Connect(function(input)
    if not Probe.Alive or UserInputService:GetFocusedTextBox() then
        return
    end
    if input.KeyCode == Enum.KeyCode.KeypadOne then
        Probe.PlayerTargeting = not Probe.PlayerTargeting
        log("PlayerTargeting " .. (Probe.PlayerTargeting and "enabled" or "disabled"))
        queueConfigSave()
    elseif input.KeyCode == Enum.KeyCode.KeypadTwo then
        cycleTarget(-1)
    elseif input.KeyCode == Enum.KeyCode.KeypadThree then
        cycleTarget(1)
    elseif input.KeyCode == Enum.KeyCode.KeypadFour then
        Probe.TrustHooks = not Probe.TrustHooks
        log("TrustHooks " .. (Probe.TrustHooks and "enabled" or "disabled"))
        queueConfigSave()
    elseif input.KeyCode == Enum.KeyCode.KeypadFive then
        toggleTargetMode()
    elseif input.KeyCode == Enum.KeyCode.KeypadSeven then
        Probe.CloseHitHook = not Probe.CloseHitHook
        log("close-range hitbox trust hook " .. (Probe.CloseHitHook and "enabled" or "disabled"))
        queueConfigSave()
    elseif input.KeyCode == Enum.KeyCode.Home then
        Probe.PanelVisible = not Probe.PanelVisible
        queueConfigSave()
    elseif input.KeyCode == Enum.KeyCode.KeypadZero or input.KeyCode == Enum.KeyCode.End then
        Probe:Unload()
    end
end))

if configStorageAvailable and Probe.ConfigStatus ~= "loaded" then
    queueConfigSave()
end
log("multiplayer combat trust probe v5 loaded: defense hooks + close-hit redirect")
