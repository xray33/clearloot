local addonName, ns = ...
local L = ns.L
local DataTracker = ns.DataTracker

local RollTrackerFrame = {}
ns.RollTrackerFrame = RollTrackerFrame

local WINDOW_WIDTH_ICONS = 304
local WINDOW_WIDTH_TEXT  = 358
local WINDOW_WIDTH_BOTH  = 376
local HEADER_HEIGHT = 38
local FOOTER_HEIGHT = 26
local ROW_HEIGHT = 20
local MIN_VISIBLE_ROWS = 5
local MAX_VISIBLE_ROWS = 10
local MAX_TABS = 6

local ROLL_ICONS = {
    [DataTracker.ROLL_TYPE_RANDOM]     = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
    [DataTracker.ROLL_TYPE_NEED]       = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
    [DataTracker.ROLL_TYPE_GREED]      = "Interface\\Buttons\\UI-GroupLoot-Coin-Up",
    [DataTracker.ROLL_TYPE_DISENCHANT] = "Interface\\Buttons\\UI-GroupLoot-DE-Up",
    [DataTracker.ROLL_TYPE_PASS]       = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
}

function RollTrackerFrame:GetChoiceDisplayMode()
    local mode = ns.db and ns.db.choiceDisplay or "ICONS"
    if mode ~= "ICONS" and mode ~= "TEXT" and mode ~= "BOTH" then
        mode = "ICONS"
    end
    return mode
end

function RollTrackerFrame:GetWindowWidth()
    local mode = self:GetChoiceDisplayMode()
    if mode == "TEXT" then
        return WINDOW_WIDTH_TEXT
    elseif mode == "BOTH" then
        return WINDOW_WIDTH_BOTH
    end
    return WINDOW_WIDTH_ICONS
end

local ROLL_COLORS = {
    [DataTracker.ROLL_TYPE_RANDOM]     = { r = 0.20, g = 1.00, b = 0.20 },
    [DataTracker.ROLL_TYPE_NEED]       = { r = 0.20, g = 1.00, b = 0.20 },
    [DataTracker.ROLL_TYPE_GREED]      = { r = 0.35, g = 0.80, b = 1.00 },
    [DataTracker.ROLL_TYPE_DISENCHANT] = { r = 0.75, g = 0.45, b = 1.00 },
    [DataTracker.ROLL_TYPE_PASS]       = { r = 0.85, g = 0.25, b = 0.25 },
    [DataTracker.ROLL_TYPE_PENDING]    = { r = 0.65, g = 0.65, b = 0.65 },
}

local ROLE_TEX_COORDS = {
    TANK    = { 0, 19/64, 22/64, 41/64 },
    HEALER  = { 20/64, 39/64, 1/64, 20/64 },
    DAMAGER = { 20/64, 39/64, 22/64, 41/64 },
}

local dropdownFrame

local function ShowPlayerContextMenu(playerData, anchorFrame)
    if not playerData or not playerData.name then return end
    local targetName = playerData.fullName or playerData.name
    local unit, unitMenuType = ns.RosterInspector:FindUnitByName(targetName)

    -- 1. If the player is in our party/raid (or is ourselves), open the exact native UnitPopup menu
    if unit and unitMenuType then
        if type(UnitPopup_OpenMenu) == "function" then
            local contextData = {
                unit = unit,
                name = UnitName(unit) or playerData.name,
            }
            local ok = pcall(UnitPopup_OpenMenu, unitMenuType, contextData)
            if ok then return end
        end
    end

    -- 2. Otherwise (or for simulated players / players who left the group), open the full native chat/player menu
    -- Passing "PARTY" and DEFAULT_CHAT_FRAME ensures Blizzard populates Whisper, Invite, Ignore, Target, Copy Name
    if type(UnitPopup_OpenMenu) == "function" then
        local contextData = {
            name = targetName,
            playerLocation = PlayerLocation and PlayerLocation:CreateFromName(targetName) or nil,
            chatType = "PARTY",
            chatTarget = targetName,
            chatFrame = DEFAULT_CHAT_FRAME,
            lineID = 0,
        }
        local ok = pcall(UnitPopup_OpenMenu, "FRIEND", contextData)
        if ok then return end
    end

    if type(FriendsFrame_ShowDropdown) == "function" then
        local ok = pcall(FriendsFrame_ShowDropdown, targetName, 1, 0, "PARTY", DEFAULT_CHAT_FRAME)
        if ok then return end
    end

    -- 3. Modern MenuUtil Context Menu (WoW Forever 1.60.1 / Mainline UI)
    if MenuUtil and type(MenuUtil.CreateContextMenu) == "function" then
        local ok = pcall(MenuUtil.CreateContextMenu, anchorFrame, function(_, rootDescription)
            rootDescription:CreateTitle(ns.RosterInspector:ColorizeName(playerData.name, playerData.class))
            rootDescription:CreateButton(_G.WHISPER or "Whisper", function()
                ns.SendWhisper(targetName)
            end)
            if not InCombatLockdown() and type(InspectUnit) == "function" then
                rootDescription:CreateButton(_G.INSPECT or "Inspect", function()
                    InspectUnit(playerData.name)
                end)
            end
            rootDescription:CreateButton(_G.INVITE or "Invite", function()
                if C_PartyInfo and C_PartyInfo.InviteUnit then
                    C_PartyInfo.InviteUnit(targetName)
                elseif InviteUnit then
                    InviteUnit(targetName)
                end
            end)
            rootDescription:CreateButton(_G.CANCEL or "Cancel", function() end)
        end)
        if ok then return end
    end

    -- 4. Legacy UIDropDownMenuTemplate fallback (Whisper, Inspect, Invite, Cancel)
    if type(UIDropDownMenu_Initialize) ~= "function" or type(ToggleDropDownMenu) ~= "function" then
        return
    end
    if DoesTemplateExist and not DoesTemplateExist("UIDropDownMenuTemplate") then
        return
    end

    if not dropdownFrame then
        dropdownFrame = CreateFrame("Frame", "ClearLootPlayerDropDown", UIParent, "UIDropDownMenuTemplate")
    end

    UIDropDownMenu_Initialize(dropdownFrame, function(_, level)
        if level ~= 1 then return end

        local titleInfo = UIDropDownMenu_CreateInfo()
        titleInfo.text = ns.RosterInspector:ColorizeName(playerData.name, playerData.class)
        titleInfo.isTitle = true
        titleInfo.notCheckable = true
        UIDropDownMenu_AddButton(titleInfo, level)

        -- Whisper / Send Message
        local whisperInfo = UIDropDownMenu_CreateInfo()
        whisperInfo.text = _G.WHISPER or "Whisper"
        whisperInfo.notCheckable = true
        whisperInfo.func = function()
            ns.SendWhisper(targetName)
        end
        UIDropDownMenu_AddButton(whisperInfo, level)

        -- Inspect (if out of combat and in range)
        local inspectInfo = UIDropDownMenu_CreateInfo()
        inspectInfo.text = _G.INSPECT or "Inspect"
        inspectInfo.notCheckable = true
        inspectInfo.disabled = InCombatLockdown()
        inspectInfo.func = function()
            if InspectUnit then
                InspectUnit(playerData.name)
            end
        end
        UIDropDownMenu_AddButton(inspectInfo, level)

        -- Invite to Group (useful if testing solo or player left party)
        local inviteInfo = UIDropDownMenu_CreateInfo()
        inviteInfo.text = _G.INVITE or "Invite"
        inviteInfo.notCheckable = true
        inviteInfo.func = function()
            if C_PartyInfo and C_PartyInfo.InviteUnit then
                C_PartyInfo.InviteUnit(targetName)
            elseif InviteUnit then
                InviteUnit(targetName)
            end
        end
        UIDropDownMenu_AddButton(inviteInfo, level)

        -- Cancel
        local cancelInfo = UIDropDownMenu_CreateInfo()
        cancelInfo.text = _G.CANCEL or "Cancel"
        cancelInfo.notCheckable = true
        UIDropDownMenu_AddButton(cancelInfo, level)
    end, "MENU")

    ToggleDropDownMenu(1, nil, dropdownFrame, "cursor", 0, 0)
