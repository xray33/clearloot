local addonName, ns = ...
local L = ns.L
local DataTracker = ns.DataTracker

local RollTrackerFrame = {}
ns.RollTrackerFrame = RollTrackerFrame

local WINDOW_WIDTH = 285
local HEADER_HEIGHT = 82
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
    [DataTracker.ROLL_TYPE_PENDING]    = "Interface\\FriendsFrame\\StatusIcon-Away",
}

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

    -- 3. Fallback custom native-styled dropdown menu (Whisper, Inspect, Invite, Cancel)
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
            if ChatFrame_SendTell then
                ChatFrame_SendTell(targetName)
            elseif ChatFrame_OpenChat then
                ChatFrame_OpenChat("/w " .. targetName .. " ")
            end
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
    badge:SetFont(badge:GetFont(), 9, "OUTLINE")
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
    row:SetSize(WINDOW_WIDTH - 24, ROW_HEIGHT)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Alternating subtle stripe background
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

    -- 1. Rank Number ("1)")
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
    nameText:SetWidth(98)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    -- 4. Role Icon (Tank / Healer / DPS)
    local roleIcon = row:CreateTexture(nil, "ARTWORK")
    roleIcon:SetSize(14, 14)
    roleIcon:SetPoint("LEFT", nameText, "RIGHT", 2, 0)
    roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
    row.roleIcon = roleIcon

    -- 5. Roll Choice Icon (Dice / Coin / DE / Pass / Pending)
    local choiceIcon = row:CreateTexture(nil, "ARTWORK")
    choiceIcon:SetSize(15, 15)
    choiceIcon:SetPoint("LEFT", roleIcon, "RIGHT", 6, 0)
    row.choiceIcon = choiceIcon

    -- 6. Roll Choice Text ("Need", "Greed", "Pass")
    local choiceText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    choiceText:SetPoint("LEFT", choiceIcon, "RIGHT", 4, 0)
    choiceText:SetWidth(54)
    choiceText:SetJustifyH("LEFT")
    choiceText:SetWordWrap(false)
    row.choiceText = choiceText

    -- 7. Roll Score ("94")
    local scoreText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scoreText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    scoreText:SetWidth(28)
    scoreText:SetJustifyH("RIGHT")
    row.scoreText = scoreText

    row:SetScript("OnClick", function(self, button)
        if not self.playerData then return end
        if button == "RightButton" then
            ShowPlayerContextMenu(self.playerData, self)
        elseif button == "LeftButton" and IsShiftKeyDown() then
            local target = self.playerData.fullName or self.playerData.name
            if ChatFrame_SendTell then
                ChatFrame_SendTell(target)
            elseif ChatFrame_OpenChat then
                ChatFrame_OpenChat("/w " .. target .. " ")
            end
        end
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

function RollTrackerFrame:Init()
    local frame = CreateFrame("Frame", "ClearLootTrackerFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetSize(WINDOW_WIDTH, HEADER_HEIGHT + (MIN_VISIBLE_ROWS * ROW_HEIGHT) + FOOTER_HEIGHT)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    ApplyClassicBackdrop(frame, 0.94)

    frame:SetScript("OnDragStart", function(self)
        if ns.db.anchorSide == "FREE" or IsShiftKeyDown() then
            self:StartMoving()
        end
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
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
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
        if session and session.itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(session.itemLink)
            GameTooltip:Show()
        end
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

    -- Provisional Winner Banner
    local winnerBanner = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    winnerBanner:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -34)
    winnerBanner:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -34)
    winnerBanner:SetHeight(22)
    if winnerBanner.SetBackdrop then
        winnerBanner:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 8,
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        winnerBanner:SetBackdropColor(0.22, 0.17, 0.04, 0.9)
        winnerBanner:SetBackdropBorderColor(0.90, 0.72, 0.20, 0.9)
    end

    local crownIcon = winnerBanner:CreateTexture(nil, "ARTWORK")
    crownIcon:SetSize(14, 14)
    crownIcon:SetPoint("LEFT", winnerBanner, "LEFT", 6, 0)
    crownIcon:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
    frame.crownIcon = crownIcon

    local winnerText = winnerBanner:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    winnerText:SetPoint("LEFT", crownIcon, "RIGHT", 4, 0)
    winnerText:SetPoint("RIGHT", winnerBanner, "RIGHT", -6, 0)
    winnerText:SetJustifyH("CENTER")
    winnerText:SetWordWrap(false)
    frame.winnerText = winnerText
    frame.winnerBanner = winnerBanner

    -- Column Headers Row
    local colHeader = CreateFrame("Frame", nil, frame)
    colHeader:SetPoint("TOPLEFT", winnerBanner, "BOTTOMLEFT", 0, -4)
    colHeader:SetPoint("TOPRIGHT", winnerBanner, "BOTTOMRIGHT", 0, -4)
    colHeader:SetHeight(16)

    local hRank = colHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hRank:SetPoint("LEFT", 4, 0)
    hRank:SetText(L.HEADER_RANK)
    hRank:SetTextColor(0.85, 0.75, 0.45)

    local hName = colHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hName:SetPoint("LEFT", 40, 0)
    hName:SetText(L.HEADER_NAME)
    hName:SetTextColor(0.85, 0.75, 0.45)

    local hChoice = colHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hChoice:SetPoint("LEFT", 168, 0)
    hChoice:SetText(L.HEADER_CHOICE)
    hChoice:SetTextColor(0.85, 0.75, 0.45)

    local hRoll = colHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hRoll:SetPoint("RIGHT", -4, 0)
    hRoll:SetText(L.HEADER_ROLL)
    hRoll:SetTextColor(0.85, 0.75, 0.45)

    local divider = colHeader:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("BOTTOMLEFT", colHeader, "BOTTOMLEFT", 0, 0)
    divider:SetPoint("BOTTOMRIGHT", colHeader, "BOTTOMRIGHT", 0, 0)
    divider:SetColorTexture(0.6, 0.5, 0.3, 0.5)

    -- ScrollFrame for Player Rows
    local scrollFrame = CreateFrame("ScrollFrame", "ClearLootRollScrollFrame", frame, "FauxScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", colHeader, "BOTTOMLEFT", 0, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, FOOTER_HEIGHT)
    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function()
            RollTrackerFrame:UpdatePlayerRows()
        end)
    end)
    frame.scrollFrame = scrollFrame

    -- Create Row Pool
    frame.rows = {}
    for i = 1, MAX_VISIBLE_ROWS do
        local row = CreatePlayerRow(frame, i)
        if i == 1 then
            row:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)
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

    frame:Hide()
    self.frame = frame
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

    -- Adjust window height dynamically to fit party/raid size cleanly
    local targetHeight = HEADER_HEIGHT + (visibleRows * ROW_HEIGHT) + FOOTER_HEIGHT
    frame:SetHeight(targetHeight)

    FauxScrollFrame_Update(frame.scrollFrame, numPlayers, visibleRows, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(frame.scrollFrame) or 0

    local hasScrollbar = (numPlayers > visibleRows)
    local rowWidth = hasScrollbar and (WINDOW_WIDTH - 38) or (WINDOW_WIDTH - 20)

    for i = 1, MAX_VISIBLE_ROWS do
        local row = frame.rows[i]
        local dataIdx = offset + i

        if i <= visibleRows and dataIdx <= numPlayers then
            local p = players[dataIdx]
            row:SetWidth(rowWidth)
            row.playerData = p

            -- 1. Rank
            row.rankText:SetText(dataIdx .. ")")

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

            -- 5. Roll Choice Icon & Text
            local iconPath = ROLL_ICONS[p.rollType] or ROLL_ICONS[DataTracker.ROLL_TYPE_PENDING]
            row.choiceIcon:SetTexture(iconPath)
            row.choiceText:SetText(DataTracker:GetRollTypeLabel(p.rollType))

            local rc = ROLL_COLORS[p.rollType] or ROLL_COLORS[DataTracker.ROLL_TYPE_PENDING]
            row.choiceText:SetTextColor(rc.r, rc.g, rc.b)

            -- 6. Roll Score
            if p.rollScore and p.rollScore > 0 then
                row.scoreText:SetText(tostring(p.rollScore))
                if self.currentEval.leaders and self.currentEval.leaders[1] == p then
                    row.scoreText:SetTextColor(1.0, 0.85, 0.1)
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

    if not ns.db.enabled then
        frame:Hide()
        return
    end

    local session = DataTracker:GetCurrentRollSession()
    if not session then
        frame:Hide()
        return
    end

    if DataTracker:IsDismissed(session.rollID) then
        frame:Hide()
        return
    end

    if isNewRoll and not ns.db.autoOpen and not frame:IsShown() then
        return
    end

    local activeRolls = DataTracker:GetActiveRolls()
    self:UpdateTabs(activeRolls, session.rollID)

    -- Item Header (use plain itemName colored by quality, without hyperlink [brackets])
    frame.itemIcon:SetTexture(session.itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
    local r, g, b = GetItemQualityColor(session.itemQuality or 2)
    local cleanName = session.itemName
    if (not cleanName or cleanName == "") and session.itemLink then
        cleanName = session.itemLink:match("%[(.-)%]") or session.itemLink
    end
    frame.itemTitle:SetText(cleanName or "Item")
    frame.itemTitle:SetTextColor(r or 1, g or 1, b or 1)

    -- Evaluate Provisional Winner & Player List
    local eval = DataTracker:EvaluateSession(session)
    self.currentEval = eval

    if eval then
        if #eval.leaders == 1 then
            local leader = eval.leaders[1]
            local coloredLeader = ns.RosterInspector:ColorizeName(leader.name, leader.class)
            local typeLabel = DataTracker:GetRollTypeLabel(eval.bestType)
            local scoreVal = eval.bestScore > 0 and eval.bestScore or 0
            local fmt = eval.isComplete and L.WINNER_WON or L.WINNER_LEADING
            frame.winnerText:SetText(string.format(fmt, coloredLeader, typeLabel, scoreVal))
            frame.crownIcon:Show()
        elseif #eval.leaders > 1 then
            local names = {}
            for _, p in ipairs(eval.leaders) do
                table.insert(names, ns.RosterInspector:ColorizeName(p.name, p.class))
            end
            local typeLabel = DataTracker:GetRollTypeLabel(eval.bestType)
            frame.winnerText:SetText(string.format(L.WINNER_TIE, typeLabel, eval.bestScore, table.concat(names, ", ")))
            frame.crownIcon:Show()
        elseif eval.allPassed then
            frame.winnerText:SetText(L.WINNER_ALL_PASSED)
            frame.crownIcon:Hide()
        else
            frame.winnerText:SetText(L.WINNER_WAITING)
            frame.crownIcon:Hide()
        end

        if eval.isComplete then
            frame.footerText:SetText(string.format(L.FOOTER_COMPLETE, eval.answeredPlayers, eval.totalPlayers))
        else
            frame.footerText:SetText(string.format(L.FOOTER_SUMMARY, eval.answeredPlayers, eval.totalPlayers, eval.pendingCount))
        end
    end

    self:UpdatePlayerRows()
    frame:Show()
end
