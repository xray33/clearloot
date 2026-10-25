local addonName, ns = ...
local L = ns.L

local DataTracker = {}
ns.DataTracker = DataTracker

-- Standard WoW Roll Types
DataTracker.ROLL_TYPE_PASS = 0
DataTracker.ROLL_TYPE_NEED = 1
DataTracker.ROLL_TYPE_GREED = 2
DataTracker.ROLL_TYPE_DISENCHANT = 3
DataTracker.ROLL_TYPE_PENDING = -1

-- Priority order for sorting and provisional winner calculation (higher = higher priority)
local ROLL_PRIORITY = {
    [DataTracker.ROLL_TYPE_NEED] = 4,
    [DataTracker.ROLL_TYPE_GREED] = 3,
    [DataTracker.ROLL_TYPE_DISENCHANT] = 2,
    [DataTracker.ROLL_TYPE_PASS] = 1,
    [DataTracker.ROLL_TYPE_PENDING] = 0,
}

-- Active and recent roll sessions keyed by rollID
local rollsByID = {}
-- Ordered list of active rollIDs (oldest first)
local activeRollOrder = {}
-- Per-rollID dismissal state (closed via the [X] button for that specific item only)
local dismissedRolls = {}
-- Currently focused rollID in the companion UI
local currentRollID = nil

local chatPatterns = {}

-- Convert a Blizzard format string (e.g. LOOT_ROLL_ROLLED_NEED = "%s rolls %d (%s)" or "%1$s rolls %2$d for %3$s")
-- into a Lua pattern + ordered capture map
local function CreatePatternFromGlobalString(globalStr, argOrder)
    if not globalStr or globalStr == "" then return nil end

    -- Escape magic Lua pattern characters except %
    local escaped = globalStr:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")

    -- Track positional or sequential specifiers
    local pattern = escaped
        :gsub("%%%d*%$?s", "(.+)")
        :gsub("%%%d*%$?d", "(%%d+)")

    return {
        pattern = "^" .. pattern .. "$",
        order = argOrder,
    }
end

local function BuildChatPatterns()
    chatPatterns = {}

    local function AddGlobal(globalName, rollType, order, isSelf)
        local raw = _G[globalName]
        local entry = CreatePatternFromGlobalString(raw, order)
        if entry then
            entry.rollType = rollType
            entry.isSelf = isSelf
            table.insert(chatPatterns, entry)
        end
    end

    -- Roll result lines (e.g. "Need Roll - 94 for [Item] by Player")
    AddGlobal("LOOT_ROLL_ROLLED_NEED", DataTracker.ROLL_TYPE_NEED, { "roll", "item", "player" })
    AddGlobal("LOOT_ROLL_ROLLED_GREED", DataTracker.ROLL_TYPE_GREED, { "roll", "item", "player" })
    AddGlobal("LOOT_ROLL_ROLLED_DE", DataTracker.ROLL_TYPE_DISENCHANT, { "roll", "item", "player" })

    -- Choice selection lines (e.g. "Player has selected Need for: [Item]")
    AddGlobal("LOOT_ROLL_NEED", DataTracker.ROLL_TYPE_NEED, { "player", "item" })
    AddGlobal("LOOT_ROLL_GREED", DataTracker.ROLL_TYPE_GREED, { "player", "item" })
    AddGlobal("LOOT_ROLL_DISENCHANT", DataTracker.ROLL_TYPE_DISENCHANT, { "player", "item" })
    AddGlobal("LOOT_ROLL_PASSED", DataTracker.ROLL_TYPE_PASS, { "player", "item" })
    AddGlobal("LOOT_ROLL_PASSED_AUTO", DataTracker.ROLL_TYPE_PASS, { "player", "item" })
    AddGlobal("LOOT_ROLL_PASSED_AUTO_FEMALE", DataTracker.ROLL_TYPE_PASS, { "player", "item" })

    -- Self selection lines (e.g. "You have selected Need for: [Item]")
    AddGlobal("LOOT_ROLL_NEED_SELF", DataTracker.ROLL_TYPE_NEED, { "item" }, true)
    AddGlobal("LOOT_ROLL_GREED_SELF", DataTracker.ROLL_TYPE_GREED, { "item" }, true)
    AddGlobal("LOOT_ROLL_DISENCHANT_SELF", DataTracker.ROLL_TYPE_DISENCHANT, { "item" }, true)
    AddGlobal("LOOT_ROLL_PASSED_SELF", DataTracker.ROLL_TYPE_PASS, { "item" }, true)
    AddGlobal("LOOT_ROLL_PASSED_SELF_AUTO", DataTracker.ROLL_TYPE_PASS, { "item" }, true)
end

