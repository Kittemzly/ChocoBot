yield("/echo [Chocobo Bot] Starting fresh...")

-- 🧠 Track whether we've already selected Sagolii Road
local sagoliiSelected = false

-- ✅ Open Duty Finder on script start
if not IsAddonVisible("ContentsFinder") and not IsAddonVisible("ContentsFinderConfirm") and GetZoneID() ~= 390 then
    yield("/dutyfinder")
    yield("/waitaddon ContentsFinder")
end

::main_loop::

-- ✅ Wait until Duty Finder or Commence popup appears
local waitTimer = 0
while not IsAddonVisible("ContentsFinder") and not IsAddonVisible("ContentsFinderConfirm") and waitTimer < 10 do
    yield("/wait 1")
    waitTimer = waitTimer + 1
end

-- ✅ Always click tab, and select duty only if needed
if IsAddonVisible("ContentsFinder") then
    -- Gold Saucer tab
    yield("/pcall ContentsFinder true 1 9")
    yield("/wait 1")

    -- Sagolii Road — only once!
    if not sagoliiSelected then
        yield("/pcall ContentsFinder true 3 4")
        yield("/wait 1")
        yield("/echo [Chocobo Bot] Selected Sagolii Road (first time only)")
        sagoliiSelected = true
    else
        yield("/echo [Chocobo Bot] Skipping Sagolii select — already selected")
    end

    -- Click Join
    yield("/pcall ContentsFinder true 12 0")
    yield("/echo [Chocobo Bot] Clicked Join")
end

-- ✅ Wait for Commence popup
local timeout = 0
while not IsAddonVisible("ContentsFinderConfirm") and timeout < 30 do
    yield("/wait 1")
    timeout = timeout + 1
end

if IsAddonVisible("ContentsFinderConfirm") then
    yield("/waitaddon ContentsFinderConfirm")
    yield("/pcall ContentsFinderConfirm true 8")
    yield("/echo [Chocobo Bot] Clicked Commence")
else
    yield("/echo [Chocobo Bot] No commence window — retrying...")
    goto main_loop
end

-- ✅ Wait for race zone to load
yield("/echo [Chocobo Bot] Waiting for zone load after commence...")
local zoneWait = 0
local zone = GetZoneID()
while zone ~= 390 and zoneWait < 30 do
    yield("/wait 1")
    zone = GetZoneID()
    zoneWait = zoneWait + 1
end

if zone ~= 390 then
    yield("/echo [Chocobo Bot] Failed to zone into race — retrying...")
    goto main_loop
end

yield("/echo [Chocobo Bot] Race zone entered — starting in 5s...")
yield("/wait 5")

-- 🎯 Side-drift to avoid the pile-up
yield("/hold W")
yield("/hold A")
yield("/wait 7")
yield("/release A")
yield("/echo [Chocobo Bot] Initial side-drift complete")

-- 🧠 In-Race Movement & Skill Logic
local counter = 0
local key_1_intervals = {15, 20, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 91, 105, 120, 135}
local wRefreshInterval = 5
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

    if counter == 15 or counter == 25 then
        yield("/send KEY_2")
        yield("/hold W")
    end

    yield("/wait 1")
until IsAddonVisible("RaceChocoboResult") or GetZoneID() ~= 390

-- 🧹 Post-race: cleanup and exit
yield("/release W")
yield("/wait 6")

if IsAddonVisible("RaceChocoboResult") then
    yield("/pcall RaceChocoboResult true 1 0 <wait.1>")
    yield("/echo [Chocobo Bot] Exited race via result screen")
else
    yield("/echo [Chocobo Bot] Exited race via zone change")
end

yield("/wait 4")

-- ✅ Hardcoded Chocobo Rank check (node 16)
yield("/goldsaucer")
yield("/waitaddon GoldSaucerInfo")

local rankText = GetNodeText("GoldSaucerInfo", 16)
local rank = tonumber(rankText and rankText:match("%d+"))

if rank then
    yield("/echo [Chocobo Bot] Chocobo Rank: " .. rank)
    if rank >= 40 then
        yield("/echo 🛑 Chocobo is Rank " .. rank .. " — stopping script.")
        return
    end
else
    yield("/echo ⚠️ Could not determine chocobo rank from node 16.")
end

-- ✅ Reopen Duty Finder if it's closed
if not IsAddonVisible("ContentsFinder") then
    yield("/dutyfinder")
    yield("/waitaddon ContentsFinder")
end

-- 🔁 Loop back to queue again
goto main_loop
