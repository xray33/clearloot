local addonName, ns = ...
local L = ns.L
local DataTracker = ns.DataTracker

local RollTrackerFrame = {}
ns.RollTrackerFrame = RollTrackerFrame

local WINDOW_WIDTH_ICONS = 324
local WINDOW_WIDTH_TEXT  = 360
local WINDOW_WIDTH_BOTH  = 378
local HEADER_HEIGHT = 56
local FOOTER_HEIGHT = 26
local ROW_HEIGHT = 20
local MIN_VISIBLE_ROWS = 5
local MAX_VISIBLE_ROWS = 10
local MAX_TABS = 6

local ROLL_ICONS = {
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

local function ApplyClassicBackdrop(frame, bgAlpha)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        frame:SetBackdropColor(0.06, 0.06, 0.08, bgAlpha or 0.92)
        frame:SetBackdropBorderColor(0.85, 0.75, 0.55, 1.0)
    end
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
    choiceIcon:SetPoint("LEFT", row, "LEFT", 235, 0)
    row.choiceIcon = choiceIcon

    -- 6. Roll Choice Text ("Need", "Greed", "Pass")
    local choiceText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    choiceText:SetPoint("LEFT", choiceIcon, "RIGHT", 4, 0)
    choiceText:SetWidth(76)
    choiceText:SetJustifyH("LEFT")
    choiceText:SetWordWrap(false)
    row.choiceText = choiceText

    -- 7. Roll Score ("94")
    local scoreText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scoreText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    scoreText:SetWidth(26)
    scoreText:SetJustifyH("RIGHT")
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
    ApplyClassicBackdrop(frame, 0.94)

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

    -- Item Header Button (Icon + Item Link/Name, hoverable for item tooltip)
    local itemHeader = CreateFrame("Button", nil, frame)
    itemHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -8)
    itemHeader:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -2, 0)
    itemHeader:SetHeight(24)

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
        if session.itemLink then
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

    -- Column Headers Row
    local colHeader = CreateFrame("Frame", nil, frame)
    colHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -34)
    colHeader:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -34)
    colHeader:SetHeight(16)

    local hRank = colHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hRank:SetPoint("LEFT", 4, 0)
    hRank:SetText(L.HEADER_RANK)
    hRank:SetTextColor(0.85, 0.75, 0.45)

    local hName = colHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hName:SetPoint("LEFT", 44, 0)
    hName:SetText(L.HEADER_NAME)
    hName:SetTextColor(0.85, 0.75, 0.45)

    local hChoice = colHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hChoice:SetPoint("LEFT", 222, 0)
    hChoice:SetWidth(42)
    hChoice:SetJustifyH("CENTER")
    hChoice:SetText(L.HEADER_CHOICE)
    hChoice:SetTextColor(0.85, 0.75, 0.45)
    frame.hChoice = hChoice

    local hRoll = colHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hRoll:SetPoint("RIGHT", -4, 0)
    hRoll:SetText(L.HEADER_ROLL)
    hRoll:SetTextColor(0.85, 0.75, 0.45)

    local divider = colHeader:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("BOTTOMLEFT", colHeader, "BOTTOMLEFT", 0, 0)
    divider:SetPoint("BOTTOMRIGHT", colHeader, "BOTTOMRIGHT", 0, 0)
    divider:SetColorTexture(0.6, 0.5, 0.3, 0.5)

    -- Pure-Lua Container & ScrollBar for Player Rows (no FauxScrollFrameTemplate dependency)
    local rowContainer = CreateFrame("Frame", "ClearLootRollRowContainer", frame)
    rowContainer:SetPoint("TOPLEFT", colHeader, "BOTTOMLEFT", 0, -2)
    rowContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, FOOTER_HEIGHT)
    frame.rowContainer = rowContainer

    local scrollBar = CreateFrame("Slider", "ClearLootRollScrollBar", frame)
    scrollBar:SetPoint("TOPRIGHT", colHeader, "BOTTOMRIGHT", -1, -4)
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
    self:UpdateOpacity()
    self:UpdateScale()
    self:HookBlizzardEditMode()
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
        local active = DataTracker:GetActiveRolls()
        if #active > 0 then
            session = active[#active]
            DataTracker:SetCurrentRollID(session.rollID, true)
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

            local eval = DataTracker:EvaluateSession(rollSession)
            if eval then
                tab.badge:SetText(string.format("%d/%d", eval.answeredPlayers, eval.totalPlayers))
            else
                tab.badge:SetText("")
            end

            if rollSession.rollID == currentRollID then
                tab.activeGlow:Show()
                tab.icon:SetDesaturated(false)
                tab.icon:SetAlpha(1.0)
                if tab.SetBackdropBorderColor then
                    tab:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
                end
            else
                tab.activeGlow:Hide()
                tab.icon:SetDesaturated(false)
                tab.icon:SetAlpha(0.65)
                if tab.SetBackdropBorderColor then
                    tab:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
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
    if frame.hChoice then
        frame.hChoice:ClearAllPoints()
        frame.hChoice:SetPoint("LEFT", 222, 0)
        if choiceMode == "ICONS" then
            frame.hChoice:SetWidth(42)
            frame.hChoice:SetJustifyH("CENTER")
        elseif choiceMode == "TEXT" then
            frame.hChoice:SetWidth(78)
            frame.hChoice:SetJustifyH("LEFT")
        else
            frame.hChoice:SetWidth(96)
            frame.hChoice:SetJustifyH("LEFT")
        end
    end

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
                    row.choiceIcon:SetPoint("CENTER", row, "LEFT", 243, 0)
                    row.choiceIcon:SetTexture(iconPath)
                    row.choiceIcon:Show()
                else
                    row.choiceIcon:Hide()
                end
            elseif choiceMode == "TEXT" then
                row.choiceIcon:Hide()
                if p.rollType ~= DataTracker.ROLL_TYPE_PENDING then
                    row.choiceText:ClearAllPoints()
                    row.choiceText:SetPoint("LEFT", row, "LEFT", 222, 0)
                    row.choiceText:SetWidth(78)
                    row.choiceText:SetText(DataTracker:GetRollTypeLabel(p.rollType))
                    row.choiceText:SetTextColor(rc.r, rc.g, rc.b)
                    row.choiceText:Show()
                else
                    row.choiceText:Hide()
                end
            else
                if iconPath then
                    row.choiceIcon:ClearAllPoints()
                    row.choiceIcon:SetPoint("LEFT", row, "LEFT", 222, 0)
                    row.choiceIcon:SetTexture(iconPath)
                    row.choiceIcon:Show()

                    row.choiceText:ClearAllPoints()
                    row.choiceText:SetPoint("LEFT", row.choiceIcon, "RIGHT", 4, 0)
                    row.choiceText:SetWidth(76)
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
    local r, g, b = ns.GetItemQualityColor(session.itemQuality or 2)
    local cleanName = session.itemName
    if (not cleanName or cleanName == "") and session.itemLink then
        cleanName = session.itemLink:match("%[(.-)%]") or session.itemLink
    end
    frame.itemTitle:SetText(cleanName or "Item")
    frame.itemTitle:SetTextColor(r or 1, g or 1, b or 1)

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
