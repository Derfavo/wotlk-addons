local addonName, addon = ...
local config = addon.config
local locale = addon.locale
local floor = math.floor
local min = math.min
local max = math.max
local spells = {}
local buttons = {}
local resurrectionSpell
local combatResurrectionSpell
local outOfManaNotified = false
local previewButtons = {}
local initialized = false
local elapsedUpdate = 0
local pendingSpells = false
local pendingLayout = false
local preview = false
local dragging = false
local root
local title
local manaLabel
local modeLabel
local modeButtons = {}
local available = {}
local spellCatalog = {}
local rosterGroups = {}
local injuredGroups = {}
local injuredTotal = 0
local criticalTotal = 0
local criticalGroups = {}
local anyDanger = false
local tankGuid
local tankGuids = {}
local mendingActive = false
local playerContext = {}
local bubbleLockUntil = 0
local selfKeys = { defensive = true, channel = true, mana = true }
local blockedNames = {}
local auraSpellNames = {}
local function auraSpellName(id)
    local name = auraSpellNames[id]
    if not name then
        name = GetSpellInfo(id)
        auraSpellNames[id] = name
    end
    return name
end
local groupRoles = {}
local rolesDirty = true

local bindings = {
    { id = "left", key = "lesser", button = "1", prefix = "", label = "STR_LEFT" },
    { id = "right", key = "wave", button = "2", prefix = "", label = "STR_RIGHT" },
    { id = "middle", key = "riptide", button = "3", prefix = "", label = "STR_MIDDLE" },
    { id = "shiftLeft", key = "chain", button = "1", prefix = "shift-", label = "STR_SHIFT_LEFT" },
    { id = "ctrlLeft", key = "cleanse", button = "1", prefix = "ctrl-", label = "STR_CTRL_LEFT" },
    { id = "ctrlRight", key = "toxins", button = "2", prefix = "ctrl-", label = "STR_CTRL_RIGHT" },
    { id = "altLeft", key = "earth", button = "1", prefix = "alt-", label = "STR_ALT_LEFT" },
    { id = "shiftRight", key = "naturewave", button = "2", prefix = "shift-", label = "STR_SHIFT_RIGHT" },
    { id = "altRight", key = "special", button = "2", prefix = "alt-", label = "STR_ALT_RIGHT" },
    { id = "ctrlMiddle", key = "mending", button = "3", prefix = "ctrl-", label = "STR_CTRL_MIDDLE" },
    { id = "shiftMiddle", key = "area", button = "3", prefix = "shift-", label = "STR_SHIFT_MIDDLE" },
    { id = "altMiddle", key = "defensive", button = "3", prefix = "alt-", label = "STR_ALT_MIDDLE" },
    { id = "ctrlShiftLeft", key = "channel", button = "1", prefix = "ctrl-shift-", label = "STR_CTRL_SHIFT_LEFT" },
    { id = "ctrlShiftRight", key = "mana", button = "2", prefix = "ctrl-shift-", label = "STR_CTRL_SHIFT_RIGHT" },
}

local function printMessage(key)
    DEFAULT_CHAT_FRAME:AddMessage("|cff57c8ff" .. locale("STR_TITLE") .. "|r: " .. locale(key))
end

local function updateModeLabel()
    if not modeLabel then
        return
    end
    modeLabel:SetText(locale(addon.getMode().label))

    for index = 1, #modeButtons do
        local button = modeButtons[index]
        if button.mode == addon.mode then
            button:SetBackdropColor(0.08, 0.4, 0.65, 0.95)
        else
            button:SetBackdropColor(0.05, 0.08, 0.12, 0.5)
        end
    end
end

local function findBinding(key)
    for index = 1, #bindings do
        if bindings[index].key == key then
            return bindings[index]
        end
    end
end

local function getSpell(key)
    local binding = findBinding(key)
    if binding and ChronixHealDB and ChronixHealDB.bindings then
        local spellId = ChronixHealDB.bindings[binding.id]
        if spellId ~= nil then
            return spellId ~= 0 and spellCatalog[spellId] or nil
        end
    end
    return spells[key]
end

local function spellLabel(key)
    if key == "lesser" and not addon.profile.healer then
        return locale("STR_TARGET")
    end

    if key == "naturewave" then
        local assigned = getSpell(key)
        if assigned then return assigned.name end
        return spells.nature and spells.wave and locale("STR_COMBO", spells.nature.name, spells.wave.name)
            or (spells.emergency and spells.emergency.name or locale("STR_NONE"))
    end

    local spell = getSpell(key)
    return spell and spell.name or locale("STR_NONE")
end

local function refreshSpells()
    if InCombatLockdown() then
        pendingSpells = true
        return
    end

    addon.selectProfile(addon.class, addon.detectSpec(addon.class))
    for key in pairs(available) do
        available[key] = nil
    end
    for index = 1, #config.blockedDispelIds do
        local name = GetSpellInfo(config.blockedDispelIds[index])
        if name then blockedNames[name] = true end
    end
    local learned = {}

    for tab = 1, GetNumSpellTabs() do
        local tabName, texture, offset, count = GetSpellTabInfo(tab)

        for index = offset + 1, offset + count do
            local name = GetSpellName(index, BOOKTYPE_SPELL)

            if name then
                learned[name] = true
            end
        end
    end

    local function findKnownSpell(candidates)
        for index = 1, #(candidates or {}) do
            local baseName = GetSpellInfo(candidates[index])
            if baseName and learned[baseName] then
                local name, rank, icon = GetSpellInfo(baseName)
                return { id = candidates[index], name = name, icon = icon }
            end
        end
    end

    resurrectionSpell = findKnownSpell(addon.profile.resurrection)
    combatResurrectionSpell = findKnownSpell(addon.profile.combatResurrection)

    for key in pairs(spells) do
        spells[key] = nil
    end

    for id in pairs(spellCatalog) do
        spellCatalog[id] = nil
    end

    local baseSpells = {}

    for key, candidates in pairs(addon.profile.spells) do
        for candidate = 1, #candidates do
            local id = candidates[candidate]
            local baseName = GetSpellInfo(id)

            if baseName and learned[baseName] then
                local name, rank, icon, cost, funnel, powerType, castTime = GetSpellInfo(baseName)
                local spell = {
                    id = id,
                    name = name,
                    icon = icon,
                    cost = cost or 0,
                    castTime = (castTime or 0) / 1000,
                    dispels = addon.profile.dispels[id],
                }
                baseSpells[key] = spell
                spellCatalog[id] = spell
                break
            end
        end
    end

    for _, candidates in pairs(addon.profile.spells) do
        for candidate = 1, #candidates do
            local id = candidates[candidate]
            local baseName = GetSpellInfo(id)
            if baseName and learned[baseName] and not spellCatalog[id] then
                local name, rank, icon, cost, funnel, powerType, castTime = GetSpellInfo(baseName)
                spellCatalog[id] = { id = id, name = name, icon = icon, cost = cost or 0,
                    castTime = (castTime or 0) / 1000, dispels = addon.profile.dispels[id] }
            end
        end
    end

    for key, spell in pairs(baseSpells) do
        spells[key] = spell
    end

    for index = 1, #bindings do
        local binding = bindings[index]
        local spellId = ChronixHealDB.bindings and ChronixHealDB.bindings[binding.id]
        if spellId ~= nil then
            spells[binding.key] = spellId ~= 0 and spellCatalog[spellId] or nil
        end
    end

    for index = 1, #buttons do
        local button = buttons[index]
        button.auraDirty = true

        for bindingIndex = 1, #bindings do
            local binding = bindings[bindingIndex]
            local suffix = binding.button
            local prefix = binding.prefix
            local spell = getSpell(binding.key)
            button:SetAttribute(prefix .. "type" .. suffix, "none")
            button:SetAttribute(prefix .. "spell" .. suffix, nil)
            button:SetAttribute(prefix .. "macrotext" .. suffix, nil)
            button:SetAttribute(prefix .. "unit" .. suffix, nil)

            if binding.id == "left" and resurrectionSpell then
                local castOptions = {}
                local unitTarget = "@" .. button.unit
                if combatResurrectionSpell and resurrectionSpell then
                    table.insert(castOptions, "[combat," .. unitTarget .. ",help,dead] " .. combatResurrectionSpell.name)
                elseif combatResurrectionSpell then
                    table.insert(castOptions, "[" .. unitTarget .. ",help,dead] " .. combatResurrectionSpell.name)
                end
                if resurrectionSpell then
                    table.insert(castOptions, "[" .. unitTarget .. ",help,dead] " .. resurrectionSpell.name)
                end
                if spell then
                    table.insert(castOptions, "[" .. unitTarget .. ",help,nodead] " .. spell.name)
                end
                button:SetAttribute("type" .. suffix, "macro")
                button:SetAttribute("macrotext" .. suffix, "/cast " .. table.concat(castOptions, "; "))
            elseif binding.key == "naturewave" and (not ChronixHealDB.bindings or ChronixHealDB.bindings[binding.id] == nil) then
                if spells.nature and spells.wave then
                    button:SetAttribute(prefix .. "type" .. suffix, "macro")
                    button:SetAttribute(prefix .. "macrotext" .. suffix,
                        "/cast [@" .. button.unit .. ",help,nodead] " .. spells.nature.name .. "\n/cast [@" .. button.unit
                        .. ",help,nodead] " .. spells.wave.name)
                elseif spells.emergency then
                    button:SetAttribute(prefix .. "type" .. suffix, "spell")
                    button:SetAttribute(prefix .. "spell" .. suffix, spells.emergency.name)
                end
            elseif binding.key == "lesser" and not addon.profile.healer and not spell
                and (not ChronixHealDB.bindings or ChronixHealDB.bindings[binding.id] == nil) then
                button:SetAttribute(prefix .. "type" .. suffix, "target")
            elseif spell then
                button:SetAttribute(prefix .. "type" .. suffix, "spell")
                button:SetAttribute(prefix .. "spell" .. suffix, spell.name)
                if selfKeys[binding.key] then
                    button:SetAttribute(prefix .. "unit" .. suffix, "player")
                end
            end
        end
    end

    pendingSpells = false