end

local THEMES = {
    FOREVER = {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
        bgColor = { 0.09, 0.08, 0.07, 0.94 },
        borderColor = { 0.76, 0.62, 0.42, 1.0 },
        dividerColor = { 0.58, 0.48, 0.35, 0.45 },
        footerTextColor = { 0.86, 0.75, 0.56 },
        scrollThumbColor = { 0.76, 0.62, 0.42, 0.85 },
        tabEdgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tabEdgeSize = 12,
        tabInsets = { left = 2, right = 2, top = 2, bottom = 2 },
        tabBgColor = { 0.10, 0.09, 0.08, 0.94 },
        tabActiveBorder = { 0.92, 0.78, 0.52, 1.0 },
        tabInactiveBorder = { 0.52, 0.43, 0.31, 0.85 },
        btnBgColor = { 0.14, 0.12, 0.10, 0.92 },
        btnBorderColor = { 0.72, 0.58, 0.40, 0.95 },
    },
    CLASSIC = {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
        bgColor = { 0.06, 0.06, 0.08, 0.94 },
        borderColor = { 1.00, 1.00, 1.00, 1.0 },
        dividerColor = { 0.70, 0.58, 0.32, 0.50 },
        footerTextColor = { 1.00, 0.82, 0.00 },
        scrollThumbColor = { 0.90, 0.75, 0.35, 0.80 },
        tabEdgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tabEdgeSize = 10,
        tabInsets = { left = 2, right = 2, top = 2, bottom = 2 },
        tabBgColor = { 0.08, 0.08, 0.08, 0.92 },
        tabActiveBorder = { 1.00, 0.82, 0.00, 1.0 },
        tabInactiveBorder = { 0.50, 0.50, 0.50, 0.80 },
        btnBgColor = { 0.12, 0.12, 0.16, 0.90 },
        btnBorderColor = { 0.75, 0.65, 0.40, 0.90 },
    },
    MINIMALIST = {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
        bgColor = { 0.06, 0.06, 0.06, 0.92 },
        borderColor = { 0.18, 0.18, 0.20, 1.0 },
        dividerColor = { 0.24, 0.24, 0.26, 0.75 },
        footerTextColor = { 0.78, 0.78, 0.80 },
        scrollThumbColor = { 0.50, 0.50, 0.54, 0.85 },
        tabEdgeFile = "Interface\\Buttons\\WHITE8X8",
        tabEdgeSize = 1,
        tabInsets = { left = 1, right = 1, top = 1, bottom = 1 },
        tabBgColor = { 0.07, 0.07, 0.08, 0.94 },
        tabActiveBorder = { 0.88, 0.88, 0.92, 1.0 },
        tabInactiveBorder = { 0.22, 0.22, 0.25, 0.90 },
        btnBgColor = { 0.10, 0.10, 0.11, 0.92 },
        btnBorderColor = { 0.28, 0.28, 0.32, 0.95 },
    },
    -- Authentic EllesmereUI in-game frame style:
    -- Pitch-black 2px border + outer drop shadow on a deep matte charcoal panel
    ELLESMERE = {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
        hasShadow = true,
        bgColor = { 0.07, 0.07, 0.08, 0.95 },
        borderColor = { 0.00, 0.00, 0.00, 1.0 },
        dividerColor = { 0.18, 0.18, 0.20, 0.85 },
        footerTextColor = { 0.85, 0.85, 0.88 },
        scrollThumbColor = { 0.38, 0.38, 0.42, 0.90 },
        tabEdgeFile = "Interface\\Buttons\\WHITE8X8",
        tabEdgeSize = 2,
        tabInsets = { left = 2, right = 2, top = 2, bottom = 2 },
        tabBgColor = { 0.07, 0.07, 0.08, 0.95 },
        tabActiveBorder = { 0.00, 0.00, 0.00, 1.0 },
        tabInactiveBorder = { 0.00, 0.00, 0.00, 0.85 },
        btnBgColor = { 0.11, 0.11, 0.13, 0.95 },
        btnBorderColor = { 0.00, 0.00, 0.00, 1.0 },
    },
    -- Authentic FlareUI style from malkkav/FlareUI (Chat & Damage Meter modules):
    -- Flat dark translucent panel background paired with "FlareUI Thin" 10px native Forever bronze border
    FLARE = {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        tileSize = 0,
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
        bgColor = { 0.06, 0.06, 0.07, 0.88 },
        borderColor = { 0.68, 0.55, 0.37, 0.95 },
        dividerColor = { 0.68, 0.55, 0.37, 0.40 },
        footerTextColor = { 0.88, 0.74, 0.50 },
        scrollThumbColor = { 0.74, 0.60, 0.40, 0.85 },
        tabEdgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tabEdgeSize = 10,
        tabInsets = { left = 2, right = 2, top = 2, bottom = 2 },
        tabBgColor = { 0.06, 0.06, 0.07, 0.92 },
        tabActiveBorder = { 0.90, 0.75, 0.48, 1.0 },
        tabInactiveBorder = { 0.46, 0.37, 0.26, 0.85 },
        btnBgColor = { 0.10, 0.09, 0.08, 0.92 },
        btnBorderColor = { 0.68, 0.55, 0.37, 0.95 },
    },
}

