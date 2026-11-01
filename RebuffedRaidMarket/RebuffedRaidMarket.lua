local M = RebuffedRaidMarket
local engine = CreateFrame("Frame")
local window, minimap, input, status, scroll
local widgets, rows, filterButtons = {}, {}, {}
local filter, dirty, watchedEvent = "Alle", true, nil
local ROW_HEIGHT, VISIBLE = 24, 13
local sources = {
    g = "CHAT_MSG_GUILD", guild = "CHAT_MSG_GUILD", gilde = "CHAT_MSG_GUILD",
    p = "CHAT_MSG_PARTY", party = "CHAT_MSG_PARTY", gruppe = "CHAT_MSG_PARTY",
    s = "CHAT_MSG_SAY", say = "CHAT_MSG_SAY", sagen = "CHAT_MSG_SAY",
    raid = "CHAT_MSG_RAID", schlachtzug = "CHAT_MSG_RAID",
    trade = "CHAT_MSG_CHANNEL", handel = "CHAT_MSG_CHANNEL",
}
local function Print(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Raid & Markt:|r " .. text)
end

function M.SourceEvent(source)
    return sources[M.Normalize(source):gsub("^/", "")] or "CHAT_MSG_CHANNEL"
end

function M.Matches(event, channelText, number, baseName)
    local source = M.Normalize(RebuffedRaidMarketDB.channel):gsub("^/", "")
    if event ~= M.SourceEvent(source) then return false end
    if event ~= "CHAT_MSG_CHANNEL" then return true end
    local wanted = tonumber(source)
    if wanted then return tonumber(number) == wanted end
    local base = M.Normalize(baseName)
    local full = M.Normalize(channelText):gsub("^%d+%.%s*", "")
    if source == "trade" or source == "handel" then
        return base == "trade" or base == "handel" or full:match("^trade%s*%-") ~= nil
            or full:match("^handel%s*%-") ~= nil or full == "trade" or full == "handel"
    end
    return base == source or full == source
end

local function Watch()
    if watchedEvent then engine:UnregisterEvent(watchedEvent) end
    -- Raid leader messages are a separate event in the 3.3.5 client.
    engine:UnregisterEvent("CHAT_MSG_RAID_LEADER")
    watchedEvent = M.SourceEvent(RebuffedRaidMarketDB.channel)
    engine:RegisterEvent(watchedEvent)
    if watchedEvent == "CHAT_MSG_RAID" then engine:RegisterEvent("CHAT_MSG_RAID_LEADER") end
end

local function SetSource(value)
    value = M.Clean(value)
    if value == "" or #value > 64 or value:find("[,;]") then
        Print("Bitte genau einen Kanalnamen, eine Kanalnummer oder g / p / raid / s eingeben.")
        return false
    end
    local number = tonumber(value)
    if number and (number < 1 or number > 99 or number ~= math.floor(number)) then
        Print("Kanalnummer muss zwischen 1 und 99 liegen.")
        return false
    end
    if RebuffedRaidMarketDB.channel ~= value then M.entries = {} end
    RebuffedRaidMarketDB.channel = value
    Watch()
    if input then input:SetText(value); input:ClearFocus() end
    if scroll then FauxScrollFrame_SetOffset(scroll, 0) end
    dirty = true
    return true
end

local function Whisper(author)
    if author and author ~= "" then ChatFrame_SendTell(author) end
end

local function Render()
    if not window or not window:IsShown() then dirty = true; return end
    rows = M.Rows(filter, GetTime())
    local maxOffset = math.max(0, #rows - VISIBLE)
    local offset = math.min(FauxScrollFrame_GetOffset(scroll), maxOffset)
    FauxScrollFrame_SetOffset(scroll, offset)
    FauxScrollFrame_Update(scroll, #rows, VISIBLE, ROW_HEIGHT)
    for i, row in ipairs(widgets) do
        local data = rows[offset + i]
        if row.entry ~= (data and data.entry) and row.hoveredItem then
            row.hoveredItem = nil; GameTooltip:Hide()
        end
        row.entry = data and data.entry
        if data then
            row:Show()
            if data.header then
                row.name:SetText("")
                local html = M.HTML(data.header .. " (" .. data.count .. ")")
                if row.message.RRMText ~= html then row.message:SetText(html); row.message.RRMText = html end
                row.age:SetText("")
                row.shade:SetTexture(0.25, 0.2, 0.08, 0.85)
            else
                local e = data.entry
                row.name:SetText(e.author)
                local html = M.HTML(e.linkedMessage or e.message)
                if row.message.RRMText ~= html then row.message:SetText(html); row.message.RRMText = html end
                row.age:SetText(math.floor((GetTime() - e.time) / 60) .. "m")
                row.shade:SetTexture(0.1, 0.1, 0.13, i % 2 == 0 and 0.65 or 0.3)
            end
        else row:Hide() end
    end
    status:SetText("Kanal: " .. RebuffedRaidMarketDB.channel .. "  |  " .. #M.entries
        .. " Anzeigen  |  Ablauf: 15 Min.  |  Klick: Flüstern")
    if #rows == 0 then window.empty:Show() else window.empty:Hide() end
    for category, button in pairs(filterButtons) do
        if category == filter then button:Disable() else button:Enable() end
    end
    dirty = false
end

local function Button(parent, label, width, x, y, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetWidth(width); b:SetHeight(22)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetText(label); b:SetScript("OnClick", onClick)
    return b
end

local function MakeWindow()
    window = CreateFrame("Frame", "RebuffedRaidMarketWindow", UIParent)
    window:SetWidth(690); window:SetHeight(490)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:SetMovable(true); window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32,
        edgeSize = 32, insets = {left = 11, right = 12, top = 12, bottom = 11}})
    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -20); title:SetText("Raid & Markt")
    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)
    close:SetScript("OnClick", function() window:Hide() end)
    tinsert(UISpecialFrames, "RebuffedRaidMarketWindow")
    local label = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 20, -56); label:SetText("Chatkanal:")
    input = CreateFrame("EditBox", "RebuffedRaidMarketChannelInput", window, "InputBoxTemplate")
    input:SetWidth(175); input:SetHeight(22); input:SetPoint("TOPLEFT", 100, -50)
    input:SetAutoFocus(false); input:SetMaxLetters(64); input:SetText(RebuffedRaidMarketDB.channel)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    input:SetScript("OnEnterPressed", function(self) if SetSource(self:GetText()) then Render() end end)
    Button(window, "Übernehmen", 110, 290, -50, function()
        if SetSource(input:GetText()) then Render() end
    end)
    Button(window, "Liste leeren", 110, 414, -50, function()
        M.entries = {}; FauxScrollFrame_SetOffset(scroll, 0); dirty = true; Render()
    end)
    Button(window, "Eigene Anzeige", 130, 540, -50, function() M.OpenPoster() end)
    local help = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", 20, -81)
    help:SetText("Name oder Nummer, z. B. world / 4 / Handel / g / p / raid. Kanal vorher beitreten.")
    for index, category in ipairs({"Alle", "Raids", "Kaufen", "Verkaufen"}) do
        local selected = category
        filterButtons[category] = Button(window, category, 105, 20 + (index - 1) * 114, -103, function()
            filter = selected; FauxScrollFrame_SetOffset(scroll, 0); dirty = true; Render()
        end)
    end
    scroll = CreateFrame("ScrollFrame", "RebuffedRaidMarketScroll", window, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 18, -136); scroll:SetPoint("BOTTOMRIGHT", -34, 40)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, Render)
    end)
    local function Wheel(self, delta)
        local offset = math.max(0, math.min(math.max(0, #rows - VISIBLE),
            FauxScrollFrame_GetOffset(scroll) - delta * 3))
        RebuffedRaidMarketScrollScrollBar:SetValue(offset * ROW_HEIGHT)
    end
    scroll:EnableMouseWheel(true); scroll:SetScript("OnMouseWheel", Wheel)
    for i = 1, VISIBLE do
        local row = CreateFrame("Button", nil, window)
        row:SetWidth(630); row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 20, -136 - (i - 1) * ROW_HEIGHT)
        row.shade = row:CreateTexture(nil, "BACKGROUND"); row.shade:SetAllPoints()
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.name:SetPoint("LEFT", 5, 0); row.name:SetWidth(125); row.name:SetJustifyH("LEFT")
        -- SimpleHTML can draw wrapped lines beyond its own height. A ScrollFrame
        -- clips both rendering and link hit areas to this row's preview.
        row.preview = CreateFrame("ScrollFrame", nil, row)
        row.preview:SetPoint("LEFT", 135, 0)
        row.preview:SetWidth(455); row.preview:SetHeight(16)
        row.message = CreateFrame("SimpleHTML", nil, row.preview)
        -- SimpleHTML accepts fonts for text blocks, never the inline "a" tag.
        -- Set its default font so both body text and links inherit a valid font.
        row.message:SetFontObject("GameFontHighlightSmall")
        row.message:SetHyperlinksEnabled(true)
        row.message:EnableMouse(true)
        row.message:SetSpacing(8)
        row.message:SetPoint("TOPLEFT", 0, 0)
        row.message:SetWidth(455); row.message:SetHeight(16)
        row.preview:SetScrollChild(row.message)
        row.age = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        row.age:SetPoint("RIGHT", -4, 0)
        row:SetScript("OnClick", function(self) if self.entry then Whisper(self.entry.author) end end)
        row:SetScript("OnEnter", function(self)
            if not self.entry then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.entry.author, 1, 0.82, 0)
            GameTooltip:AddLine(M.Display(self.entry.message), 1, 1, 1, true)
            GameTooltip:AddLine("Klicken: Flüsternachricht öffnen", 0.3, 1, 0.3)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.message:SetScript("OnEnter", function() row:GetScript("OnEnter")(row) end)
        row.message:SetScript("OnLeave", function() row.hoveredItem = nil; GameTooltip:Hide() end)
        row.message:SetScript("OnHyperlinkEnter", function(self, data)
            if not row.entry or not M.ValidItemLink(data) then return end
            row.hoveredItem = data
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, data)
            if ok then GameTooltip:Show() else row.hoveredItem = nil; GameTooltip:Hide() end
        end)
        row.message:SetScript("OnHyperlinkLeave", function()
            row.hoveredItem = nil
            GameTooltip:Hide()
        end)
        row.message:SetScript("OnHyperlinkClick", function()
            if row.entry then Whisper(row.entry.author) end
        end)
        row.message:SetScript("OnMouseUp", function(self, button)
            if button == "LeftButton" and row.entry and not row.hoveredItem then Whisper(row.entry.author) end
        end)
        row.message:EnableMouseWheel(true); row.message:SetScript("OnMouseWheel", Wheel)
        row:EnableMouseWheel(true); row:SetScript("OnMouseWheel", Wheel)
        widgets[i] = row
    end
    window.empty = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    window.empty:SetPoint("CENTER", 0, -10)
    window.empty:SetText("Noch keine passenden Nachrichten.\nKanal prüfen und neue Anzeigen abwarten.")
    status = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("BOTTOMLEFT", 20, 20)
    window:SetScript("OnShow", function() dirty = true; Render() end)
    window:SetScript("OnHide", function() input:ClearFocus(); GameTooltip:Hide() end)
    local elapsedTotal = 0
    window:SetScript("OnUpdate", function(self, elapsed)
        elapsedTotal = elapsedTotal + elapsed
        if elapsedTotal >= 1 then elapsedTotal = 0; Render() end
    end)
    window:Hide()
