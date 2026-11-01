-- WoW 3.3.5a (12340). No modern C_Item/C_Timer APIs required.
local addon = CreateFrame("Frame")
local slots = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
local cache = {}
local pending
local lastRequest = -10
local ownRequest = false
local elapsedTotal = 0
local characterLabel, inspectLabel
local hoverGUID, attemptedGUID
local playerDirty = true
local playerNextRetry = 0
local playerRetryUntil = 0
local CACHE_SECONDS = 600
local REQUEST_SECONDS = 2
local TIMEOUT_SECONDS = 5

-- Traditional GearScoreLite weighting and calibration, without enchant penalties.
-- Reference: github.com/Arcitec/GearScoreLite_Reborn (GearScoreLite 3x05).
local scoreWeights = {
    INVTYPE_HEAD = 1, INVTYPE_NECK = 0.5625, INVTYPE_SHOULDER = 0.75,
    INVTYPE_CHEST = 1, INVTYPE_ROBE = 1, INVTYPE_WAIST = 0.75,
    INVTYPE_LEGS = 1, INVTYPE_FEET = 0.75, INVTYPE_WRIST = 0.5625,
    INVTYPE_HAND = 0.75, INVTYPE_FINGER = 0.5625, INVTYPE_TRINKET = 0.5625,
    INVTYPE_CLOAK = 0.5625, INVTYPE_WEAPON = 1, INVTYPE_WEAPONMAINHAND = 1,
    INVTYPE_WEAPONOFFHAND = 1, INVTYPE_SHIELD = 1, INVTYPE_HOLDABLE = 1,
    INVTYPE_2HWEAPON = 2, INVTYPE_RANGED = 0.3164, INVTYPE_RANGEDRIGHT = 0.3164,
    INVTYPE_THROWN = 0.3164, INVTYPE_RELIC = 0.3164,
}
local scoreHigh = { [2] = {73, 1}, [3] = {81.375, 0.8125}, [4] = {91.45, 0.65} }
local scoreLow = { [2] = {8, 2}, [3] = {0.75, 1.8}, [4] = {26, 1.2} }

local function ItemScore(quality, level, equipType)
    local scale = 1
    if quality == 5 then
        quality, scale = 4, 1.3
    elseif quality == 0 or quality == 1 then
        quality, scale = 2, 0.005
    elseif quality == 7 then
        quality, level = 3, 187.05
    end
    local weight = scoreWeights[equipType]
    local calibration = (level > 120 and scoreHigh or scoreLow)[quality]
    if not weight or not calibration then return 0 end
    return math.max(0, math.floor((level - calibration[1]) / calibration[2] * weight * 1.8618 * scale))
end

local function IsPlayer(unit)
    return unit and UnitExists(unit) and UnitIsPlayer(unit)
end

local function InspectOpen()
    return InspectFrame and InspectFrame:IsShown()
end

-- Empty equipment slots count as zero. Shirts and tabards do not count.
-- A two-handed weapon fills an empty off-hand for this average (17 slots).
local function Calculate(unit)
    local total, count, gearScore = 0, 0, 0
    local mainLevel, mainType, offType, offhand
    local mainScore, offScore = 0, 0
    local _, class = UnitClass(unit)
    for _, slot in ipairs(slots) do
        local link = GetInventoryItemLink(unit, slot)
        if link then
            local _, _, quality, level, _, _, _, _, equipType = GetItemInfo(link)
            if not level or quality == nil or not equipType then return nil end
            total = total + level
            count = count + 1
            local score = ItemScore(quality, level, equipType)
            if slot == 16 then
                mainLevel, mainType, mainScore = level, equipType, score
            elseif slot == 17 then
                offhand, offType, offScore = true, equipType, score
            else
                gearScore = gearScore + score * (slot == 18 and class == "HUNTER" and 5.3224 or 1)
            end
        elseif GetInventoryItemTexture(unit, slot) then
            return nil -- Equipped, but the server has not sent the link yet.
        end
    end
    if mainType == "INVTYPE_2HWEAPON" and not offhand then
        total = total + mainLevel
    end
    local weaponScale = offhand and (mainType == "INVTYPE_2HWEAPON" or offType == "INVTYPE_2HWEAPON") and 0.5 or 1
    local hunterScale = class == "HUNTER" and 0.3164 or 1
    gearScore = gearScore + (mainScore + offScore) * weaponScale * hunterScale
    return total / #slots, count, math.floor(gearScore)
