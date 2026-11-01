local addonName, addon = ...
local config = addon.config
local max = math.max
local exp = math.exp

function addon.sampleHealth(history, guid, health, maximum, now)
    if history.guid ~= guid or history.maximum ~= maximum or not history.time then
        history.guid = guid
        history.maximum = maximum
        history.health = health
        history.time = now
        history.loss = 0
        return 0
    end

    local elapsed = now - history.time

    if elapsed <= 0 then
        return history.loss
    end

    if elapsed > 3 then
        history.loss = 0
    else
        local decay = exp(-elapsed / config.damageWindow)
        local netLoss = (history.health - health) / elapsed
        history.loss = max(0, history.loss * decay + netLoss * (1 - decay))
    end

    history.health = health
    history.time = now
    return history.loss
end

local function usable(state, key)
    return state.available[key] == true
end

local function findDispel(state)
    local types = { "Curse", "Magic", "Poison", "Disease" }
    local affected = { Curse = state.curse, Magic = state.magic, Poison = state.poison, Disease = state.disease }
    local keys = { "cleanse", "toxins" }

    for index = 1, #types do
        local kind = types[index]

        if affected[kind] then
            for keyIndex = 1, #keys do
                local key = keys[keyIndex]
                local capabilities = state.dispelTypes and state.dispelTypes[key]

                if capabilities and capabilities[kind] and usable(state, key) then
                    local blocked = false
                    for blockedType in pairs(state.blockedTypes or {}) do
                        blocked = blocked or capabilities[blockedType]
                    end
                    if not blocked then
                        return key
                    end
                end
            end
        end
    end
end

function addon.recommend(state)
    if not state.connected then
        return nil, "STR_OFFLINE"
    end

    if state.dead then
        return nil, "STR_DEAD"
    end

    if state.inRange == false then
        return nil, "STR_RANGE"
    end

    if state.channeling then
        return nil, "STR_CHANNELING"
    end

    local profile = state.profile or addon.profile
    local mode = addon.getMode()
    local minimumDeficit = mode.minimumDeficit or config.minimumDeficit
    local fraction = state.health / max(1, state.maximum)
    local deficit = 1 - fraction
    local timeToDeath = state.loss > 0 and state.health / state.loss or math.huge
    local waveTime = state.waveTime or 2.5
    local emergency = fraction <= config.emergencyHealth or timeToDeath < 2
    local danger = fraction <= config.criticalHealth or timeToDeath < waveTime + 1
    local cleanse = findDispel(state)
    local lowMana = not mode.ignoreConservation
        and (mode.alwaysConserve or state.manaFraction <= (mode.lowMana or config.lowMana))

    if cleanse and (not emergency or not profile.healer) then
        return cleanse, "STR_READY"
    end

    if not profile.healer then
        return nil, "STR_GRID_ONLY"
    end

    if config.recommendCooldowns and state.self and not state.defensiveActive and usable(state, "defensive") then
        if profile.class == "PALADIN" and emergency and not state.tanking and not state.forbearance then
            return "defensive", "STR_DANGER"
        elseif profile.class == "DRUID" and danger and state.loss > 0 then
            return "defensive", "STR_DANGER"
        end
    end

    if danger then
        if config.recommendCooldowns and emergency then
            if state.natureComboAvailable or usable(state, "nature") and usable(state, "wave") or usable(state, "emergency") then
                return "naturewave", "STR_DANGER"
            end
        end
        local heal = addon.urgentHeal(state)
        if heal then
            return heal, "STR_DANGER"
        end
        if cleanse then
            return cleanse, "STR_READY"
        end
        return nil, "STR_NO_MANA"
    end

    if config.recommendCooldowns and state.self and not state.moving and state.inCombat then
        local count = profile.class == "DRUID" and (state.subgroupCriticalCount or 0) or (state.criticalCount or 0)
        if config.recommendGroupHeals and count >= 3 and usable(state, "channel") then
            return "channel", "STR_GROUP_HEAL"
        end
        if state.manaFraction <= config.manaCooldownThreshold and not state.manaActive and usable(state, "mana") then
            local safeWindow = not state.anyDanger and (state.raidInjuredCount or 0) == 0
            if profile.class == "SHAMAN" or profile.class == "DRUID" or safeWindow then
                return "mana", "STR_MANA_COOLDOWN"
            end
        end
    end

    if fraction > 0.55 and timeToDeath > 5 and not state.anyDanger then
        local maintenance = addon.maintenance(state)
        if maintenance then
            return maintenance, "STR_MAINTAIN"
        end
    end

    local heal, reason = addon.classPriority(state, mode, deficit, lowMana)
    if heal then
        return heal, reason or (lowMana and "STR_LOW_MANA" or "STR_READY")
    end

    if deficit + 0.000001 >= minimumDeficit and not usable(state, "lesser") and not usable(state, "wave")
        and not usable(state, "riptide") and not usable(state, "special") then
        return nil, "STR_NO_MANA"
    end
    return nil, state.blockedDispel and "STR_DISPEL_CAUTION" or state.magic and "STR_MAGIC_TYPE" or "STR_WAIT"
end
