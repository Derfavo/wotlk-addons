local addonName, addon = ...
local events = CreateFrame("Frame")
local tips = {}
local cache, cacheCount = {}, 0
local profile, profileReason, profileDirty = nil, nil, true
local profileMap = {
    WARRIOR = { "WarriorArms", "WarriorFury", "WarriorTank" },
    PALADIN = { "PaladinHoly", "PaladinTank", "PaladinRetribution" },
    HUNTER = { "HunterBeastMastery", "HunterMarksman", "HunterSurvival" },
    ROGUE = { "RogueAssassination", "RogueCombat", "RogueSubtlety" },
    PRIEST = { "PriestDiscipline", "PriestHoly", "PriestShadow" },
    DEATHKNIGHT = { "DeathKnightBloodDps", "DeathKnightFrostDps", "DeathKnightUnholyDps" },
    SHAMAN = { "ShamanElemental", "ShamanEnhancement", "ShamanRestoration" },
    MAGE = { "MageArcane", "MageFire", "MageFrost" },
    WARLOCK = { "WarlockAffliction", "WarlockDemonology", "WarlockDestruction" },
    DRUID = { "DruidBalance", "DruidFeralDps", "DruidRestoration" },
}
local colors = { upgrade = {0.25,1,0.35}, small = {1,0.82,0},
    downgrade = {1,0.4,0.3}, review = {1,0.82,0}, neutral = {0.8,0.8,0.8},
    pending = {0.8,0.8,0.8} }

local function HasBuff(id)
    local wanted = GetSpellInfo(id)
    if not wanted then return false end
    for i = 1, 40 do
        local name = UnitBuff("player", i)
        if not name then break end
        if name == wanted then return true end
    end
    return false
end

local function Role()
    if GetPartyAssignment and GetPartyAssignment("MAINTANK", "player") then return "TANK" end
    if UnitGroupRolesAssigned then
        local tank, healer, damage = UnitGroupRolesAssigned("player")
        if type(tank) == "string" then return tank end
        if tank then return "TANK" elseif healer then return "HEALER" elseif damage then return "DAMAGER" end
    end
    return "NONE"
end

function addon.DetectProfile()
    if not PawnGetItemData or not PawnGetSingleValueFromItem or not PawnGetSlotsForItemType then
        return nil, "Bitte das bereits installierte Pawn ebenfalls aktivieren."
    end
    if PawnInitializePlugins then PawnInitializePlugins() end
    if RebuffedUpgradeDB and RebuffedUpgradeDB.scale then
        local name = RebuffedUpgradeDB.scale
        if PawnCommon and PawnCommon.Scales and PawnCommon.Scales[name] then return name end
        return nil, "Die gespeicherte Pawn-Skala fehlt. /upgrade auto verwenden."
    end
    local _, class = UnitClass("player")
    local best, points, tied = nil, 0, false
    for i = 1, 3 do
        local _, _, spent = GetTalentTabInfo(i)
        spent = spent or 0
        if spent > points then best, points, tied = i, spent, false
        elseif spent == points and spent > 0 then tied = true end
    end
    if not best or tied then return nil, "Skillung noch nicht eindeutig; zuerst Talente verteilen." end
    local key = profileMap[class] and profileMap[class][best]
    if class == "DRUID" and best == 2 then
        local role = Role()
        if role == "TANK" or HasBuff(5487) or HasBuff(9634) then key = "DruidFeralTank"
        elseif role ~= "DAMAGER" and not HasBuff(768) then
            return nil, "Feral: Tank oder Schaden unklar. Baeren-/Katzengestalt oder zugewiesene Rolle verwenden."
        end
    elseif class == "DEATHKNIGHT" and (Role() == "TANK" or HasBuff(48263)) then
        if best == 1 then key = "DeathKnightBloodTank"
        elseif best == 2 then key = "DeathKnightFrostTank"
        else return nil, "Fuer Unheilig-Tanks ist hier keine passende Pawn-Skala vorhanden." end
    elseif class == "DEATHKNIGHT" and Role() == "NONE" and not HasBuff(48266) and not HasBuff(48265) then
        return nil, "Todesritter: Rolle unklar. Praesenz aktivieren oder Pawn-Skala waehlen."
    end
    local name = key and PawnGetProviderScaleName("Wowhead", key)
    if name and PawnCommon and PawnCommon.Scales and PawnCommon.Scales[name]
        and PawnCommon.Scales[name].Values then return name end
    return nil, "Passendes Pawn-Profil nicht verfuegbar. /upgrade skalen zeigt deine Skalen."
end

local function RefreshProfile()
    if profileDirty then
        profile, profileReason = addon.DetectProfile()
        profileDirty = false
    end
end

local function ItemId(link)
    return link and link:match("item:(%d+)")
end

