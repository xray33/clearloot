local addonName, ns = ...
local L = ns.L

local SettingsModule = {}
ns.Settings = SettingsModule

local function CreateCheckbox(parent, label, tooltip, dbKey, yOffset, onChange)
    local template = DoesTemplateExist and DoesTemplateExist("InterfaceOptionsCheckButtonTemplate") and "InterfaceOptionsCheckButtonTemplate" or "UICheckButtonTemplate"
    local cb = CreateFrame("CheckButton", nil, parent, template)
    cb:SetSize(26, 26)
    cb:SetPoint("TOPLEFT", 16, yOffset)

    local text = cb.Text or cb.text
    if not text then
        text = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        cb.Text = text
    end
    text:SetText(label)

    cb:SetScript("OnEnter", function(self)
        if tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label, 1, 0.82, 0)
            GameTooltip:AddLine(tooltip, 0.85, 0.85, 0.85, true)
            GameTooltip:Show()
        end
    end)
    cb:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    cb:SetScript("OnShow", function(self)
        self:SetChecked(ns.db[dbKey] and true or false)
    end)

    cb:SetScript("OnClick", function(self)
        local val = self:GetChecked() and true or false
        ns.db[dbKey] = val
        if onChange then
            onChange(val)
        end
    end)

    return cb
end