end

local function Store(unit)
    local guid = UnitGUID(unit)
    if not guid then return false end
    local level, _, score = Calculate(unit)
    if level == nil then return false end
    cache[guid] = { level = level, text = string.format("%.1f", level),
        score = tostring(score), time = GetTime() }
    return true
end

local function UpdatePlayer()
    if not playerDirty or GetTime() < playerNextRetry then return end
    if Store("player") then
        playerDirty = false
    else
        playerNextRetry = GetTime() + 0.5
        if GetTime() > playerRetryUntil then playerDirty = false end
    end
end

local function Value(unit)
    local entry = cache[UnitGUID(unit)]
    if not entry then return nil end
    local stale = not UnitIsUnit(unit, "player") and GetTime() - entry.time > CACHE_SECONDS
    local suffix = stale and "*" or ""
    return entry.text .. suffix, entry.score .. suffix
end

-- Read-only access for our chat addon; never starts an inventory scan/inspection.
function RebuffedItemLevel_GetPlayerGearScore()
    local guid = UnitGUID("player")
    local entry = guid and cache[guid]
    return entry and tonumber(entry.score) or nil
end

local function Release()
    local clear = pending and pending.owned and not InspectOpen()
    pending = nil
    if clear then ClearInspectPlayer() end
end

local function CanRequest(unit)
    return IsPlayer(unit) and not UnitIsUnit(unit, "player")
        and not InCombatLockdown() and CanInspect(unit)
        and CheckInteractDistance(unit, 1)
end

local function Request(unit)
    local guid = UnitGUID(unit)
    if not guid or UnitIsUnit(unit, "player") or attemptedGUID == guid then return end
    local entry = cache[guid]
    if entry and GetTime() - entry.time <= CACHE_SECONDS then return end
    if pending or GetTime() - lastRequest < REQUEST_SECONDS then return end
    if not CanRequest(unit) or InspectOpen() then return end
    -- At most one automatic request during this hover, even after a timeout.
    attemptedGUID = guid
    ownRequest = true
    NotifyInspect(unit)
    ownRequest = false
end

-- Observe all inspection requests, including Blizzard's and other addons'.
-- A newer request replaces ours, so its response cannot be assigned to our target.
hooksecurefunc("NotifyInspect", function(unit)
    lastRequest = GetTime()
    if IsPlayer(unit) then
        pending = { unit = unit, guid = UnitGUID(unit), started = lastRequest,
            ready = false, owned = ownRequest }
    else
        pending = nil
    end
end)
hooksecurefunc("ClearInspectPlayer", function() pending = nil end)

local function MakeLabel(parent, anchor, offset)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOP", anchor or parent, "BOTTOM", 0, offset or -3)
    label:SetTextColor(1, 0.82, 0)
    return label
end

local function SetupFrames()
    if PaperDollFrame and CharacterLevelText and not characterLabel then
        -- A font string on PaperDollFrame is covered by the child PlayerModel.
        -- Use a small, non-interactive frame above the model's rendering level.
        local badge = CreateFrame("Frame", nil, PaperDollFrame)
        badge:SetWidth(174)
        badge:SetHeight(16)
        badge:SetPoint("TOP", CharacterTitleDropDown or CharacterLevelText,
            "BOTTOM", 0, CharacterTitleDropDown and 0 or -26)
        badge:SetFrameLevel(math.max(PaperDollFrame:GetFrameLevel(),
            CharacterModelFrame and CharacterModelFrame:GetFrameLevel() or 0) + 10)
        badge:EnableMouse(false)
        badge:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        badge:SetBackdropColor(0, 0, 0, 0.8)
        characterLabel = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        characterLabel:SetPoint("CENTER", badge, "CENTER", 0, 0)
        characterLabel:SetTextColor(1, 0.82, 0)
    end
    if InspectPaperDollFrame and InspectLevelText and not inspectLabel then
        inspectLabel = MakeLabel(InspectPaperDollFrame, InspectLevelText)
    end
end

