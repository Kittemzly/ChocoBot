-----------------------------------------------------------
-- Chocobo Racing Automation Script
-- (User-configurable settings: maxRank, raceType, and speed only)
-----------------------------------------------------------
-----------------------------------------------------------
-- IMPORTANT IF USING SUPERSPRINT IF YOURE USING BOTH
-- CHOCO CURE AND SUPERSPRINT YOULL NEED TO GO CHANGE THE KEYPRESS FOR SUPERSPRINT TO THE CORRECT KEY
-----------------------------------------------------------

-- User-configurable settings:
local config = {
    maxRank = 50,                -- Stop when reaching this rank If you wanna use it as a win farm bot at max just set to 51
    raceType = "sagolii",         -- Options: "random", "sagolii", "costa", "tranquil"
    superSprint = true,       -- Set to true to enable SuperSprint press loop
    speed = "fast"               -- Set to "fast" or "slow" for UI handling delays
}

-- Internal constants (dont need to touch)
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

-----------------------------------------------------------
-- Duty Selection Helpers
-----------------------------------------------------------

-- Helper function to trim whitespace.
local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

-- Verify the current duty selection state by reading node 15.
-- Returns true if it exactly reads "1/1 selected" (case-insensitive), false otherwise.
local function verifyDutySelection()
    local selectionText = GetNodeText("ContentsFinder", 15)
    local normalized = selectionText and string.lower(trim(selectionText)) or ""
    if normalized == "1/1 selected" then
        return true
    else
        return false
    end
end

-- Reselects the duty up to maxAttempts if the state is not verified.
local function reselectDutyIfNeeded()
    local maxAttempts = 3
    for attempt = 1, maxAttempts do
        if verifyDutySelection() then
            yield("/pcall ContentsFinder true 12 0")
            log("Duty selection verified: 1/1 selected. Clicked Join")
            return true
        else
            log("Duty selection state not valid (attempt " .. attempt .. "). Reselecting duty...")
            yield("/pcall ContentsFinder true 13 0")
            yield("/wait " .. getRandomDelay(0.3, 0.7))
            yield("/pcall ContentsFinder true 3 " .. dutyIndex)
            yield("/wait " .. getRandomDelay(0.3, 0.7))
        end
    end
    log("Duty selection failed after " .. maxAttempts .. " attempts.")
    return false
end

-- Ensure the duty selection is valid.
-- On the very first run (state.totalRaces == 0), it performs an initial selection.
-- On subsequent runs, if the selection isn't valid, it reselects the duty.
local function ensureDutySelection()
    if state.totalRaces == 0 then
        -- First run: perform a fresh duty selection.
        yield("/pcall ContentsFinder true 1 9")
        yield("/wait " .. getRandomDelay(0.3, 0.7))
        yield("/pcall ContentsFinder true 13 0")
        yield("/wait " .. getRandomDelay(0.3, 0.7))
        log("Cleared any existing selections for first run")
        yield("/pcall ContentsFinder true 3 " .. dutyIndex)
        yield("/wait " .. getRandomDelay(0.3, 0.7))
        log("Selected " .. config.raceType .. " duty on first run")
    end

    -- Always verify the current selection.
    if verifyDutySelection() then
        yield("/pcall ContentsFinder true 12 0")
        log("Duty selection verified: 1/1 selected. Clicked Join")
        return true
    else
        log("Duty selection invalid; reselecting duty...")
        return reselectDutyIfNeeded()
    end
end

-----------------------------------------------------------
-- Race Functions
-----------------------------------------------------------
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
        local delay = getRawRandomDelay(5, 7)
        log("Race zone entered (" .. zone .. ") — starting in " .. string.format("%.1f", delay) .. "s...")
        yield("/wait " .. delay)
        return true
    else
        log("Failed to zone into race — retrying...")
        return false
    end
end

-----------------------------------------------------------
-- Racing logic below
-- If youre using non default keys 
-- Or have supersprint on something other than 2 change it here
-----------------------------------------------------------

local function executeRace()
    if config.superSprint then
        log("Trying to SuperSprint")
        repeat
            yield("/send KEY_2")
        until HasStatusId(1058) == true
    end

    if HasStatusId(1058) == true
    then
        log("Now Sprinting!")
end
    yield("/hold W")
    local driftTime = getRandomizedInterval(6, 0.1)
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
function open_gold_saucer_tab()
    if not IsAddonReady("GoldSaucerInfo") then
        yield("/goldsaucer")
    end
    
    -- Use the working callback method to select the Chocobo tab
    yield("/callback GoldSaucerInfo true 0 1 2 0 0")
end

local function get_chocobo_info()
    open_gold_saucer_tab()
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
            -- Always ensure duty selection is correct.
            -- On the first run, it selects the duty;
            -- on subsequent runs, it only reselects if the state isn’t verified.
            ensureDutySelection()
        end
        if not waitForCommence() then goto continue end
        if not waitForRaceZone() then goto continue end
        executeRace()
        handlePostRaceCleanup()
    end

    while not IsAddonReady("GoldSaucerInfo") do
        yield("/goldsaucer")
        yield("/wait 0.5")
    end

    local rank, name, training = get_chocobo_info()
    if rank >= config.maxRank then
        log("� Chocobo is Rank " .. rank .. " — stopping script.")
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