end

local function updateAvailability()
    for key, spell in pairs(spells) do
        local usable, noMana = IsUsableSpell(spell.name)
        local start, duration, enabled = GetSpellCooldown(spell.name)
        local cooldown = enabled == 0 or (duration and duration > 1.5 and start + duration > GetTime())
        available[key] = usable and not noMana and not cooldown and true or false
    end

    for key in pairs(addon.profile.spells) do
        if not spells[key] then
            available[key] = false
        end
    end
end

local healingKeys = { "lesser", "wave", "riptide", "chain", "emergency", "special", "mending", "area", "channel" }

local function hasUsableHealingSpell()
    if not addon.profile.healer then
        return false
    end

    for index = 1, #healingKeys do
        local candidates = addon.profile.spells[healingKeys[index]]
        for candidate = 1, #(candidates or {}) do
            local spell = spellCatalog[candidates[candidate]]
            if spell then
                local usable, noMana = IsUsableSpell(spell.name)
                local start, duration, enabled = GetSpellCooldown(spell.name)
                local cooldown = enabled == 0 or duration and duration > 1.5 and start + duration > GetTime()
                if usable and not noMana and not cooldown then
                    return true
                end
            end
        end
    end

    return false
end

local function updateManaWarning()
    local maximumMana = UnitPowerMax("player", 0)
    local mana = UnitPower("player", 0)
    playerContext.outOfMana = addon.profile.healer and maximumMana > 0 and mana < 2000
        and not hasUsableHealingSpell()
    if GetNumPartyMembers() == 0 and GetNumRaidMembers() == 0 then
        outOfManaNotified = false
        return
    end
    if playerContext.outOfMana and not outOfManaNotified then
        if SendChatMessage then
            SendChatMessage(locale("STR_OUT_OF_MANA_CHAT"), "YELL")
        else
            DEFAULT_CHAT_FRAME:AddMessage(locale("STR_OUT_OF_MANA_CHAT"))
        end
        outOfManaNotified = true
    elseif not playerContext.outOfMana then
        outOfManaNotified = false
    end
end

local function readAuras(button)
    local state = button.state
    state.poison = false
    state.disease = false
    state.curse = false
    state.magic = false
    state.riptide = false
    state.earth = false
    state.chainAura = false
    state.regrowth = false
    state.weakenedSoul = false
    state.forbearance = false
    state.blockedDispel = false
    state.blockedTypes = {}
    state.auras = {}
    state.defensiveActive = false
    state.manaActive = false
    state.emergencyActive = false
    button.debuffIcon:Hide()
    local debuffIcon
    local dispellable = false

    for index = 1, 40 do
        local name, rank, icon, count, kind = UnitDebuff(button.unit, index)

        if not name then
            break
        end

        local canDispel = false
        if blockedNames[name] and kind then
            state.blockedTypes[kind] = true
            state.blockedDispel = true
        end
        if name == auraSpellName(25771) then
            state.forbearance = true
        end

        if kind == "Poison" then
            state.poison = true
        elseif kind == "Disease" then
            state.disease = true
        elseif kind == "Curse" then
            state.curse = true
        elseif kind == "Magic" then
            state.magic = true
        end

        for key, spell in pairs(spells) do
            if spell.dispels and spell.dispels[kind] then
                canDispel = true
            end
        end

        if name == auraSpellName(6788) then
            state.weakenedSoul = true
        end

        if canDispel and not dispellable then
            debuffIcon = icon
            dispellable = true
        elseif not debuffIcon and kind then
            debuffIcon = icon
        end
    end

    for index = 1, 40 do
        local name, rank, icon, count, kind, duration, expiration, caster = UnitBuff(button.unit, index)

        if not name then
            break
        end

        local own = caster and UnitIsUnit(caster, "player") and true or false
        for key, spell in pairs(spells) do
            if name == spell.name then
                local existing = state.auras[key]
                if not existing or own then
                    state.auras[key] = { own = own, expires = expiration or 0, count = count or 0, icon = icon }
                end
            end
        end
        if spells.defensive and name == spells.defensive.name then state.defensiveActive = true end
        if spells.mana and name == spells.mana.name then state.manaActive = true end
        if spells.emergency and name == spells.emergency.name then state.emergencyActive = true end
        if spells.riptide and name == spells.riptide.name and own then
            state.riptide = true
        end

        if spells.earth and name == spells.earth.name then
            state.earth = true
        end

        if spells.chain and name == spells.chain.name then
            state.chainAura = true
        end

        if name == auraSpellName(8936) then
            state.regrowth = true
        end
    end

    if debuffIcon then
        button.debuffIcon:SetTexture(debuffIcon)
        button.debuffIcon:Show()
    end

    button.dispellable = dispellable
    button.auraDirty = false
end

local statusKeys = { "earth", "chain", "riptide", "mending", "special", "defensive", "emergency" }

-- Shared immutable labels: do not rebuild five tables per aura slot and unit.
local auraLabels = {
        SHAMAN = { earth = "STR_BUFF_EARTH_SHIELD", riptide = "STR_BUFF_RIPTIDE" },
        PALADIN = { earth = "STR_BUFF_SACRED_SHIELD", chain = "STR_BUFF_BEACON", defensive = "STR_BUFF_BUBBLE" },
        PRIEST = { earth = "STR_BUFF_POWER_WORD_SHIELD", riptide = "STR_BUFF_RENEW", mending = "STR_BUFF_PRAYER_MENDING", emergency = "STR_BUFF_GUARDIAN" },
        DRUID = { earth = "STR_BUFF_REJUVENATION", mending = "STR_BUFF_LIFEBLOOM", special = "STR_BUFF_REGROWTH", defensive = "STR_BUFF_BARKSKIN" },
}

local function auraLabel(key)
    return auraLabels[addon.class] and auraLabels[addon.class][key]
end

local function auraTime(entry, now)
    if not entry.expires or entry.expires == 0 then
        return locale("STR_BUFF_ACTIVE")
    end
    local remaining = math.max(0, math.ceil(entry.expires - now))
    if remaining >= 60 then
        return locale("STR_BUFF_MINUTES", math.ceil(remaining / 60))
    end
    return locale("STR_BUFF_SECONDS", remaining)
end

local function getOwnAuraEntries(state, now, entries)
    entries = entries or {}
    local count = 0
    for index = 1, #statusKeys do
        local key = statusKeys[index]
        local entry = state.auras and state.auras[key]
        if entry and entry.own and (entry.expires == 0 or entry.expires > now) then
            local label = auraLabel(key)
            if label then
                count = count + 1
                local display = entries[count] or {}
                entries[count] = display
                display.key = key
                display.label = locale(label)
                display.count = entry.count or 0
                display.icon = entry.icon or spells[key] and spells[key].icon
                display.remaining = auraTime(entry, now)
            end
        end
    end
    for index = #entries, count + 1, -1 do entries[index] = nil end
    return entries
end

