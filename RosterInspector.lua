local addonName, ns = ...

local RosterInspector = {}
ns.RosterInspector = RosterInspector

local playerCache = {}

-- Normalize player name:
-- - In WoW Forever (1.60.1), characters always have 2 names (First Name + Last Name).
--   Normalize "First-Last", "First Last", or "First-Last-Realm" into "First Last".
-- - In Classic Era / Anniversary / MoP, strip "-Realm" suffix.
function RosterInspector:GetShortName(fullName)
    if not fullName or ns.IsSecretValue(fullName) or type(fullName) ~= "string" then return "" end
    local trimmed = fullName:match("^%s*(.-)%s*$") or fullName
    if trimmed == "" then return "" end

    if ns.IsForever then
        local first, second = trimmed:match("^([^%-%s]+)[%-%s]+([^%-%s]+)")
        if first and second then
            return first .. " " .. second
        end
        local cached = playerCache[trimmed]
        if cached and cached.name then
            return cached.name
        end
        return trimmed
    end

    local short = trimmed:match("^([^%-]+)")
    return short or trimmed
end

function RosterInspector:GetUnitNames(unit)
    if not UnitExists(unit) then return nil, nil, nil end

    local first, second
    if ns.IsForever and type(UnitFullName) == "function" then
        first, second = UnitFullName(unit)
    end
    if not first or ns.IsSecretValue(first) then
        first, second = UnitName(unit)
    end
    if not first or ns.IsSecretValue(first) or first == UNKNOWNOBJECT then
        return nil, nil, nil
    end
    if ns.IsSecretValue(second) then
        second = nil
    end

    if ns.IsForever then
        -- In WoW Forever, `first` is First Name and `second` is Surname / Last Name
        if second and second ~= "" then
            local displayName = first .. " " .. second
            local hyphenName = first .. "-" .. second
            return displayName, hyphenName, first
        end
        local f1, f2 = first:match("^([^%-%s]+)[%-%s]+([^%-%s]+)")
        if f1 and f2 then
            return f1 .. " " .. f2, f1 .. "-" .. f2, f1
        end
        return first, first, first
    end

    local fullName = (second and second ~= "") and (first .. "-" .. second) or first
    return first, fullName, first
end

function RosterInspector:GetClassColorHex(classFile)
    if classFile and not ns.IsSecretValue(classFile) and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
        local c = RAID_CLASS_COLORS[classFile]
        if c.colorStr then
            return c.colorStr
        end
        return string.format("ff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
    end
    return "ffffffff"
end

function RosterInspector:ColorizeName(name, classFile)
    local shortName = self:GetShortName(name)
    local hex = self:GetClassColorHex(classFile)
    return "|c" .. hex .. shortName .. "|r"
end

local function CacheUnit(unit)
    local displayName, fullName, firstOnly = RosterInspector:GetUnitNames(unit)
    if not displayName then return end

    local _, classFile = UnitClass(unit)
    if ns.IsSecretValue(classFile) then classFile = nil end
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or "NONE"
    if ns.IsSecretValue(role) then role = "NONE" end

    local entry = playerCache[displayName] or (firstOnly and playerCache[firstOnly]) or {}
    entry.name = displayName
    entry.fullName = fullName or displayName
    entry.firstOnly = firstOnly
    entry.unit = unit
    entry.class = classFile or entry.class
    if role and role ~= "NONE" then
        entry.role = role
    end

    playerCache[displayName] = entry
    if fullName then
        playerCache[fullName] = entry
    end
    if firstOnly then
        playerCache[firstOnly] = entry
    end
end

function RosterInspector:FindUnitByName(name)
    if not name or ns.IsSecretValue(name) then return nil end
    local shortName = self:GetShortName(name)

    local myDisplay, myFull, myFirst = self:GetUnitNames("player")
    if myDisplay and (myDisplay == name or myDisplay == shortName or myFull == name or myFirst == name) then
        return "player", "SELF"
    end

    if IsInRaid() then
        for i = 1, 40 do
            local u = "raid" .. i
            local uDisplay, uFull, uFirst = self:GetUnitNames(u)
            if uDisplay and (uDisplay == name or uDisplay == shortName or uFull == name or uFirst == name) then
                return u, "RAID_PLAYER"
            end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            local u = "party" .. i
            local uDisplay, uFull, uFirst = self:GetUnitNames(u)
            if uDisplay and (uDisplay == name or uDisplay == shortName or uFull == name or uFirst == name) then
                return u, "PARTY"
            end
        end
    end

    return nil, nil
end

function RosterInspector:ScanGroup()
    CacheUnit("player")
    if IsInRaid() then
        for i = 1, 40 do
            CacheUnit("raid" .. i)
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            CacheUnit("party" .. i)
        end
    end
end

function RosterInspector:GetPlayerInfo(name, fallbackClass, fallbackRole)
    if not name then
        return { name = "Unknown", class = fallbackClass or "PRIEST", role = fallbackRole or "NONE" }
    end

    local shortName = self:GetShortName(name)
    local cached = playerCache[name] or playerCache[shortName]

    if not cached then
        self:ScanGroup()
        cached = playerCache[name] or playerCache[shortName]
    end

    if cached then
        if fallbackClass and not cached.class then
            cached.class = fallbackClass
        end
        if fallbackRole and (not cached.role or cached.role == "NONE") then
            cached.role = fallbackRole
        end
        return cached
    end

    local info = {
        name = shortName,
        fullName = name,
        class = fallbackClass,
        role = fallbackRole or "NONE",
    }
    playerCache[shortName] = info
    playerCache[name] = info
    return info
end

function RosterInspector:GetEligibleGroupMembers()
    self:ScanGroup()
    local members = {}
    local seen = {}

    local function AddUnit(unit)
        local displayName, fullName, firstOnly = self:GetUnitNames(unit)
        if displayName and not seen[displayName] then
            seen[displayName] = true
            local _, classFile = UnitClass(unit)
            if ns.IsSecretValue(classFile) then classFile = nil end
            local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or "NONE"
            if ns.IsSecretValue(role) then role = "NONE" end
            table.insert(members, {
                name = displayName,
                fullName = fullName or displayName,
                firstOnly = firstOnly,
                class = classFile,
                role = role,
            })
        end
    end

    AddUnit("player")
    if IsInRaid() then
        for i = 1, 40 do
            AddUnit("raid" .. i)
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            AddUnit("party" .. i)
        end
    end

    return members
end

function RosterInspector:Init()
    self:ScanGroup()
    ns:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        RosterInspector:ScanGroup()
    end)
    ns:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        RosterInspector:ScanGroup()
    end)
    ns:RegisterEvent("ROLE_CHANGED_INFORM", function()
        RosterInspector:ScanGroup()
    end)
    ns:RegisterEvent("UNIT_NAME_UPDATE", function()
        RosterInspector:ScanGroup()
    end)
end
