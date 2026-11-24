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

local function CreateDropdown(parent, globalName, labelText, tooltipText, xOffset, yOffset, width, options, dbKey, defaultValue, onSelect)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", xOffset, yOffset)
    label:SetText(labelText)

    local function GetCurrentVal()
        if ns.db and ns.db[dbKey] ~= nil then
            return ns.db[dbKey]
        end
        return defaultValue
    end

    local function GetOptionText(val)
        for _, opt in ipairs(options) do
            if opt.value == val then return opt.text end
        end
        return options[1] and options[1].text or ""
    end

    local function ShowDropdownTooltip(owner)
        if tooltipText then
            GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
            GameTooltip:SetText(labelText, 1, 0.82, 0)
            GameTooltip:AddLine(tooltipText, 0.85, 0.85, 0.85, true)
            GameTooltip:Show()
        end
    end

    local hasLegacyDropdown = (not DoesTemplateExist or DoesTemplateExist("UIDropDownMenuTemplate"))
        and type(UIDropDownMenu_SetWidth) == "function"
        and type(UIDropDownMenu_Initialize) == "function"

    local widget
    local UpdateDisplay

    if hasLegacyDropdown then
        local dropdown = CreateFrame("Frame", globalName, parent, "UIDropDownMenuTemplate")
        dropdown:SetPoint("TOPLEFT", label, "BOTTOMLEFT", -16, -4)
        dropdown:EnableMouse(true)

        UpdateDisplay = function(val)
            UIDropDownMenu_SetText(dropdown, GetOptionText(val))
        end

        UIDropDownMenu_SetWidth(dropdown, width)
        UIDropDownMenu_Initialize(dropdown, function(self, level)
            local curVal = GetCurrentVal()
            for _, opt in ipairs(options) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = opt.text
                info.value = opt.value
                info.checked = (curVal == opt.value)
                info.func = function()
                    ns.db[dbKey] = opt.value
                    UpdateDisplay(opt.value)
                    if onSelect then
                        onSelect(opt.value)
                    end
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)

        dropdown:SetScript("OnShow", function()
            UpdateDisplay(GetCurrentVal())
        end)
        dropdown:SetScript("OnEnter", ShowDropdownTooltip)
        dropdown:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        local ddButton = _G[globalName .. "Button"]
        if ddButton then
            ddButton:HookScript("OnEnter", function()
                ShowDropdownTooltip(dropdown)
            end)
            ddButton:HookScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end
        widget = dropdown
    else
        local btn = CreateFrame("Button", globalName .. "Button", parent, "UIPanelButtonTemplate")
        btn:SetSize(width + 20, 24)
        btn:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)

        UpdateDisplay = function(val)
            btn:SetText(GetOptionText(val))
        end

        btn:SetScript("OnShow", function()
            UpdateDisplay(GetCurrentVal())
        end)
        btn:SetScript("OnEnter", ShowDropdownTooltip)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        btn:SetScript("OnClick", function(self)
            if MenuUtil and type(MenuUtil.CreateContextMenu) == "function" then
                MenuUtil.CreateContextMenu(self, function(_, rootDescription)
                    for _, opt in ipairs(options) do
                        rootDescription:CreateRadio(opt.text, function()
                            return GetCurrentVal() == opt.value
                        end, function()
                            ns.db[dbKey] = opt.value
                            UpdateDisplay(opt.value)
                            if onSelect then
                                onSelect(opt.value)
                            end
                        end)
                    end
                end)
            else
                local cur = GetCurrentVal()
                local nextIdx = 1
                for idx, opt in ipairs(options) do
                    if opt.value == cur then
                        nextIdx = (idx % #options) + 1
                        break
                    end
                end
                local chosen = options[nextIdx]
                ns.db[dbKey] = chosen.value
                UpdateDisplay(chosen.value)
                if onSelect then
                    onSelect(chosen.value)
                end
            end
        end)
        widget = btn
    end

    return widget, UpdateDisplay
end

local function CreatePercentSlider(parent, globalName, labelText, tooltipText, xOffset, yOffset, minVal, maxVal, stepVal, dbKey, defaultVal, onChange)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", xOffset, yOffset)

    local slider = CreateFrame("Slider", globalName, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    slider:SetSize(220, 16)
    slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(stepVal)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end

    if slider.SetBackdrop then
        slider:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        slider:SetBackdropColor(0.08, 0.08, 0.10, 0.85)
        slider:SetBackdropBorderColor(0.6, 0.5, 0.3, 0.9)
    else
        local sliderBg = slider:CreateTexture(nil, "BACKGROUND")
        sliderBg:SetAllPoints(slider)
        sliderBg:SetColorTexture(0.08, 0.08, 0.10, 0.85)
    end

    local sliderThumb = slider:CreateTexture(nil, "ARTWORK")
    sliderThumb:SetSize(14, 20)
    sliderThumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider:SetThumbTexture(sliderThumb)

    local minLabel = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    minLabel:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
    minLabel:SetText(minVal .. "%")

    local maxLabel = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    maxLabel:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
    maxLabel:SetText(maxVal .. "%")

    local function UpdateLabel(val)
        label:SetText(string.format("%s: |cffffffff%d%%|r", labelText, val))
    end

    slider:SetScript("OnShow", function(self)
        local val = (ns.db and tonumber(ns.db[dbKey])) or defaultVal
        self._updating = true
        self:SetValue(val)
        self._updating = false
        UpdateLabel(val)
    end)

    slider:SetScript("OnValueChanged", function(self, value)
        local rounded = math.floor(((value or defaultVal) / stepVal) + 0.5) * stepVal
        if rounded < minVal then rounded = minVal end
        if rounded > maxVal then rounded = maxVal end
        UpdateLabel(rounded)
        if self._updating then return end
        ns.db[dbKey] = rounded
        if onChange then
            onChange(rounded)
        end
    end)

    slider:SetScript("OnEnter", function(self)
        if tooltipText then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(labelText, 1, 0.82, 0)
            GameTooltip:AddLine(tooltipText, 0.85, 0.85, 0.85, true)
            GameTooltip:Show()
        end
    end)
    slider:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return slider
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

    local y = -58

    -- Two-column general checkboxes to save vertical space cleanly
    local cb1 = CreateCheckbox(panel, L.SETTINGS_ENABLE, L.SETTINGS_ENABLE_DESC, "enabled", y, function()
        if ns.RollTrackerFrame then
            ns.RollTrackerFrame:Refresh()
        end
    end)

    local cb2 = CreateCheckbox(panel, L.SETTINGS_AUTO_OPEN, L.SETTINGS_AUTO_OPEN_DESC, "autoOpen", y)
    cb2:ClearAllPoints()
    cb2:SetPoint("TOPLEFT", 286, y)
    y = y - 26

    local cb3 = CreateCheckbox(panel, L.SETTINGS_SHOW_ROLE, L.SETTINGS_SHOW_ROLE_DESC, "showRoleIcons", y, function()
        if ns.RollTrackerFrame then
            ns.RollTrackerFrame:Refresh()
        end
    end)

    local cb4 = CreateCheckbox(panel, L.SETTINGS_AUTO_SWITCH, L.SETTINGS_AUTO_SWITCH_DESC, "autoSwitchOnHover", y)
    cb4:ClearAllPoints()
    cb4:SetPoint("TOPLEFT", 286, y)
    y = y - 26

    local cb5 = CreateCheckbox(panel, L.SETTINGS_KEEP_AFTER_ROLL, L.SETTINGS_KEEP_AFTER_ROLL_DESC, "keepOpenAfterMyRoll", y)

    local cb6 = CreateCheckbox(panel, L.SETTINGS_HIDE_PASS, L.SETTINGS_HIDE_PASS_DESC, "hidePassed", y, function()
        if ns.RollTrackerFrame then
            ns.RollTrackerFrame:Refresh()
        end
    end)
    cb6:ClearAllPoints()
    cb6:SetPoint("TOPLEFT", 286, y)
    y = y - 26

    CreateCheckbox(panel, L.SETTINGS_HIDE_PENDING, L.SETTINGS_HIDE_PENDING_DESC, "hidePending", y, function()
        if ns.RollTrackerFrame then
            ns.RollTrackerFrame:Refresh()
        end
    end)

    local UpdateAnchorDisplay
    local moveWinBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    moveWinBtn:SetSize(130, 24)
    moveWinBtn:SetPoint("TOPLEFT", 290, y - 1)
    moveWinBtn:SetText(L.SETTINGS_MOVE_BTN)
    moveWinBtn:SetScript("OnClick", function()
        if ns.RollTrackerFrame and ns.RollTrackerFrame.ToggleMoveMode then
            ns.RollTrackerFrame:ToggleMoveMode()
        end
    end)

    local resetPosBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetPosBtn:SetSize(130, 24)
    resetPosBtn:SetPoint("LEFT", moveWinBtn, "RIGHT", 8, 0)
    resetPosBtn:SetText(L.SETTINGS_RESET_POS_BTN)
    resetPosBtn:SetScript("OnClick", function()
        ns.db.freePosition = nil
        ns.db.anchorSide = "RIGHT"
        if UpdateAnchorDisplay then
            UpdateAnchorDisplay("RIGHT")
        end
        if ns.MultiItemManager then
            ns.MultiItemManager:UpdateAnchoring()
        end
        ns:Print(L.MSG_POS_RESET)
    end)

    y = y - 34

    -- Row 1: Choice Column Display (Left) & Auto-Close Window (Right)
    local CHOICE_OPTIONS = {
        { value = "ICONS", text = L.SETTINGS_CHOICE_ICONS },
        { value = "TEXT",  text = L.SETTINGS_CHOICE_TEXT },
        { value = "BOTH",  text = L.SETTINGS_CHOICE_BOTH },
    }
    CreateDropdown(
        panel,
        "ClearLootChoiceDropDown",
        L.SETTINGS_CHOICE_DISPLAY,
        L.SETTINGS_CHOICE_DISPLAY_DESC,
        20,
        y,
        210,
        CHOICE_OPTIONS,
        "choiceDisplay",
        "ICONS",
        function()
            if ns.RollTrackerFrame then
                ns.RollTrackerFrame:Refresh()
            end
        end
    )

    local AUTO_CLOSE_OPTIONS = {
        { value = 3,  text = L.SETTINGS_AUTO_CLOSE_3S },
        { value = 5,  text = L.SETTINGS_AUTO_CLOSE_5S },
        { value = 10, text = L.SETTINGS_AUTO_CLOSE_10S },
        { value = 15, text = L.SETTINGS_AUTO_CLOSE_15S },
        { value = 0,  text = L.SETTINGS_AUTO_CLOSE_NEVER },
    }
    CreateDropdown(
        panel,
        "ClearLootAutoCloseDropDown",
        L.SETTINGS_AUTO_CLOSE,
        L.SETTINGS_AUTO_CLOSE_DESC,
        290,
        y,
        210,
        AUTO_CLOSE_OPTIONS,
        "autoCloseDelay",
        5,
        function()
            if ns.DataTracker and ns.DataTracker.TriggerAutoCloseForCompletedRolls then
                ns.DataTracker:TriggerAutoCloseForCompletedRolls()
            end
        end
    )

    y = y - 56

    -- Row 2: Window Anchor Position (Left) & Color Theme (Right)
    local ANCHOR_OPTIONS = {
        { value = "RIGHT", text = L.SETTINGS_ANCHOR_RIGHT },
        { value = "LEFT",  text = L.SETTINGS_ANCHOR_LEFT },
        { value = "FREE",  text = L.SETTINGS_ANCHOR_FREE },
    }
    _, UpdateAnchorDisplay = CreateDropdown(
        panel,
        "ClearLootAnchorDropDown",
        L.SETTINGS_ANCHOR_SIDE,
        L.SETTINGS_ANCHOR_SIDE_DESC,
        20,
        y,
        210,
        ANCHOR_OPTIONS,
        "anchorSide",
        "RIGHT",
        function()
            if ns.MultiItemManager then
                ns.MultiItemManager:UpdateAnchoring()
            end
        end
    )

    local THEME_OPTIONS = {
        { value = "FOREVER",    text = L.SETTINGS_THEME_FOREVER or "Classic Forever (Bronze - Default)" },
        { value = "CLASSIC",    text = L.SETTINGS_THEME_CLASSIC or "Classic" },
        { value = "MINIMALIST", text = L.SETTINGS_THEME_MINIMALIST or "Minimalist (Flat Dark)" },
        { value = "ELLESMERE",  text = L.SETTINGS_THEME_ELLESMERE or "EllesmereUI" },
        { value = "FLARE",      text = L.SETTINGS_THEME_FLARE or "FlareUI" },
    }
    CreateDropdown(
        panel,
        "ClearLootThemeDropDown",
        L.SETTINGS_THEME or "Color Theme",
        L.SETTINGS_THEME_DESC,
        290,
        y,
        210,
        THEME_OPTIONS,
        "theme",
        "FOREVER",
        function()
            if ns.RollTrackerFrame and ns.RollTrackerFrame.ApplyTheme then
                ns.RollTrackerFrame:ApplyTheme()
            end
        end
    )

    y = y - 58

    -- Row 3: Window Opacity Slider (Left) & Window Scale Slider (Right)
    CreatePercentSlider(
        panel,
        "ClearLootOpacitySlider",
        L.SETTINGS_OPACITY,
        L.SETTINGS_OPACITY_DESC,
        20,
        y,
        20,
        100,
        5,
        "windowOpacity",
        100,
        function()
            if ns.RollTrackerFrame and ns.RollTrackerFrame.UpdateOpacity then
                ns.RollTrackerFrame:UpdateOpacity()
            end
        end
    )

    CreatePercentSlider(
        panel,
        "ClearLootScaleSlider",
        L.SETTINGS_SCALE,
        L.SETTINGS_SCALE_DESC,
        290,
        y,
        60,
        160,
        5,
        "windowScale",
        100,
        function()
            if ns.RollTrackerFrame and ns.RollTrackerFrame.UpdateScale then
                ns.RollTrackerFrame:UpdateScale()
            end
        end
    )

    y = y - 56

    -- Row 4: Random Rolls (/roll 1-100) Section
    local randomDivider = panel:CreateTexture(nil, "ARTWORK")
    randomDivider:SetHeight(1)
    randomDivider:SetPoint("TOPLEFT", 18, y + 6)
    randomDivider:SetPoint("TOPRIGHT", -18, y + 6)
    randomDivider:SetColorTexture(0.5, 0.5, 0.5, 0.25)

    local randomHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    randomHeader:SetPoint("TOPLEFT", 20, y - 4)
    randomHeader:SetText(L.SETTINGS_RANDOM_HEADER or "Random Rolls (/roll 1-100)")

    y = y - 24

    CreateCheckbox(panel, L.SETTINGS_RANDOM_ENABLE, L.SETTINGS_RANDOM_ENABLE_DESC, "trackRandomRolls", y)
    y = y - 26

    CreateCheckbox(panel, L.SETTINGS_RANDOM_SOLO, L.SETTINGS_RANDOM_SOLO_DESC, "trackSoloRandomRolls", y)

    local RANDOM_TIMEOUT_OPTIONS = {
        { value = 15, text = L.SETTINGS_RANDOM_TIMEOUT_15S or "15 Seconds" },
        { value = 20, text = L.SETTINGS_RANDOM_TIMEOUT_20S or "20 Seconds" },
        { value = 30, text = L.SETTINGS_RANDOM_TIMEOUT_30S or "30 Seconds (Default)" },
        { value = 45, text = L.SETTINGS_RANDOM_TIMEOUT_45S or "45 Seconds" },
        { value = 60, text = L.SETTINGS_RANDOM_TIMEOUT_60S or "60 Seconds" },
    }
    CreateDropdown(
        panel,
        "ClearLootRandomTimeoutDropDown",
        L.SETTINGS_RANDOM_TIMEOUT or "Random Roll Timeout",
        L.SETTINGS_RANDOM_TIMEOUT_DESC,
        290,
        y + 20,
        210,
        RANDOM_TIMEOUT_OPTIONS,
        "randomRollTimeout",
        30
    )

    y = y - 42

    -- Row 5: Solo Testing & Simulation Section
    local testDivider = panel:CreateTexture(nil, "ARTWORK")
    testDivider:SetHeight(1)
    testDivider:SetPoint("TOPLEFT", 18, y + 6)
    testDivider:SetPoint("TOPRIGHT", -18, y + 6)
    testDivider:SetColorTexture(0.5, 0.5, 0.5, 0.25)

    local testHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    testHeader:SetPoint("TOPLEFT", 20, y - 4)
    testHeader:SetText(L.SETTINGS_TEST_HEADER)

    y = y - 24

    local testSingleBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testSingleBtn:SetSize(130, 26)
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
    testMultiBtn:SetSize(130, 26)
    testMultiBtn:SetPoint("LEFT", testSingleBtn, "RIGHT", 8, 0)
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
    testRaidBtn:SetSize(130, 26)
    testRaidBtn:SetPoint("LEFT", testMultiBtn, "RIGHT", 8, 0)
    testRaidBtn:SetText(L.SETTINGS_TEST_RAID_BTN)
    testRaidBtn:SetScript("OnClick", function()
        if ns.Simulator then
            local ok, err = pcall(ns.Simulator.StartRaidTest, ns.Simulator, 40)
            if not ok then
                ns:Print("|cffff4444Simulation error:|r " .. tostring(err))
            end
        end
    end)

    local testRandomBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testRandomBtn:SetSize(130, 26)
    testRandomBtn:SetPoint("LEFT", testRaidBtn, "RIGHT", 8, 0)
    testRandomBtn:SetText(L.SETTINGS_TEST_RANDOM_BTN or "Test /roll (1-100)")
    testRandomBtn:SetScript("OnClick", function()
        if ns.Simulator and ns.Simulator.StartRandomRollTest then
            local ok, err = pcall(ns.Simulator.StartRandomRollTest, ns.Simulator)
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