function SettingsModule:Init()
    local panel = CreateFrame("Frame", "ClearLootSettingsPanel", UIParent)
    panel.name = "|TInterface\\Buttons\\UI-GroupLoot-Dice-Up:16:16:0:0|t ClearLoot"

    local headerIcon = panel:CreateTexture(nil, "ARTWORK")
    headerIcon:SetSize(28, 28)
    headerIcon:SetPoint("TOPLEFT", 16, -14)
    headerIcon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Up")

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("LEFT", headerIcon, "RIGHT", 8, 0)
    title:SetText(L.ADDON_TITLE .. " |cff888888v" .. (ns.VERSION or "0.1.0") .. "|r")

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", headerIcon, "BOTTOMLEFT", 0, -8)
    subtitle:SetWidth(540)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText(L.ADDON_SUBTITLE)

    local y = -68

    CreateCheckbox(panel, L.SETTINGS_ENABLE, L.SETTINGS_ENABLE_DESC, "enabled", y, function()
        if ns.RollTrackerFrame then
            ns.RollTrackerFrame:Refresh()
        end
    end)
    y = y - 32

    CreateCheckbox(panel, L.SETTINGS_AUTO_OPEN, L.SETTINGS_AUTO_OPEN_DESC, "autoOpen", y)
    y = y - 32

    CreateCheckbox(panel, L.SETTINGS_SHOW_ROLE, L.SETTINGS_SHOW_ROLE_DESC, "showRoleIcons", y, function()
        if ns.RollTrackerFrame then
            ns.RollTrackerFrame:Refresh()
        end
    end)
    y = y - 32

    CreateCheckbox(panel, L.SETTINGS_AUTO_SWITCH, L.SETTINGS_AUTO_SWITCH_DESC, "autoSwitchOnHover", y)
    y = y - 32

    CreateCheckbox(panel, L.SETTINGS_KEEP_AFTER_ROLL, L.SETTINGS_KEEP_AFTER_ROLL_DESC, "keepOpenAfterMyRoll", y)
    y = y - 32

    CreateCheckbox(panel, L.SETTINGS_HIDE_PASS, L.SETTINGS_HIDE_PASS_DESC, "hidePassed", y, function()
        if ns.RollTrackerFrame then
            ns.RollTrackerFrame:Refresh()
        end
    end)
    y = y - 32

    CreateCheckbox(panel, L.SETTINGS_HIDE_PENDING, L.SETTINGS_HIDE_PENDING_DESC, "hidePending", y, function()
        if ns.RollTrackerFrame then
            ns.RollTrackerFrame:Refresh()
        end
    end)
    y = y - 40

    -- Window Anchor Dropdown
    local anchorLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    anchorLabel:SetPoint("TOPLEFT", 20, y)
    anchorLabel:SetText(L.SETTINGS_ANCHOR_SIDE)

    local ANCHOR_OPTIONS = {
        { value = "RIGHT", text = L.SETTINGS_ANCHOR_RIGHT },
        { value = "LEFT",  text = L.SETTINGS_ANCHOR_LEFT },
        { value = "FREE",  text = L.SETTINGS_ANCHOR_FREE },
    }

    local function GetAnchorText(val)
        for _, opt in ipairs(ANCHOR_OPTIONS) do
            if opt.value == val then return opt.text end
        end
        return L.SETTINGS_ANCHOR_RIGHT
    end

    local anchorWidget
    local UpdateAnchorDisplay

    local hasLegacyDropdown = (not DoesTemplateExist or DoesTemplateExist("UIDropDownMenuTemplate"))
        and type(UIDropDownMenu_SetWidth) == "function"
        and type(UIDropDownMenu_Initialize) == "function"

    if hasLegacyDropdown then
        local dropdown = CreateFrame("Frame", "ClearLootAnchorDropDown", panel, "UIDropDownMenuTemplate")
        dropdown:SetPoint("TOPLEFT", anchorLabel, "BOTTOMLEFT", -16, -4)

        UpdateAnchorDisplay = function(val)
            UIDropDownMenu_SetText(dropdown, GetAnchorText(val))
        end

        UIDropDownMenu_SetWidth(dropdown, 220)
        UIDropDownMenu_Initialize(dropdown, function(self, level)
            for _, opt in ipairs(ANCHOR_OPTIONS) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = opt.text
                info.value = opt.value
                info.checked = (ns.db.anchorSide == opt.value)
                info.func = function()
                    ns.db.anchorSide = opt.value
                    UpdateAnchorDisplay(opt.value)
                    if ns.MultiItemManager then
                        ns.MultiItemManager:UpdateAnchoring()
                    end
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)

        dropdown:SetScript("OnShow", function()
            UpdateAnchorDisplay(ns.db.anchorSide)
        end)
        anchorWidget = dropdown
    else
        local anchorBtn = CreateFrame("Button", "ClearLootAnchorButton", panel, "UIPanelButtonTemplate")
        anchorBtn:SetSize(240, 24)
        anchorBtn:SetPoint("TOPLEFT", anchorLabel, "BOTTOMLEFT", 0, -6)

        UpdateAnchorDisplay = function(val)
            anchorBtn:SetText(GetAnchorText(val))
        end

        anchorBtn:SetScript("OnShow", function()
            UpdateAnchorDisplay(ns.db.anchorSide)
        end)

        anchorBtn:SetScript("OnClick", function(self)
            if MenuUtil and type(MenuUtil.CreateContextMenu) == "function" then
                MenuUtil.CreateContextMenu(self, function(_, rootDescription)
                    for _, opt in ipairs(ANCHOR_OPTIONS) do
                        rootDescription:CreateRadio(opt.text, function()
                            return ns.db.anchorSide == opt.value
                        end, function()
                            ns.db.anchorSide = opt.value
                            UpdateAnchorDisplay(opt.value)
                            if ns.MultiItemManager then
                                ns.MultiItemManager:UpdateAnchoring()
                            end
                        end)
                    end
                end)
            else
                local nextIdx = 1
                for idx, opt in ipairs(ANCHOR_OPTIONS) do
                    if opt.value == ns.db.anchorSide then
                        nextIdx = (idx % #ANCHOR_OPTIONS) + 1
                        break
                    end
                end
                local chosen = ANCHOR_OPTIONS[nextIdx]
                ns.db.anchorSide = chosen.value
                UpdateAnchorDisplay(chosen.value)
                if ns.MultiItemManager then
                    ns.MultiItemManager:UpdateAnchoring()
                end
            end
        end)
        anchorWidget = anchorBtn
    end

    local resetPosBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetPosBtn:SetSize(160, 24)
    resetPosBtn:SetPoint("LEFT", anchorWidget, "RIGHT", hasLegacyDropdown and 0 or 10, hasLegacyDropdown and 2 or 0)
    resetPosBtn:SetText(L.SETTINGS_RESET_POS_BTN)
    resetPosBtn:SetScript("OnClick", function()
        ns.db.freePosition = nil
        ns.db.anchorSide = "RIGHT"
        UpdateAnchorDisplay("RIGHT")
        if ns.MultiItemManager then
            ns.MultiItemManager:UpdateAnchoring()
        end
        ns:Print(L.MSG_POS_RESET)
    end)

    y = y - 68

    -- Solo Testing & Simulation Section
    local testHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    testHeader:SetPoint("TOPLEFT", 20, y)
    testHeader:SetText(L.SETTINGS_TEST_HEADER)

    y = y - 24

    local testSingleBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testSingleBtn:SetSize(165, 26)
    testSingleBtn:SetPoint("TOPLEFT", 20, y)
    testSingleBtn:SetText(L.SETTINGS_TEST_SINGLE_BTN)
    testSingleBtn:SetScript("OnClick", function()
        if ns.Simulator then
            local ok, err = pcall(ns.Simulator.StartSingleTest, ns.Simulator)
            if not ok then
                ns:Print("|cffff4444Simulation error:|r " .. tostring(err))
            end
        end
    end)

    local testMultiBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testMultiBtn:SetSize(165, 26)
    testMultiBtn:SetPoint("LEFT", testSingleBtn, "RIGHT", 10, 0)
    testMultiBtn:SetText(L.SETTINGS_TEST_MULTI_BTN)
    testMultiBtn:SetScript("OnClick", function()
        if ns.Simulator then
            local ok, err = pcall(ns.Simulator.StartMultiTest, ns.Simulator)
            if not ok then
                ns:Print("|cffff4444Simulation error:|r " .. tostring(err))
            end
        end
    end)

    local testRaidBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testRaidBtn:SetSize(165, 26)
    testRaidBtn:SetPoint("LEFT", testMultiBtn, "RIGHT", 10, 0)
    testRaidBtn:SetText(L.SETTINGS_TEST_RAID_BTN)
    testRaidBtn:SetScript("OnClick", function()
        if ns.Simulator then
            local ok, err = pcall(ns.Simulator.StartRaidTest, ns.Simulator, 40)
            if not ok then
                ns:Print("|cffff4444Simulation error:|r " .. tostring(err))
            end
        end
    end)

    self.panel = panel

    -- Register in Modern Blizzard Settings API (1.15.x / 2.5.x / Forever) or Legacy InterfaceOptions
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        self.categoryID = category:GetID()
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

function SettingsModule:OpenSettings()
    if Settings and Settings.OpenToCategory and self.categoryID then
        Settings.OpenToCategory(self.categoryID)
    elseif InterfaceOptionsFrame_OpenToCategory and self.panel then
        InterfaceOptionsFrame_OpenToCategory(self.panel)
        InterfaceOptionsFrame_OpenToCategory(self.panel)
    end
end