local function updateAuraStatus(button, now)
    local entries = getOwnAuraEntries(button.state, now, button.statusEntries)
    for index = 1, #button.auraSlots do
        local slot = button.auraSlots[index]
        local entry = entries[index]
        if entry then
            slot.texture:SetTexture(entry.icon)
            slot.counter:SetText(entry.count > 0 and tostring(entry.count) or "")
            slot.timer:SetText(entry.remaining)
            slot:Show()
        else
            slot.texture:SetTexture(nil)
            slot.counter:SetText("")
            slot.timer:SetText("")
            slot:Hide()
        end
    end
    if #entries > #button.auraSlots then
        button.auraOverflow:SetText("+" .. tostring(#entries - #button.auraSlots))
        button.auraOverflow:Show()
    else
        button.auraOverflow:SetText("")
        button.auraOverflow:Hide()
    end
    button.statusEntries = entries
end

local function showTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:AddLine(UnitName(button.unit) or locale("STR_TITLE"), 1, 1, 1)
    GameTooltip:AddLine(locale("STR_HEALTH", button.state.health or 0, button.state.maximum or 0))
    GameTooltip:AddLine(locale("STR_LOSS", button.state.loss or 0))
    GameTooltip:AddLine(locale("STR_BUFF_HEADER"), 0.7, 1, 0.8)
    for _, entry in ipairs(getOwnAuraEntries(button.state, GetTime())) do
        local value = entry.count > 0 and locale("STR_BUFF_STACKS", entry.count) or entry.remaining
        GameTooltip:AddDoubleLine(entry.label, value, 0.7, 1, 0.8, 1, 1, 1)
    end
    if not button.statusEntries or #button.statusEntries == 0 then
        GameTooltip:AddLine(locale("STR_BUFF_NONE"), 0.65, 0.65, 0.65)
    end
    GameTooltip:AddLine(locale("STR_PROFILE", locale("STR_SPEC_" .. string.upper(addon.profile.spec))), 0.7, 0.8, 1)
    if button.state.tank then GameTooltip:AddLine(locale("STR_TANK_BUFF_TARGET"), 0.4, 1, 0.7) end
    if button.state.role == "TANK" then GameTooltip:AddLine(locale("STR_ROLE_TANK"), 0.4, 1, 0.7) end
    if button.state.healer then GameTooltip:AddLine(locale("STR_ROLE_HEALER"), 0.4, 0.9, 1) end
    if resurrectionSpell then
        GameTooltip:AddDoubleLine(locale("STR_RESURRECTION"), resurrectionSpell.name, 0.7, 0.8, 0.9, 1, 1, 1)
    end
    if button.state.blockedDispel then GameTooltip:AddLine(locale("STR_DISPEL_CAUTION"), 1, 0.5, 0.2, true) end

    if button.recommendation then
        GameTooltip:AddLine(locale("STR_RECOMMENDATION", spellLabel(button.recommendation)), 0.4, 0.9, 1)
        local binding = findBinding(button.recommendation)

        if binding then
            GameTooltip:AddLine(locale("STR_BINDING", locale(binding.label)), 1, 0.85, 0.3)
        end
    end

    GameTooltip:AddLine(" ")

    for index = 1, #bindings do
        local binding = bindings[index]
        local spell = getSpell(binding.key)
        local defaultCombo = binding.key == "naturewave" and spells.nature and spells.wave
        if spell or defaultCombo then
            GameTooltip:AddDoubleLine(locale(binding.label), spellLabel(binding.key), 0.7, 0.8, 0.9, 1, 1, 1)
        end
    end

    if button.state.magic then
        GameTooltip:AddLine(locale("STR_MAGIC_TYPE"), 0.6, 0.7, 1)
    end

    if button.state.curse then
        GameTooltip:AddLine(locale("STR_CURSE"), 0.8, 0.5, 1)
    end

    if button.state.poison then
        GameTooltip:AddLine(locale("STR_POISON"), 0.3, 1, 0.3)
    end

    if button.state.disease then
        GameTooltip:AddLine(locale("STR_DISEASE"), 0.8, 0.6, 0.2)
    end

    if (button.recommendation == "chain" or button.recommendation == "area" or button.recommendation == "channel") and addon.profile.groupHeal then
        GameTooltip:AddLine(locale("STR_GROUP_HEAL_HINT", button.state.injuredCount or 0), 0.4, 0.9, 1, true)
    end

    GameTooltip:AddLine(locale("STR_TOOLTIP_HINT"), 0.7, 0.7, 0.7, true)
    GameTooltip:AddLine(locale("STR_MODIFIERS"), 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
end

local function createVisuals(button)
    button:SetSize(config.width, config.height)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    button:SetBackdropColor(0.045, 0.065, 0.09, 0.96)
    button:SetBackdropBorderColor(0.2, 0.3, 0.4, 1)
    button.health = CreateFrame("StatusBar", nil, button)
    button.health:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    button.health:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    button.health:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    button.nameText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.nameText:SetPoint("TOPLEFT", 29, -3)
    button.nameText:SetWidth(config.width - 53)
    button.nameText:SetHeight(10)
    button.nameText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    button.nameText:SetJustifyH("LEFT")
    button.nameText:SetTextColor(1, 1, 1)
    button.healthText = button.health:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.healthText:SetPoint("CENTER", 0, 0)
    button.healthText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    button.healthText:SetTextColor(1, 1, 1)
    button.icon = button:CreateTexture(nil, "OVERLAY")
    button.icon:SetSize(14, 14)
    button.icon:SetPoint("TOPRIGHT", -4, -4)
    button.tankRoleIcon = button:CreateTexture(nil, "OVERLAY")
    button.tankRoleIcon:SetSize(12, 12)
    button.tankRoleIcon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -2)
    button.healerRoleIcon = button:CreateTexture(nil, "OVERLAY")
    button.healerRoleIcon:SetSize(12, 12)
    button.healerRoleIcon:SetPoint("TOPLEFT", button.tankRoleIcon, "TOPRIGHT", 1, 0)
    button.actionText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.actionText:SetPoint("TOPLEFT", 4, -14)
    button.actionText:SetWidth(config.width - 8)
    button.actionText:SetHeight(8)
    button.actionText:SetJustifyH("LEFT")
    button.auraSlots = {}
    for index = 1, 6 do
        local slot = CreateFrame("Frame", nil, button)
        slot:SetSize(20, 26)
        slot:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 4 + (index - 1) * 20, 2)
        slot.texture = slot:CreateTexture(nil, "ARTWORK")
        slot.texture:SetSize(18, 18)
        slot.texture:SetPoint("TOP", 0, -1)
        slot.counter = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        slot.counter:SetPoint("TOPRIGHT", 0, 0)
        slot.counter:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
        slot.counter:SetTextColor(1, 0.9, 0.35)
        slot.timer = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        slot.timer:SetPoint("BOTTOM", 0, 0)
        slot.timer:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        slot.timer:SetTextColor(1, 1, 1)
        slot:Hide()
        button.auraSlots[index] = slot
    end
    button.auraOverflow = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.auraOverflow:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 124, 8)
    button.auraOverflow:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    button.auraOverflow:SetTextColor(0.85, 0.9, 1)
    button.auraOverflow:Hide()
    button.debuffIcon = button.health:CreateTexture(nil, "OVERLAY")
    button.debuffIcon:SetSize(config.healthBarHeight, config.healthBarHeight)
    button.debuffIcon:SetPoint("RIGHT", -1, 0)
    button.state = {}
    button.history = {}
    button.auraDirty = true
end

local function positionButton(button, index)
    local column = floor((index - 1) / config.rows)
    local row = (index - 1) % config.rows
    button:SetPoint("TOPLEFT", root, "TOPLEFT",
        8 + column * (config.width + config.gap), -40 - row * (config.height + config.gap))
end