function DataTracker:GetRollTypeLabel(rollType)
    if rollType == self.ROLL_TYPE_NEED then
        return L.ROLL_NEED
    elseif rollType == self.ROLL_TYPE_GREED then
        return L.ROLL_GREED
    elseif rollType == self.ROLL_TYPE_DISENCHANT then
        return L.ROLL_DISENCHANT
    elseif rollType == self.ROLL_TYPE_PASS then
        return L.ROLL_PASS
    else
        return L.ROLL_PENDING
    end
end

function DataTracker:IsDismissed(rollID)
    return dismissedRolls[rollID] == true
end

function DataTracker:DismissRoll(rollID)
    if not rollID then return end
    dismissedRolls[rollID] = true

    -- If there is another non-dismissed active roll, switch to it; otherwise hide
    local nextRoll = self:GetNextVisibleRollID(rollID)
    if nextRoll then
        self:SetCurrentRollID(nextRoll)
    else
        if ns.RollTrackerFrame then
            ns.RollTrackerFrame:HideWindow()
        end
    end
end

function DataTracker:UndismissRoll(rollID)
    if not rollID then return end
    dismissedRolls[rollID] = nil
end

function DataTracker:GetNextVisibleRollID(excludeRollID)
    for i = #activeRollOrder, 1, -1 do
        local id = activeRollOrder[i]
        if id ~= excludeRollID and not dismissedRolls[id] then
            local session = rollsByID[id]
            if session and not session.isClosed then
                return id
            end
        end
    end
    return nil
end

function DataTracker:GetActiveRolls()
    local list = {}
    for i = 1, #activeRollOrder do
        local id = activeRollOrder[i]
        local session = rollsByID[id]
        if session and not session.isClosed then
            table.insert(list, session)
        end
    end
    return list
end

function DataTracker:GetRollSession(rollID)
    return rollsByID[rollID]
end

function DataTracker:GetCurrentRollSession()
    if currentRollID and rollsByID[currentRollID] and not rollsByID[currentRollID].isClosed then
        return rollsByID[currentRollID]
    end
    local fallbackID = self:GetNextVisibleRollID()
    if fallbackID then
        currentRollID = fallbackID
        return rollsByID[currentRollID]
    end
    return nil
end

function DataTracker:SetCurrentRollID(rollID, forceShow)
    if not rollID or not rollsByID[rollID] then return end
    currentRollID = rollID
    if forceShow then
        dismissedRolls[rollID] = nil
    end
    self:NotifyUI()
end

function DataTracker:CreateOrUpdateRollSession(rollID, data)
    if not rollID then return nil end

    local isNew = (rollsByID[rollID] == nil)
    local session = rollsByID[rollID] or {
        rollID = rollID,
        itemLink = nil,
        itemName = nil,
        itemTexture = nil,
        itemQuality = 2,
        count = 1,
        players = {}, -- keyed by shortName -> { name, fullName, class, role, rollType, rollScore }
        numPlayers = 0,
        isDone = false,
        isClosed = false,
        isSimulated = false,
        startedAt = GetTime(),
    }

    if data then
        if data.itemLink then session.itemLink = data.itemLink end
        if data.itemName then session.itemName = data.itemName end
        if data.itemTexture then session.itemTexture = data.itemTexture end
        if data.itemQuality then session.itemQuality = data.itemQuality end
        if data.count then session.count = data.count end
        if data.isDone ~= nil then session.isDone = data.isDone end
        if data.isSimulated ~= nil then session.isSimulated = data.isSimulated end
    end

    -- Populate initial eligible group roster if new real roll
    if isNew then
        rollsByID[rollID] = session
        table.insert(activeRollOrder, rollID)

        if not session.isSimulated then
            local members = ns.RosterInspector:GetEligibleGroupMembers()
            for _, m in ipairs(members) do
                local short = ns.RosterInspector:GetShortName(m.name)
                session.players[short] = {
                    name = short,
                    fullName = m.fullName,
                    class = m.class,
                    role = m.role,
                    rollType = self.ROLL_TYPE_PENDING,
                    rollScore = nil,
                }
            end
        end

        -- A new item dropped! Reset dismissal for this new rollID and focus if none active
        dismissedRolls[rollID] = nil
        if not currentRollID or dismissedRolls[currentRollID] or (rollsByID[currentRollID] and rollsByID[currentRollID].isDone) then
            currentRollID = rollID
        end
    end

    return session
end

