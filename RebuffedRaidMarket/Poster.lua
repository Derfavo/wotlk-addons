local M = RebuffedRaidMarket
local P = {}
M.Poster = P
local engine = CreateFrame("Frame")
local panel, preview, state, destination, startButton, stopButton
local modeButtons, roleButton = {}, nil
local running, nextSend, lastSend = nil, nil, -100000
local INTERVAL = 300
local roleNames = {"Tank", "Heiler", "Nahkampf-DD", "Fernkampf-DD"}
local roleText = {"Tank", "Healer", "Melee DPS", "Ranged DPS"}
local groupEvents = {"PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD"}
local Refresh, Changed, OpenRaidSelector
local raidSummary, raidSelector, raidScroll
local raidRows = {}
local raids = {
    {id="naxx", label="Naxxramas", code="Naxx", sizes={"","10","25"}, modes={"","N","HC"}},
    {id="ulduar", label="Ulduar", code="Ulduar", sizes={"","10","25"}, modes={"","N","HM"}},
    {id="toc", label="Prüfung des Kreuzfahrers", code="TOC", sizes={"","10","25"}, modes={"","N","HC"}},
    {id="icc", label="Eiskronenzitadelle", code="ICC", sizes={"","10","25"}, modes={"","N","HC"}},
    {id="rs", label="Rubinsanktum", code="RS", sizes={"","10","25"}, modes={"","N","HC"}},
    {id="os", label="Obsidiansanktum", code="OS", sizes={"","10","25"}, modes={"","N","HC"}},
    {id="eoe", label="Auge der Ewigkeit", code="EOE", sizes={"","10","25"}, modes={"","N","HC"}},
    {id="voa", label="Archavons Kammer", code="VOA", sizes={"","10","25"}, modes={"","N","HC"}},
    {id="ony", label="Onyxias Hort", code="Onyxia", sizes={"","10","25"}, modes={"","N","HC"}},
    {id="kara", label="Karazhan", code="Kara", sizes={"","10"}},
    {id="gruul", label="Gruuls Unterschlupf", code="Gruul", sizes={"","25"}},
    {id="mag", label="Magtheridons Kammer", code="Magtheridon", sizes={"","25"}},
    {id="ssc", label="Höhle des Schlangenschreins", code="SSC", sizes={"","25"}},
    {id="tk", label="Festung der Stürme", code="TK", sizes={"","25"}},
    {id="hyjal", label="Schlacht um den Hyjal", code="Hyjal", sizes={"","25"}},
    {id="bt", label="Schwarzer Tempel", code="BT", sizes={"","25"}},
    {id="swp", label="Sonnenbrunnenplateau", code="SWP", sizes={"","25"}},
    {id="za", label="Zul'Aman", code="ZA", sizes={"","10"}},
    {id="zg", label="Zul'Gurub", code="ZG", sizes={"","20"}},
    {id="mc", label="Geschmolzener Kern", code="MC", sizes={"","40"}},
    {id="bwl", label="Pechschwingenhort", code="BWL", sizes={"","40"}},
    {id="aq", label="Ahn'Qiraj", code="AQ", sizes={"","20","40"}},
}
local raidByID = {}
for _, raid in ipairs(raids) do raidByID[raid.id] = raid end
local function Contains(list, value)
    for _, option in ipairs(list) do if option == value then return true end end
    return false
end