function RollTrackerFrame:SyncEllesmereTheme(S)
    local eui = THEMES.ELLESMERE
    if not eui or type(S) ~= "table" then return end
    if type(S.GetPanelColor) == "function" then
        local pr, pg, pb, pa = S.GetPanelColor()
        if pr and pg and pb then
            eui.bgColor = { pr, pg, pb, pa or 0.95 }
            eui.tabBgColor = { pr, pg, pb, pa or 0.95 }
        end
    end
    if self:GetThemeKey() == "ELLESMERE" then
        self:ApplyTheme()
    end
end

function RollTrackerFrame:GetThemeKey()
    local key = ns.db and ns.db.theme or "FOREVER"
    if not THEMES[key] then
        key = "FOREVER"
    end
    return key
end

function RollTrackerFrame:GetTheme()
    return THEMES[self:GetThemeKey()] or THEMES.FOREVER
end

local function CreateItemTab(parent, index)
    local tab = CreateFrame("Button", "ClearLootItemTab" .. index, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    tab:SetSize(30, 30)

    if tab.SetBackdrop then
        tab:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        tab:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
    end

    local icon = tab:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", -3, 3)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    tab.icon = icon

    local activeGlow = tab:CreateTexture(nil, "OVERLAY")
    activeGlow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    activeGlow:SetBlendMode("ADD")
    activeGlow:SetAllPoints(tab)
    activeGlow:Hide()
    tab.activeGlow = activeGlow

    local badge = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    badge:SetPoint("BOTTOMRIGHT", -2, 2)
    local fontFile = badge:GetFont()
    if fontFile then
        pcall(badge.SetFont, badge, fontFile, 9, "OUTLINE")
    end
    tab.badge = badge

    tab:SetScript("OnClick", function(self)
        if self.rollID then
            DataTracker:SetCurrentRollID(self.rollID, true)
        end
    end)

    tab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.itemLink then
            GameTooltip:SetHyperlink(self.itemLink)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L.TOOLTIP_TAB_SWITCH, 0.5, 0.8, 1.0)
        elseif self.itemName then
            GameTooltip:SetText(self.itemName, 1, 1, 1)
            GameTooltip:AddLine(L.TOOLTIP_TAB_SWITCH, 0.5, 0.8, 1.0)
        end
        GameTooltip:Show()
    end)

    tab:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    tab:Hide()
    return tab
end

local function CreatePlayerRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(WINDOW_WIDTH_ICONS - 24, ROW_HEIGHT)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.rowIndex = index

    -- Alternating subtle stripe background (or leader gold highlight)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(row)
    if index % 2 == 1 then
        bg:SetColorTexture(1, 1, 1, 0.04)
    else
        bg:SetColorTexture(0, 0, 0, 0.15)
    end
    row.bg = bg

    -- Hover highlight
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(row)
    hl:SetColorTexture(1, 0.82, 0, 0.14)

    -- 1. Rank Number ("1.")
    local rankText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rankText:SetPoint("LEFT", 4, 0)
    rankText:SetWidth(18)
    rankText:SetJustifyH("LEFT")
    rankText:SetTextColor(0.8, 0.8, 0.8)
    row.rankText = rankText

    -- 2. Class Icon
    local classIcon = row:CreateTexture(nil, "ARTWORK")
    classIcon:SetSize(15, 15)
    classIcon:SetPoint("LEFT", rankText, "RIGHT", 2, 0)
    classIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
    row.classIcon = classIcon

    -- 3. Player Name (Class Colored)
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetPoint("LEFT", classIcon, "RIGHT", 5, 0)
    nameText:SetWidth(156)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    -- 4. Role Icon (Tank / Healer / DPS)
    local roleIcon = row:CreateTexture(nil, "ARTWORK")
    roleIcon:SetSize(14, 14)
    roleIcon:SetPoint("LEFT", nameText, "RIGHT", 2, 0)
    roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
    row.roleIcon = roleIcon

    -- 5. Roll Choice Icon (Dice / Coin / DE / Pass)
    local choiceIcon = row:CreateTexture(nil, "ARTWORK")
    choiceIcon:SetSize(16, 16)
    choiceIcon:SetPoint("LEFT", row, "LEFT", 222, 0)
    row.choiceIcon = choiceIcon

    -- 6. Roll Choice Text ("Need", "Greed", "Pass")
    local choiceText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    choiceText:SetPoint("LEFT", choiceIcon, "RIGHT", 4, 0)
    choiceText:SetWidth(68)
    choiceText:SetJustifyH("LEFT")
    choiceText:SetWordWrap(false)
    row.choiceText = choiceText

    -- 7. Roll Score ("100")
    local scoreText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scoreText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    scoreText:SetWidth(36)
    scoreText:SetJustifyH("RIGHT")
    scoreText:SetWordWrap(false)
    row.scoreText = scoreText

    row:SetScript("OnClick", function(self, button)
        if not self.playerData then return end
        if button == "RightButton" then
            ShowPlayerContextMenu(self.playerData, self)
        elseif button == "LeftButton" and IsShiftKeyDown() then
            local target = self.playerData.fullName or self.playerData.name
            ns.SendWhisper(target)
        end
    end)

    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(_, delta)
        RollTrackerFrame:OnMouseWheel(delta)
    end)

    row:SetScript("OnEnter", function(self)
        if not self.playerData then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local colored = ns.RosterInspector:ColorizeName(self.playerData.name, self.playerData.class)
        GameTooltip:SetText(colored)
        GameTooltip:AddLine(L.TOOLTIP_PLAYER_CLICK, 0.75, 0.75, 0.75, true)
        GameTooltip:Show()
    end)

    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    row:Hide()
    return row
end

function RollTrackerFrame:OnMouseWheel(delta)
    local frame = self.frame
    if not frame then return end
    local maxOffset = frame.maxScrollOffset or 0
    if maxOffset <= 0 then return end

    local newOffset = (frame.scrollOffset or 0) - (delta > 0 and 1 or -1)
    if newOffset < 0 then newOffset = 0 end
    if newOffset > maxOffset then newOffset = maxOffset end

    if newOffset ~= frame.scrollOffset then
        frame.scrollOffset = newOffset
        if frame.scrollBar and frame.scrollBar:IsShown() then
            frame.scrollBar._updating = true
            frame.scrollBar:SetValue(newOffset)
            frame.scrollBar._updating = false
        end
        self:UpdatePlayerRows()
    end
end