function DataTracker:SetPlayerRoll(rollID, playerName, classFile, rollType, rollScore, role)
    local session = rollsByID[rollID]
    if not session or not playerName then return end

    local shortName = ns.RosterInspector:GetShortName(playerName)
    local rosterInfo = ns.RosterInspector:GetPlayerInfo(playerName, classFile, role)

    local entry = session.players[shortName]
    if not entry then
        entry = {
            name = shortName,
            fullName = rosterInfo.fullName or playerName,
            class = classFile or rosterInfo.class,
            role = role or rosterInfo.role or "NONE",
            rollType = self.ROLL_TYPE_PENDING,
            rollScore = nil,
        }
        session.players[shortName] = entry
    else
        if classFile then entry.class = classFile end
        if not entry.class and rosterInfo.class then entry.class = rosterInfo.class end
        if role and role ~= "NONE" then entry.role = role end
        if (not entry.role or entry.role == "NONE") and rosterInfo.role then
            entry.role = rosterInfo.role
        end
    end

    if rollType ~= nil then
        entry.rollType = rollType
    end
    if rollScore ~= nil then
        entry.rollScore = tonumber(rollScore)
    end
end

-- Returns sorted array of player entries and summary statistics, including provisional winner
function DataTracker:EvaluateSession(session)
    if not session then return nil end

    local sortedPlayers = {}
    local totalPlayers = 0
    local answeredPlayers = 0

    for _, p in pairs(session.players) do
        totalPlayers = totalPlayers + 1
        if p.rollType ~= self.ROLL_TYPE_PENDING then
            answeredPlayers = answeredPlayers + 1
        end
        table.insert(sortedPlayers, p)
    end

    table.sort(sortedPlayers, function(a, b)
        local prioA = ROLL_PRIORITY[a.rollType] or 0
        local prioB = ROLL_PRIORITY[b.rollType] or 0
        if prioA ~= prioB then
            return prioA > prioB
        end
        local scoreA = a.rollScore or -1
        local scoreB = b.rollScore or -1
        if scoreA ~= scoreB then
            return scoreA > scoreB
        end
        return (a.name or "") < (b.name or "")
    end)

    -- Provisional winner calculation:
    -- Highest priority > PASS (Need > Greed > Disenchant) with highest numeric rollScore
    local bestType = nil
    local bestScore = -1
    local leaders = {}
    local anyNonPass = false

    for _, p in ipairs(sortedPlayers) do
        if p.rollType == self.ROLL_TYPE_NEED or p.rollType == self.ROLL_TYPE_GREED or p.rollType == self.ROLL_TYPE_DISENCHANT then
            anyNonPass = true
            local score = p.rollScore or 0
            if not bestType then
                bestType = p.rollType
                bestScore = score
                leaders = { p }
            elseif p.rollType == bestType then
                if score > bestScore then
                    bestScore = score
                    leaders = { p }
                elseif score == bestScore and score > 0 then
                    table.insert(leaders, p)
                end
            end
        end
    end

    local pendingCount = math.max(0, totalPlayers - answeredPlayers)
    local isComplete = session.isDone or (totalPlayers > 0 and pendingCount == 0)

    return {
        players = sortedPlayers,
        totalPlayers = totalPlayers,
        answeredPlayers = answeredPlayers,
        pendingCount = pendingCount,
        isComplete = isComplete,
        bestType = bestType,
        bestScore = bestScore,
        leaders = leaders,
        allPassed = (not anyNonPass and answeredPlayers > 0 and pendingCount == 0),
    }
end

function DataTracker:SyncFromLootHistory()
    if not C_LootHistory or not C_LootHistory.GetNumItems then
        return
    end

    local numItems = C_LootHistory.GetNumItems() or 0
    for itemIdx = 1, numItems do
        local rollID, itemLink, numPlayers, isDone, winnerIdx, isMasterLoot = C_LootHistory.GetItem(itemIdx)
        if rollID and not isMasterLoot then
            local session = rollsByID[rollID]
            -- Only sync rolls that started during this session or are still active
            if session or not isDone then
                local itemName, _, itemQuality, _, _, _, _, _, _, itemTexture = GetItemInfo(itemLink or "")
                session = self:CreateOrUpdateRollSession(rollID, {
                    itemLink = itemLink,
                    itemName = itemName,
                    itemQuality = itemQuality,
                    itemTexture = itemTexture,
                    isDone = isDone,
                })

                if session and numPlayers and numPlayers > 0 then
                    for playerIdx = 1, numPlayers do
                        local name, class, rollType, roll, isWinner, isMe = C_LootHistory.GetPlayerInfo(itemIdx, playerIdx)
                        if name then
                            local mappedType = self.ROLL_TYPE_PENDING
                            if rollType == LOOT_ROLL_TYPE_NEED or rollType == 1 then
                                mappedType = self.ROLL_TYPE_NEED
                            elseif rollType == LOOT_ROLL_TYPE_GREED or rollType == 2 then
                                mappedType = self.ROLL_TYPE_GREED
                            elseif rollType == LOOT_ROLL_TYPE_DISENCHANT or rollType == 3 then
                                mappedType = self.ROLL_TYPE_DISENCHANT
                            elseif rollType == LOOT_ROLL_TYPE_PASS or rollType == 0 then
                                mappedType = self.ROLL_TYPE_PASS
                            end
                            self:SetPlayerRoll(rollID, name, class, mappedType, roll)
                        end
                    end
                end
            end
        end
    end

    self:NotifyUI()
