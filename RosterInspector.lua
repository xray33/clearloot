local addonName, ns = ...

local RosterInspector = {}
ns.RosterInspector = RosterInspector

local playerCache = {}

-- Normalize player name by stripping realm suffix if same realm or matching short name
function RosterInspector:GetShortName(fullName)
    if not fullName then return "" end
    local short = fullName:match("^([^%-]+)")
    return short or fullName
end

function RosterInspector:GetClassColorHex(classFile)
    if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
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
    if not UnitExists(unit) then return end
    local name, realm = UnitName(unit)
    if not name or name == UNKNOWNOBJECT then return end

    local fullName = (realm and realm ~= "") and (name .. "-" .. realm) or name
    local _, classFile = UnitClass(unit)
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or "NONE"

    local entry = playerCache[name] or {}
    entry.name = name
    entry.fullName = fullName
    entry.unit = unit
    entry.class = classFile or entry.class
    if role and role ~= "NONE" then
        entry.role = role
    end

    playerCache[name] = entry
    playerCache[fullName] = entry
end

function RosterInspector:FindUnitByName(name)
    if not name then return nil end
    local shortName = self:GetShortName(name)

    local myName = UnitName("player")
    if myName and (myName == name or myName == shortName) then
        return "player", "SELF"
    end

    if IsInRaid() then
        for i = 1, 40 do
            local u = "raid" .. i
            if UnitExists(u) then
                local uName = UnitName(u)
                if uName == name or uName == shortName then
                    return u, "RAID_PLAYER"
                end
            end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            local u = "party" .. i
            if UnitExists(u) then
                local uName = UnitName(u)
                if uName == name or uName == shortName then
                    return u, "PARTY"
                end
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
        if UnitExists(unit) then
            local name, realm = UnitName(unit)
            if name and name ~= UNKNOWNOBJECT and not seen[name] then
                seen[name] = true
                local _, classFile = UnitClass(unit)
                local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or "NONE"
                table.insert(members, {
                    name = name,
                    fullName = (realm and realm ~= "") and (name .. "-" .. realm) or name,
                    class = classFile,
                    role = role,
                })
            end
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
end