function RollTrackerFrame:Init()
    local frame = CreateFrame("Frame", "ClearLootTrackerFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetSize(self:GetWindowWidth(), HEADER_HEIGHT + (MIN_VISIBLE_ROWS * ROW_HEIGHT) + FOOTER_HEIGHT)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")

    frame.scrollOffset = 0
    frame.maxScrollOffset = 0
    frame:SetScript("OnMouseWheel", function(_, delta)
        RollTrackerFrame:OnMouseWheel(delta)
    end)

    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint(1)
        if point then
            ns.db.anchorSide = "FREE"
            ns.db.freePosition = {
                point = point,
                relativePoint = relativePoint,
                x = x,
                y = y,
            }
        end
    end)

    -- Item Tabs above the top-left of the window (shown when 2+ items are active)
    frame.tabs = {}
    for i = 1, MAX_TABS do
        local tab = CreateItemTab(frame, i)
        if i == 1 then
            tab:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 6, -2)
        else
            tab:SetPoint("LEFT", frame.tabs[i - 1], "RIGHT", 4, 0)
        end
        frame.tabs[i] = tab
    end

    -- Close [X] button (dismisses current item only)
    local closeTemplate = (not DoesTemplateExist or DoesTemplateExist("UIPanelCloseButton")) and "UIPanelCloseButton" or nil
    local closeBtn = CreateFrame("Button", nil, frame, closeTemplate)
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    if not closeTemplate then
        local closeLabel = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        closeLabel:SetPoint("CENTER", 0, 0)
        closeLabel:SetText("×")
    end
    closeBtn:SetScript("OnClick", function()
        local session = DataTracker:GetCurrentRollSession()
        if session then
            DataTracker:DismissRoll(session.rollID)
        else
            frame:Hide()
        end
    end)
    closeBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.TOOLTIP_CLOSE_ITEM, 1, 0.82, 0)
        GameTooltip:AddLine(L.TOOLTIP_CLOSE_ITEM_DESC, 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    closeBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    frame.closeBtn = closeBtn

    -- Restart Random Roll Session Button (shown only on Random Roll sessions)
    local restartRollBtn = CreateFrame("Button", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    restartRollBtn:SetSize(22, 22)
    restartRollBtn:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)
    if restartRollBtn.SetBackdrop then
        restartRollBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        restartRollBtn:SetBackdropColor(0.12, 0.12, 0.16, 0.9)
        restartRollBtn:SetBackdropBorderColor(0.65, 0.55, 0.35, 0.9)
    end
    local restartIcon = restartRollBtn:CreateTexture(nil, "ARTWORK")
    restartIcon:SetSize(15, 15)
    restartIcon:SetPoint("CENTER", 0, 0)
    restartIcon:SetTexture("Interface\\Buttons\\UI-RotationLeft-Button-Up")
    restartRollBtn.icon = restartIcon
    local restartHl = restartRollBtn:CreateTexture(nil, "HIGHLIGHT")
    restartHl:SetAllPoints(restartRollBtn)
    restartHl:SetColorTexture(1, 0.82, 0, 0.2)
    restartRollBtn:SetScript("OnClick", function()
        local session = DataTracker:GetCurrentRollSession()
        if session and session.isRandomRoll then
            DataTracker:RestartRandomRollSession(session.rollID)
            if L.MSG_RANDOM_RESTARTED then
                ns:Print(L.MSG_RANDOM_RESTARTED)
            end
        end
    end)
    restartRollBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.TOOLTIP_RESTART_ROLL_BTN or "Restart Roll Session", 1, 0.82, 0)
        GameTooltip:AddLine(L.TOOLTIP_RESTART_ROLL_BTN_DESC or "Clear current rolls and start a fresh /roll (1-100) round.", 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)
    restartRollBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    restartRollBtn:Hide()
    frame.restartRollBtn = restartRollBtn

    -- Quick /roll (1-100) Dice Button (shown only on Random Roll sessions)
    local rollDiceBtn = CreateFrame("Button", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    rollDiceBtn:SetSize(22, 22)
    rollDiceBtn:SetPoint("RIGHT", restartRollBtn, "LEFT", -3, 0)
    if rollDiceBtn.SetBackdrop then
        rollDiceBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        rollDiceBtn:SetBackdropColor(0.12, 0.22, 0.12, 0.9)
        rollDiceBtn:SetBackdropBorderColor(0.35, 0.85, 0.35, 0.95)
    end
    local diceIcon = rollDiceBtn:CreateTexture(nil, "ARTWORK")
    diceIcon:SetSize(16, 16)
    diceIcon:SetPoint("CENTER", 0, 0)
    diceIcon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Up")
    rollDiceBtn.icon = diceIcon
    local diceHl = rollDiceBtn:CreateTexture(nil, "HIGHLIGHT")
    diceHl:SetAllPoints(rollDiceBtn)
    diceHl:SetColorTexture(0.2, 1.0, 0.2, 0.2)
    rollDiceBtn:SetScript("OnClick", function()
        local session = DataTracker:GetCurrentRollSession()
        if not session or not session.isRandomRoll then return end
        if DataTracker:HasLocalPlayerRolled(session.rollID) then
            return
        end
        if session.isSimulated then
            local myDisplayName = ns.RosterInspector:GetUnitNames("player") or (ns.IsForever and "Player Hero" or "Player")
            DataTracker:SetPlayerRoll(session.rollID, myDisplayName, nil, DataTracker.ROLL_TYPE_RANDOM, math.random(1, 100))
            DataTracker:NotifyUI()
            return
        end
        if type(RandomRoll) == "function" then
            RandomRoll(1, 100)
        end
    end)
    rollDiceBtn:SetScript("OnEnter", function(self)
        local session = DataTracker:GetCurrentRollSession()
        local alreadyRolled = session and DataTracker:HasLocalPlayerRolled(session.rollID)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.TOOLTIP_RANDOM_ROLL_BTN or "Roll (1-100)", 1, 0.82, 0)
        if alreadyRolled then
            GameTooltip:AddLine(L.TOOLTIP_RANDOM_ROLL_DONE or "You have already rolled in this session.", 0.65, 0.65, 0.65, true)
        else
            GameTooltip:AddLine(L.TOOLTIP_RANDOM_ROLL_BTN_DESC or "Click to perform a standard /roll (1-100).", 0.2, 1.0, 0.2, true)
        end
        GameTooltip:Show()
    end)
    rollDiceBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    rollDiceBtn:Hide()
    frame.rollDiceBtn = rollDiceBtn

    -- Item Header Button (Icon + Item Link/Name, hoverable for item tooltip)
    local itemHeader = CreateFrame("Button", nil, frame)
    itemHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -8)
    itemHeader:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -2, 0)
    itemHeader:SetHeight(24)
    frame.itemHeader = itemHeader

    local itemIcon = itemHeader:CreateTexture(nil, "ARTWORK")
    itemIcon:SetSize(20, 20)
    itemIcon:SetPoint("LEFT", itemHeader, "LEFT", 0, 0)
    itemIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.itemIcon = itemIcon

    local itemTitle = itemHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemTitle:SetPoint("LEFT", itemIcon, "RIGHT", 6, 0)
    itemTitle:SetPoint("RIGHT", itemHeader, "RIGHT", -2, 0)
    itemTitle:SetJustifyH("LEFT")
    itemTitle:SetWordWrap(false)
    frame.itemTitle = itemTitle

    itemHeader:SetScript("OnEnter", function(self)
        local session = DataTracker:GetCurrentRollSession()
        if not session then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if session.isRandomRoll then
            GameTooltip:SetText(session.itemName or L.RANDOM_ROLL_TITLE or "Random Roll (1-100)", 1, 0.82, 0)
            GameTooltip:AddLine(L.RANDOM_ROLL_TOOLTIP_DESC or "Tracks standard /roll (1-100) from group/raid members.\nOnly the first roll per player is counted.", 0.85, 0.85, 0.85, true)
        elseif session.itemLink then
            GameTooltip:SetHyperlink(session.itemLink)
        elseif session.itemName then
            local r, g, b = ns.GetItemQualityColor(session.itemQuality or 2)
            GameTooltip:SetText(session.itemName, r or 1, g or 1, b or 1)
        end
        GameTooltip:Show()
    end)
    itemHeader:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    itemHeader:RegisterForDrag("LeftButton")
    itemHeader:SetScript("OnDragStart", function()
        frame:GetScript("OnDragStart")(frame)
    end)
    itemHeader:SetScript("OnDragStop", function()
        frame:GetScript("OnDragStop")(frame)
    end)

    -- Divider line below Item Header
    local headerDivider = frame:CreateTexture(nil, "ARTWORK")
    headerDivider:SetHeight(1)
    headerDivider:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -34)
    headerDivider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -34)
    headerDivider:SetColorTexture(0.6, 0.5, 0.3, 0.5)
    frame.headerDivider = headerDivider

    -- Pure-Lua Container & ScrollBar for Player Rows (no FauxScrollFrameTemplate dependency)
    local rowContainer = CreateFrame("Frame", "ClearLootRollRowContainer", frame)
    rowContainer:SetPoint("TOPLEFT", headerDivider, "BOTTOMLEFT", 0, -3)
    rowContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, FOOTER_HEIGHT)
    frame.rowContainer = rowContainer

    local scrollBar = CreateFrame("Slider", "ClearLootRollScrollBar", frame)
    scrollBar:SetPoint("TOPRIGHT", headerDivider, "BOTTOMRIGHT", -1, -4)
    scrollBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -11, FOOTER_HEIGHT + 4)
    scrollBar:SetWidth(8)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetValueStep(1)
    if scrollBar.SetObeyStepOnDrag then
        scrollBar:SetObeyStepOnDrag(true)
    end
    scrollBar:SetMinMaxValues(0, 0)
    scrollBar:SetValue(0)

    local sbTrack = scrollBar:CreateTexture(nil, "BACKGROUND")
    sbTrack:SetAllPoints(scrollBar)
    sbTrack:SetColorTexture(0, 0, 0, 0.35)

    local sbThumb = scrollBar:CreateTexture(nil, "ARTWORK")
    sbThumb:SetSize(8, 28)
    sbThumb:SetColorTexture(0.85, 0.75, 0.45, 0.75)
    scrollBar:SetThumbTexture(sbThumb)
    frame.scrollBarThumb = sbThumb

    scrollBar:SetScript("OnValueChanged", function(self, value)
        if self._updating then return end
        local rounded = math.floor((value or 0) + 0.5)
        if rounded ~= frame.scrollOffset then
            frame.scrollOffset = rounded
            RollTrackerFrame:UpdatePlayerRows()
        end
    end)
    scrollBar:Hide()
    frame.scrollBar = scrollBar

    -- Create Row Pool
    frame.rows = {}
    for i = 1, MAX_VISIBLE_ROWS do
        local row = CreatePlayerRow(frame, i)
        if i == 1 then
            row:SetPoint("TOPLEFT", rowContainer, "TOPLEFT", 0, 0)
        else
            row:SetPoint("TOPLEFT", frame.rows[i - 1], "BOTTOMLEFT", 0, 0)
        end
        frame.rows[i] = row
    end

    -- Bottom Footer Summary
    local footerDivider = frame:CreateTexture(nil, "ARTWORK")
    footerDivider:SetHeight(1)
    footerDivider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, FOOTER_HEIGHT)
    footerDivider:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, FOOTER_HEIGHT)
    footerDivider:SetColorTexture(0.6, 0.5, 0.3, 0.4)
    frame.footerDivider = footerDivider

    local footerText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footerText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 8)
    footerText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 8)
    footerText:SetJustifyH("CENTER")
    footerText:SetTextColor(0.85, 0.78, 0.55)
    frame.footerText = footerText

    -- Edit Mode / Move Mode Overlay (shown during Blizzard Edit Mode or /cl move)
    local moverOverlay = CreateFrame("Frame", "ClearLootMoverOverlay", frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    moverOverlay:SetAllPoints(frame)
    moverOverlay:SetFrameLevel(frame:GetFrameLevel() + 20)
    moverOverlay:EnableMouse(true)
    moverOverlay:RegisterForDrag("LeftButton")
    if moverOverlay.SetBackdrop then
        moverOverlay:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 14,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        moverOverlay:SetBackdropColor(0.04, 0.28, 0.65, 0.86)
        moverOverlay:SetBackdropBorderColor(0.35, 0.80, 1.00, 1.0)
    else
        local moverBg = moverOverlay:CreateTexture(nil, "BACKGROUND")
        moverBg:SetAllPoints(moverOverlay)
        moverBg:SetColorTexture(0.04, 0.28, 0.65, 0.86)
    end

    local moverLabel = moverOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    moverLabel:SetPoint("CENTER", moverOverlay, "CENTER", 0, 12)
    moverLabel:SetText(L.EDIT_MODE_LABEL or "Clear Loot\nDrag to Move")
    moverLabel:SetTextColor(1.0, 0.92, 0.50)

    local lockBtn = CreateFrame("Button", nil, moverOverlay, "UIPanelButtonTemplate")
    lockBtn:SetSize(120, 24)
    lockBtn:SetPoint("BOTTOM", moverOverlay, "BOTTOM", 0, 14)
    lockBtn:SetText(L.EDIT_MODE_LOCK_BTN or "Lock Window")
    lockBtn:SetScript("OnClick", function()
        RollTrackerFrame:SetMoveMode(false, false)
    end)
    moverOverlay.lockBtn = lockBtn

    moverOverlay:SetScript("OnDragStart", function()
        frame:GetScript("OnDragStart")(frame)
    end)
    moverOverlay:SetScript("OnDragStop", function()
        frame:GetScript("OnDragStop")(frame)
    end)
    moverOverlay:Hide()
    frame.moverOverlay = moverOverlay

    frame:Hide()
    self.frame = frame
    if _G.EllesmereUI and type(_G.EllesmereUI.RegisterSkin) == "function" then
        pcall(_G.EllesmereUI.RegisterSkin, "ClearLoot", function(S)
            RollTrackerFrame:SyncEllesmereTheme(S)
            if type(S.OnLooksChanged) == "function" then
                S.OnLooksChanged(function()
                    RollTrackerFrame:SyncEllesmereTheme(S)
                end)
            end
        end)
    end
    self:ApplyTheme()
    self:UpdateOpacity()
    self:UpdateScale()
    self:HookBlizzardEditMode()
end

function RollTrackerFrame:ApplyTheme()
    local frame = self.frame
    if not frame then return end
    local themeKey = self:GetThemeKey()
    local theme = self:GetTheme()

    if theme.hasShadow then
        if not frame.outerShadow then
            local shadow = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
            shadow:SetPoint("TOPLEFT", frame, "TOPLEFT", -3, 3)
            shadow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 3, -3)
            shadow:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
            if shadow.SetBackdrop then
                shadow:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    edgeSize = 3,
                    insets = { left = 3, right = 3, top = 3, bottom = 3 },
                })
                shadow:SetBackdropColor(0, 0, 0, 0)
                shadow:SetBackdropBorderColor(0, 0, 0, 0.45)
            end
            frame.outerShadow = shadow
        end
        frame.outerShadow:Show()
    elseif frame.outerShadow then
        frame.outerShadow:Hide()
    end

    if frame.SetBackdrop then
        if self._appliedThemeKey ~= themeKey then
            frame:SetBackdrop({
                bgFile = theme.bgFile,
                edgeFile = theme.edgeFile,
                tile = theme.tile,
                tileSize = theme.tileSize,
                edgeSize = theme.edgeSize,
                insets = theme.insets,
            })
        end
        local bg = theme.bgColor
        local bc = theme.borderColor
        frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 0.94)
        frame:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4] or 1.0)
    end

    if frame.headerDivider then
        local dc = theme.dividerColor
        frame.headerDivider:SetColorTexture(dc[1], dc[2], dc[3], dc[4] or 0.5)
    end
    if frame.footerDivider then
        local dc = theme.dividerColor
        frame.footerDivider:SetColorTexture(dc[1], dc[2], dc[3], (dc[4] or 0.5) * 0.85)
    end
    if frame.footerText then
        local fc = theme.footerTextColor
        frame.footerText:SetTextColor(fc[1], fc[2], fc[3])
    end
    if frame.scrollBarThumb then
        local sc = theme.scrollThumbColor
        frame.scrollBarThumb:SetColorTexture(sc[1], sc[2], sc[3], sc[4] or 0.8)
    end
    if frame.restartRollBtn and frame.restartRollBtn.SetBackdrop then
        local bbg = theme.btnBgColor
        local bbc = theme.btnBorderColor
        frame.restartRollBtn:SetBackdropColor(bbg[1], bbg[2], bbg[3], bbg[4] or 0.9)
        frame.restartRollBtn:SetBackdropBorderColor(bbc[1], bbc[2], bbc[3], bbc[4] or 0.9)
    end

    if frame.tabs then
        local currentRollID = DataTracker and DataTracker.currentRollID
        for i = 1, MAX_TABS do
            local tab = frame.tabs[i]
            if tab and tab.SetBackdrop then
                if self._appliedThemeKey ~= themeKey then
                    tab:SetBackdrop({
                        bgFile = "Interface\\Buttons\\WHITE8X8",
                        edgeFile = theme.tabEdgeFile,
                        edgeSize = theme.tabEdgeSize,
                        insets = theme.tabInsets,
                    })
                end
                local tbg = theme.tabBgColor
                tab:SetBackdropColor(tbg[1], tbg[2], tbg[3], tbg[4] or 0.9)
                local tbc = (tab.rollID and tab.rollID == currentRollID) and theme.tabActiveBorder or theme.tabInactiveBorder
                tab:SetBackdropBorderColor(tbc[1], tbc[2], tbc[3], tbc[4] or 1.0)
            end
        end
    end

    self._appliedThemeKey = themeKey