end

local function Toggle()
    if not window then MakeWindow() end
    if window:IsShown() then window:Hide() else window:Show() end
end

local function PositionIcon()
    local angle = math.rad(RebuffedRaidMarketDB.angle)
    minimap:ClearAllPoints()
    minimap:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
end

local function MakeIcon()
    minimap = CreateFrame("Button", "RebuffedRaidMarketMinimap", Minimap)
    minimap:SetWidth(31); minimap:SetHeight(31)
    minimap:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    -- TrackingBorder's visible ring is offset within its larger texture.
    -- A full-button normal texture sticks out of that ring as a square.
    local background = minimap:CreateTexture(nil, "BACKGROUND")
    background:SetWidth(20); background:SetHeight(20)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetPoint("TOPLEFT", 7, -5)
    local icon = minimap:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(20); icon:SetHeight(20)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    icon:SetPoint("TOPLEFT", 7, -5)
    local border = minimap:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetWidth(53); border:SetHeight(53); border:SetPoint("TOPLEFT")
    minimap:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    minimap:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimap:RegisterForDrag("LeftButton")
    minimap:SetScript("OnClick", Toggle)
    minimap:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition()
            local cx, cy = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            RebuffedRaidMarketDB.angle = math.deg(math.atan2(y / scale - cy, x / scale - cx))
            PositionIcon()
        end)
    end)
    minimap:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    minimap:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Raid & Markt", 1, 0.82, 0)
        GameTooltip:AddLine("Klick: Übersicht öffnen", 1, 1, 1)
        GameTooltip:AddLine("Ziehen: Symbol verschieben", 1, 1, 1)
        GameTooltip:AddLine("Kanal: " .. RebuffedRaidMarketDB.channel, 0.7, 0.7, 0.7)
        if M.Poster and M.Poster.IsRunning() then
            GameTooltip:AddLine("Eigene Anzeige aktiv (alle 5 Minuten)", 0.3, 1, 0.3)
        end
        GameTooltip:Show()
    end)
    minimap:SetScript("OnLeave", function() GameTooltip:Hide() end)
    PositionIcon()
