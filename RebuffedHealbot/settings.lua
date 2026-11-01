local addonName, addon = ...
local locale = addon.locale
local panel
local content
local refreshing = false
local controls = {}

local function refresh()
    refreshing = true
    for index = 1, #controls do
        controls[index].refresh()
    end
    refreshing = false
end

local function getValue(key)
    if key == "visible" then
        return not ChronixHealDB.hidden
    elseif key == "scale" or key == "unlocked" then
        return ChronixHealDB[key]
    end
    return addon.config[key]
end

local function createCheckbox(key, label, y)
    local box = CreateFrame("CheckButton", addonName .. "Setting_" .. key, content, "UICheckButtonTemplate")
    box:SetPoint("TOPLEFT", 12, y)
    local text = _G[box:GetName() .. "Text"] or box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", box, "RIGHT", 0, 0)
    text:SetText(locale(label))
    box:SetScript("OnClick", function(self)
        addon.settingsActions.setOption(key, self:GetChecked() and true or false)
        refresh()
    end)
    controls[#controls + 1] = { refresh = function() box:SetChecked(getValue(key)) end }
end

local function createSlider(definition, index)
    local slider = CreateFrame("Slider", addonName .. "Setting_" .. definition.key, content, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 24, -470 - (index - 1) * 58)
    slider:SetWidth(280)
    slider:SetMinMaxValues(definition.minimum, definition.maximum)
    slider:SetValueStep(1)
    local name = slider:GetName()
    _G[name .. "Low"]:SetText(tostring(definition.minimum))
    _G[name .. "High"]:SetText(tostring(definition.maximum))
    local multiplier = definition.multiplier or 1
    slider:SetScript("OnValueChanged", function(self, value)
        if refreshing then
            return
        end
        addon.settingsActions.setOption(definition.key, math.floor(value + 0.5) / multiplier)
        refresh()
    end)
    controls[#controls + 1] = { refresh = function()
        local value = math.floor(getValue(definition.key) * multiplier + 0.5)
        slider:SetValue(value)
        _G[name .. "Text"]:SetText(locale(definition.label, value))
    end }
end

local function createButton(label, x, y, callback)
    local button = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", x, y)
    button:SetSize(125, 22)
    button:SetText(locale(label))
    button:SetScript("OnClick", function()
        callback()
        refresh()
    end)
    return button
end

local function createSpellSelector(index, binding, y)
    local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 20, y - 6)
    label:SetText(locale(binding.label))
    local dropdown = CreateFrame("Frame", addonName .. "BindingSelector" .. index, content, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", 145, y + 2)
    UIDropDownMenu_SetWidth(dropdown, 190)
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local empty = UIDropDownMenu_CreateInfo()
        empty.text = locale("STR_BINDING_UNASSIGNED")
        empty.checked = not addon.settingsActions.getBindingSpell(index)
        empty.func = function()
            addon.settingsActions.setBindingSpell(index, 0)
            refresh()
        end
        UIDropDownMenu_AddButton(empty, level)
        local options = addon.settingsActions.getBindingOptions()
        for optionIndex = 1, #options do
            local option = options[optionIndex]
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.name
            info.icon = option.icon
            local selected = addon.settingsActions.getBindingSpell(index)
            info.checked = selected and selected.id == option.id or false
            info.func = function()
                addon.settingsActions.setBindingSpell(index, option.id)
                refresh()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    controls[#controls + 1] = { refresh = function()
        local spell = addon.settingsActions.getBindingSpell(index)
        UIDropDownMenu_SetText(dropdown, spell and spell.name or locale("STR_BINDING_UNASSIGNED"))
    end }
end

function addon.createSettings()
    if panel then
        return
    end
    panel = CreateFrame("Frame", addonName .. "Settings", UIParent)
    panel.name = locale("STR_TITLE")
    panel:Hide()
    InterfaceOptions_AddCategory(panel, true)

    local scroll = CreateFrame("ScrollFrame", addonName .. "SettingsScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -8)
    scroll:SetPoint("BOTTOMRIGHT", -30, 8)
    content = CreateFrame("Frame", addonName .. "SettingsContent", scroll)
    content:SetSize(360, 1360)
    scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local offset = math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * 40))
        self:SetVerticalScroll(offset)
    end)
    scroll:SetScript("OnSizeChanged", function(self, width)
        content:SetWidth(math.max(1, width))
    end)

    local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(locale("STR_SETTINGS"))
    local description = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", 16, -44)
    description:SetPoint("TOPRIGHT", -16, -44)
    description:SetJustifyH("LEFT")
    description:SetText(locale("STR_SETTINGS_DESCRIPTION"))

    for index = 1, #addon.config.modeOrder do
        local key = addon.config.modeOrder[index]
        local button = createButton(addon.config.modes[key].label, 16 + (index - 1) * 110, -82, function()
            addon.settingsActions.setMode(key)
        end)
        button:SetWidth(105)
    end

    createCheckbox("visible", "STR_SETTING_VISIBLE", -112)
    createCheckbox("unlocked", "STR_SETTING_UNLOCKED", -144)
    createCheckbox("recommendFocusBuffs", "STR_SETTING_FOCUS", -176)
    createCheckbox("recommendGroupHeals", "STR_SETTING_GROUP", -208)
    createCheckbox("recommendCooldowns", "STR_SETTING_COOLDOWNS", -240)

    local sliders = {
        { key = "scale", label = "STR_SETTING_SCALE", minimum = 60, maximum = 180, multiplier = 100 },
        { key = "width", label = "STR_SETTING_WIDTH", minimum = 128, maximum = 220 },
        { key = "height", label = "STR_SETTING_HEIGHT", minimum = 50, maximum = 80 },
        { key = "healthBarHeight", label = "STR_SETTING_BAR", minimum = 6, maximum = 16 },
        { key = "minimumDeficit", label = "STR_SETTING_DEFICIT", minimum = 1, maximum = 25, multiplier = 100 },
        { key = "lowMana", label = "STR_SETTING_MANA", minimum = 10, maximum = 60, multiplier = 100 },
    }
    for index = 1, #sliders do
        createSlider(sliders[index], index)
    end

    createButton("STR_SETTING_RESET_POSITION", 16, -280, addon.settingsActions.resetPosition)
    createButton("STR_SETTING_PREVIEW", 151, -280, addon.settingsActions.preview)
    local restore = createButton("STR_SETTING_RESTORE", 16, -311, addon.settingsActions.restoreGrid)
    restore:SetWidth(260)
    local hint = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 16, -347)
    hint:SetPoint("TOPRIGHT", -16, -347)
    hint:SetJustifyH("LEFT")
    hint:SetText(locale("STR_SETTINGS_HINT"))
    local bindingTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bindingTitle:SetPoint("TOPLEFT", 16, -802)
    bindingTitle:SetText(locale("STR_BINDINGS_TITLE"))
    local bindingHint = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bindingHint:SetPoint("TOPLEFT", 16, -824)
    bindingHint:SetPoint("TOPRIGHT", -16, -824)
    bindingHint:SetHeight(24)
    bindingHint:SetJustifyH("LEFT")
    bindingHint:SetText(locale("STR_BINDINGS_HINT"))
    local bindingList = addon.settingsActions.getBindings()
    for index = 1, #bindingList do
        createSpellSelector(index, bindingList[index], -850 - (index - 1) * 33)
    end
    panel:SetScript("OnShow", refresh)
end

function addon.openSettings()
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
end
