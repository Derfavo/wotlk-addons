local addonName, addon = ...

-- Persistent self-buffs only: no short rotation effects or cooldowns.
function addon.getSelfBuffTree()
    if not GetTalentTabInfo then return 0 end
    local best, spent, tied = 0, 0, false
    for index = 1, 3 do
        local _, _, points = GetTalentTabInfo(index, false, false)
        points = points or 0
        if points > spent then best, spent, tied = index, points, false
        elseif points > 0 and points == spent then tied = true end
    end
    return tied and 0 or best
end

function addon.getSelfBuffDefinitions(class, tree)
    tree = tree or addon.getSelfBuffTree()
    local function buff(ids, alternatives, charges)
        return {ids = ids, alternatives = alternatives, charges = charges}
    end
    local function weapon(ids, slot)
        return {ids = ids, weapon = slot}
    end
    if class == "SHAMAN" then
        local shield = tree == 2 and {324, 52127} or {52127, 324}
        local main = tree == 2 and {8232, 8024, 8017} or tree == 1 and {8024, 51730, 8017} or {51730, 8024, 8017}
        local result = {buff(shield, nil, true), weapon(main, 16)}
        result[1].exact = true
        if tree == 2 then result[#result+1] = weapon({8024, 8232, 8017}, 17) end
        return result
    elseif class == "ROGUE" then
        if UnitLevel and UnitLevel("player") < 20 then return {} end
        return {
            {weapon = 16, items = {43231,43230,21927,8928,8927,8926,6950,6949,6947}},
            {weapon = 17, items = {43233,43232,22054,22053,20844,8985,8984,2893,2892}},
        }
    elseif class == "PRIEST" then
        local result = {buff({588},nil,true), buff({1243},{21562}), buff({14752},{27681}), buff({976},{27683})}
        if tree == 3 then result[#result+1] = buff({15473}); result[#result+1] = buff({15286}) end
        return result
    elseif class == "PALADIN" then
        local seals = tree == 1 and {20166,20165,21084} or {31801,53736,20375,21084,20166}
        local aura = tree == 1 and {19746,465,7294} or tree == 2 and {465,19746,7294} or {7294,465,19746}
        local blessing = tree == 1 and {19742,20217,19740} or tree == 2 and {20911,20217,19740} or {19740,20217,19742}
        local result = {
            buff(seals,{20166,20165,21084,31801,53736,20375,20164}),
            buff(aura,{19746,465,7294,19876,19888,19891,32223}),
            buff(blessing,{19742,20217,19740,20911,25894,25898,25782,25899}),
        }
        if tree == 2 then result[#result+1] = buff({25780}) end
        return result
    elseif class == "MAGE" then
        return {buff(tree == 1 and {6117,30482,7302,168} or {30482,6117,7302,168}), buff({1459},{23028,61024,61316})}
    elseif class == "WARLOCK" then
        return {buff({28176,706,687}), {ids = {19028}, alternatives = {25228}, pet = true}}
    elseif class == "DRUID" then
        local result = {buff({1126},{21849})}
        if tree == 2 then result[#result+1] = buff({467}) end
        return result
    elseif class == "WARRIOR" then
        return {buff(tree == 3 and {469,6673} or {6673,469})}
    elseif class == "HUNTER" then
        return {buff({61846,13165,13163},{34074,5118,13159,13161,20043}), buff({19506})}
    elseif class == "DEATHKNIGHT" then
        local tank = false
        if UnitGroupRolesAssigned then
            local role = UnitGroupRolesAssigned("player")
            tank = role == true or role == "TANK"
        end
        return {buff(tank and {48263,48266,48265} or {48266,48265,48263}), buff({57330})}
    end
    return {}
end

addon.profiles = {
    SHAMAN = {
        healer = true,
        resurrection = { 2008, 49277 },
        spells = {
            lesser = { 8004 }, wave = { 331 }, riptide = { 61295 }, chain = { 1064 },
            cleanse = { 51886, 526 }, earth = { 974 }, nature = { 16188 }, mana = { 16190 },
        },
        dispels = {
            [51886] = { Poison = true, Disease = true, Curse = true },
            [526] = { Poison = true, Disease = true },
        },
        urgent = { "riptide", "lesser", "wave" },
        groupHeal = true,
        focusBuffs = { "earth" },
    },
    PALADIN = {
        healer = true,
        resurrection = { 7328, 48950 },
        spells = {
            lesser = { 19750 }, wave = { 635 }, riptide = { 20473 }, chain = { 53563 },
            cleanse = { 4987, 1152 }, earth = { 53601 }, emergency = { 633 },
            defensive = { 642 }, mana = { 54428 },
        },
        dispels = {
            [4987] = { Poison = true, Disease = true, Magic = true },
            [1152] = { Poison = true, Disease = true },
        },
        urgent = { "riptide", "lesser", "wave" },
        focusBuffs = { "chain", "earth" },
    },
    PRIEST = {
        healer = true,
        resurrection = { 2006, 48171 },
        spells = {
            lesser = { 2061 }, wave = { 2060, 2054, 2050 }, riptide = { 139 }, chain = { 596 },
            cleanse = { 527 }, toxins = { 552, 528 }, earth = { 17 }, emergency = { 47788, 33206 },
            special = { 47540 }, mending = { 33076 }, area = { 34861 },
            channel = { 64843 }, mana = { 64901 },
        },
        dispels = {
            [527] = { Magic = true }, [552] = { Disease = true }, [528] = { Disease = true },
        },
        urgent = { "earth", "lesser", "wave" },
        groupHeal = true,
        groupOnly = true,
        instantIsHot = true,
        shield = true,
    },
    DRUID = {
        healer = true,
        resurrection = { 50769 },
        combatResurrection = { 20484 },
        spells = {
            lesser = { 50464, 8936 }, wave = { 5185 }, riptide = { 18562 }, chain = { 48438 },
            cleanse = { 2782 }, toxins = { 2893, 8946 }, earth = { 774 }, nature = { 17116 },
            special = { 8936 }, mending = { 33763 }, defensive = { 22812 },
            channel = { 740 }, mana = { 29166 },
        },
        dispels = {
            [2782] = { Curse = true }, [2893] = { Poison = true }, [8946] = { Poison = true },
        },
        urgent = { "riptide", "lesser", "wave" },
        groupHeal = true,
        swiftmend = true,
        maintenanceIsHot = true,
    },
    MAGE = {
        spells = { cleanse = { 475 } },
        dispels = { [475] = { Curse = true } },
        urgent = {},
    },
}

for class, profile in pairs(addon.profiles) do
    profile.class = class
end

local defaultSpecs = { SHAMAN = "restoration", PALADIN = "holy", PRIEST = "holy", DRUID = "restoration" }
local trees = {
    SHAMAN = { "support", "support", "restoration" },
    PALADIN = { "holy", "protection", "support" },
    PRIEST = { "discipline", "holy", "support" },
    DRUID = { "support", "support", "restoration" },
}

function addon.detectSpec(class)
    if not trees[class] or not GetTalentTabInfo then
        return defaultSpecs[class] or "none"
    end

    local best, spent = 0, 0
    for index = 1, 3 do
        local name, icon, points = GetTalentTabInfo(index)
        if (points or 0) > spent then
            best, spent = index, points
        end
    end
    return trees[class][best] or "support"
end

function addon.selectProfile(class, spec)
    local base = addon.profiles[class] or { spells = {}, dispels = {}, urgent = {} }
    local profile = {}
    for key, value in pairs(base) do
        profile[key] = value
    end
    profile.class = class
    profile.spec = spec or defaultSpecs[class] or "none"
    addon.profile = profile
    addon.class = class
end
