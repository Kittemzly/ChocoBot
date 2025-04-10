-----------------------------------------------------------
-- Chocobo Racing Automation Script (Merged Version)
-- (Based on ChocoBot original with ChocoboRace queueing logic merged in.)
-----------------------------------------------------------
-- User-configurable settings:
local config = {
    maxRank = 51,         -- Stop when reaching this rank; set to 51 for win-farm.
    raceType = "sagolii", -- Options: "random", "sagolii", "costa", "tranquil"
    superSprint = true,   -- Enable SuperSprint press loop.
    speed = "fast"        -- "fast" or "slow" for UI handling delays.
}

-- Mapping from race types to duty names with correct names.
local dutyNames = {
    random   = "Chocobo Race: Random",
    sagolii  = "Chocobo Race: Sagolii Road",
    costa    = "Chocobo Race: Costa del Sol",
    tranquil = "Chocobo Race: Tranquil Paths"
}
local expectedDuty = dutyNames[config.raceType]
if not expectedDuty then
    yield("/echo Error: Invalid raceType '" .. tostring(config.raceType) .. "'.")
    return
end

-----------------------------------------------------------
-- Helper Functions
-----------------------------------------------------------
local function log(message)
    yield("/echo [ChocoBot] " .. message)
end

local function getRandomDelay(min, max)
    local multiplier = (config.speed == "slow" and 2 or 1)
    return multiplier * (min + math.random() * (max - min))
end

local function getRawRandomDelay(min, max)
    return min + math.random() * (max - min)
end

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

-- Opens the Gold Saucer tab to retrieve Chocobo info.
function open_gold_saucer_tab()
    if not IsAddonReady("GoldSaucerInfo") then
        yield("/goldsaucer")
    end
    yield("/callback GoldSaucerInfo true 0 1 2 0 0")
end

-- Retrieves the current Chocobo's rank, name, and training sessions.
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
-- New Queueing (Duty Selection) Logic (from ChocoboRace)
-----------------------------------------------------------
local
function selectDuty()
    while not IsAddonReady("ContentsFinder") do
        yield("/wait 0.5")
    end
    -- Wait until the ContentsFinder addon is ready

    -- Retrieve total number of duties available.
    local list = GetNodeListCount("ContentsFinder")
    yield("/echo Total Duties Found: " .. list)
    yield("/wait 0.5")

    local FoundDuty = false
    for i = 1, list do
        yield("/pcall ContentsFinder true 3 " .. i)
        yield("/wait 0.1")

        local dutyText = GetNodeText("ContentsFinder", 14)
        local normalizedDutyText = string.lower(dutyText or "")
        local normalizedExpected = string.lower(expectedDuty)
        if string.find(normalizedDutyText, normalizedExpected, 1, true) then
            FoundDuty = true
            yield("/echo " .. expectedDuty .. " selected at position " .. i)
            break
        end
    end

    if not FoundDuty then
        yield("/echo Error: Could not find the duty '" .. expectedDuty .. "'.")
        yield("/snd stop")
        return false
    end

    -- Clear any previous selection and join the duty.
    yield("/pcall ContentsFinder true 12 0")
    return true
end

-----------------------------------------------------------
-- Duty Finder and Race Execution Helpers (from ChocoBot)
-----------------------------------------------------------
local function openDutyFinder()
    if not IsAddonVisible("ContentsFinder")
        and not IsAddonVisible("ContentsFinderConfirm")
    then
        yield("/dutyfinder")
        yield("/wait 0.5")
        yield("/pcall ContentsFinder true 1 9")
    end
end

local function waitForCommence()
    local timeout = 0
    while not IsAddonVisible("ContentsFinderConfirm") and timeout < 35 do
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

local function isInRaceZone()
    local currentZone = GetZoneID()
    if config.raceType == "random" then
        local zones = { 390, 391, 389 }
        for _, zoneID in ipairs(zones) do
            if currentZone == zoneID then
                return true
            end
        end
        return false
    else
        local mapping = { sagolii = 390, costa = 389, tranquil = 391 }
        return currentZone == mapping[config.raceType]
    end
end

local function waitForRaceZone()
    log("Waiting for zone load after commence...")
    local zoneWait = 0
    local zone = GetZoneID()
    while not isInRaceZone() and zoneWait < 20 do
        yield("/wait 1")
        zone = GetZoneID()
        zoneWait = zoneWait + 1
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

local function table_contains(tbl, element)
    for _, value in pairs(tbl) do
        if value == element then
            return true
        end
    end
    return false
end

-----------------------------------------------------------
-- Race Execution with Static Drift Time (from ChocoboRace)
-----------------------------------------------------------
local function executeRace()
    if config.superSprint then
        log("Trying to SuperSprint")
        repeat
            yield("/send KEY_2")
        until HasStatusId(1058) == true
    end

    if HasStatusId(1058) == true then
        log("Now Sprinting!")
    end

    -- Start with side-drift using a static drift time.
    yield("/hold W")
    local driftTime = 6 -- Static drift time in seconds.
    log("Side-drifting for " .. driftTime .. "s")
    yield("/hold A")
    yield("/wait " .. driftTime)
    yield("/release A")
    log("Initial side-drift complete")

    local key_1_intervals = { 15, 20, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 91, 105, 120, 135 }
    local counter = 0
    repeat
        yield("/hold W")
        counter = counter + 1
        if table_contains(key_1_intervals, counter) then
            yield("/send KEY_1")
        end
        if counter == 15 or counter == 25 then
            yield("/send KEY_2")
        end
        if counter == 90 then
            yield("/send KEY_3")
        end
        yield("/wait 1")
    until IsAddonVisible("RaceChocoboResult") or not isInRaceZone()
    log("Race complete!")
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
-- Main Automation Loop
-----------------------------------------------------------
log("Starting fresh...")

while true do
    if isInRaceZone() then
        -- If inside the race zone but still at the commence screen,
        -- wait for the commence window before starting the race.
        if IsAddonVisible("ContentsFinderConfirm") then
            if not waitForCommence() then goto continue end
            if not waitForRaceZone() then goto continue end
        end
        executeRace()
        handlePostRaceCleanup()
    else
        openDutyFinder()
        if IsAddonVisible("ContentsFinder") then
            if not selectDuty() then
                goto continue
            end
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
        log("Chocobo is Rank " .. rank .. " — stopping script.")
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