end

function DataTracker:OnStartLootRoll(rollID, rollTime)
    if not rollID then return end
    local texture, name, count, quality, bindOnPickUp, canNeed, canGreed, canDisenchant = GetLootRollItemInfo(rollID)
    local link = GetLootRollItemLink(rollID)

    self:CreateOrUpdateRollSession(rollID, {
        itemLink = link,
        itemName = name,
        itemTexture = texture,
        itemQuality = quality,
        count = count,
        isDone = false,
        isSimulated = false,
    })

    -- Focus the newly started roll if autoOpen is enabled
    currentRollID = rollID
    self:SyncFromLootHistory()
    self:NotifyUI(true)
end

function DataTracker:OnCancelLootRoll(rollID)
    local session = rollsByID[rollID]
    if not session then return end

    self:SyncFromLootHistory()

    if not ns.db.keepOpenAfterMyRoll then
        session.isClosed = true
        if currentRollID == rollID then
            currentRollID = self:GetNextVisibleRollID(rollID)
        end
    end

    self:NotifyUI()
end

function DataTracker:OnChatMsgLoot(msg)
    if not msg or msg == "" then return end

    for _, entry in ipairs(chatPatterns) do
        local c1, c2, c3 = msg:match(entry.pattern)
        if c1 then
            local captures = { c1, c2, c3 }
            local parsed = {}
            for idx, key in ipairs(entry.order) do
                parsed[key] = captures[idx]
            end

            local playerName = parsed.player
            if entry.isSelf then
                playerName = UnitName("player")
            end
            local itemLink = parsed.item
            local rollScore = parsed.roll and tonumber(parsed.roll) or nil

            if playerName and itemLink then
                -- Match to the most recent active roll session for this itemLink
                for i = #activeRollOrder, 1, -1 do
                    local id = activeRollOrder[i]
                    local session = rollsByID[id]
                    if session and not session.isSimulated and not session.isClosed then
                        if session.itemLink == itemLink or (session.itemName and itemLink:find(session.itemName, 1, true)) then
                            self:SetPlayerRoll(id, playerName, nil, entry.rollType, rollScore)
                            self:NotifyUI()
                            break
                        end
                    end
                end
            end
            return
        end
    end
end

function DataTracker:ClearSimulatedRolls()
    local keptOrder = {}
    for _, id in ipairs(activeRollOrder) do
        local s = rollsByID[id]
        if s and s.isSimulated then
            rollsByID[id] = nil
            dismissedRolls[id] = nil
            if currentRollID == id then
                currentRollID = nil
            end
        else
            table.insert(keptOrder, id)
        end
    end
    activeRollOrder = keptOrder
    self:NotifyUI()
end

function DataTracker:NotifyUI(isNewRoll)
    if ns.MultiItemManager then
        ns.MultiItemManager:UpdateAnchoring()
    end
    if ns.RollTrackerFrame then
        ns.RollTrackerFrame:Refresh(isNewRoll)
    end
end

function DataTracker:Init()
    BuildChatPatterns()

    ns:RegisterEvent("START_LOOT_ROLL", function(_, rollID, rollTime)
        DataTracker:OnStartLootRoll(rollID, rollTime)
    end)

    ns:RegisterEvent("CANCEL_LOOT_ROLL", function(_, rollID)
        DataTracker:OnCancelLootRoll(rollID)
    end)

    ns:RegisterEvent("LOOT_HISTORY_AUTO_SHOW", function()
        DataTracker:SyncFromLootHistory()
    end)

    ns:RegisterEvent("LOOT_HISTORY_ROLL_CHANGED", function()
        DataTracker:SyncFromLootHistory()
    end)

    ns:RegisterEvent("LOOT_HISTORY_ROLL_COMPLETE", function()
        DataTracker:SyncFromLootHistory()
    end)

    ns:RegisterEvent("LOOT_HISTORY_FULL_UPDATE", function()
        DataTracker:SyncFromLootHistory()
    end)

    ns:RegisterEvent("CHAT_MSG_LOOT", function(_, msg)
        DataTracker:OnChatMsgLoot(msg)
    end)
end