local function createUnitButton(unit, index, condition)
    local button = CreateFrame("Button", addonName .. "_" .. unit, root, "SecureActionButtonTemplate")
    button.unit = unit
    button:SetAttribute("unit", unit)
    button:RegisterForClicks("AnyUp")
    button:SetAttribute("type", "none")

    local prefixes = { "shift-", "ctrl-", "alt-", "alt-ctrl-", "alt-shift-", "ctrl-shift-", "alt-ctrl-shift-" }

    for prefixIndex = 1, #prefixes do
        for mouse = 1, 3 do
            button:SetAttribute(prefixes[prefixIndex] .. "type" .. mouse, "none")
        end
    end

    createVisuals(button)
    positionButton(button, index)
    button:SetScript("OnEnter", showTooltip)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    RegisterStateDriver(button, "visibility", condition)
    buttons[#buttons + 1] = button
end

local function applyLayout()
    if InCombatLockdown() then
        pendingLayout = true
        return
    end

    local raidCount = GetNumRaidMembers()
    local count = raidCount > 0 and raidCount or GetNumPartyMembers() + 1
    local columns = math.ceil(count / config.rows)
    local rows = min(count, config.rows)
    root:SetSize(max(160, 16 + columns * config.width + (columns - 1) * config.gap),
        46 + rows * config.height + (rows - 1) * config.gap)
    root:SetScale(ChronixHealDB.scale)
    pendingLayout = false
end

local function restorePosition()
    local scale = ChronixHealDB.scale
    root:ClearAllPoints()
    root:SetPoint("TOPLEFT", UIParent, "CENTER", ChronixHealDB.x / scale, ChronixHealDB.y / scale)
end

local function finishDragging()
    if InCombatLockdown() then
        return
    end

    root:StopMovingOrSizing()

    if not dragging then
        return
    end

    local parentX, parentY = UIParent:GetCenter()
    local scale = root:GetScale()
    ChronixHealDB.x = root:GetLeft() * scale - parentX
    ChronixHealDB.y = root:GetTop() * scale - parentY
    dragging = false
    restorePosition()
end

local function assignedRole(unit)
    if GetPartyAssignment and GetPartyAssignment("MAINTANK", unit) then
        return "TANK"
    end
    local combatRole
    local raidIndex = tonumber(unit:match("^raid(%d+)$"))
    if raidIndex and GetRaidRosterInfo then
        local _, _, _, _, _, _, _, _, _, assignment, _, role = GetRaidRosterInfo(raidIndex)
        if assignment == "MAINTANK" then return "TANK" end
        combatRole = role
    end
    -- Original 3.3.5 returns three booleans; some server clients return a string.
    if UnitGroupRolesAssigned then
        local tank, healer, damage = UnitGroupRolesAssigned(unit)
        if type(tank) == "string" then
            if tank == "TANK" or tank == "HEALER" or tank == "DAMAGER" then return tank end
        else
            if tank == true or tank == 1 then return "TANK" end
            if healer == true or healer == 1 then return "HEALER" end
            if damage == true or damage == 1 then return "DAMAGER" end
        end
    end
    if combatRole == "TANK" or combatRole == "HEALER" or combatRole == "DAMAGER" then return combatRole end
    return "NONE"
end

local function updateRoles()
    for guid in pairs(groupRoles) do groupRoles[guid] = nil end
    for index = 1, #buttons do
        local button = buttons[index]
        if button:IsShown() and UnitExists(button.unit) then
            local guid = UnitGUID(button.unit)
            if guid then groupRoles[guid] = assignedRole(button.unit) end
        end
    end
    rolesDirty = false
end

local function updateRoster()
    for key in pairs(rosterGroups) do
        rosterGroups[key] = nil
    end

    for index = 1, GetNumRaidMembers() do
        local name, rank, subgroup = GetRaidRosterInfo(index)
        rosterGroups["raid" .. index] = subgroup or 1
    end

    applyLayout()
    rolesDirty = true
end

local function selectTank()
    if rolesDirty then updateRoles() end
    local focusGuid = UnitExists("focus") and UnitGUID("focus")
    local selected, focused, assigned, solo
    for guid in pairs(tankGuids) do tankGuids[guid] = nil end
    for index = 1, #buttons do
        local button = buttons[index]
        local unit = button.unit
        if button:IsShown() and UnitExists(unit) and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) then
            local guid = UnitGUID(unit)
            if guid == ChronixHealDB.tankGuid then selected = guid end
            if groupRoles[guid] == "TANK" then
                tankGuids[guid] = true
                assigned = assigned or guid
            end
            if guid == focusGuid then focused = guid end
            if GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0 and unit == "player" then solo = guid end
        end
    end
    if selected then
        for guid in pairs(tankGuids) do tankGuids[guid] = nil end
        tankGuids[selected] = true
    else
        if not next(tankGuids) and focused then tankGuids[focused] = true end
        if not next(tankGuids) and solo then tankGuids[solo] = true end
    end
    tankGuid = selected or assigned or focused or solo
end

local function updatePlayerContext()
    playerContext.tidalWaves = false
    playerContext.serendipity = 0
    playerContext.surgeOfLight = false
    playerContext.infusion = false
    playerContext.moving = GetUnitSpeed and GetUnitSpeed("player") > 0 or false
    playerContext.channeling = UnitChannelInfo and UnitChannelInfo("player") ~= nil or false
    playerContext.inCombat = UnitAffectingCombat and UnitAffectingCombat("player") and true or false
    updateManaWarning()
    for index = 1, 40 do
        local name, rank, icon, count, kind, duration, expiration = UnitBuff("player", index)
        if not name then break end
        if name == auraSpellName(53390) then playerContext.tidalWaves = true end
        if name == auraSpellName(63735) then playerContext.serendipity = count or 0 end
        if name == auraSpellName(33151) then playerContext.surgeOfLight = true end
        if name == auraSpellName(54149) then playerContext.infusion = true end
        if name == auraSpellName(31884) and expiration and duration then
            bubbleLockUntil = max(bubbleLockUntil, expiration - duration + 30)
        end
    end
end

local function updateUnitState(button, now)
    local state = button.state
    local unit = button.unit
    local guid = UnitGUID(unit)

    if button.history.guid ~= guid then
        button.auraDirty = true
    end

    state.connected = UnitIsConnected(unit) and true or false
    state.dead = UnitIsDeadOrGhost(unit) and true or false
    state.health = UnitHealth(unit)
    state.maximum = max(1, UnitHealthMax(unit))
    state.loss = addon.sampleHealth(button.history, guid, state.health, state.maximum, now)
    state.focus = UnitExists("focus") and UnitIsUnit(unit, "focus") and true or false
    state.tank = tankGuids[guid] and true or false
    state.self = UnitIsUnit(unit, "player") and true or false
    state.role = groupRoles[guid] or "NONE"
    state.healer = state.role == "HEALER" or (state.role == "NONE" and state.self and addon.profile.healer) or false
    state.now = now
    for key, value in pairs(playerContext) do state[key] = value end
    state.tanking = state.tank and (GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0)
        or addon.profile.spec == "protection"
        or (UnitThreatSituation and (UnitThreatSituation(unit) or 0) >= 2) or false
    state.serendipity = state.serendipity or 0
    state.available = button.unitAvailable or {}
    button.unitAvailable = state.available

    for key in pairs(state.available) do
        state.available[key] = nil
    end

    for key, value in pairs(available) do
        state.available[key] = value
    end

    state.profile = addon.profile
    state.dispelTypes = button.dispelTypes or {}
    button.dispelTypes = state.dispelTypes

    for key in pairs(state.dispelTypes) do
        state.dispelTypes[key] = nil
    end

    for key, spell in pairs(spells) do
        if spell.dispels then
            state.dispelTypes[key] = spell.dispels
        end
    end
    state.manaFraction = UnitPower("player", 0) / max(1, UnitPowerMax("player", 0))
    state.waveTime = spells.wave and spells.wave.castTime or 2.5

    if spells.wave then
        local name, rank, icon, cost, funnel, powerType, castTime = GetSpellInfo(spells.wave.name)
        state.waveTime = (castTime or state.waveTime * 1000) / 1000
    end

    local rangeSpell = spells.lesser or spells.wave or spells.riptide or spells.cleanse
    local range = rangeSpell and IsSpellInRange(rangeSpell.name, unit)
    state.inRange = nil

    if range ~= nil then
        state.inRange = range == 1
    end

    for key, spell in pairs(spells) do
        if not selfKeys[key] and IsSpellInRange(spell.name, unit) == 0 then
            state.available[key] = false
        end
        local instantProc = key == "lesser" and (state.surgeOfLight or state.infusion)
        if state.moving and not instantProc and (spell.castTime > 0 or key == "channel" or key == "special" and addon.class == "PRIEST"
            or key == "mana" and addon.class == "PRIEST") then
            state.available[key] = false
        end
    end

    state.natureComboAvailable = available.nature and available.wave and spells.wave
        and IsSpellInRange(spells.wave.name, unit) ~= 0 and true or false

    local expectedDeficit = (state.maximum - state.health + state.loss * 2) / state.maximum
    if state.connected and not state.dead and expectedDeficit >= addon.getMode().groupDeficit
        and state.inRange ~= false then
        local group = rosterGroups[unit] or 1
        injuredGroups[group] = (injuredGroups[group] or 0) + 1
        injuredTotal = injuredTotal + 1
    end

    if button.auraDirty then
        readAuras(button)
    end

    if state.connected and not state.dead and state.inRange ~= false then
        local remaining = state.loss > 0 and state.health / state.loss or math.huge
        if state.health / state.maximum <= config.criticalHealth or remaining < state.waveTime + 1 then
            anyDanger = true
        end
        if state.health / state.maximum <= 0.5 then
            local group = rosterGroups[unit] or 1
            criticalTotal = criticalTotal + 1
            criticalGroups[group] = (criticalGroups[group] or 0) + 1
        end
    end
    local mending = state.auras.mending
    if addon.class == "PRIEST" and mending and mending.own and (mending.expires == 0 or mending.expires > now) then
        mendingActive = true
    end
    if state.emergencyActive then state.available.emergency = false end
    if addon.class == "PALADIN" then
        if state.forbearance or now < bubbleLockUntil then state.available.defensive = false end
        if state.self and state.forbearance then state.available.emergency = false end
    end
    if state.defensiveActive then state.available.defensive = false end

    if addon.profile.shield and (state.weakenedSoul or state.earth) then
        state.available.earth = false
    end

    if addon.profile.swiftmend and not state.earth and not state.regrowth then
        state.available.riptide = false
    end
