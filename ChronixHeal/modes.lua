local addonName, addon = ...
local config = addon.config

function addon.getMode()
    local key = addon.mode or config.defaultMode
    return config.modes[key] or config.modes.mixed
end

function addon.setMode(key)
    key = string.lower(key or ""):gsub("[%s_%-]", "")
    local aliases = { safemana = "safe", fullheal = "full" }
    key = aliases[key] or key

    if not config.modes[key] then
        return false
    end

    addon.mode = key

    if type(ChronixHealDB) == "table" then
        ChronixHealDB.mode = key
    end

    return true
end

function addon.cycleMode(direction)
    local order = config.modeOrder
    local current = 1

    for index = 1, #order do
        if order[index] == addon.mode then
            current = index
            break
        end
    end

    local nextIndex = (current - 1 + direction) % #order + 1
    addon.setMode(order[nextIndex])
end