local function ItemInfo(link)
    local name, _, _, _, minLevel, _, _, _, location = GetItemInfo(link)
    if not name then return nil end
    return { name = name, minLevel = minLevel or 0, location = location }
end

local function Score(link, scale)
    if not link then return 0, false end
    local item = PawnGetItemData(link)
    if not item or not item.Stats or not item.UnenchantedStats then return nil end
    local value, unenchanted = PawnGetSingleValueFromItem(item, scale)
    local score = unenchanted or value
    if type(score) ~= "number" or score ~= score then return nil end
    return score, item.UnknownLines and #item.UnknownLines > 0 or false, item.Stats
end

local function Result(kind, title, detail, warning)
    return { kind = kind, title = title, detail = detail, warning = warning }
end

-- Local comparison only. No inspections, chat messages or automatic loot rolls.
function addon.Evaluate(link, scale, hints)
    hints = hints or {}
    local item = ItemInfo(link)
    if not item then return Result("pending", "Itemdaten werden geladen", "Kurz auf dem Item bleiben.") end
    local slot1, slot2 = PawnGetSlotsForItemType(item.location)
    if not slot1 or slot1 == 0 or slot1 == 4 or slot1 == 19 then return nil end
    if hints.equipped then return Result("neutral", "Bereits angelegt", "Dieses Item traegst du bereits.") end
    if item.minLevel > UnitLevel("player") then
        return Result("review", "Noch nicht tragbar", "Benoetigt Stufe " .. item.minLevel .. "; gegebenenfalls fuer spaeter behalten.")
    end
    local candidate, uncertain, candidateStats = Score(link, scale)
    if candidate == nil then return Result("pending", "Bewertung wird geladen", "Pawn benoetigt noch Itemdaten.") end
    if candidate <= 0 then return Result("downgrade", "Kein Nutzen laut Profil", "Fuer die aktuelle Skillung nicht als Upgrade einplanen.") end
    local _, class = UnitClass("player")
    local titan = class == "WARRIOR" and IsSpellKnown and IsSpellKnown(46917)
    if titan and item.location == "INVTYPE_2HWEAPON" and not
        (candidateStats.IsAxe or candidateStats.IsSword or candidateStats.IsMace) then
        return Result("review", "Titanengriff: Waffentyp pruefen", "Staebe und Stangenwaffen koennen nicht als Titanengriff-Nebenhand gewertet werden.")
    end
    local dual = IsSpellKnown and (IsSpellKnown(674) or IsSpellKnown(30798))
    if item.location == "INVTYPE_WEAPON" and not dual then slot2 = nil end
    if item.location == "INVTYPE_2HWEAPON" and titan then slot2 = 17 end
    local main = (slot1 == 16 or slot1 == 17) and GetInventoryItemLink("player", 16)
    local mainInfo = main and ItemInfo(main)
    if main and not mainInfo then return Result("pending", "Vergleichsdaten fehlen", "Daten der angelegten Waffe werden geladen.") end
    if titan and mainInfo and mainInfo.location == "INVTYPE_2HWEAPON" then
        local mainScore, _, mainStats = Score(main, scale)
        if mainScore == nil then return Result("pending", "Vergleichsdaten fehlen", "Waffentyp der Haupthand wird geladen.") end
        if not (mainStats.IsAxe or mainStats.IsSword or mainStats.IsMace) then
            return Result("review", "Waffenset-Wechsel: pruefen", "Die angelegte Zweihandwaffe erlaubt keinen direkten Titanengriff-Vergleich.")
        end
    end
    if (slot1 == 16 or slot1 == 17) and item.location ~= "INVTYPE_2HWEAPON"
        and mainInfo and mainInfo.location == "INVTYPE_2HWEAPON" and not titan then
        return Result("review", "Waffenset-Wechsel: pruefen", "Einhand plus Nebenhand muss mit der Zweihandwaffe gemeinsam verglichen werden.")
    end
    local current1, current2 = GetInventoryItemLink("player", slot1), slot2 and GetInventoryItemLink("player", slot2)
    if hints.unique then
        if ItemId(current1) == ItemId(link) or current2 and ItemId(current2) == ItemId(link) then
            return Result("neutral", "Bereits vorhanden", "Einzigartig angelegt: kein zweites Exemplar gleichzeitig anlegen.")
        end
    end
    local baseline, baselineUncertain = Score(current1, scale)
    if baseline == nil then return Result("pending", "Vergleichsdaten fehlen", "Angelegtes Item wird noch ausgewertet.") end
    local replaced = current1
    if item.location == "INVTYPE_2HWEAPON" and not titan then
        local offhand = GetInventoryItemLink("player", 17)
        local offScore, offUncertain = Score(offhand, scale)
        if offScore == nil then return Result("pending", "Vergleichsdaten fehlen", "Nebenhand wird noch ausgewertet.") end
        baseline = baseline + offScore
        baselineUncertain = baselineUncertain or offUncertain
        if offhand then replaced = (current1 or "Leere Haupthand") .. " + " .. offhand end
    elseif slot2 then
        local second, secondUncertain = Score(current2, scale)
        if second == nil then return Result("pending", "Vergleichsdaten fehlen", "Zweiter Ausruestungsplatz wird noch ausgewertet.") end
        if second < baseline then baseline, replaced, baselineUncertain = second, current2, secondUncertain end
    end
    local warning = "Setboni, Treffer-/Defensiv-Caps und spezielle Effekte selbst pruefen."
    local comparison = replaced and ("Vergleich: " .. replaced) or "Vergleich: leerer Ausruestungsplatz"
    if hints.red or hints.category or hints.set or uncertain or baselineUncertain then
        return Result("review", "Wertevergleich: erst pruefen", comparison,
            "Anforderungen, Setboni oder Effekte sind nicht vollstaendig bewertbar; kein sicheres Nehmen/Verzichten.")
    end
    local delta = candidate - baseline
    local percent = baseline > 0 and delta / baseline * 100 or nil
    local difference = percent and string.format("%+.1f%% Pawn-Wert", percent) or "Vergleichswert vorher: 0 Pawn-Punkte"
    if delta > 0.000001 then
        local small = percent and percent < 1
        return Result(small and "small" or "upgrade", small and "Kleines Upgrade - optional behalten" or "Upgrade - Nehmen/Behalten empfohlen",
            difference .. "; " .. comparison, warning)
    elseif delta < -0.000001 then
        return Result("downgrade", "Kein Upgrade - fuer diese Skillung verzichten", difference .. "; " .. comparison, warning)
    end
    return Result("neutral", "Gleichwertig - kein klares Upgrade", comparison, warning)