end

engine:RegisterEvent("PLAYER_LOGIN")
engine:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        if type(RebuffedRaidMarketDB) ~= "table" then RebuffedRaidMarketDB = {} end
        if type(RebuffedRaidMarketDB.channel) ~= "string" or RebuffedRaidMarketDB.channel == "" then
            RebuffedRaidMarketDB.channel = "world"
        end
        if type(RebuffedRaidMarketDB.angle) ~= "number" then RebuffedRaidMarketDB.angle = 220 end
        Watch(); MakeIcon()
        Print("Bereit. Minimap-Symbol oder /raidmarkt. Überwachter Chat: " .. RebuffedRaidMarketDB.channel)
        return
    end
    if not RebuffedRaidMarketDB then return end
    local message, author, _, channelText, _, _, _, channelNumber, baseName = ...
    local sourceEvent = event == "CHAT_MSG_RAID_LEADER" and "CHAT_MSG_RAID" or event
    if M.Matches(sourceEvent, channelText, channelNumber, baseName) and M.Add(author, message, GetTime()) then
        dirty = true
    end
end)

SLASH_REBUFFEDRAIDMARKET1 = "/raidmarkt"
SLASH_REBUFFEDRAIDMARKET2 = "/rrm"
SlashCmdList.REBUFFEDRAIDMARKET = function(text)
    if not RebuffedRaidMarketDB then return end
    local command, value = text:match("^(%S+)%s*(.-)%s*$")
    command = command and command:lower()
    if command == "kanal" then
        if SetSource(value) then Print("Überwachter Chat: " .. RebuffedRaidMarketDB.channel); Render() end
    elseif command == "clear" or command == "leeren" then
        M.entries = {}; dirty = true; Render()
    else Toggle() end
end
