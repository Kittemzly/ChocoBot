-----------------------------------------------------------
-- Chocobo Racing Automation Script
-- (User-configurable settings: maxRank, raceType, and speed only)
-----------------------------------------------------------

-- User-configurable settings:
local config = {
    maxRank = 40,                -- Stop when reaching this rank
    raceType = "sagolii",         -- Options: "random", "sagolii", "costa", "tranquil"
    speed = "fast",               -- Set to "fast" or "slow" for UI handling delays
    uiWaitTimeout = 10           -- Maximum seconds to wait for UI elements
}

-- Internal constants (do not change)
local MAX_WAIT_FOR_COMMENCE = 35   -- seconds (raw delay)
local MAX_WAIT_FOR_ZONE = 20       -- seconds (raw delay)
local W_REFRESH_INTERVAL = 5       -- seconds (for in-race refresh)

-- Mapping from race types to duty selection indices and zone IDs.
-- For "random", a list of possible zone IDs is provided.
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
-- Enhanced UI Wait Functions
-----------------------------------------------------------
local function waitForAddon(addonName, timeout)
    timeout = timeout or config.uiWaitTimeout
    local elapsed = 0
    local checkInterval = 0.5
    
    while not IsAddonReady(addonName) and elapsed < timeout do
        yield("/wait " .. checkInterval)
        elapsed = elapsed + checkInterval
    end
    
    if not IsAddonReady(addonName) then
        yield("/echo [Chocobo Bot] Warning: " .. addonName .. " not ready after " .. timeout .. " seconds.")
        return false
    end
    
    -- Extra small delay to ensure UI is fully loaded
    yield("/wait " .. getRandomDelay(0.1, 0.3))
    return true
end

local function waitForAddonVisible(addonName, timeout)
    timeout = timeout or config.uiWaitTimeout
    local elapsed = 0
    local checkInterval = 0.5
    
    while not IsAddonVisible(addonName) and elapsed < timeout do
        yield("/wait " .. checkInterval)
        elapsed = elapsed + checkInterval
    end
    
    if not IsAddonVisible(addonName) then
        yield("/echo [Chocobo Bot] Warning: " .. addonName .. " not visible after " .. timeout .. " seconds.")
        return false
    end
    
    return true
end

local function waitForNodeExist(addonName, nodeId, timeout)
    timeout = timeout or config.uiWaitTimeout
    local elapsed = 0
    local checkInterval = 0.5
    
    while not IsNodeVisible(addonName, nodeId) and elapsed < timeout do
        yield("/wait " .. checkInterval)
        elapsed = elapsed + checkInterval
    end
    
    if not IsNodeVisible(addonName, nodeId) then
        yield("/echo [Chocobo Bot] Warning: Node " .. nodeId .. " in " .. addonName .. " not visible after " .. timeout .. " seconds.")
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
        if not waitForAddon("ContentsFinder") then
            log("Failed to open duty finder, retrying...")
            yield("/dutyfinder")
            if not waitForAddonVisible("ContentsFinder") then
                log("Still failed to open duty finder. Will try again next cycle.")
                return false
            end
        end
    end
    return true
end

local function selectRaceDuty()
    -- Wait for ContentsFinder to be fully ready
    if not waitForAddon("ContentsFinder") then
        return false
    end
    
    -- 1. Switch to the Gold Saucer tab
    yield("/pcall ContentsFinder true 1 9")
    yield("/wait " .. getRandomDelay(0.3, 0.7))
    
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
    return true
end

local function waitForCommence()
    local timeout = 0
    while not IsAddonVisible("ContentsFinderConfirm") and timeout < MAX_WAIT_FOR_COMMENCE do
        local waitTime = getRawRandomDelay(0.7, 1.0)
        yield("/wait " .. waitTime)
        timeout = timeout + waitTime
    end
    if IsAddonVisible("ContentsFinderConfirm") then
        if not waitForAddon("ContentsFinderConfirm") then
            log("ContentsFinderConfirm addon not ready")
            return false
        end
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
    while not isInRaceZone() and zoneWait < MAX_WAIT_FOR_ZONE do
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
                yield("/hold W")
                break
            end
        end
        for _, t in ipairs(key_2_intervals) do
            if counter == t then
                yield("/send KEY_2")
                yield("/hold W")
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
        if waitForAddon("RaceChocoboResult") then
            yield("/pcall RaceChocoboResult true 1 0 <wait.1>")
            log("Exited race via result screen")
        else
            log("Race result screen not ready, waiting...")
            yield("/wait 2")
            if IsAddonVisible("RaceChocoboResult") then
                yield("/pcall RaceChocoboResult true 1 0 <wait.1>")
                log("Exited race via result screen (second attempt)")
            end
        end
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
        if not waitForAddon("GoldSaucerInfo", 5) then
            log("GoldSaucerInfo addon not ready, retrying...")
            yield("/goldsaucer")
            if not waitForAddon("GoldSaucerInfo", 5) then
                log("Failed to open Gold Saucer info")
                return false
            end
        end
        yield("/callback GoldSaucerInfo true 0 1 119 0 0")
        yield("/wait " .. (0.5 * uiWaitMultiplier))
    end
    return true
end

local function get_chocobo_info()
    if not open_gold_saucer_tab() then
        return 0, "Unknown", 0
    end
    
    -- Wait for specific nodes to be ready
    if not waitForNodeExist("GoldSaucerInfo", 16) then
        log("Rank node not found")
        return 0, "Unknown", 0
    end
    
    local rank = tonumber(GetNodeText("GoldSaucerInfo", 16)) or 0
    local name = GetNodeText("GoldSaucerInfo", 20) or "Unknown"
    local trainingSessionsAvailable = 0
    
    if IsAddonReady("GSInfoChocoboParam") then
        if waitForNodeExist("GSInfoChocoboParam", 9) then
            trainingSessionsAvailable = tonumber(GetNodeText("GSInfoChocoboParam", 9, 0)) or 0
        end
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
log("Starting Chocobo Racing Bot with UI wait improvements...")

while true do
    if isInRaceZone() then
        log("Detected race zone at startup; proceeding directly to race execution.")
        executeRace()
        handlePostRaceCleanup()
    else
        if not openDutyFinder() then 
            yield("/wait 3")
            goto continue 
        end
        
        if IsAddonVisible("ContentsFinder") then
            if not selectRaceDuty() then
                log("Failed to select race duty")
                yield("/wait 3")
                goto continue
            end
        end
        
        if not waitForCommence() then goto continue end
        if not waitForRaceZone() then goto continue end
        executeRace()
        handlePostRaceCleanup()
    end

    -- Try up to 3 times to get chocobo info
    local rank, name, training = 0, "Unknown", 0
    for attempt = 1, 3 do
        if waitForAddon("GoldSaucerInfo", 3) or IsAddonReady("GoldSaucerInfo") then
            rank, name, training = get_chocobo_info()
            if rank > 0 then break end
        end
        yield("/goldsaucer")
        yield("/wait 1")
    end
    
    if rank >= config.maxRank then
        log("◆ Chocobo is Rank " .. rank .. " — stopping script.")
        break
    end

    if not IsAddonVisible("ContentsFinder") then
        yield("/dutyfinder")
        waitForAddonVisible("ContentsFinder", 5)
    end

    ::continue::
end

log("Script completed successfully.")
return "/echo [Chocobo Bot] Script completed successfully."