end

function RollTrackerFrame:UpdateOpacity()
    if not self.frame then return end
    local pct = (ns.db and tonumber(ns.db.windowOpacity)) or 100
    if pct < 20 then pct = 20 end
    if pct > 100 then pct = 100 end
    self.frame:SetAlpha(pct / 100)
end

function RollTrackerFrame:UpdateScale()
    if not self.frame then return end
    local pct = (ns.db and tonumber(ns.db.windowScale)) or 100
    if pct < 60 then pct = 60 end
    if pct > 160 then pct = 160 end
    self.frame:SetScale(pct / 100)
end

function RollTrackerFrame:SetMoveMode(active, fromBlizzardEditMode)
    local frame = self.frame
    if not frame or not frame.moverOverlay then return end

    self.isMoveMode = active and true or false
    if self.isMoveMode then
        if ns.MultiItemManager and frame:GetNumPoints() == 0 then
            ns.MultiItemManager:UpdateAnchoring()
        end
        frame:SetWidth(self:GetWindowWidth())
        if fromBlizzardEditMode then
            frame.moverOverlay.lockBtn:Hide()
        else
            frame.moverOverlay.lockBtn:Show()
        end
        frame.moverOverlay:Show()
        frame:Show()
        if frame.Raise then
            frame:Raise()
        end
    else
        frame.moverOverlay:Hide()
        self:Refresh()
    end