local function WindowText(unit, compact)
    local level, score = Value(unit)
    return (compact and "iLvl: " or "Itemlevel: ") .. (level or "...") .. " | GS: " .. (score or "...")
end

local function UpdateWindows()
    if characterLabel and PaperDollFrame:IsShown() then
        local text = WindowText("player", true)
        if characterLabel.RILText ~= text then
            characterLabel:SetText(text)
            characterLabel.RILText = text
        end
    end
    if inspectLabel and InspectOpen() and IsPlayer(InspectFrame.unit) then
        local unit = InspectFrame.unit
        local text = WindowText(unit)
        if inspectLabel.RILText ~= text then
            inspectLabel:SetText(text)
            inspectLabel.RILText = text
        end
    end
end

local function TooltipUnit()
    if not GameTooltip:IsShown() then return nil end
    local _, unit = GameTooltip:GetUnit()
    if IsPlayer(unit) then return unit end
end

local function UpdateTooltip()
    local unit = TooltipUnit()
    if not unit then
        hoverGUID, attemptedGUID = nil, nil
        return
    end
    local line = GameTooltipTextLeft1
    if not line then return end
    local guid = UnitGUID(unit)
    if hoverGUID ~= guid then
        hoverGUID, attemptedGUID = guid, nil
    end
    local current = line:GetText()
    if not current then return end
    if GameTooltip.RILGuid ~= guid or current ~= GameTooltip.RILRendered then
        GameTooltip.RILBase = current
    end
    GameTooltip.RILGuid = guid
    local value, score = Value(unit)
    local waiting = pending and pending.guid == guid
    local status = value or ((waiting or attemptedGUID ~= guid and CanRequest(unit)) and "..." or "?")
    local rendered = GameTooltip.RILBase .. " |cffffd100[iLvl " .. status .. " | GS " .. (score or status) .. "]|r"
    if current ~= rendered then
        line:SetText(rendered)
        GameTooltip.RILRendered = rendered
        GameTooltip:Show() -- Resize for the added name suffix.
    end
    Request(unit)
end

GameTooltip:HookScript("OnTooltipCleared", function(self)
    self.RILGuid, self.RILBase, self.RILRendered = nil, nil, nil
end)
GameTooltip:HookScript("OnTooltipSetUnit", UpdateTooltip)
GameTooltip:HookScript("OnHide", function()
    hoverGUID, attemptedGUID = nil, nil
end)

addon:RegisterEvent("PLAYER_ENTERING_WORLD")
addon:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
addon:RegisterEvent("UNIT_INVENTORY_CHANGED")
addon:RegisterEvent("INSPECT_TALENT_READY")
addon:RegisterEvent("ADDON_LOADED")
addon:SetScript("OnEvent", function(self, event, unit)
    if event == "ADDON_LOADED" or event == "PLAYER_ENTERING_WORLD" then
        SetupFrames()
    end
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_EQUIPMENT_CHANGED"
        or (event == "UNIT_INVENTORY_CHANGED" and unit == "player") then
        local guid = UnitGUID("player")
        if guid then cache[guid] = nil end
        playerDirty = true
        playerNextRetry = 0
        playerRetryUntil = GetTime() + 10
        UpdatePlayer()
    end
    if pending then
        if event == "INSPECT_TALENT_READY" then
            pending.ready = true
        elseif event == "UNIT_INVENTORY_CHANGED" and unit
            and UnitGUID(unit) == pending.guid then
            pending.ready = true
        end
    end
    UpdateWindows()
end)

addon:SetScript("OnUpdate", function(self, elapsed)
    if not playerDirty and not pending and not GameTooltip:IsShown()
        and not (PaperDollFrame and PaperDollFrame:IsShown()) and not InspectOpen() then
        return
    end
    elapsedTotal = elapsedTotal + elapsed
    if elapsedTotal < 0.2 then return end
    elapsedTotal = 0
    if pending then
        if not IsPlayer(pending.unit) or UnitGUID(pending.unit) ~= pending.guid
            or GetTime() - pending.started > TIMEOUT_SECONDS then
            Release()
        elseif pending.ready and Store(pending.unit) then
            Release()
        end
    end
    UpdatePlayer()
    UpdateWindows()
    UpdateTooltip()
end)

SetupFrames()