function P.Target(config)
    local result, count = {}, 0
    if type(config.raids) ~= "table" then return nil, "Bitte mindestens einen Raid auswählen." end
    for id in pairs(config.raids) do
        if not raidByID[id] then return nil, "Unbekannter Raid. Bitte die Raid-Auswahl prüfen." end
    end
    for _, raid in ipairs(raids) do
        local choice = config.raids[raid.id]
        if choice then
            if type(choice) ~= "table" or not Contains(raid.sizes, choice.size or "")
                or not Contains(raid.modes or {""}, choice.mode or "") then
                return nil, "Bitte Größe und Schwierigkeit für " .. raid.label .. " prüfen."
            end
            local size, mode = choice.size or "", choice.mode or ""
            result[#result+1] = raid.code .. (size == "" and mode ~= "" and " " or "") .. size .. mode
            count = count + 1
        end
    end
    if count == 0 then return nil, "Bitte mindestens einen Raid auswählen." end
    return table.concat(result, " + "), count
end

function P.MigrateRaids(config)
    if type(config.raids) == "table" then
        for id, choice in pairs(config.raids) do
            local raid = raidByID[id]
            if not raid or type(choice) ~= "table" then config.raids[id] = nil
            else
                choice.size = Contains(raid.sizes,choice.size or "") and (choice.size or "") or ""
                choice.mode = Contains(raid.modes or {""},choice.mode or "") and (choice.mode or "") or ""
            end
        end
        return
    end
    config.raids = {}
    local target = M.Normalize(config.target)
    if target == "" then return end
    local groups = M.Classify("LFG " .. target)
    local ten = target:find("%f[%d]10%f[%D]")
    local twentyFive = target:find("%f[%d]25%f[%D]")
    local size = ten and not twentyFive and "10" or twentyFive and not ten and "25" or ""
    local mode = target:find("%f[%a]hc%f[%A]") and "HC" or target:find("%f[%a]hm%f[%A]") and "HM" or ""
    for _, label in ipairs(groups) do
        for _, raid in ipairs(raids) do
            if raid.label == label then
                config.raids[raid.id] = {size = Contains(raid.sizes,size) and size or "", mode = Contains(raid.modes or {""},mode) and mode or ""}
            end
        end
    end
end

local english = {}
local function Words(output, aliases)
    for word in (aliases or output:lower()):gmatch("[^,]+") do english[word] = output end
end
for _, word in ipairs({"Warrior", "Paladin", "Hunter", "Rogue", "Priest", "Shaman", "Mage", "Warlock", "Druid",
    "Death", "Knight", "Restoration", "Resto", "Holy", "Discipline", "Shadow", "Protection", "Retribution",
    "Balance", "Feral", "Combat", "Assassination", "Subtlety", "Survival", "Beast", "Mastery", "Marksmanship",
    "Arms", "Fury", "Blood", "Frost", "Unholy", "Enhancement", "Elemental", "Affliction", "Demonology",
    "Destruction", "Arcane", "Fire", "Tank", "Healer", "Melee", "Ranged", "DPS", "GS", "XP", "HC", "HM",
    "ICC", "RS", "OS", "MS", "BIS", "TOC", "TOGC", "VOA", "EOE", "Naxx", "Naxxramas", "Ulduar",
    "Onyxia", "Karazhan", "Gruul", "Magtheridon", "SSC", "TK", "BT", "SWP", "ZA", "ZG", "MC", "BWL", "AQ",
    "Icecrown", "Citadel", "Ruby", "Obsidian", "Sanctum", "Eye", "Eternity", "Vault", "Archavon", "Trial",
    "Crusader", "Grand", "Serpentshrine", "Cavern", "Tempest", "Keep", "Mount", "Hyjal", "Black", "Temple",
    "Sunwell", "Plateau", "Molten", "Core", "Blackwing", "Lair", "Zul", "Aman", "Gurub", "Ahn", "Qiraj"}) do Words(word) end
for output, aliases in pairs({
    Warrior="krieger,kriegerin", Paladin="paladine", Hunter="jaeger,jaegerin", Rogue="schurke,schurkin",
    Priest="priester,priesterin", ["Death Knight"]="todesritter,deathknight,dk", Shaman="schamane,schamanin",
    Mage="magier,magierin", Warlock="hexenmeister,hexenmeisterin", Druid="druide,druidin",
    Restoration="wiederherstellung", Holy="heilig", Discipline="disziplin,diszi", Shadow="schatten",
    Protection="schutz,prot", Retribution="vergelter,vergeltung,ret", Balance="gleichgewicht,eule,boomkin",
    Combat="kampf", Assassination="meucheln", Subtlety="taeuschung", Survival="ueberleben",
    ["Beast Mastery"]="tierherrschaft,bm", Marksmanship="treffsicherheit,mm", Arms="waffen", Fury="furor",
    Blood="blut", Unholy="unheilig", Enhancement="verstaerkung,verstaerker", Elemental="elementar,ele",
    Affliction="gebrechen,affli", Demonology="daemonologie,demo", Destruction="zerstoerung,destro",
    Arcane="arkan", Fire="feuer", Healer="heiler,heal,heals", DPS="dd,dds", Ranged="fernkampf",
    Melee="nahkampf", HC="heroisch", Normal="normal,nhc,nm", Naxxramas="naxxramas", Onyxia="ony",
    TOC="pdk", TOGC="pdok", VOA="ak", ["Icecrown Citadel"]="eiskronenzitadelle",
    ["Ruby Sanctum"]="rubinsanktum", ["Obsidian Sanctum"]="obsidiansanktum",
    ["Serpentshrine Cavern"]="schlangenschrein", ["Sunwell Plateau"]="sonnenbrunnenplateau,sonnenbrunnen",
    ["Blackwing Lair"]="pechschwingenhort", ["Molten Core"]="geschmolzenerkern",
    need="need,brauche,brauchen", needed="needed,gesucht", looking="looking", ["for"]="for",
    experience="experience,erfahrung", full="full,voll,volle,vollen", required="required,erforderlich",
    free="free,frei", reserved="reserved,reserviert,resv", only="only,nur", minimum="minimum,mindestens,min",
    no="no,keine,kein", with="with,mit", without="without,ohne", ["and"]="and,und", ["or"]="or,oder",
    all="all,alle,alles", bosses="bosses,bosse", boss="boss", raid="raid", group="group,gruppe",
    run="run", clear="clear", fresh="fresh,frisch", achievement="achievement,erfolg,achiev,ach",
    gems="gems,sockel", enchants="enchants,verzauberungen", BoE="boe", BoEs="boes",
    legendaries="legendaries,legy", today="today,heute", tomorrow="tomorrow,morgen", at="at,um",
    from="from,ab", pm="pm", am="am", me="me,mich", whisper="whisper,fluestern", please="please,bitte",
    English="english,englisch", German="german,deutsch", k="k", g="g", SR="sr",
    HR="hr", GDKP="gdkp", LFM="lfm", LFG="lfg", spec="spec,skillung", offspec="offspec", mainspec="mainspec",
}) do Words(output, aliases) end
local phrases = {
    {"pruefung des grossen kreuzfahrers", "trial of the grand crusader"},
    {"pruefung des kreuzfahrers", "trial of the crusader"},
    {"auge der ewigkeit", "eye of eternity"}, {"archavons kammer", "vault of archavon"},
    {"hoehle des schlangenschreins", "serpentshrine cavern"}, {"festung der stuerme", "tempest keep"},
    {"schlacht um den hyjal", "mount hyjal"}, {"schwarzer tempel", "black temple"},
    {"geschmolzener kern", "molten core"}, {"onyxias hort", "onyxia"},
    {"gruuls unterschlupf", "gruul"}, {"magtheridons kammer", "magtheridon"},
    {"volle erfahrung", "full experience"}, {"vollstaendige erfahrung", "full experience"},
}
-- English raid names also use these ordinary words.
for _, word in ipairs({"of", "the", "hard", "mode", "heroic", "progress", "farm", "geared", "experienced", "ready", "s"}) do Words(word) end
for output, aliases in pairs({star="star,stern", circle="circle,kreis", diamond="diamond,diamant",
    triangle="triangle,dreieck", moon="moon,mond", square="square,quadrat", cross="cross,kreuz",
    skull="skull,totenkopf", rt="rt"}) do Words(output, aliases) end

function P.English(value, field)
    local text = M.Clean(value):lower():gsub("ä", "ae"):gsub("ö", "oe"):gsub("ü", "ue")
        :gsub("Ä", "ae"):gsub("Ö", "oe"):gsub("Ü", "ue"):gsub("ß", "ss")
    for _, phrase in ipairs(phrases) do
        text = text:gsub("%f[%a]" .. phrase[1] .. "%f[%A]", phrase[2])
    end
    local unknown
    text = text:gsub("%a+", function(word)
        if english[word] then return english[word] end
        unknown = unknown or word
        return word
    end)
    if unknown or text:find("[\128-\255]") then
        return nil, (field or "Text") .. ": Begriff nicht erkannt (" .. (unknown or "Sonderzeichen")
            .. "). Bitte bekannte Raid-/Klassenbegriffe verwenden oder den Zusatz kürzen."
    end
    return text
end

local function Notice(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Raid & Markt:|r " .. message)
end

local function Grouped()
    return GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0
end

function P.GearScore()
    if type(RebuffedItemLevel_GetPlayerGearScore) ~= "function" then return nil end
    local score = RebuffedItemLevel_GetPlayerGearScore()
    if type(score) ~= "number" or score < 0 or score ~= score or score == math.huge then return nil end
    return string.format("%.1fk", math.floor(score / 100 + 0.5) / 10)
end

function P.Build(config)
    if type(config) ~= "table" then return nil, "Bitte die Anzeige ausfüllen." end
    if config.mode ~= "LFM" and config.mode ~= "LFG" then return nil, "Bitte LFM oder LFG wählen." end
    local target, targetProblem = P.Target(config)
    if not target then return nil, targetProblem end
    local own, extra = M.Clean(config.own), M.Clean(config.extra)
    if own == "" then return nil, "Bitte eigene Klasse oder Skillung eingeben." end
    local problem
    own, problem = P.English(own, "Klasse / Skillung")
    if not own then return nil, problem end
    extra, problem = P.English(extra, "Zusatz")
    if not extra then return nil, problem end
    local role = roleText[tonumber(config.role)]
    if not role then return nil, "Bitte die eigene Rolle wählen." end
    local gs = P.GearScore()
    if not gs then return nil, "GearScore noch nicht verfügbar. Rebuffed ItemLevel aktivieren und kurz warten." end
    local message = config.mode .. " " .. target .. " | " .. own .. " (" .. role .. ", " .. gs .. " GS)"
    if extra ~= "" then message = message .. " | " .. extra end
    message = message .. " | /w me"
    -- Clean strips formatting pipes but keeps readable separators and chat icons.
    message = message:gsub(" | ", " - ")
    if #message > 255 then return nil, "Nachricht zu lang (" .. #message .. "/255 Bytes). Bitte kürzen." end
    return message
end

function P.Resolve(source)
    local event = M.SourceEvent(source)
    if event == "CHAT_MSG_GUILD" then
        if not IsInGuild() then return nil, "Du bist in keiner Gilde." end
        return "GUILD", nil, "Gilde"
    elseif event == "CHAT_MSG_SAY" then return "SAY", nil, "Sagen"
    elseif event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_RAID" then
        return nil, "Die Automatik läuft nur ohne Gruppe. Bitte einen öffentlichen Kanal oder Gilde wählen."
    end
    local name = M.Clean(source):gsub("^/", "")
    local id, channelName = GetChannelName(tonumber(name) or name)
    if (not id or id == 0) and (M.Normalize(name) == "handel" or M.Normalize(name) == "trade") then
        id, channelName = GetChannelName(M.Normalize(name) == "handel" and "Trade" or "Handel")
    end
    if not id or id < 1 or not channelName or channelName == "" then
        return nil, "Dem eingestellten Kanal zuerst beitreten: " .. name
    end
    return "CHANNEL", id, channelName
end

function P.Stop(reason)
    local wasRunning = running ~= nil
    running, nextSend = nil, nil
    engine:SetScript("OnUpdate", nil)
    for _, event in ipairs(groupEvents) do engine:UnregisterEvent(event) end
    P.reason = reason or "Manuell gestoppt."
    if wasRunning then Notice(P.reason) end
    if Refresh then Refresh() end
end

local function Send()
    if not running then return false end
    if Grouped() then P.Stop("Automatik gestoppt: Du bist jetzt in einer Gruppe."); return false end
    if RebuffedRaidMarketDB.channel ~= running.source then
        P.Stop("Automatik gestoppt: Chatkanal wurde geändert."); return false
    end
    local chatType, id, name = P.Resolve(running.source)
    if not chatType or chatType ~= running.chatType or M.Normalize(name) ~= M.Normalize(running.name) then
        P.Stop("Automatik gestoppt: Der eingestellte Chat ist nicht mehr verfügbar oder wurde geändert.")
        return false
    end
    local message, problem = P.Build(RebuffedRaidMarketPostDB)
    if not message then P.Stop("Automatik gestoppt: " .. problem); return false end
    running.message = message
    local ok = pcall(SendChatMessage, message, chatType, nil, id)
    if not ok then P.Stop("Automatik gestoppt: Nachricht konnte nicht gesendet werden."); return false end
    lastSend = GetTime()
    nextSend = lastSend + INTERVAL
    return true
end

function P.Tick()
    if not running then return end
    if Grouped() then P.Stop("Automatik gestoppt: Du bist jetzt in einer Gruppe."); return end
    if RebuffedRaidMarketDB.channel ~= running.source then
        P.Stop("Automatik gestoppt: Chatkanal wurde geändert."); return
    end
    if GetTime() >= nextSend then Send() end
    if Refresh then Refresh() end
end

function P.Start()
    if running then return false, "Die Automatik läuft bereits." end
    local message, problem = P.Build(RebuffedRaidMarketPostDB)
    if not message then return false, problem end
    if Grouped() then return false, "Du bist bereits in einer Gruppe. Die Automatik läuft nur ohne Gruppe." end
    local chatType, id, name = P.Resolve(RebuffedRaidMarketDB.channel)
    if not chatType then return false, id end
    running = {message = message, source = RebuffedRaidMarketDB.channel, chatType = chatType, name = name}
    P.reason = nil
    nextSend = math.max(GetTime(), lastSend + INTERVAL)
    for _, event in ipairs(groupEvents) do engine:RegisterEvent(event) end
    local elapsedTotal = 0
    engine:SetScript("OnUpdate", function(self, elapsed)
        elapsedTotal = elapsedTotal + elapsed
        if elapsedTotal >= 1 then elapsedTotal = 0; P.Tick() end
    end)
    if GetTime() >= nextSend then
        if not Send() then return false, P.reason end
    end
    if Refresh then Refresh() end
    return true
end

function P.IsRunning() return running ~= nil end
function P.NextSend() return nextSend end

Refresh = function()
    if not panel or not panel:IsShown() then return end
    local config = RebuffedRaidMarketPostDB
    local text, problem = P.Build(config)
    preview:SetText(text or problem)
    local targets = P.Target(config)
    raidSummary:SetText(targets or "Noch keine Raids ausgewählt")
    destination:SetText("Senden in: " .. RebuffedRaidMarketDB.channel .. "  |  Wiederholung: 5 Minuten")
    if running then
        state:SetText("Aktiv – nächste Anzeige in " .. math.max(0, math.ceil(nextSend - GetTime())) .. " Sek.\nStoppt beim Gruppenbeitritt, auch bei LFM.")
        startButton:Disable(); stopButton:Enable()
    else
        state:SetText(P.reason or "Gestoppt. Starten sendet die erste Anzeige sofort.\nAutomatik läuft nur, solange du in keiner Gruppe bist.")
        startButton:Enable(); stopButton:Disable()
    end
    for mode, button in pairs(modeButtons) do
        if mode == config.mode then button:Disable() else button:Enable() end
    end
    if roleButton then roleButton:SetText(roleNames[config.role] or "Rolle wählen") end
end

Changed = function()
    if running then P.Stop("Automatik gestoppt: Anzeige wurde geändert. Bitte erneut starten.") end
    P.reason = nil
    Refresh()
end

local function Button(text, width, x, y, click, owner)
    owner = owner or panel
    local b = CreateFrame("Button", nil, owner, "UIPanelButtonTemplate")
    b:SetWidth(width); b:SetHeight(24); b:SetPoint("TOPLEFT", x, y)
    b:SetText(text); b:SetScript("OnClick", click)
    return b
end

local function NextOption(list, current)
    for index, value in ipairs(list) do if value == current then return list[index % #list + 1] end end
    return list[1]
end
local function RenderRaids()
    local offset = FauxScrollFrame_GetOffset(raidScroll)
    FauxScrollFrame_Update(raidScroll, #raids, 10, 28)
    for index, row in ipairs(raidRows) do
        local raid = raids[offset + index]
        row.raid = raid
        if raid then
            row.toggle:Show(); row.size:Show(); row.mode:Show()
            local choice = RebuffedRaidMarketPostDB.raids[raid.id]
            row.toggle:SetText((choice and "|cff55ff55[x]|r " or "[ ] ") .. raid.label)
            row.size:SetText(choice and choice.size ~= "" and choice.size or "Beliebig")
            local mode = choice and choice.mode or ""
            row.mode:SetText(mode == "HC" and "Heroisch" or mode == "HM" and "Hardmode" or mode == "N" and "Normal" or "Beliebig")
            if choice then row.size:Enable() else row.size:Disable() end
            if choice and raid.modes then row.mode:Enable() else row.mode:Disable() end
        else row.toggle:Hide(); row.size:Hide(); row.mode:Hide() end
    end
end
OpenRaidSelector = function()
    if raidSelector then raidSelector:Show(); RenderRaids(); return end
    raidSelector = CreateFrame("Frame", "RebuffedRaidMarketRaidSelector", UIParent)
    raidSelector:SetWidth(640); raidSelector:SetHeight(450); raidSelector:SetPoint("CENTER")
    raidSelector:SetFrameStrata("DIALOG"); raidSelector:SetFrameLevel(panel:GetFrameLevel() + 10)
    raidSelector:SetClampedToScreen(true); raidSelector:EnableMouse(true)
    raidSelector:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
        tile=true, tileSize=32, edgeSize=32, insets={left=11,right=12,top=12,bottom=11}})
    tinsert(UISpecialFrames,"RebuffedRaidMarketRaidSelector")
    local title = raidSelector:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    title:SetPoint("TOPLEFT",22,-22); title:SetText("Raids auswählen – mehrere möglich")
    for _, heading in ipairs({{"Raid anklicken",22},{"Größe",355},{"Schwierigkeit",453}}) do
        local text = raidSelector:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        text:SetPoint("TOPLEFT",heading[2],-54); text:SetText(heading[1])
    end
    local close = CreateFrame("Button",nil,raidSelector,"UIPanelCloseButton")
    close:SetPoint("TOPRIGHT",-6,-6); close:SetScript("OnClick",function() raidSelector:Hide() end)
    raidScroll = CreateFrame("ScrollFrame","RebuffedRaidMarketRaidScroll",raidSelector,"FauxScrollFrameTemplate")
    raidScroll:SetPoint("TOPLEFT",20,-75); raidScroll:SetPoint("BOTTOMRIGHT",-34,83)
    raidScroll:SetScript("OnVerticalScroll",function(self,offset) FauxScrollFrame_OnVerticalScroll(self,offset,28,RenderRaids) end)
    local function Wheel(self,delta)
        local offset = math.max(0,math.min(#raids-10,FauxScrollFrame_GetOffset(raidScroll)-delta*3))
        RebuffedRaidMarketRaidScrollScrollBar:SetValue(offset*28)
    end
    raidScroll:EnableMouseWheel(true); raidScroll:SetScript("OnMouseWheel",Wheel)
    for index=1,10 do
        local row = {}
        local y = -77-(index-1)*28
        row.toggle = Button("",315,22,y,function()
            local id = row.raid.id
            local selected = RebuffedRaidMarketPostDB.raids
            if selected[id] then selected[id] = nil else selected[id] = {size="",mode=""} end
            Changed(); RenderRaids()
        end,raidSelector)
        row.size = Button("",90,347,y,function()
            local choice = RebuffedRaidMarketPostDB.raids[row.raid.id]
            choice.size = NextOption(row.raid.sizes,choice.size or "")
            Changed(); RenderRaids()
        end,raidSelector)
        row.mode = Button("",125,445,y,function()
            local choice = RebuffedRaidMarketPostDB.raids[row.raid.id]
            choice.mode = NextOption(row.raid.modes,choice.mode or "")
            Changed(); RenderRaids()
        end,raidSelector)
        for _, button in ipairs({row.toggle,row.size,row.mode}) do
            button:EnableMouseWheel(true); button:SetScript("OnMouseWheel",Wheel)
        end
        raidRows[index] = row
    end
    local help = raidSelector:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    help:SetPoint("TOPLEFT",22,-369); help:SetText("Größe/Schwierigkeit durch Anklicken wechseln. Beliebig lässt die Angabe offen.")
    Button("Auswahl leeren",150,22,-398,function()
        RebuffedRaidMarketPostDB.raids = {}; Changed(); RenderRaids()
    end,raidSelector)
    Button("Fertig",120,450,-398,function() raidSelector:Hide() end,raidSelector)
    RenderRaids()
end

local function Field(label, key, y, maximum)
    local caption = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    caption:SetPoint("TOPLEFT", 22, y - 5); caption:SetText(label)
    local edit = CreateFrame("EditBox", "RebuffedRaidMarketPost_" .. key, panel, "InputBoxTemplate")
    edit:SetWidth(390); edit:SetHeight(22); edit:SetPoint("TOPLEFT", 160, y)
    edit:SetAutoFocus(false); edit:SetMaxLetters(maximum)
    edit:SetText(RebuffedRaidMarketPostDB[key] or "")
    edit:SetScript("OnTextChanged", function(self)
        RebuffedRaidMarketPostDB[key] = self:GetText(); Changed()
    end)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return edit
end

function M.OpenPoster()
    if not RebuffedRaidMarketPostDB then return end
    if panel then if panel:IsShown() then panel:Hide() else panel:Show(); Refresh() end; return end
    panel = CreateFrame("Frame", "RebuffedRaidMarketPostWindow", UIParent)
    panel:SetWidth(580); panel:SetHeight(450); panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG"); panel:SetClampedToScreen(true)
    panel:SetMovable(true); panel:EnableMouse(true); panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32,
        edgeSize = 32, insets = {left = 11, right = 12, top = 12, bottom = 11}})
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 22, -20); title:SetText("Eigene LFM-/LFG-Anzeige")
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6); close:SetScript("OnClick", function() panel:Hide() end)
    tinsert(UISpecialFrames, "RebuffedRaidMarketPostWindow")
    modeButtons.LFM = Button("LFM – Mitspieler", 165, 22, -52, function()
        RebuffedRaidMarketPostDB.mode = "LFM"; Changed()
    end)
    modeButtons.LFG = Button("LFG – Gruppe", 165, 198, -52, function()
        RebuffedRaidMarketPostDB.mode = "LFG"; Changed()
    end)
    Button("Raids auswählen",180,22,-90,OpenRaidSelector)
    raidSummary = panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    raidSummary:SetPoint("TOPLEFT",215,-96); raidSummary:SetWidth(335); raidSummary:SetHeight(26); raidSummary:SetJustifyH("LEFT")
    Field("Klasse / Skillung:", "own", -150, 55)
    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 22, -190); label:SetText("Eigene Rolle:")
    roleButton = Button("", 230, 155, -185, function()
        RebuffedRaidMarketPostDB.role = RebuffedRaidMarketPostDB.role % #roleNames + 1; Changed()
    end)
    Field("Zusatz (übersetzt):", "extra", -220, 100)
    destination = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    destination:SetPoint("TOPLEFT", 22, -259)
    preview = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    preview:SetPoint("TOPLEFT", 22, -284); preview:SetWidth(536); preview:SetHeight(70)
    preview:SetJustifyH("LEFT"); preview:SetJustifyV("TOP")
    startButton = Button("Automatik starten", 170, 22, -366, function()
        local ok, problem = P.Start()
        if not ok then P.reason = problem; Notice(problem); Refresh() end
    end)
    stopButton = Button("Stoppen", 120, 204, -366, function() P.Stop("Manuell gestoppt.") end)
    state = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    state:SetPoint("TOPLEFT", 22, -401); state:SetWidth(536); state:SetJustifyH("LEFT")
    panel:SetScript("OnShow", Refresh)
    panel:SetScript("OnHide", function() if raidSelector then raidSelector:Hide() end end)
    Refresh()
end

engine:RegisterEvent("PLAYER_LOGIN")
engine:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        if type(RebuffedRaidMarketPostDB) ~= "table" then RebuffedRaidMarketPostDB = {} end
        local c = RebuffedRaidMarketPostDB
        if c.mode ~= "LFM" and c.mode ~= "LFG" then c.mode = "LFM" end
        if type(c.role) ~= "number" or not roleNames[c.role] then c.role = 0 end
        local defaults = {target = "", own = UnitClass("player") or "", extra = ""}
        for key, value in pairs(defaults) do if type(c[key]) ~= "string" then c[key] = value end end
        P.MigrateRaids(c)
        return
    end
    if running and Grouped() then P.Stop("Automatik gestoppt: Du bist jetzt in einer Gruppe.") end
end)

SLASH_REBUFFEDRAIDMARKETPOST1 = "/raidpost"
SlashCmdList.REBUFFEDRAIDMARKETPOST = M.OpenPoster