end

local function renderUnit(button)
    local state = button.state
    local unit = button.unit
    local ratio = state.health / state.maximum
    state.injuredCount = addon.profile.groupOnly and (injuredGroups[rosterGroups[unit] or 1] or 0) or injuredTotal
    state.raidInjuredCount = injuredTotal
    state.subgroupInjuredCount = injuredGroups[rosterGroups[unit] or 1] or 0
    state.criticalCount = criticalTotal
    state.subgroupCriticalCount = criticalGroups[rosterGroups[unit] or 1] or 0
    state.anyDanger = anyDanger
    state.mendingActive = mendingActive
    local recommendation, reason = addon.recommend(state)
    button.recommendation = recommendation
    button.health:SetMinMaxValues(0, state.maximum)
    button.health:SetValue(state.health)
    button.health:SetStatusBarColor(min(1, (1 - ratio) * 2), min(1, ratio * 1.5), 0.15, config.healthBarAlpha)
    button.nameText:SetText(UnitName(unit) or "")
    if state.tank or state.role == "TANK" then
        button.tankRoleIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        button.tankRoleIcon:SetTexCoord(0.75, 1, 0.5, 1)
        button.tankRoleIcon:Show()
    else
        button.tankRoleIcon:Hide()
    end
    if state.healer then
        button.healerRoleIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        button.healerRoleIcon:SetTexCoord(0.5, 0.75, 0.5, 1)
        button.healerRoleIcon:Show()
    else
        button.healerRoleIcon:Hide()
    end
    updateAuraStatus(button, GetTime())
    local percent = tostring(floor(ratio * 100 + 0.5)) .. "%"
    button.healthText:SetText("")

    if state.outOfMana then
        recommendation = nil
        reason = "STR_LOW_MANA"
        button.recommendation = nil
        button.icon:Hide()
        button.actionText:SetText(locale("STR_OUT_OF_MANA"))
    elseif state.dead and state.connected and resurrectionSpell then
        button.icon:SetTexture(resurrectionSpell.icon)
        button.icon:Show()
        button.actionText:SetText(locale("STR_LEFT"))
    elseif recommendation then
        local binding = findBinding(recommendation)
        local customSpell = binding and ChronixHealDB.bindings and ChronixHealDB.bindings[binding.id]
        local spell
        if customSpell ~= nil then
            spell = getSpell(recommendation)
        elseif recommendation == "naturewave" then
            spell = spells.nature or spells.emergency
        else
            spell = getSpell(recommendation)
        end
        if not binding or not spell then
            recommendation = nil
            reason = "STR_NO_MANA"
        end
        button.recommendation = recommendation
        if recommendation then
            button.icon:SetTexture(spell.icon)
            button.icon:Show()
            button.actionText:SetText(locale(binding.label))
        else
            button.icon:Hide()
            button.actionText:SetText(locale(reason))
        end
    else
        button.icon:Hide()
        button.actionText:SetText(locale(reason))
    end

    if reason == "STR_DANGER" then
        button:SetBackdropBorderColor(1, 0.15, 0.1, 1)
        button.actionText:SetTextColor(1, 0.45, 0.3)
    elseif button.dispellable then
        button:SetBackdropBorderColor(0.6, 0.3, 1, 1)
        button.actionText:SetTextColor(0.85, 0.65, 1)
    elseif reason == "STR_LOW_MANA" then
        button:SetBackdropBorderColor(0.9, 0.65, 0.15, 1)
        button.actionText:SetTextColor(1, 0.8, 0.3)
    else
        button:SetBackdropBorderColor(0.2, 0.3, 0.4, 1)
        button.actionText:SetTextColor(0.65, 0.9, 1)
    end

    button.health:SetAlpha(state.inRange == false and 0.4 or 1)
end

local function updateGrid()
    updateAvailability()
    selectTank()
    updatePlayerContext()
    injuredTotal = 0
    criticalTotal = 0
    anyDanger = false
    mendingActive = false
    for group in pairs(criticalGroups) do criticalGroups[group] = nil end

    for group in pairs(injuredGroups) do
        injuredGroups[group] = nil
    end

    local now = GetTime()

    for index = 1, #buttons do
        local button = buttons[index]

        if button:IsShown() and UnitExists(button.unit) then
            updateUnitState(button, now)
        end
    end

    for index = 1, #buttons do
        local button = buttons[index]

        if button:IsShown() and UnitExists(button.unit) then
            renderUnit(button)
        end
    end

    manaLabel:SetText(locale("STR_MANA", floor(UnitPower("player", 0) / max(1, UnitPowerMax("player", 0)) * 100)))
end

local function togglePreview()
    preview = not preview

    if not previewButtons[1] then
        for index = 1, 5 do
            local button = CreateFrame("Frame", nil, UIParent)
            createVisuals(button)
            button:SetScale(ChronixHealDB.scale)
            button:SetPoint("TOPLEFT", root, "TOPRIGHT", 12, -40 - (index - 1) * (config.height + config.gap))
            button.nameText:SetText(locale("STR_PREVIEW", index))
            button.health:SetMinMaxValues(0, 100)
            button.health:SetValue(100 - index * 15)
            button.health:SetStatusBarColor(index / 5, 1 - index / 6, 0.15, config.healthBarAlpha)
            button.healthText:SetText(tostring(100 - index * 15) .. "%")
            button.icon:SetTexture(spells.lesser and spells.lesser.icon or "Interface\\Icons\\Spell_Nature_HealingWaveLesser")
            button.debuffIcon:Hide()
            button.actionText:SetText(locale("STR_LEFT"))
            previewButtons[index] = button
        end
    end

    for index = 1, #previewButtons do
        if preview then
            previewButtons[index]:Show()
        else
            previewButtons[index]:Hide()
        end
    end

    printMessage("STR_TEST")
end

