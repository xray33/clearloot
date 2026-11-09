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
    choiceDisplay = "ICONS", -- "ICONS", "TEXT", or "BOTH"
    windowOpacity = 100,     -- 20..100 (%)
    windowScale = 100,       -- 60..160 (%)
    anchorSide = "RIGHT",    -- "RIGHT", "LEFT", or "FREE"
    freePosition = nil,      -- { point = "CENTER", relativePoint = "CENTER", x = 220, y = 0 }
}

local eventFrame = CreateFrame("Frame", "ClearLootEventFrame")
local registeredEvents = {}
ns.initErrors = {}

local buildInterface = type(GetBuildInfo) == "function" and select(4, GetBuildInfo()) or 0
ns.IsForever = (WOW_PROJECT_ID ~= nil and ((WOW_PROJECT_CAMELOT and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT) or WOW_PROJECT_ID == 18))
    or (buildInterface >= 16000 and buildInterface < 17000)

-- Cross-client API compatibility wrappers (WoW Forever 1.60.1 / 12.x vs Classic Era 1.15.x / MoP 5.5.x)
function ns.IsSecretValue(val)
    return type(issecretvalue) == "function" and issecretvalue(val) or false
end

function ns.GetItemInfo(itemInfo)
    if not itemInfo then return nil end
    local fn = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
    if type(fn) == "function" then
        return fn(itemInfo)
    end
    return nil
end

local FALLBACK_QUALITY_COLORS = {
    [0] = { 0.62, 0.62, 0.62 },
    [1] = { 1.00, 1.00, 1.00 },
    [2] = { 0.12, 1.00, 0.00 },
    [3] = { 0.00, 0.44, 0.87 },
    [4] = { 0.64, 0.21, 0.93 },
    [5] = { 1.00, 0.50, 0.00 },
}

function ns.GetItemQualityColor(quality)
    local q = tonumber(quality) or 2
    local fn = (C_Item and C_Item.GetItemQualityColor) or _G.GetItemQualityColor
    if type(fn) == "function" then
        local r, g, b, hex = fn(q)
        if r and g and b then
            return r, g, b, hex
        end
    end
    if ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q] then
        local c = ITEM_QUALITY_COLORS[q]
        return c.r or 1, c.g or 1, c.b or 1, c.hex
    end
    local fb = FALLBACK_QUALITY_COLORS[q] or FALLBACK_QUALITY_COLORS[2]
    return fb[1], fb[2], fb[3]
end

function ns.SendWhisper(targetName)
    if not targetName or targetName == "" then return end
    if ChatFrameUtil and type(ChatFrameUtil.SendTell) == "function" then
        ChatFrameUtil.SendTell(targetName)
    elseif type(ChatFrame_SendTell) == "function" then
        ChatFrame_SendTell(targetName)
    elseif type(ChatFrame_OpenChat) == "function" then
        ChatFrame_OpenChat("/w " .. targetName .. " ")
    end
end

function ns:Print(msg)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[ClearLoot]|r " .. tostring(msg))
    else
        print("|cff00ccff[ClearLoot]|r " .. tostring(msg))
    end
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

local function TrimString(s)
    if type(s) ~= "string" then return "" end
    if type(strtrim) == "function" then
        return strtrim(s)
    end
    return s:match("^%s*(.-)%s*$") or ""
end

local function ExecuteSlashCommand(msg)
    if not ns.db then
        ns:InitDB()
    end
    local cmd = TrimString(msg):lower()

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
    elseif cmd == "move" or cmd == "unlock" or cmd == "lock" then
        if ns.RollTrackerFrame and ns.RollTrackerFrame.ToggleMoveMode then
            ns.RollTrackerFrame:ToggleMoveMode()
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
        ns:Print(L.SLASH_HELP_TEST)
        ns:Print(L.SLASH_HELP_TESTMULTI)
        ns:Print(L.SLASH_HELP_TESTRAID)
        ns:Print(L.SLASH_HELP_STOP)
        ns:Print(L.SLASH_HELP_SHOW)
        if L.SLASH_HELP_MOVE then
            ns:Print(L.SLASH_HELP_MOVE)
        end
        ns:Print(L.SLASH_HELP_CONFIG)
    end
end

local function HandleSlashCommand(msg)
    local ok, err = pcall(ExecuteSlashCommand, msg)
    if not ok then
        ns:Print("|cffff4444Error running command:|r " .. tostring(err))
    end
end

SLASH_CLEARLOOT1 = "/clearloot"
SLASH_CLEARLOOT2 = "/cl"
SlashCmdList["CLEARLOOT"] = HandleSlashCommand

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
                local errMsg = "|cffff4444Error initializing " .. entry.name .. ":|r " .. tostring(err)
                table.insert(ns.initErrors, errMsg)
                ns:Print(errMsg)
            end
        end
    end
end)

ns:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    if ns.initErrors and #ns.initErrors > 0 then
        for _, errMsg in ipairs(ns.initErrors) do
            ns:Print(errMsg)
        end
        ns.initErrors = {}
    end
end)
