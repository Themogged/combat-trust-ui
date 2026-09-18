-- Combat Trust loader
-- Loads only first-party files from this repository, in core -> UI order.

-- CONFIG

local RAW_BASE = "https://raw.githubusercontent.com/Themogged/combat-trust-ui/main/"
local CORE_URL = RAW_BASE .. "core.lua"
local UI_URL = RAW_BASE .. "CombatTrustUltraUI.lua"
local Environment = getgenv and getgenv() or _G

local function loaderWarning(component, stage, detail)
    warn(string.format(
        "[Combat Loader] %s ERROR (%s): %s",
        string.upper(component),
        stage,
        tostring(detail)
    ))
end

local function destroyKnownUI()
    local globalUI = Environment.CombatTrustUltraUI
    if globalUI then
        pcall(function()
            globalUI:Destroy()
        end)
    end
    Environment.CombatTrustUltraUI = nil

    local ok, playerGui = pcall(function()
        local players = game:GetService("Players")
        local player = players.LocalPlayer
        return player and player:FindFirstChildOfClass("PlayerGui") or nil
    end)

    if ok and playerGui then
        for _, name in { "CombatTrustUltraUI", "MultiplayerDefenseTrustProbe" } do
            local existing = playerGui:FindFirstChild(name)
            if existing then
                pcall(function()
                    existing:Destroy()
                end)
            end
        end
    end
end

-- CLEAN PREVIOUS INSTANCE

local function cleanPreviousInstance()
    local previous = Environment.CombatTrustProbe
    if type(previous) == "table" then
        if type(previous.Unload) == "function" then
            local ok, err = pcall(previous.Unload, previous)
            if not ok then
                loaderWarning("cleanup", "unload", err)
            end
        else
            previous.Alive = false
        end
    end

    if Environment.CombatTrustProbe == previous then
        Environment.CombatTrustProbe = nil
    end
    destroyKnownUI()
end

-- REMOTE LOADER

local function validateSource(name, source)
    if type(source) ~= "string" then
        return false, "response was not text"
    end
    if source:match("^%s*$") then
        return false, "response was empty"
    end

    local prefix = string.lower(source:sub(1, 512)):gsub("^%s+", "")
    if prefix:sub(1, 5) == "<html"
        or prefix:sub(1, 9) == "<!doctype"
        or prefix:find("404: not found", 1, true) == 1
        or prefix:find("repository not found", 1, true) == 1 then
        return false, "response looked like HTML or a GitHub error page"
    end

    if #source < 32 then
        return false, name .. " response was unexpectedly short"
    end
    return true
end

local function loadRemote(name, url)
    local okDownload, sourceOrError = pcall(function()
        return game:HttpGet(url, true)
    end)
    if not okDownload then
        loaderWarning(name, "download", sourceOrError)
        return false
    end

    local valid, validationError = validateSource(name, sourceOrError)
    if not valid then
        loaderWarning(name, "validation", validationError)
        return false
    end

    if type(loadstring) ~= "function" then
        loaderWarning(name, "compile", "loadstring is unavailable")
        return false
    end

    local okCompile, chunkOrError, compileError = pcall(
        loadstring,
        sourceOrError,
        "=CombatTrust/" .. name
    )
    if not okCompile then
        loaderWarning(name, "compile", chunkOrError)
        return false
    end
    if type(chunkOrError) ~= "function" then
        loaderWarning(name, "compile", compileError or "compiler returned no function")
        return false
    end

    local okRun, runError = pcall(chunkOrError)
    if not okRun then
        loaderWarning(name, "runtime", runError)
        return false
    end
    return true
end

-- CORE

print("[Combat Loader] Starting...")
cleanPreviousInstance()

print("[Combat Loader] Loading core...")
if not loadRemote("core", CORE_URL) then
    cleanPreviousInstance()
    return
end

local Probe = Environment.CombatTrustProbe
if type(Probe) ~= "table" or Probe.Alive == false then
    loaderWarning("core", "verification", "getgenv().CombatTrustProbe was not created")
    cleanPreviousInstance()
    return
end
print("[Combat Loader] Core loaded.")

-- UI

print("[Combat Loader] Loading Ultra UI...")
if not loadRemote("ui", UI_URL) then
    cleanPreviousInstance()
    return
end

if Environment.CombatTrustUltraUI == nil then
    loaderWarning("ui", "verification", "CombatTrustUltraUI was not created")
    cleanPreviousInstance()
    return
end

print("[Combat Loader] Ultra UI loaded.")

-- READY

print("[Combat Loader] Ready.")
