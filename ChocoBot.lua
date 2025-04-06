-----------------------------------------------------------
-- Chocobo Racing Automation Script
-- (User-configurable settings: maxRank, raceType, and speed only)
-----------------------------------------------------------

-- User-configurable settings:
local config = {
    maxRank = 40,                -- Stop when reaching this rank
    raceType = "sagolii",         -- Options: "random", "sagolii", "costa", "tranquil"
    speed = "fast"               -- Set to "fast" or "slow" for UI handling delays
}

-- Internal constants (do not change)
local MAX_WAIT_FOR_COMMENCE = 35   -- seconds (raw delay)
local MAX_WAIT_FOR_ZONE = 20       -- seconds (raw delay)
local W_REFRESH_INTERVAL = 5       -- seconds (for in-race refresh)
local GOLDSAUCER_TAB = 9           -- Gold Saucer tab index (used with command "1 9")

-- Mapping from race types to duty selection indices and zone IDs.
local raceMapping = {
    random   = { dutyIndex = 3, zoneIDs = {390, 391, 389} },
    sagolii  = { dutyIndex = 4, zoneID = 390 },
    costa    = { dutyIndex = 5, zoneID = 389 },
    tranquil = { dutyIndex = 6, zoneID = 391 }
}

-- Internal: derive duty index from chosen raceType.
local dutyIndex = raceMapping[config.raceType].dutyIndex

-- Helper to check if current zone is a valid race zone.
local function isInRaceZone()
    local currentZone = GetZoneID()
    if config.raceType == "random" then
        local zones = raceMapping.random.zoneIDs
        for _, zoneID in ipairs(zones) do
            if currentZone == zoneID then
                return true
            end
        end
        return false
    else
        return currentZone == raceMapping[config.raceType].zoneID
    end
end

-----------------------------------------------------------
-- Timing Helpers
-----------------------------------------------------------
local uiWaitMultiplier = (config.speed == "slow" and 2 or 1)

local function getRandomDelay(min, max)
    return uiWaitMultiplier * (min + math.random() * (max - min))
end

local function getRawRandomDelay(min, max)
    return min + math.random() * (max - min)
end

local function getRandomizedInterval(baseValue, variance)
    return math.floor(baseValue * (1 - variance/2 + math.random() * variance))
end

-----------------------------------------------------------
-- WaitForAddon Helper Function
-----------------------------------------------------------
local function waitForAddon(addonName, timeout)
    timeout = timeout or 5
    local elapsed = 0
    while not IsAddonReady(addonName) and elapsed < timeout do
        yield("/wait 0.5")
        elapsed = elapsed + 0.5
    end
    if not IsAddonReady(addonName) then
        yield("/echo [Chocobo Bot] Warning: " .. addonName .. " not ready after " .. timeout .. " seconds.")
        return false
    end
    return true
end

-----------------------------------------------------------
-- Initialization & State
-----------------------------------------------------------
math.randomseed(os.time())

local state = {
    totalRaces = 0,
    lastRaceTime = 0
}

local function log(message)
    yield("/echo [Chocobo Bot] " .. message)
end

-----------------------------------------------------------
-- UI Interaction Functions
-----------------------------------------------------------
local function openDutyFinder()
    if not IsAddonVisible("ContentsFinder")
       and not IsAddonVisible("ContentsFinderConfirm")
       and not isInRaceZone()
    then
        yield("/dutyfinder")
        yield("/waitaddon ContentsFinder")
    end
end

local function selectRaceDuty()
    -- 1. Switch to the Gold Saucer tab using the "1 9" command.
    yield("/pcall ContentsFinder true 1 9")
    yield("/wait " .. getRandomDelay(0.3, 0.7))  -- wait for the tab to load

    -- 2. Clear any existing selection (assumed node 13)
    yield("/pcall ContentsFinder true 13 0")
    yield("/wait " .. getRandomDelay(0.3, 0.7))
    log("Cleared any existing selections")
    
    -- 3. Select the duty using command type 3 with the proper duty index.
    yield("/pcall ContentsFinder true 3 " .. dutyIndex)
    yield("/wait " .. getRandomDelay(0.3, 0.7))
    log("Selected " .. config.raceType .. " duty")
    
    -- 4. Click Join
    yield("/pcall ContentsFinder true 12 0")
    log("Clicked Join")
end

local function waitForCommence()
    local timeout = 0
    while not IsAddonVisible("ContentsFinderConfirm") and timeout < MAX_WAIT_FOR_COMMENCE do
        local waitTime = getRawRandomDelay(0.7, 1.0)
        yield("/wait " .. waitTime)
        timeout = timeout + waitTime
    end
    if IsAddonVisible("ContentsFinderConfirm") then
        yield("/waitaddon ContentsFinderConfirm")
        yield("/wait " .. getRawRandomDelay(0.3, 1.0))
        yield("/pcall ContentsFinderConfirm true 8")
        log("Clicked Commence")
        return true
    else
        log("No commence window appeared — retrying...")
        return false
    end
end

