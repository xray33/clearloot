local addonName, ns = ...
local L = ns.L
local DataTracker = ns.DataTracker

local Simulator = {}
ns.Simulator = Simulator

local simCounter = 9000
local activeTimers = {}

local MOCK_ITEMS = {
    {
        itemID = 17074,
        name = "Shadowstrike",
        link = "|cffa335ee|Hitem:17074::::::::60:::::::|h[Shadowstrike]|h|r",
        texture = "Interface\\Icons\\INV_Spear_08",
        quality = 4,
    },
    {
        itemID = 13359,
        name = "Crown of Tyranny",
        link = "|cff0070dd|Hitem:13359::::::::60:::::::|h[Crown of Tyranny]|h|r",
        texture = "Interface\\Icons\\INV_Helmet_24",
        quality = 3,
    },
    {
        itemID = 11992,
        name = "Band of the Steadfast",
        link = "|cff1eff00|Hitem:11992::::::::60:::::::|h[Band of the Steadfast]|h|r",
        texture = "Interface\\Icons\\INV_Jewelry_Ring_03",
        quality = 2,
    },
    {
        itemID = 12930,
        name = "Briarwood Reed",
        link = "|cff0070dd|Hitem:12930::::::::60:::::::|h[Briarwood Reed]|h|r",
        texture = "Interface\\Icons\\INV_Misc_Root_02",
        quality = 3,
    },
}

local MOCK_CLASSES = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"
}

local MOCK_ROLES = {
    "TANK", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER"
}

local MOCK_RAID_NAMES = {
    "Thrall", "Garrosh", "Jaina", "Valeera", "Anduin",
    "Sylvanas", "Varian", "Cairne", "Voljin", "Tyrande",
    "Malfurion", "Illidan", "Arthas", "Uther", "Khadgar",
    "Medivh", "Rexxar", "Rokhan", "Chen", "Gazlowe",
    "Saurfang", "Nazgrel", "Eitrigg", "Bolvar", "Tirion",
    "Darion", "Chromie", "Kalecgos", "Alexstrasza", "Ysera",
    "Wrathion", "Alleria", "Turalyon", "Velen", "Muradin",
    "Brann", "Magni", "Gelbin", "Genn", "Baine",
}

local function CancelAllTimers()
    for _, t in ipairs(activeTimers) do
        if t and t.Cancel then
            t:Cancel()
        end
    end
    activeTimers = {}
end

local function ScheduleTimer(delay, callback)
    if C_Timer and C_Timer.NewTimer then
        local handle = C_Timer.NewTimer(delay, callback)
        table.insert(activeTimers, handle)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(delay, callback)
    else
        callback()
    end
end

local function ResolveMockItemInfo(mockItem, onResolved)
    local itemName, itemLink, itemQuality, _, _, _, _, _, _, itemTexture = GetItemInfo(mockItem.itemID)
    if itemName and itemLink then
        return {
            itemID = mockItem.itemID,
            name = itemName,
            link = itemLink,
            texture = itemTexture or mockItem.texture,
            quality = itemQuality or mockItem.quality,
        }
    end

    -- Request item data from server asynchronously so it updates to the client's locale as soon as cached
    if Item and Item.CreateFromItemID then
        local itemObj = Item:CreateFromItemID(mockItem.itemID)
        itemObj:ContinueOnItemLoad(function()
            local loadedName, loadedLink, loadedQuality, _, _, _, _, _, _, loadedTexture = GetItemInfo(mockItem.itemID)
            if onResolved and loadedName and loadedLink then
                onResolved(loadedName, loadedLink, loadedTexture, loadedQuality)
            end
        end)
    end

    return {
        itemID = mockItem.itemID,
        name = mockItem.name,
        link = mockItem.link,
        texture = mockItem.texture,
        quality = mockItem.quality,
    }
end