end

local function Hints(tip)
    local hints = {}
    local originalLines = tip.RULines and tip.RULines[1]-2 or tip:NumLines()
    for i = 1, originalLines do
        for _, side in ipairs({"Left", "Right"}) do
            local line = _G[tip:GetName() .. "Text" .. side .. i]
            local text = line and line:GetText()
            if text then
                if text == ITEM_CURRENTLY_EQUIPPED then hints.equipped = true end
                if text:find("Einzigartig",1,true) or text:find("Unique",1,true) then hints.unique = true end
                if text:find("Einzigartig angelegt:",1,true) or text:find("Unique-Equipped:",1,true) then hints.category = true end
                if text:match("%(%d+/%d+%)") then hints.set = true end
                local r,g,b = line:GetTextColor()
                if r and r > 0.8 and g < 0.3 and b < 0.3 then hints.red = true end
            end
        end
    end
    return hints
end

local function Queue(tip)
    local _, link = tip:GetItem()
    if not link or not ItemId(link) then return end
    tip.RURequest = { link = link, hints = Hints(tip), due = GetTime() + 0.05, deadline = GetTime() + 2 }
end

local function Render(tip, result)
    local color = colors[result.kind] or colors.neutral
    local name = profile and PawnGetScaleLocalizedName(profile) or "Automatische Skillung"
    local lines = { "Upgrade-Hilfe: " .. result.title, "Profil: " .. name, result.detail or "",
        result.warning or "Vergleich ohne Verzauberungen, Sockel nach Pawn." }
    if not tip.RULines then
        tip:AddLine(" ")
        tip.RULines = {}
        for i,text in ipairs(lines) do
            tip:AddLine(text,1,1,1,true)
            tip.RULines[i] = tip:NumLines()
        end
    end
    for i,text in ipairs(lines) do
        local line = _G[tip:GetName() .. "TextLeft" .. tip.RULines[i]]
        if line then
            line:SetText(text)
            if i == 1 then line:SetTextColor(color[1],color[2],color[3]) else line:SetTextColor(0.85,0.85,0.85) end
        end
    end
    tip:Show()
end

local function Tick(tip)
    if tip.RURendering then return end
    local request = tip.RURequest
    if not request or not tip:IsShown() or GetTime() < request.due then return end
    local _, link = tip:GetItem()
    if link ~= request.link then tip.RURequest = nil; return end
    RefreshProfile()
    local result
    if not profile then
        result = Result("review", "Keine sichere Bewertung", profileReason)
    else
        local key = link .. "\031" .. profile
        for _,hint in ipairs({"equipped","unique","category","red","set"}) do
            key = key .. (request.hints[hint] and ("\031" .. hint) or "")
        end
        result = cache[key]
        if not result then
            local ok, answer = pcall(addon.Evaluate, link, profile, request.hints)
            result = ok and answer or Result("review", "Bewertung nicht verfuegbar", "Pawn-Einstellungen und Itemdaten pruefen.")
            if result and result.kind ~= "pending" then
                if cacheCount >= 128 then cache,cacheCount = {},0 end
                cache[key],cacheCount = result,cacheCount+1
            end
        end
    end
    if result and result.kind == "pending" and GetTime() >= request.deadline then
        result = Result("review", "Itemdaten noch nicht verfuegbar", "Spaeter erneut mit der Maus ueber das Item fahren.")
    end
    if result then
        tip.RURendering = true
        Render(tip,result)
        tip.RURendering = nil
    end
    if result and result.kind == "pending" and GetTime() < request.deadline then
        request.due = GetTime() + 0.3
    else
        tip.RURequest = nil
    end