end

function RollTrackerFrame:ToggleMoveMode()
    self:SetMoveMode(not self.isMoveMode, false)
end

function RollTrackerFrame:HookBlizzardEditMode()
    if self._editModeHooked then return end
    self._editModeHooked = true

    if EventRegistry and type(EventRegistry.RegisterCallback) == "function" then
        pcall(function()
            EventRegistry:RegisterCallback("EditMode.Enter", function()
                RollTrackerFrame:SetMoveMode(true, true)
            end, RollTrackerFrame)
            EventRegistry:RegisterCallback("EditMode.Exit", function()
                RollTrackerFrame:SetMoveMode(false, true)
            end, RollTrackerFrame)
        end)
    end

    local function HookManagerFrame()
        if _G.EditModeManagerFrame and not _G.EditModeManagerFrame._clearLootHooked then
            _G.EditModeManagerFrame._clearLootHooked = true
            _G.EditModeManagerFrame:HookScript("OnShow", function()
                RollTrackerFrame:SetMoveMode(true, true)
            end)
            _G.EditModeManagerFrame:HookScript("OnHide", function()
                RollTrackerFrame:SetMoveMode(false, true)
            end)
        end
    end

    HookManagerFrame()
    ns:RegisterEvent("ADDON_LOADED", function(_, loadedName)
        if loadedName == "Blizzard_EditMode" then
            HookManagerFrame()
        end
    end)