local function SpawnSimulatedItemRoll(mockItem, baseDelay, numGroupMembers)
    simCounter = simCounter + 1
    local rollID = simCounter
    local targetSize = numGroupMembers or 5

    local resolved = ResolveMockItemInfo(mockItem, function(loadedName, loadedLink, loadedTexture, loadedQuality)
        local s = DataTracker:GetRollSession(rollID)
        if s then
            s.itemName = loadedName
            s.itemLink = loadedLink
            if loadedTexture then s.itemTexture = loadedTexture end
            if loadedQuality then s.itemQuality = loadedQuality end
            DataTracker:NotifyUI()
        end
    end)

    local session = DataTracker:CreateOrUpdateRollSession(rollID, {
        itemLink = resolved.link,
        itemName = resolved.name,
        itemTexture = resolved.texture,
        itemQuality = resolved.quality,
        count = 1,
        isDone = false,
        isSimulated = true,
    })

    -- Include the actual player + mock party/raid members up to targetSize
    local myName = UnitName("player") or "Player"
    local _, myClass = UnitClass("player")
    local myRole = (UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")) or "DAMAGER"
    if myRole == "NONE" then myRole = "DAMAGER" end

    local roster = {
        { name = myName, class = myClass or "PALADIN", role = myRole },
    }
    for i = 1, #MOCK_RAID_NAMES do
        if #roster >= targetSize then break end
        local name = MOCK_RAID_NAMES[i]
        if name ~= myName then
            table.insert(roster, {
                name = name,
                class = MOCK_CLASSES[((i - 1) % #MOCK_CLASSES) + 1],
                role = MOCK_ROLES[((i - 1) % #MOCK_ROLES) + 1],
            })
        end
    end

    for _, p in ipairs(roster) do
        DataTracker:SetPlayerRoll(rollID, p.name, p.class, DataTracker.ROLL_TYPE_PENDING, nil, p.role)
    end

    -- Stagger simulated answers over ~6-10 seconds
    local choices = {
        DataTracker.ROLL_TYPE_NEED,
        DataTracker.ROLL_TYPE_GREED,
        DataTracker.ROLL_TYPE_GREED,
        DataTracker.ROLL_TYPE_PASS,
        DataTracker.ROLL_TYPE_PASS,
        DataTracker.ROLL_TYPE_PASS,
    }

    local stepDelay = (targetSize > 10) and 0.22 or 1.1
    for idx, p in ipairs(roster) do
        local delay = (baseDelay or 0) + (idx * stepDelay) + (math.random() * 0.3)
        ScheduleTimer(delay, function()
            local current = DataTracker:GetRollSession(rollID)
            if not current or current.isClosed then return end

            local choice = choices[((idx + rollID) % #choices) + 1]
            local score = nil
            if choice ~= DataTracker.ROLL_TYPE_PASS then
                score = math.random(1, 100)
            end

            DataTracker:SetPlayerRoll(rollID, p.name, p.class, choice, score, p.role)
            if idx == #roster then
                current.isDone = true
            end
            DataTracker:NotifyUI()
        end)
    end

    return rollID
end

function Simulator:StartSingleTest()
    CancelAllTimers()
    DataTracker:ClearSimulatedRolls()

    local rollID = SpawnSimulatedItemRoll(MOCK_ITEMS[1], 0, 5)
    DataTracker:SetCurrentRollID(rollID, true)
    ns:Print(string.format(L.MSG_SIM_STARTED, 1))
end

function Simulator:StartRaidTest(raidSize)
    CancelAllTimers()
    DataTracker:ClearSimulatedRolls()

    local rollID = SpawnSimulatedItemRoll(MOCK_ITEMS[1], 0, raidSize or 40)
    DataTracker:SetCurrentRollID(rollID, true)
    ns:Print(string.format(L.MSG_SIM_STARTED, 1) .. " (40-man raid)")
end

function Simulator:StartMultiTest()
    CancelAllTimers()
    DataTracker:ClearSimulatedRolls()

    local firstRollID = nil
    for i = 1, #MOCK_ITEMS do
        local id = SpawnSimulatedItemRoll(MOCK_ITEMS[i], (i - 1) * 0.4)
        if i == 1 then
            firstRollID = id
        end
    end

    if firstRollID then
        DataTracker:SetCurrentRollID(firstRollID, true)
    end
    ns:Print(string.format(L.MSG_SIM_STARTED, #MOCK_ITEMS))
end

function Simulator:StopTests()
    CancelAllTimers()
    DataTracker:ClearSimulatedRolls()
    ns:Print(L.MSG_SIM_STOPPED)
end