end

-- Auctionator refreshes some tooltips every 0.2s. Finish our annotation in the
-- same setter call, after Pawn/Auctionator have added their own lines, so the
-- tooltip never spends a rendered frame at its shorter, unannotated height.
local function AfterItemSetter(tip)
    if tip.RURendering then return end
    if not tip.RURequest and not tip.RULines then Queue(tip) end
    if tip.RURequest then
        tip.RURequest.due = GetTime()
        Tick(tip)
    end
end

local function Invalidate()
    cache,cacheCount,profileDirty = {},0,true
    for _, tip in ipairs(tips) do
        if tip:IsShown() then Queue(tip) end
    end
end

for _, name in ipairs({"GameTooltip","ItemRefTooltip"}) do
    local tip = _G[name]
    if tip then
        tips[#tips+1] = tip
        tip:HookScript("OnTooltipSetItem",Queue)
        tip:HookScript("OnTooltipCleared",function(self) self.RURequest,self.RULines = nil,nil end)
        tip:HookScript("OnHide",function(self) self.RURequest = nil end)
        tip:HookScript("OnUpdate",Tick)
        if hooksecurefunc then
            for _, method in ipairs({"SetHyperlink","SetBagItem","SetInventoryItem","SetMerchantItem",
                "SetAuctionItem","SetAuctionSellItem","SetLootItem","SetLootRollItem","SetQuestItem",
                "SetQuestLogItem","SetTradeSkillItem","SetGuildBankItem","SetInboxItem","SetSendMailItem",
                "SetTradePlayerItem","SetTradeTargetItem","SetSocketedItem","SetSocketGem","SetExistingSocketGem"}) do
                if type(tip[method]) == "function" then hooksecurefunc(tip,method,AfterItemSetter) end
            end
        end
    end
end
if PawnResetTooltips and hooksecurefunc then hooksecurefunc("PawnResetTooltips",Invalidate) end
for _, event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","PLAYER_EQUIPMENT_CHANGED","PLAYER_TALENT_UPDATE",
    "ACTIVE_TALENT_GROUP_CHANGED","SPELLS_CHANGED","PLAYER_ROLES_ASSIGNED","RAID_ROSTER_UPDATE","PARTY_MEMBERS_CHANGED",
    "PLAYER_LEVEL_UP","SKILL_LINES_CHANGED","UNIT_INVENTORY_CHANGED","UPDATE_SHAPESHIFT_FORM"}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent",function(self,event,unit)
    if event == "UNIT_INVENTORY_CHANGED" and unit ~= "player" then return end
    RebuffedUpgradeDB = RebuffedUpgradeDB or {}
    Invalidate()
end)

SLASH_REBUFFEDUPGRADE1 = "/upgrade"
SlashCmdList.REBUFFEDUPGRADE = function(message)
    RebuffedUpgradeDB = RebuffedUpgradeDB or {}
    local command, argument = message:match("^(%S*)%s*(.-)%s*$")
    if command == "auto" then RebuffedUpgradeDB.scale = nil; Invalidate()
    elseif command == "skala" and argument ~= "" then
        if PawnInitializePlugins then PawnInitializePlugins() end
        if PawnCommon and PawnCommon.Scales and PawnCommon.Scales[argument] then
            RebuffedUpgradeDB.scale = argument; Invalidate()
        else DEFAULT_CHAT_FRAME:AddMessage("Upgrade-Hilfe: Skala nicht gefunden. /upgrade skalen"); return end
    elseif command == "skalen" then
        if PawnInitializePlugins then PawnInitializePlugins() end
        local names = {}
        for name in pairs(PawnCommon and PawnCommon.Scales or {}) do names[#names+1] = name end
        table.sort(names)
        for _,name in ipairs(names) do DEFAULT_CHAT_FRAME:AddMessage(name) end
        return
    end
    RefreshProfile()
    DEFAULT_CHAT_FRAME:AddMessage("Upgrade-Hilfe: " .. (profile and PawnGetScaleLocalizedName(profile) or profileReason or "nicht bereit"))
end
