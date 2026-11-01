local addonName, addon = ...
local config = addon.config

local function usable(state, key)
    return state.available[key] == true
end

local function first(state, ...)
    for index = 1, select("#", ...) do
        local key = select(index, ...)
        if usable(state, key) then
            return key
        end
    end
end

local function aura(state, key, own)
    local entry = state.auras and state.auras[key]
    if entry and (not own or entry.own) and (entry.expires == 0 or entry.expires > (state.now or 0)) then
        return entry
    end
end

local function missing(state, key)
    if aura(state, key, true) then
        return false
    end
    return not (state[key] and not state.auras)
end

function addon.maintenance(state)
    if not config.recommendFocusBuffs or not (state.tank or state.focus) then
        return
    end
    local class = state.profile.class
    if class ~= "SHAMAN" and class ~= "PALADIN" then
        return
    end
    for _, key in ipairs(state.profile.focusBuffs or {}) do
        local entry = aura(state, key)
        local legacy = not state.auras and (key == "chain" and state.chainAura or key == "earth" and state.earth)
        local refresh = not entry and not legacy
        if entry and entry.own then
            refresh = entry.expires > 0 and entry.expires - (state.now or 0) <= config.buffRefreshSeconds
            if class == "SHAMAN" and key == "earth" then
                refresh = refresh or entry.count > 0 and entry.count <= config.earthShieldCharges
            end
        end
        if class == "PALADIN" and key == "chain" and entry and not entry.own then
            refresh = true
        end
        if refresh and usable(state, key) then
            return key
        end
    end
end

function addon.urgentHeal(state)
    local class = state.profile.class
    if class == "PRIEST" then
        if state.profile.spec == "discipline" then
            return first(state, "special", "earth", "lesser", "wave")
        end
        return first(state, "lesser", "earth", "wave")
    elseif class == "SHAMAN" and state.tidalWaves and state.health / state.maximum < 0.35 then
        return first(state, "wave", "riptide", "lesser")
    end
    return first(state, unpack(state.profile.urgent))
end

function addon.classPriority(state, mode, deficit, lowMana)
    local profile = state.profile
    local class = profile.class
    local fraction = 1 - deficit
    local sustained = state.loss > 0 or (state.tank and state.inCombat)
    local group = config.recommendGroupHeals and state.manaFraction >= mode.groupMana
    local minimum = mode.minimumDeficit or config.minimumDeficit
    local needsHeal = deficit + 0.000001 >= minimum
    local raidCount = state.raidInjuredCount or state.injuredCount or 0
    local subgroupCount = state.subgroupInjuredCount or state.injuredCount or 0
    local groupCount = profile.groupOnly and subgroupCount or raidCount

    if class == "PRIEST" and profile.spec == "discipline" then
        if (needsHeal or sustained) and usable(state, "earth") and (sustained or fraction <= mode.shieldHealth) then
            return "earth"
        end
        if needsHeal and usable(state, "special") then
            return "special"
        end
        if sustained and not state.mendingActive and usable(state, "mending") then
            return "mending"
        end
        if group and subgroupCount >= math.max(4, mode.groupCount) and fraction < 0.60 and usable(state, "chain") then
            return "chain", "STR_GROUP_HEAL"
        end
        if needsHeal then
            return first(state, "lesser", "wave")
        end
        return
    end

    if class == "PRIEST" and profile.spec == "holy" then
        if group and raidCount >= mode.groupCount and usable(state, "area") then
            return "area", "STR_GROUP_HEAL"
        end
        if sustained and not state.mendingActive and usable(state, "mending") then
            return "mending"
        end
        if group and subgroupCount >= mode.groupCount and needsHeal and usable(state, "chain")
            and ((state.serendipity or 0) >= 3 or fraction <= 0.65) then
            return "chain", "STR_GROUP_HEAL"
        end
        if needsHeal and missing(state, "riptide") and deficit >= mode.hotDeficit and usable(state, "riptide") then
            return "riptide"
        end
        if needsHeal then
            if state.surgeOfLight and usable(state, "lesser") then
                return "lesser"
            end
            if (state.serendipity or 0) >= 3 and fraction <= 0.5 and usable(state, "wave") then
                return "wave"
            end
            return first(state, "lesser", "wave")
        end
        return
    end

    if needsHeal and profile.groupHeal and group and groupCount >= mode.groupCount and usable(state, "chain") then
        return "chain", "STR_GROUP_HEAL"
    end
    if not needsHeal then
        return
    end

    if class == "PALADIN" then
        if (state.moving or fraction <= 0.45) and usable(state, "riptide") then
            return "riptide"
        end
        if state.infusion and usable(state, "lesser") and fraction > 0.4 then
            return "lesser"
        end
        local large = lowMana and 0.45 or (mode.ignoreConservation and 0.85 or 0.65)
        if fraction <= large and usable(state, "wave") then
            return "wave"
        end
        return first(state, "lesser", "wave", "riptide")
    elseif class == "DRUID" then
        if fraction <= 0.65 and usable(state, "riptide") then
            return "riptide"
        end
        if missing(state, "earth") and deficit >= mode.hotDeficit and usable(state, "earth") then
            return "earth"
        end
        if state.tank and sustained then
            if not lowMana and missing(state, "special") and usable(state, "special") then
                return "special"
            end
            local bloom = aura(state, "mending", true)
            local buildStack = bloom and not lowMana and bloom.count < 3
                and (bloom.expires == 0 or bloom.expires - (state.now or 0) > 3)
            if (missing(state, "mending") or buildStack) and usable(state, "mending") then
                return "mending"
            end
        end
        if not lowMana or fraction <= mode.conserveHealth then
            return first(state, "lesser", "special", "wave")
        end
    elseif class == "SHAMAN" then
        if missing(state, "riptide") and deficit >= mode.hotDeficit and usable(state, "riptide") then
            return "riptide"
        end
        if fraction <= mode.waveHealth and (state.tidalWaves or fraction <= 0.5) then
            return first(state, "wave", "lesser")
        end
        if not lowMana or fraction <= mode.conserveHealth then
            return first(state, "lesser", "wave")
        end
    elseif needsHeal then
        return first(state, "lesser", "wave", "riptide")
    end
end
