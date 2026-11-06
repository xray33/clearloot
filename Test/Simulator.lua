local addonName, ns = ...
local L = ns.L
local DataTracker = ns.DataTracker

local Simulator = {}
ns.Simulator = Simulator

local simCounter = 9000
local activeTimers = {}

local MOCK_ITEMS = {
    {
        itemID = 5191,
        name = "Cruel Barb",
        texture = "Interface\\Icons\\INV_Sword_24",
        quality = 3,
    },
    {
        itemID = 6460,
        name = "Cobrahn's Grasp",
        texture = "Interface\\Icons\\INV_Belt_03",
        quality = 3,
    },
    {
        itemID = 11992,
        name = "Band of the Steadfast",
        texture = "Interface\\Icons\\INV_Jewelry_Ring_03",
        quality = 2,
    },
    {
        itemID = 5201,
        name = "Emberstone Staff",
        texture = "Interface\\Icons\\INV_Staff_13",
        quality = 3,
    },
}

local MOCK_CLASSES = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"
}

local MOCK_ROLES = {
    "TANK", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER"
}

local MOCK_RAID_NAMES_CLASSIC = {
    "Thrall", "Garrosh", "Jaina", "Valeera", "Anduin",
    "Sylvanas", "Varian", "Cairne", "Voljin", "Tyrande",
    "Malfurion", "Illidan", "Arthas", "Uther", "Khadgar",
    "Medivh", "Rexxar", "Rokhan", "Chen", "Gazlowe",
    "Saurfang", "Nazgrel", "Eitrigg", "Bolvar", "Tirion",
    "Darion", "Chromie", "Kalecgos", "Alexstrasza", "Ysera",
    "Wrathion", "Alleria", "Turalyon", "Velen", "Muradin",
    "Brann", "Magni", "Gelbin", "Genn", "Baine",
}

local MOCK_RAID_NAMES_FOREVER = {
    "Thrall Doomhammer", "Garrosh Hellscream", "Jaina Proudmoore", "Valeera Sanguinar", "Anduin Wrynn",
    "Sylvanas Windrunner", "Varian Wrynn", "Cairne Bloodhoof", "Voljin Darkspear", "Tyrande Whisperwind",
    "Malfurion Stormrage", "Illidan Stormrage", "Arthas Menethil", "Uther Lightbringer", "Khadgar Medivh",
    "Medivh Aran", "Rexxar Moknathal", "Rokhan Shadow", "Chen Stormstout", "Gazlowe Steamwheedle",
    "Varok Saurfang", "Nazgrel Frostwolf", "Eitrigg Blackrock", "Bolvar Fordragon", "Tirion Fordring",
    "Darion Mograine", "Chromie Chronormu", "Kalecgos Azure", "Alexstrasza Lifebinder", "Ysera Dreamer",
    "Wrathion Blacktalon", "Alleria Windrunner", "Turalyon Lothar", "Velen Prophet", "Muradin Bronzebeard",
    "Brann Bronzebeard", "Magni Bronzebeard", "Gelbin Mekkatorque", "Genn Greymane", "Baine Bloodhoof",
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
    local itemName, itemLink, itemQuality, _, _, _, _, _, _, itemTexture = ns.GetItemInfo(mockItem.itemID)
    if itemName and itemLink then
        return {
            itemID = mockItem.itemID,
            name = itemName,
            link = itemLink,
            texture = itemTexture or mockItem.texture,
            quality = itemQuality or mockItem.quality,
        }
    end

    if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
        pcall(C_Item.RequestLoadItemDataByID, mockItem.itemID)
    end

    -- Request item data from server asynchronously so it updates to the client's locale as soon as cached
    if Item and Item.CreateFromItemID then
        local ok, itemObj = pcall(Item.CreateFromItemID, Item, mockItem.itemID)
        if ok and itemObj and itemObj.ContinueOnItemLoad then
            itemObj:ContinueOnItemLoad(function()
                local loadedName, loadedLink, loadedQuality, _, _, _, _, _, _, loadedTexture = ns.GetItemInfo(mockItem.itemID)
                if onResolved and loadedName and loadedLink then
                    onResolved(loadedName, loadedLink, loadedTexture, loadedQuality)
                end
            end)
        end
    end

    return {
        itemID = mockItem.itemID,
        name = mockItem.name,
        link = nil, -- Only attach hyperlink once server confirms item exists in this client's database
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
    local myDisplayName = ns.RosterInspector:GetUnitNames("player")
    local myName = (myDisplayName and myDisplayName ~= "") and myDisplayName or (ns.IsForever and "Player Hero" or "Player")
    local _, rawClass = UnitClass("player")
    local myClass = (rawClass and not ns.IsSecretValue(rawClass)) and rawClass or "PALADIN"
    local myRole = (UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")) or "DAMAGER"
    if ns.IsSecretValue(myRole) or myRole == "NONE" then myRole = "DAMAGER" end

    local roster = {
        { name = myName, class = myClass or "PALADIN", role = myRole },
    }
    local namePool = ns.IsForever and MOCK_RAID_NAMES_FOREVER or MOCK_RAID_NAMES_CLASSIC
    for i = 1, #namePool do
        if #roster >= targetSize then break end
        local name = namePool[i]
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