local function createGrid()
    root = CreateFrame("Frame", addonName .. "Grid", UIParent)
    root:SetFrameStrata("MEDIUM")
    root:SetMovable(true)
    root:SetClampedToScreen(true)
    root:SetPoint("TOPLEFT", UIParent, "CENTER", ChronixHealDB.x, ChronixHealDB.y)
    title = CreateFrame("Frame", nil, root)
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetPoint("TOPRIGHT", 0, 0)
    title:SetHeight(18)
    title:EnableMouse(true)
    title:RegisterForDrag("LeftButton")
    modeLabel = title:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    modeLabel:SetPoint("TOPLEFT", 8, -5)
    manaLabel = title:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    manaLabel:SetPoint("TOPRIGHT", -8, -5)
    manaLabel:SetTextColor(0.4, 0.7, 1)
    title:SetScript("OnDragStart", function()
        if ChronixHealDB.unlocked and not InCombatLockdown() then
            dragging = true
            root:StartMoving()
        end
    end)
    title:SetScript("OnDragStop", finishDragging)

    local shortLabels = { "STR_MODE_SAFE_SHORT", "STR_MODE_MIXED_SHORT", "STR_MODE_FULL_SHORT" }

    for index = 1, #config.modeOrder do
        local key = config.modeOrder[index]
        local button = CreateFrame("Button", nil, root)
        button:EnableMouse(true)
        button:SetFrameLevel(title:GetFrameLevel() + 2)
        button.mode = key
        button:SetPoint("TOPLEFT", 8 + (index - 1) * 26, -21)
        button:SetSize(22, 14)
        local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("CENTER", 0, 0)
        button:SetFontString(text)
        button:SetNormalFontObject("GameFontNormalSmall")
        button:SetHighlightFontObject("GameFontHighlightSmall")
        button:SetText(locale(shortLabels[index]))
        button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        button:RegisterForClicks("LeftButtonUp")
        button:SetScript("OnClick", function()
            addon.setMode(key)
            updateModeLabel()
        end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(locale(config.modes[key].label), 1, 1, 1)
            GameTooltip:AddLine(locale(config.modes[key].description), 1, 0.9, 0.7, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(locale("STR_MODE_HINT"), 0.7, 0.8, 1, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        modeButtons[#modeButtons + 1] = button
    end

    local settingsButton = CreateFrame("Button", nil, root)
    settingsButton:EnableMouse(true)
    settingsButton:SetFrameLevel(title:GetFrameLevel() + 2)
    settingsButton:SetPoint("TOPLEFT", 90, -21)
    settingsButton:SetSize(22, 14)
    local settingsText = settingsButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    settingsText:SetPoint("CENTER", 0, 0)
    settingsButton:SetFontString(settingsText)
    settingsButton:SetNormalFontObject("GameFontNormalSmall")
    settingsButton:SetHighlightFontObject("GameFontHighlightSmall")
    settingsButton:SetText(locale("STR_SETTINGS_SHORT"))
    settingsButton:RegisterForClicks("LeftButtonUp")
    settingsButton:SetScript("OnClick", function()
        addon.openSettings()
    end)
    settingsButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(locale("STR_SETTINGS"), 1, 1, 1)
        GameTooltip:Show()
    end)
    settingsButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local tankDropdown = CreateFrame("Frame", addonName .. "TankDropdown", root, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(tankDropdown, 140)
    UIDropDownMenu_Initialize(tankDropdown, function(_, level)
        if level ~= 1 then return end
        local automatic = UIDropDownMenu_CreateInfo()
        automatic.text = locale("STR_TANK_AUTO")
        automatic.checked = not ChronixHealDB.tankGuid
        automatic.func = function()
            addon.settingsActions.clearTank()
        end
        UIDropDownMenu_AddButton(automatic, level)
        for _, candidate in ipairs(addon.getTankCandidates()) do
            local unit = candidate.unit
            local option = UIDropDownMenu_CreateInfo()
            option.text = candidate.name
            option.checked = candidate.guid == ChronixHealDB.tankGuid
            option.func = function()
                addon.settingsActions.setTank(unit)
            end
            UIDropDownMenu_AddButton(option, level)
        end
    end)
    tankDropdown:Hide()

    local tankButton = CreateFrame("Button", addonName .. "TankButton", root)
    tankButton:EnableMouse(true)
    tankButton:SetFrameLevel(title:GetFrameLevel() + 2)
    tankButton:SetPoint("TOPLEFT", 116, -21)
    tankButton:SetSize(38, 14)
    local tankText = tankButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tankText:SetPoint("CENTER", 0, 0)
    tankButton:SetFontString(tankText)
    tankButton:SetNormalFontObject("GameFontNormalSmall")
    tankButton:SetHighlightFontObject("GameFontHighlightSmall")
    tankButton:SetText(locale("STR_TANK_SHORT"))
    tankButton:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    tankButton:SetBackdropColor(0.05, 0.08, 0.12, 0.5)
    tankButton:RegisterForClicks("LeftButtonUp")
    tankButton:SetScript("OnClick", function()
        ToggleDropDownMenu(1, nil, tankDropdown, "cursor", 0, 0)
    end)
    tankButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(locale("STR_TANK_TOOLTIP", ChronixHealDB.tankName or locale("STR_TANK_AUTO")), 1, 1, 1)
        GameTooltip:AddLine(locale("STR_TANK_HINT"), 0.7, 0.8, 1, true)
        GameTooltip:Show()
    end)
    tankButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    updateModeLabel()

    createUnitButton("player", 1, "[group:raid]hide;show")

    for index = 1, 4 do
        local unit = "party" .. index
        createUnitButton(unit, index + 1, "[group:raid]hide;[@" .. unit .. ",exists]show;hide")
    end

    for index = 1, 40 do
        local unit = "raid" .. index
        createUnitButton(unit, index, "[group:raid,@" .. unit .. ",exists]show;hide")
    end

    applyLayout()

    if ChronixHealDB.anchorVersion ~= 2 then
        ChronixHealDB.x = ChronixHealDB.x - root:GetWidth() * ChronixHealDB.scale / 2
        ChronixHealDB.y = ChronixHealDB.y + root:GetHeight() * ChronixHealDB.scale / 2
        ChronixHealDB.anchorVersion = 2
    end

    restorePosition()

    if ChronixHealDB.hidden then
        root:Hide()
    end
end

local function applyOptions()
    if not initialized or not root then
        printMessage("STR_LOADING")
        return false
    end
    if InCombatLockdown() then
        printMessage("STR_COMBAT")
        return false
    end

    for index = 1, #buttons do
        local button = buttons[index]
        button:SetSize(config.width, config.height)
        button.health:ClearAllPoints()
        button.health:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        button.health:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        button.nameText:SetWidth(config.width - 26)
        button.actionText:SetWidth(config.width - 8)
        for auraIndex = 1, #button.auraSlots do
            local slot = button.auraSlots[auraIndex]
            slot:ClearAllPoints()
            slot:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 4 + (auraIndex - 1) * 20, 2)
        end
        button.auraOverflow:ClearAllPoints()
        button.auraOverflow:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 124, config.healthBarHeight + 8)
        button.debuffIcon:SetSize(config.healthBarHeight, config.healthBarHeight)
        button:ClearAllPoints()
        local unitIndex = button.unit == "player" and 1
            or (button.unit:find("party") == 1 and tonumber(button.unit:match("%d+")) + 1)
            or tonumber(button.unit:match("%d+"))
        positionButton(button, unitIndex)
    end

    for index = 1, #previewButtons do
        previewButtons[index]:Hide()
    end
    preview = false
    applyLayout()
    restorePosition()
    return true
end

local function createSettingsActions()
    addon.settingsActions = {
        setTank = function(unit)
            if not unit and UnitExists("target") and UnitIsFriend("player", "target") then
                local targetGuid = UnitGUID("target")
                for index = 1, #buttons do
                    local candidate = buttons[index]
                    if candidate:IsShown() and UnitExists(candidate.unit) and UnitGUID(candidate.unit) == targetGuid then
                        unit = candidate.unit
                        break
                    end
                end
            end
            if not unit then
                printMessage("STR_TANK_INVALID")
                return
            end
            for index = 1, #buttons do
                local candidate = buttons[index].unit
                if candidate == unit and buttons[index]:IsShown() and UnitExists(candidate)
                    and UnitIsFriend("player", candidate) then
                    local guid = UnitGUID(candidate)
                    ChronixHealDB.tankGuid = guid
                    ChronixHealDB.tankName = UnitName(candidate)
                    return
                end
            end
            printMessage("STR_TANK_INVALID")
        end,
        clearTank = function()
            ChronixHealDB.tankGuid = nil
            ChronixHealDB.tankName = nil
        end,
        setMode = function(key)
            addon.setMode(key)
            updateModeLabel()
        end,
        getBindingOptions = function()
            local options = {}
            for id, spell in pairs(spellCatalog) do
                table.insert(options, { id = id, name = spell.name, icon = spell.icon })
            end
            table.sort(options, function(left, right) return left.name < right.name end)
            return options
        end,
        getBindings = function()
            return bindings
        end,
        getBindingSpell = function(index)
            local binding = bindings[index]
            if not binding then return nil end
            local spellId = ChronixHealDB.bindings and ChronixHealDB.bindings[binding.id]
            if spellId ~= nil then
                return spellId ~= 0 and spellCatalog[spellId] or nil
            end
            if binding.key == "naturewave" then
                return spells.nature or spells.emergency or spells.wave
            end
            return spells[binding.key]
        end,
        setBindingSpell = function(index, spellId)
            if not initialized or not root then
                printMessage("STR_LOADING")
                return false
            end
            if InCombatLockdown() then
                printMessage("STR_COMBAT")
                return false
            end
            local binding = bindings[index]
            if not binding or spellId ~= 0 and not spellCatalog[spellId] then return false end
            ChronixHealDB.bindings = ChronixHealDB.bindings or {}
            ChronixHealDB.bindings[binding.id] = spellId
            refreshSpells()
            updateAvailability()
            updateGrid()
            return true
        end,
        setOption = function(key, value)
            if not initialized or not root then
                printMessage("STR_LOADING")
                return false
            end
            if InCombatLockdown() then
                printMessage("STR_COMBAT")
                return false
            end

            if key == "scale" then
                ChronixHealDB.scale = value
            elseif key == "unlocked" then
                ChronixHealDB.unlocked = value
            elseif key == "visible" then
                ChronixHealDB.hidden = not value
                if value then root:Show() else root:Hide() end
            else
                config[key] = value
                ChronixHealDB.options[key] = value

            end

            if config.height < 50 then
                config.height = 50
                ChronixHealDB.options.height = config.height
            end

            return applyOptions()
        end,
        resetPosition = function()
            if not initialized or not root then
                printMessage("STR_LOADING")
                return
            end
            if InCombatLockdown() then
                printMessage("STR_COMBAT")
                return
            end
            finishDragging()
            ChronixHealDB.x = -root:GetWidth() * ChronixHealDB.scale / 2
            ChronixHealDB.y = root:GetHeight() * ChronixHealDB.scale / 2
            restorePosition()
        end,
        restoreGrid = function()
            if not initialized or not root then
                printMessage("STR_LOADING")
                return
            end
            if InCombatLockdown() then
                printMessage("STR_COMBAT")
                return
            end
            addon.settingsActions.resetPosition()
            ChronixHealDB.hidden = false
            root:Show()
            printMessage("STR_GRID_RESTORED")
        end,
        preview = function()
            if InCombatLockdown() then
                printMessage("STR_COMBAT")
                return
            end
            togglePreview()
        end,
    }
    addon.getTankCandidates = function()
        local candidates = {}
        for index = 1, #buttons do
            local button = buttons[index]
            local unit = button.unit
            if button:IsShown() and UnitExists(unit) and UnitIsFriend("player", unit)
                and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) then
                candidates[#candidates + 1] = { unit = unit, name = UnitName(unit), guid = UnitGUID(unit) }
            end
        end
        return candidates
    end
end

local function handleCommand(message)
    local command, argument = message:match("^%s*(%S*)%s*(.-)%s*$")

    if not initialized or string.lower(command or "") ~= "mode" then
        printMessage("STR_MODE_HELP")
        return
    end

    if argument ~= "" and not addon.setMode(argument) then
        printMessage("STR_MODE_HELP")
        return
    end

    updateModeLabel()
    DEFAULT_CHAT_FRAME:AddMessage(locale("STR_MODE_CHANGED", locale(addon.getMode().label)))
end

local function initialize()
    local className, class = UnitClass("player")

    addon.selectProfile(class)

    if InCombatLockdown() then
        return
    end

    ChronixHealDB = type(ChronixHealDB) == "table" and ChronixHealDB or {}
    ChronixHealDB.scale = min(1.8, max(0.6, tonumber(ChronixHealDB.scale) or 1))
    ChronixHealDB.x = tonumber(ChronixHealDB.x) or 0
    ChronixHealDB.y = tonumber(ChronixHealDB.y) or 0

    if not addon.setMode(type(ChronixHealDB.mode) == "string" and ChronixHealDB.mode or config.defaultMode) then
        addon.setMode("mixed")
    end

    if ChronixHealDB.unlocked == nil then
        ChronixHealDB.unlocked = true
    end
    ChronixHealDB.options = type(ChronixHealDB.options) == "table" and ChronixHealDB.options or {}
    local limits = {
        width = { 128, 220 }, height = { 50, 80 }, healthBarHeight = { 6, 16 },
        minimumDeficit = { 0.01, 0.25 }, lowMana = { 0.1, 0.6 },
    }
    for key, bounds in pairs(limits) do
        local value = tonumber(ChronixHealDB.options[key])
        if value then config[key] = min(bounds[2], max(bounds[1], value)) end
    end
    for _, key in ipairs({ "recommendFocusBuffs", "recommendGroupHeals", "recommendCooldowns" }) do
        if type(ChronixHealDB.options[key]) == "boolean" then
            config[key] = ChronixHealDB.options[key]
        end
    end
    config.width = max(config.width, 128)
    config.height = max(config.height, 50)

    if ChronixHealDB.recoveryVersion ~= "0.4.1" then
        ChronixHealDB.hidden = false
        ChronixHealDB.x = 0
        ChronixHealDB.y = 0
        ChronixHealDB.anchorVersion = nil
        ChronixHealDB.recoveryVersion = "0.4.1"
    end

    createSettingsActions()
    addon.createMinimap()

    local success, errorMessage = pcall(addon.createSettings)
    if not success then
        printMessage("STR_SETTINGS_ERROR")
        geterrorhandler()(errorMessage)
    end

    createGrid()
    initialized = true
    refreshSpells()
    updateRoster()

    addon.initializeSelfBuffReminder(root)

    printMessage("STR_LOADED")

    if not addon.profile.healer then
        printMessage("STR_GRID_ONLY")
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_DEAD")
events:RegisterEvent("PLAYER_ALIVE")
events:RegisterEvent("PLAYER_UNGHOST")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("UNIT_INVENTORY_CHANGED")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:RegisterEvent("BAG_UPDATE")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("RAID_ROSTER_UPDATE")
events:RegisterEvent("PARTY_MEMBERS_CHANGED")
events:RegisterEvent("SPELLS_CHANGED")
events:RegisterEvent("PLAYER_TALENT_UPDATE")
events:RegisterEvent("UNIT_AURA")
events:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
events:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
events:RegisterEvent("PLAYER_ROLES_ASSIGNED")
events:RegisterEvent("LFG_ROLE_UPDATE")
events:RegisterEvent("LFG_PROPOSAL_SUCCEEDED")
events:RegisterEvent("PARTY_LEADER_CHANGED")
events:SetScript("OnEvent", function(self, event, unit, spellName)
    if event == "PLAYER_LOGIN" or (event == "PLAYER_REGEN_ENABLED" and not initialized) then
        if not initialized then
            initialize()
        end
        return
    end

    if not initialized then
        return
    end

    if addon.selfBuffEvent then addon.selfBuffEvent(event, unit) end
    if event == "UNIT_INVENTORY_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" or event == "BAG_UPDATE" then return end
    if event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" or event == "PLAYER_REGEN_DISABLED" then return end

    if event == "PLAYER_ROLES_ASSIGNED" or event == "LFG_ROLE_UPDATE"
        or event == "LFG_PROPOSAL_SUCCEEDED" or event == "PARTY_LEADER_CHANGED" then
        rolesDirty = true
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit == "player" and spellName == auraSpellName(31884) then
            bubbleLockUntil = GetTime() + 30
        end
    elseif event == "UNIT_AURA" then
        for index = 1, #buttons do
            if unit and UnitExists(buttons[index].unit) and UnitIsUnit(buttons[index].unit, unit) then
                buttons[index].auraDirty = true
            end
        end
    elseif event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
        refreshSpells()
    elseif event == "PLAYER_REGEN_ENABLED" then
        finishDragging()
        updateRoster()

        if pendingSpells then
            refreshSpells()
        end

        if pendingLayout then
            applyLayout()
        end
    else
        updateRoster()

        for index = 1, #buttons do
            buttons[index].auraDirty = true
        end
    end
end)
events:SetScript("OnUpdate", function(self, elapsed)
    if not initialized then
        return
    end

    if addon.pollSelfBuffWeapons then addon.pollSelfBuffWeapons(elapsed) end

    elapsedUpdate = elapsedUpdate + elapsed

    if elapsedUpdate < config.updateInterval then
        return
    end

    elapsedUpdate = 0
    if root:IsShown() then
        -- updateGrid already checks mana through updatePlayerContext.
        updateGrid()
    else
        updateManaWarning()
    end
end)

SLASH_REBUFFEDHEALBOT1 = "/rhb"
SLASH_REBUFFEDHEALBOT2 = "/rebuffedhealbot"
SLASH_REBUFFEDHEALBOT3 = "/chheal"
SLASH_REBUFFEDHEALBOT4 = "/chronixheal"
SlashCmdList.REBUFFEDHEALBOT = handleCommand

-- Kept in the existing core file so an update needs only /reload, not discovery
-- of a new addon or Lua file. Uses the grid's events and never adds a ticker.
addon.initializeSelfBuffReminder = function(parent)
    if addon.selfBuffEvent then return end
    local _, playerClass = UnitClass("player")
    local rows, auraCounts = {}, {}
    local pending, moving, hasWeapons, pollElapsed = false, nil, false, 0
    addon.selfBuffRows = rows

    local function position()
        local saved = ChronixHealDB.selfBuffPosition
        if type(saved) ~= "table" or type(saved.x) ~= "number" or type(saved.y) ~= "number" then
            local left, bottom = parent:GetLeft(), parent:GetBottom()
            local scale = parent:GetEffectiveScale() / UIParent:GetEffectiveScale()
            local cx, cy = UIParent:GetCenter()
            saved = {x = left and left * scale or cx - 16, y = bottom and bottom * scale - 6 or cy - 180}
            ChronixHealDB.selfBuffPosition = saved
        end
        return saved
    end
    local function placeRows()
        if #rows == 0 then return end
        local saved = position()
        local last = 1
        for index, row in ipairs(rows) do if row.entry then last = index end end
        local width = (last - 1) * 36 + 32
        saved.x = math.max(0, math.min(saved.x, math.max(0, UIParent:GetWidth() - width)))
        saved.y = math.max(32, math.min(saved.y, UIParent:GetHeight()))
        for index, row in ipairs(rows) do
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", saved.x + (index - 1) * 36, saved.y)
        end
    end
    local function finishMoving()
        if not moving or InCombatLockdown() then return end
        local row = moving
        row:StopMovingOrSizing(); moving = nil
        row:SetScript("OnUpdate", nil)
        local x, y = row:GetLeft(), row:GetTop()
        if x and y then
            ChronixHealDB.selfBuffPosition = {x = x - (row.index - 1) * 36, y = y}
            placeRows()
        end
    end
    local function weaponEquipped(slot)
        if not GetInventoryItemLink then return false end
        local link = GetInventoryItemLink("player", slot)
        if not link then return false end
        local _, _, _, _, _, _, _, _, equip = GetItemInfo(link)
        return equip == "INVTYPE_WEAPON" or equip == "INVTYPE_WEAPONMAINHAND"
            or equip == "INVTYPE_WEAPONOFFHAND" or equip == "INVTYPE_2HWEAPON"
    end
    local function enchants()
        if not GetWeaponEnchantInfo then return end
        local a,b,c,d,e,f,g = GetWeaponEnchantInfo()
        -- Original 3.3.5 has six results. Also accept clients adding enchant IDs.
        if type(d) == "number" or type(e) == "boolean" then return a,b,c,e,f,g end
        return a,b,c,d,e,f
    end
    local function update(weaponsOnly)
        local dead = UnitIsDeadOrGhost("player")
        if not weaponsOnly then
            for key in pairs(auraCounts) do auraCounts[key] = nil end
            for index = 1, 40 do
                local name, _, _, count = UnitBuff("player", index)
                if not name then break end
                auraCounts[name] = count or 0
            end
        end
        local mh, mhTime, mhCharges, oh, ohTime, ohCharges
        if hasWeapons then mh, mhTime, mhCharges, oh, ohTime, ohCharges = enchants() end
        for _, row in ipairs(rows) do
            local entry = row.entry
            if entry and (not weaponsOnly or entry.weapon) then
                local present, count, eligible = false, 0, true
                if entry.weapon then
                    eligible = weaponEquipped(entry.weapon)
                    local active, remaining, charges
                    if entry.weapon == 16 then active, remaining, charges = mh, mhTime, mhCharges
                    else active, remaining, charges = oh, ohTime, ohCharges end
                    present = active and (not remaining or remaining > 0)
                    -- Zero means a timed, uncharged enchant such as Earthliving.
                    count = charges and charges > 0 and charges or nil
                else
                    for name in pairs(entry.names) do
                        if auraCounts[name] ~= nil then present, count = true, auraCounts[name]; break end
                    end
                    if entry.pet then eligible = UnitExists and UnitExists("pet") and not UnitIsDeadOrGhost("pet") end
                end
                local low = present and (entry.charges or entry.weapon) and count and count <= 1
                local alert = not dead and eligible and (not present or low) or false
                row.buffAlert = alert
                -- Every configured action has a visible 32px icon matching its
                -- click area, including healthy buffs and combat.
                row:SetAlpha(1)
                local title = entry.name
                if entry.weapon then title = title .. " (" .. locale(entry.weapon == 16 and "STR_SELF_BUFF_MAIN_HAND" or "STR_SELF_BUFF_OFF_HAND") .. ")" end
                row.displayName = title
                if dead then row.status = locale("STR_SELF_BUFF_DEAD")
                elseif alert and entry.item and GetItemCount(entry.item) == 0 then row.status = locale("STR_SELF_BUFF_NO_POISON")
                elseif not present then row.status = locale("STR_SELF_BUFF_MISSING")
                elseif low then row.status = locale("STR_SELF_BUFF_LOW", count)
                elseif entry.charges then row.status = locale("STR_SELF_BUFF_CHARGES", count)
                else row.status = locale("STR_SELF_BUFF_ACTIVE") end
                if alert then
                    row:SetBackdropBorderColor(1, 0.15, 0.05, 1)
                    row.icon:SetVertexColor(1, 1, 1)
                else
                    row:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
                    local shade = eligible and not dead and 0.7 or 0.35
                    row.icon:SetVertexColor(shade, shade, shade)
                end
            end
        end
    end
    local function createRow(index)
        local name = addonName .. "SelfBuff" .. (index == 1 and "" or index)
        local row = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
        row.index = index
        row:SetWidth(32); row:SetHeight(32); row:SetClampedToScreen(true)
        row:SetMovable(true); row:EnableMouse(true)
        row:RegisterForDrag("RightButton"); row:RegisterForClicks("LeftButtonUp")
        row:SetScript("OnDragStart", function(self)
            if not InCombatLockdown() then
                self:StartMoving(); moving = self
            end
        end)
        row:SetScript("OnDragStop", finishMoving)
        row:SetBackdrop({edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8})
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetWidth(28); row.icon:SetHeight(28); row.icon:SetPoint("CENTER", 0, 0)
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        row:SetScript("OnEnter", function(self)
            if not self.entry then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.displayName or self.entry.name, 1, 0.82, 0)
            if self.status then GameTooltip:AddLine(self.status, 1, 1, 1, true) end
            GameTooltip:AddLine(locale(self.entry.weapon and "STR_SELF_BUFF_WEAPON_CLICK" or "STR_SELF_BUFF_CLICK"), 1, 1, 1, true)
            GameTooltip:AddLine(locale("STR_SELF_BUFF_MOVE"), 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:SetScript("OnHide", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
        rows[index] = row
        return row
    end
    local learned = {}
    local function resolve(definition)
        if definition.items then
            local item = definition.items[1]
            for _, id in ipairs(definition.items) do
                if GetItemCount(id) > 0 then
                    local _, _, _, _, required = GetItemInfo(id)
                    if not required or not UnitLevel or required <= UnitLevel("player") then item = id; break end
                end
            end
            local name, _, _, _, _, _, _, _, _, icon = GetItemInfo(item)
            return {name = name or locale("STR_SELF_BUFF_POISON"), icon = icon or "Interface\\Icons\\Ability_Poisons",
                weapon = definition.weapon, item = item}
        end
        local names, chosen = {}, nil
        for _, id in ipairs(definition.ids) do
            local name, _, icon = GetSpellInfo(id)
            if name then
                names[name] = true
                if not chosen and learned[name] then chosen = {name = name, icon = icon} end
            end
        end
        for _, id in ipairs(definition.alternatives or {}) do
            local name = GetSpellInfo(id)
            if name then names[name] = true end
        end
        if not chosen then return end
        if definition.exact then names = {[chosen.name] = true} end
        chosen.names, chosen.charges = names, definition.charges
        chosen.weapon, chosen.pet = definition.weapon, definition.pet
        return chosen
    end
    local function configure(reuseBook)
        if InCombatLockdown() then pending = true; return end
        pending = false
        if not reuseBook then
            for key in pairs(learned) do learned[key] = nil end
            for tab = 1, GetNumSpellTabs() do
                local _, _, offset, count = GetSpellTabInfo(tab)
                for index = offset + 1, offset + count do
                    local name = GetSpellName(index, BOOKTYPE_SPELL)
                    if name then learned[name] = true end
                end
            end
        end
        local count = 0
        hasWeapons, pollElapsed = false, 0
        for _, definition in ipairs(addon.getSelfBuffDefinitions(playerClass)) do
            local entry = resolve(definition)
            if entry then
                count = count + 1
                local row = rows[count] or createRow(count)
                row.entry = entry
                row:SetAttribute("type1", entry.item and "item" or "spell")
                row:SetAttribute("unit", not entry.weapon and "player" or nil)
                row:SetAttribute("spell1", not entry.item and entry.name or nil)
                row:SetAttribute("item1", entry.item and ("item:" .. entry.item) or nil)
                row:SetAttribute("target-slot1", entry.weapon)
                row:EnableMouse(true)
                row.icon:SetTexture(entry.icon)
                row:Show()
                if entry.weapon then hasWeapons = true end
            end
        end
        for index = count + 1, #rows do
            local row = rows[index]
            row.entry, row.buffAlert = nil, false
            if GameTooltip:IsOwned(row) then GameTooltip:Hide() end
            row:EnableMouse(false)
            row:SetAttribute("type1", nil); row:SetAlpha(0); row:Hide()
        end
        placeRows()
        update()
    end
    addon.selfBuffEvent = function(event, unit)
        if event == "PLAYER_REGEN_ENABLED" then finishMoving() end
        if event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE" or event == "ACTIVE_TALENT_GROUP_CHANGED"
            or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" and pending then configure()
        elseif event == "BAG_UPDATE" and playerClass == "ROGUE" then configure(true)
        elseif playerClass == "DEATHKNIGHT" and (event == "PLAYER_ROLES_ASSIGNED" or event == "LFG_ROLE_UPDATE") then configure(true)
        elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "UNIT_INVENTORY_CHANGED" and unit == "player" then update(true)
        elseif event == "UNIT_AURA" and unit == "player" or event == "PLAYER_ENTERING_WORLD"
            or event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED"
            or event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then update() end
    end
    addon.pollSelfBuffWeapons = function(elapsed)
        if not hasWeapons then return end
        pollElapsed = pollElapsed + elapsed
        if pollElapsed >= 1 then pollElapsed = 0; update(true) end
    end
    configure()
end