local function waitForRaceZone()
    log("Waiting for zone load after commence...")
    local zoneWait = 0
    local zone = GetZoneID()
    while not isInRaceZone() and zoneWait < 20 do
        yield("/wait " .. (1 * uiWaitMultiplier))
        zone = GetZoneID()
        zoneWait = zoneWait + (1 * uiWaitMultiplier)
    end
    if isInRaceZone() then
        local delay = getRawRandomDelay(4, 6)
        log("Race zone entered (" .. zone .. ") — starting in " .. string.format("%.1f", delay) .. "s...")
        yield("/wait " .. delay)
        return true
    else
        log("Failed to zone into race — retrying...")
        return false
    end
end

-----------------------------------------------------------
-- In-Race Logic Functions
-----------------------------------------------------------
local function executeRace()
    yield("/hold W")
    local driftTime = getRandomizedInterval(7, 0.1)
    log("Side-drifting for " .. driftTime .. "s")
    yield("/hold A")
    yield("/wait " .. driftTime)
    yield("/release A")
    log("Initial side-drift complete")
    
    local counter = 0
    local key_1_base_intervals = {15,20,30,35,40,45,50,55,60,65,70,75,80,85,91,105,120,135}
    local key_1_intervals = {}
    for _, interval in ipairs(key_1_base_intervals) do
        table.insert(key_1_intervals, getRandomizedInterval(interval, 0.05))
    end
    local key_2_intervals = {
        getRandomizedInterval(15, 0.05),
        getRandomizedInterval(25, 0.05)
    }
    local wRefreshInterval = getRandomizedInterval(W_REFRESH_INTERVAL, 0.1)
    local nextWRefresh = 0
    repeat
        counter = counter + 1
        if counter >= nextWRefresh then
            yield("/hold W")
            nextWRefresh = counter + wRefreshInterval
        end
        for _, t in ipairs(key_1_intervals) do
            if counter == t then
                yield("/send KEY_1")
                yield("/hold W")  -- Immediately re-assert W after KEY_1
                break
            end
        end
        for _, t in ipairs(key_2_intervals) do
            if counter == t then
                yield("/send KEY_2")
                yield("/hold W")  -- Immediately re-assert W after KEY_2
                break
            end
        end
        yield("/wait 1")
    until IsAddonVisible("RaceChocoboResult") or not isInRaceZone()
    state.totalRaces = state.totalRaces + 1
    state.lastRaceTime = os.time()
    log("Race #" .. state.totalRaces .. " completed")
    return true
end

local function handlePostRaceCleanup()
    yield("/release W")
    local waitTime = getRandomDelay(2.5, 3.5)
    yield("/wait " .. waitTime)
    if IsAddonVisible("RaceChocoboResult") then
        yield("/pcall RaceChocoboResult true 1 0 <wait.1>")
        log("Exited race via result screen")
    else
        log("Exited race via zone change")
    end
    yield("/wait " .. getRandomDelay(1.5, 2))
end

-----------------------------------------------------------
-- Chocobo Info Retrieval Functions
-----------------------------------------------------------
local function open_gold_saucer_tab()
    if not IsAddonReady("GoldSaucerInfo") then
        yield("/goldsaucer")
        yield("/wait " .. (1 * uiWaitMultiplier))
        yield("/callback GoldSaucerInfo true 0 1 119 0 0")
        yield("/wait " .. (1 * uiWaitMultiplier))
    end
end

local function get_chocobo_info()
    open_gold_saucer_tab()
    yield("/wait " .. (0.2 * uiWaitMultiplier))
    local rank = tonumber(GetNodeText("GoldSaucerInfo", 16)) or 0
    local name = GetNodeText("GoldSaucerInfo", 20) or "Unknown"
    local trainingSessionsAvailable = 0
    if IsAddonReady("GSInfoChocoboParam") then
        trainingSessionsAvailable = tonumber(GetNodeText("GSInfoChocoboParam", 9, 0)) or 0
    else
        yield("/echo [Chocobo] GSInfoChocoboParam not ready. Defaulting training sessions to 0.")
    end
    yield("/echo [Chocobo] Rank: " .. rank)
    yield("/echo [Chocobo] Name: " .. name)
    yield("/echo [Chocobo] Training Sessions Available: " .. trainingSessionsAvailable)
    yield("/pcall GoldSaucerInfo true -1")
    return rank, name, trainingSessionsAvailable
end

-----------------------------------------------------------
-- Main Automation Loop
-----------------------------------------------------------
log("Starting fresh...")

while true do
    if isInRaceZone() then
        log("Detected race zone at startup; proceeding directly to race execution.")
        executeRace()
        handlePostRaceCleanup()
    else
        openDutyFinder()
        if IsAddonVisible("ContentsFinder") then
            selectRaceDuty()
        end
        if not waitForCommence() then goto continue end
        if not waitForRaceZone() then goto continue end
        executeRace()
        handlePostRaceCleanup()
    end

    while not IsAddonReady("GoldSaucerInfo") do
        yield("/goldsaucer")
        yield("/wait 1")
    end

    local rank, name, training = get_chocobo_info()
    if rank >= config.maxRank then
        log("🛑 Chocobo is Rank " .. rank .. " — stopping script.")
        break
    end

    if not IsAddonVisible("ContentsFinder") then
        yield("/dutyfinder")
        yield("/waitaddon ContentsFinder")
    end

    ::continue::
end

log("Script completed successfully.")
return "/echo [Chocobo Bot] Script completed successfully."