end

function RollTrackerFrame:HideWindow()
    if self.frame then
        self.frame:Hide()
    end
end

function RollTrackerFrame:ForceShowCurrent()
    local session = DataTracker:GetCurrentRollSession()
    if not session then
        local lastID = DataTracker.GetLastRollID and DataTracker:GetLastRollID()
        if lastID then
            DataTracker:UndismissRoll(lastID)
            DataTracker:SetCurrentRollID(lastID, true)
            return
        end
    else
        DataTracker:UndismissRoll(session.rollID)
    end
    self:Refresh(true)
end

function RollTrackerFrame:UpdateTabs(activeRolls, currentRollID)
    local frame = self.frame
    if not frame then return end

    local showTabs = (#activeRolls > 1)
    for i = 1, MAX_TABS do
        local tab = frame.tabs[i]
        local rollSession = showTabs and activeRolls[i] or nil
        if rollSession then
            tab.rollID = rollSession.rollID
            tab.itemLink = rollSession.itemLink
            tab.itemName = rollSession.itemName
            tab.icon:SetTexture(rollSession.itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
            if rollSession.isRandomRoll then
                tab.icon:SetTexCoord(0, 1, 0, 1)
            else
                tab.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end

            local eval = DataTracker:EvaluateSession(rollSession)
            if eval then
                tab.badge:SetText(string.format("%d/%d", eval.answeredPlayers, eval.totalPlayers))
            else
                tab.badge:SetText("")
            end

            local theme = self:GetTheme()
            if rollSession.rollID == currentRollID then
                tab.activeGlow:Show()
                tab.icon:SetDesaturated(false)
                tab.icon:SetAlpha(1.0)
                if tab.SetBackdropBorderColor then
                    local ab = theme.tabActiveBorder
                    tab:SetBackdropBorderColor(ab[1], ab[2], ab[3], ab[4] or 1.0)
                end
            else
                tab.activeGlow:Hide()
                tab.icon:SetDesaturated(false)
                tab.icon:SetAlpha(0.65)
                if tab.SetBackdropBorderColor then
                    local ib = theme.tabInactiveBorder
                    tab:SetBackdropBorderColor(ib[1], ib[2], ib[3], ib[4] or 0.85)
                end
            end
            tab:Show()
        else
            tab:Hide()
        end
    end
end

function RollTrackerFrame:UpdatePlayerRows()
    local frame = self.frame
    if not frame or not self.currentEval then return end

    local allPlayers = self.currentEval.players or {}
    local players = {}
    for _, p in ipairs(allPlayers) do
        local skip = false
        if ns.db.hidePassed and p.rollType == DataTracker.ROLL_TYPE_PASS then
            skip = true
        elseif ns.db.hidePending and p.rollType == DataTracker.ROLL_TYPE_PENDING then
            skip = true
        end
        if not skip then
            table.insert(players, p)
        end
    end

    local numPlayers = #players
    local visibleRows = math.min(MAX_VISIBLE_ROWS, math.max(MIN_VISIBLE_ROWS, numPlayers))

    -- Adjust window width & height dynamically to fit choice mode and party/raid size cleanly
    local winWidth = self:GetWindowWidth()
    local targetHeight = HEADER_HEIGHT + (visibleRows * ROW_HEIGHT) + FOOTER_HEIGHT
    frame:SetSize(winWidth, targetHeight)

    local choiceMode = self:GetChoiceDisplayMode()

    local maxOffset = math.max(0, numPlayers - visibleRows)
    frame.maxScrollOffset = maxOffset
    local offset = frame.scrollOffset or 0
    if offset > maxOffset then
        offset = maxOffset
        frame.scrollOffset = offset
    elseif offset < 0 then
        offset = 0
        frame.scrollOffset = 0
    end

    local hasScrollbar = (numPlayers > visibleRows)
    if frame.scrollBar then
        if hasScrollbar then
            frame.scrollBar._updating = true
            frame.scrollBar:SetMinMaxValues(0, maxOffset)
            frame.scrollBar:SetValue(offset)
            frame.scrollBar._updating = false
            frame.scrollBar:Show()
        else
            frame.scrollBar:Hide()
        end
    end

    local rowWidth = hasScrollbar and (winWidth - 34) or (winWidth - 20)
    local leaders = self.currentEval.leaders or {}
    local isLeaderMap = {}
    for _, l in ipairs(leaders) do
        isLeaderMap[l] = true
    end

    for i = 1, MAX_VISIBLE_ROWS do
        local row = frame.rows[i]
        local dataIdx = offset + i

        if i <= visibleRows and dataIdx <= numPlayers then
            local p = players[dataIdx]
            local isLeader = isLeaderMap[p] == true
            row:SetWidth(rowWidth)
            row.playerData = p

            -- Subtle highlight for leading row(s)
            if isLeader then
                row.bg:SetColorTexture(0.85, 0.68, 0.15, 0.18)
                row.rankText:SetTextColor(1.0, 0.85, 0.15)
            else
                if (row.rowIndex or i) % 2 == 1 then
                    row.bg:SetColorTexture(1, 1, 1, 0.04)
                else
                    row.bg:SetColorTexture(0, 0, 0, 0.15)
                end
                row.rankText:SetTextColor(0.8, 0.8, 0.8)
            end

            -- 1. Rank ("1.", "2.")
            row.rankText:SetText(dataIdx .. ".")

            -- 2. Class Icon
            local coords = p.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[p.class]
            if coords then
                row.classIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
                row.classIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
                row.classIcon:Show()
            else
                row.classIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                row.classIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                row.classIcon:Show()
            end

            -- 3. Class-Colored Player Name
            row.nameText:SetText(ns.RosterInspector:ColorizeName(p.name, p.class))

            -- 4. Role Icon
            local roleCoords = ns.db.showRoleIcons and p.role and ROLE_TEX_COORDS[p.role]
            if roleCoords then
                row.roleIcon:SetTexCoord(roleCoords[1], roleCoords[2], roleCoords[3], roleCoords[4])
                row.roleIcon:Show()
            else
                row.roleIcon:Hide()
            end

            -- 5. Roll Choice Icon & Text (Icons / Text / Both; Pending shows nothing)
            local iconPath = ROLL_ICONS[p.rollType]
            local rc = ROLL_COLORS[p.rollType] or ROLL_COLORS[DataTracker.ROLL_TYPE_PENDING]

            if choiceMode == "ICONS" then
                row.choiceText:Hide()
                if iconPath then
                    row.choiceIcon:ClearAllPoints()
                    row.choiceIcon:SetPoint("CENTER", row, "LEFT", 228, 0)
                    row.choiceIcon:SetTexture(iconPath)
                    row.choiceIcon:Show()
                else
                    row.choiceIcon:Hide()
                end
            elseif choiceMode == "TEXT" then
                row.choiceIcon:Hide()
                if p.rollType ~= DataTracker.ROLL_TYPE_PENDING then
                    row.choiceText:ClearAllPoints()
                    row.choiceText:SetPoint("LEFT", row, "LEFT", 220, 0)
                    row.choiceText:SetWidth(68)
                    row.choiceText:SetText(DataTracker:GetRollTypeLabel(p.rollType))
                    row.choiceText:SetTextColor(rc.r, rc.g, rc.b)
                    row.choiceText:Show()
                else
                    row.choiceText:Hide()
                end
            else
                if iconPath then
                    row.choiceIcon:ClearAllPoints()
                    row.choiceIcon:SetPoint("LEFT", row, "LEFT", 220, 0)
                    row.choiceIcon:SetTexture(iconPath)
                    row.choiceIcon:Show()

                    row.choiceText:ClearAllPoints()
                    row.choiceText:SetPoint("LEFT", row.choiceIcon, "RIGHT", 4, 0)
                    row.choiceText:SetWidth(68)
                    row.choiceText:SetText(DataTracker:GetRollTypeLabel(p.rollType))
                    row.choiceText:SetTextColor(rc.r, rc.g, rc.b)
                    row.choiceText:Show()
                else
                    row.choiceIcon:Hide()
                    row.choiceText:Hide()
                end
            end

            -- 6. Roll Score
            if p.rollScore and p.rollScore > 0 then
                row.scoreText:SetText(tostring(p.rollScore))
                if isLeader then
                    row.scoreText:SetTextColor(1.0, 0.85, 0.15)
                else
                    row.scoreText:SetTextColor(1.0, 1.0, 1.0)
                end
            elseif p.rollType == DataTracker.ROLL_TYPE_PASS then
                row.scoreText:SetText("-")
                row.scoreText:SetTextColor(0.55, 0.55, 0.55)
            else
                row.scoreText:SetText("...")
                row.scoreText:SetTextColor(0.55, 0.55, 0.55)
            end

            row:Show()
        else
            row.playerData = nil
            row:Hide()
        end
    end
end

function RollTrackerFrame:Refresh(isNewRoll)
    local frame = self.frame
    if not frame then return end

    self:ApplyTheme()
    self:UpdateOpacity()
    self:UpdateScale()
    frame:SetWidth(self:GetWindowWidth())

    if not ns.db.enabled then
        if not self.isMoveMode then
            frame:Hide()
        end
        return
    end

    local session = DataTracker:GetCurrentRollSession()
    if not session then
        if not self.isMoveMode then
            frame:Hide()
        end
        return
    end

    if DataTracker:IsDismissed(session.rollID) then
        if not self.isMoveMode then
            frame:Hide()
        end
        return
    end

    if isNewRoll and not ns.db.autoOpen and not frame:IsShown() then
        return
    end

    local activeRolls = DataTracker:GetActiveRolls()
    self:UpdateTabs(activeRolls, session.rollID)

    -- Item Header (use plain itemName colored by quality, without hyperlink [brackets])
    frame.itemIcon:SetTexture(session.itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
    if session.isRandomRoll then
        frame.itemIcon:SetTexCoord(0, 1, 0, 1)
    else
        frame.itemIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    local r, g, b = ns.GetItemQualityColor(session.itemQuality or 2)
    if session.isRandomRoll then
        r, g, b = 1.0, 0.85, 0.25
    end
    local cleanName = session.itemName
    if (not cleanName or cleanName == "") and session.itemLink then
        cleanName = session.itemLink:match("%[(.-)%]") or session.itemLink
    end
    frame.itemTitle:SetText(cleanName or "Item")
    frame.itemTitle:SetTextColor(r or 1, g or 1, b or 1)

    -- Show/Hide Random Roll Dice & Restart Session header buttons
    if frame.rollDiceBtn and frame.restartRollBtn and frame.itemHeader then
        if session.isRandomRoll then
            local alreadyRolled = DataTracker:HasLocalPlayerRolled(session.rollID)
            if alreadyRolled then
                frame.rollDiceBtn.icon:SetDesaturated(true)
                frame.rollDiceBtn.icon:SetAlpha(0.45)
                if frame.rollDiceBtn.SetBackdropBorderColor then
                    frame.rollDiceBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
                end
            else
                frame.rollDiceBtn.icon:SetDesaturated(false)
                frame.rollDiceBtn.icon:SetAlpha(1.0)
                if frame.rollDiceBtn.SetBackdropBorderColor then
                    frame.rollDiceBtn:SetBackdropBorderColor(0.35, 0.85, 0.35, 0.95)
                end
            end
            frame.restartRollBtn:Show()
            frame.rollDiceBtn:Show()
            frame.itemHeader:SetPoint("TOPRIGHT", frame.rollDiceBtn, "TOPLEFT", -4, 0)
        else
            frame.restartRollBtn:Hide()
            frame.rollDiceBtn:Hide()
            frame.itemHeader:SetPoint("TOPRIGHT", frame.closeBtn, "TOPLEFT", -2, 0)
        end
    end

    -- Evaluate Player List & Leaders
    local eval = DataTracker:EvaluateSession(session)
    self.currentEval = eval

    if eval then
        if eval.isComplete then
            frame.footerText:SetText(string.format(L.FOOTER_COMPLETE, eval.answeredPlayers, eval.totalPlayers))
        else
            frame.footerText:SetText(string.format(L.FOOTER_SUMMARY, eval.answeredPlayers, eval.totalPlayers, eval.pendingCount))
        end
    end

    self:UpdatePlayerRows()
    frame:Show()
    if frame.Raise then
        frame:Raise()
    end
end
