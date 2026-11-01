local addonName, addon = ...
local locale = addon.locale
local button

local function position()
    local angle = math.rad(ChronixHealDB.minimapAngle or 225)
    local radiusX = Minimap:GetWidth() / 2 + 10
    local radiusY = Minimap:GetHeight() / 2 + 10
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radiusX, math.sin(angle) * radiusY)
end

function addon.createMinimap()
    if button then
        return
    end

    button = CreateFrame("Button", addonName .. "MinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\Spell_Nature_HealingWaveGreater")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", 0, 0)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:SetScript("OnClick", function(self, mouse)
        if mouse == "RightButton" then
            addon.settingsActions.restoreGrid()
        else
            addon.openSettings()
        end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(locale("STR_TITLE"), 1, 1, 1)
        GameTooltip:AddLine(locale("STR_MINIMAP_HINT"), 0.7, 0.85, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            local centerX, centerY = Minimap:GetCenter()
            ChronixHealDB.minimapAngle = math.deg(math.atan2(y / scale - centerY, x / scale - centerX))
            position()
        end)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    position()
end
