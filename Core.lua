local addonName, ns = ...
local L = ns.L

ClearLoot = ns

local rawVersion = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version")
    or (GetAddOnMetadata and GetAddOnMetadata(addonName, "Version"))
if not rawVersion or rawVersion:find("project%-version") then
    rawVersion = "0.1.0-dev"
end
ns.VERSION = rawVersion

local DEFAULT_SETTINGS = {
    enabled = true,
    autoOpen = true,
    showRoleIcons = true,
    autoSwitchOnHover = true,
    keepOpenAfterMyRoll = true,
    hidePassed = false,
    hidePending = false,
    anchorSide = "RIGHT", -- "RIGHT", "LEFT", or "FREE"
    freePosition = nil,   -- { point = "CENTER", relativePoint = "CENTER", x = 220, y = 0 }
}

local eventFrame = CreateFrame("Frame", "ClearLootEventFrame")
local registeredEvents = {}

function ns:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[ClearLoot]|r " .. tostring(msg))
end

function ns:InitDB()
    if type(ClearLootDB) ~= "table" then
        ClearLootDB = {}
    end
    for k, v in pairs(DEFAULT_SETTINGS) do
        if ClearLootDB[k] == nil then
            if type(v) == "table" then
                ClearLootDB[k] = CopyTable(v)
            else
                ClearLootDB[k] = v
            end
        end
    end
    ns.db = ClearLootDB
end

function ns:RegisterEvent(event, handler)
    if not registeredEvents[event] then
        registeredEvents[event] = {}
        pcall(function()
            eventFrame:RegisterEvent(event)
        end)
    end
    table.insert(registeredEvents[event], handler)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local handlers = registeredEvents[event]
    if handlers then
        for i = 1, #handlers do
            handlers[i](event, ...)
        end
    end
end)

local function HandleSlashCommand(msg)
    local cmd = strtrim(msg or ""):lower()

    if cmd == "test" or cmd == "sim" then
        if ns.Simulator then
            ns.Simulator:StartSingleTest()
        end
    elseif cmd == "testmulti" or cmd == "multi" then
        if ns.Simulator then
            ns.Simulator:StartMultiTest()
        end
    elseif cmd == "testraid" or cmd == "raid" then
        if ns.Simulator then
            ns.Simulator:StartRaidTest(40)
        end
    elseif cmd == "stop" or cmd == "clear" then
        if ns.Simulator then
            ns.Simulator:StopTests()
        end
    elseif cmd == "show" then
        if ns.RollTrackerFrame then
            ns.RollTrackerFrame:ForceShowCurrent()
        end
    elseif cmd == "reset" then
        ns.db.freePosition = nil
        ns.db.anchorSide = "RIGHT"
        if ns.MultiItemManager then
            ns.MultiItemManager:UpdateAnchoring()
        end
        ns:Print(L.MSG_POS_RESET)
    elseif cmd == "config" or cmd == "options" or cmd == "settings" then
        if ns.Settings then
            ns.Settings:OpenSettings()
        end
    else
        ns:Print(L.SLASH_HELP_HEADER)
        DEFAULT_CHAT_FRAME:AddMessage(L.SLASH_HELP_TEST)
        DEFAULT_CHAT_FRAME:AddMessage(L.SLASH_HELP_TESTMULTI)
        DEFAULT_CHAT_FRAME:AddMessage(L.SLASH_HELP_TESTRAID)
        DEFAULT_CHAT_FRAME:AddMessage(L.SLASH_HELP_STOP)
        DEFAULT_CHAT_FRAME:AddMessage(L.SLASH_HELP_SHOW)
        DEFAULT_CHAT_FRAME:AddMessage(L.SLASH_HELP_CONFIG)
    end
end

ns:RegisterEvent("ADDON_LOADED", function(_, loadedName)
    if loadedName ~= addonName then
        return
    end

    ns:InitDB()

    local modules = {
        { name = "RosterInspector", mod = ns.RosterInspector },
        { name = "DataTracker",     mod = ns.DataTracker },
        { name = "RollTrackerFrame",mod = ns.RollTrackerFrame },
        { name = "MultiItemManager",mod = ns.MultiItemManager },
        { name = "Settings",        mod = ns.Settings },
    }

    for _, entry in ipairs(modules) do
        if entry.mod and entry.mod.Init then
            local ok, err = pcall(entry.mod.Init, entry.mod)
            if not ok then
                ns:Print("|cffff4444Error initializing " .. entry.name .. ":|r " .. tostring(err))
            end
        end
    end

    SLASH_CLEARLOOT1 = "/clearloot"
    SLASH_CLEARLOOT2 = "/cl"
    SlashCmdList["CLEARLOOT"] = HandleSlashCommand
end)
