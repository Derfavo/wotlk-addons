RebuffedRaidMarket = {}
local M = RebuffedRaidMarket
M.LIFETIME = 15 * 60
M.LIMIT = 300
M.entries = {}

local chatIcons = {
    star = 1, stern = 1, circle = 2, kreis = 2, diamond = 3, diamant = 3,
    triangle = 4, dreieck = 4, moon = 5, mond = 5, square = 6, quadrat = 6,
    cross = 7, kreuz = 7, skull = 8, totenkopf = 8,
    rt1 = 1, rt2 = 2, rt3 = 3, rt4 = 4, rt5 = 5, rt6 = 6, rt7 = 7, rt8 = 8,
}
local function IconIndex(token)
    return chatIcons[token:match("^%s*(.-)%s*$"):lower()]
end

function M.Clean(text)
    text = tostring(text or "")
    text = text:gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", ""):gsub("|T.-|t", ""):gsub("|", "")
    return text:gsub("[%c]", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
end

function M.Normalize(text)
    -- Decoration should not participate in categorization or duplicate keys.
    local plain = M.Clean(text):gsub("{([^{}]+)}", function(token)
        return IconIndex(token) and " " or "{" .. token .. "}"
    end)
    plain = plain:gsub("%s+", " "):match("^%s*(.-)%s*$")
    return plain:lower():gsub("ä", "ae"):gsub("ö", "oe"):gsub("ü", "ue")
        :gsub("Ä", "ae"):gsub("Ö", "oe"):gsub("Ü", "ue"):gsub("ß", "ss")
end

function M.Display(text)
    -- Only emit fixed game textures; arbitrary incoming texture markup is removed.
    return (M.Clean(text):gsub("{([^{}]+)}", function(token)
        local index = IconIndex(token)
        if index then return "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_" .. index .. ":14:14|t" end
        return "{" .. token .. "}"
    end))
end

function M.ValidItemLink(data)
    return type(data) == "string" and #data <= 256
        and (data:match("^item:%d+$") or data:match("^item:%d+:[%d:%-]*$")) ~= nil
end

local function EscapeHTML(text)
    return text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
end

function M.HTML(text)
    -- SimpleHTML supplies per-link mouse events in the 3.3.5 client.
    -- Rebuild only valid item links and escape every piece of ordinary text.
    local parts, position = {}, 1
    local function Plain(value)
        -- Sentinels preserve spaces next to item links despite Clean's trimming.
        return EscapeHTML(M.Display("x" .. value .. "x"):sub(2, -2))
    end
    while true do
        local first, last, data, label = text:find("|H(.-)|h(.-)|h", position)
        if not first then parts[#parts + 1] = Plain(text:sub(position)); break end
        parts[#parts + 1] = Plain(text:sub(position, first - 1))
        if M.ValidItemLink(data) then
            parts[#parts + 1] = '<a href="' .. data .. '">' .. Plain(label) .. '</a>'
        else
            parts[#parts + 1] = Plain(label)
        end
        position = last + 1
    end
    return "<html><body><p>" .. table.concat(parts) .. "</p></body></html>"
end

local function ItemKey(text)
    local links = {}
    for data in text:gmatch("|H(.-)|h.-|h") do
        if M.ValidItemLink(data) then links[#links + 1] = data end
    end
    return #links > 0 and ("\031" .. table.concat(links, "\031")) or ""
end

-- Letter boundaries accept common spellings such as ICC25, Naxx10 and RS25HC.
local function Has(text, alias)
    return text:find("%f[%a]" .. alias .. "%f[%A]") ~= nil
end
local raids = {
    {"Naxxramas", {"naxxramas", "naxx"}},
    {"Ulduar", {"ulduar", "uldu"}},
    {"Prüfung des Kreuzfahrers", {"toc", "togc", "totc", "pdk", "pdok", "trial of the crusader", "trial of the grand crusader", "pruefung des kreuzfahrers"}},
    {"Eiskronenzitadelle", {"icc", "eiskronenzitadelle", "icecrown", "lich king"}},
    {"Rubinsanktum", {"rs", "ruby sanctum", "rubinsanktum"}},
    {"Obsidiansanktum", {"os", "obsidian sanctum", "obsidiansanktum", "sartharion", "sarth"}},
    {"Auge der Ewigkeit", {"eoe", "eye of eternity", "auge der ewigkeit", "malygos"}},
    {"Archavons Kammer", {"voa", "ak", "vault of archavon", "archavon", "archavons kammer"}},
    {"Onyxias Hort", {"onyxia", "ony", "onyxias hort"}},
    {"Karazhan", {"karazhan", "kara"}},
    {"Gruuls Unterschlupf", {"gruul"}},
    {"Magtheridons Kammer", {"magtheridon", "maggy"}},
    {"Höhle des Schlangenschreins", {"ssc", "serpentshrine", "schlangenschrein"}},
    {"Festung der Stürme", {"tk", "tempest keep", "festung der stuerme"}},
    {"Schlacht um den Hyjal", {"hyjal", "mount hyjal"}},
    {"Schwarzer Tempel", {"bt", "black temple", "schwarzer tempel"}},
    {"Sonnenbrunnenplateau", {"swp", "sunwell", "sonnenbrunnen"}},
    {"Zul'Aman", {"za", "zul.aman"}},
    {"Zul'Gurub", {"zg", "zul.gurub"}},
    {"Geschmolzener Kern", {"mc", "molten core", "geschmolzener kern"}},
    {"Pechschwingenhort", {"bwl", "blackwing lair", "pechschwingenhort"}},
    {"Ahn'Qiraj", {"aq", "ahn.qiraj"}},
}

function M.Classify(message)
    local text = M.Normalize(message)
    -- Trade intent wins: selling raid boosts belongs under Verkaufen.
    if Has(text, "wtb") or Has(text, "buying") or Has(text, "kaufe") or Has(text, "kaufen") or Has(text, "ankauf")
        or Has(text, "want to buy") then return {"Kaufen"} end
    if Has(text, "wts") or Has(text, "selling") or Has(text, "verkaufe") or Has(text, "verkaufen") or Has(text, "vk")
        or Has(text, "verkauf") or Has(text, "want to sell") then return {"Verkaufen"} end
    local groups = {}
    local recruiting = Has(text, "lfm") or Has(text, "lfg") or text:find("%f[%a]lf%d*%s*m%f[%A]")
        or Has(text, "lf") or Has(text, "looking") or Has(text, "need") or Has(text, "suche")
        or Has(text, "suchen") or Has(text, "sucht") or Has(text, "gesucht") or Has(text, "suchen noch")
        or Has(text, "tank") or Has(text, "tanks") or Has(text, "healer") or Has(text, "healers")
        or Has(text, "heiler") or Has(text, "heal") or Has(text, "heals")
        or Has(text, "dps") or Has(text, "dd") or Has(text, "spots") or Has(text, "platz")
        or Has(text, "inv") or Has(text, "recruiting") or text:find("/w", 1, true)
    if not recruiting then return groups end
    -- OS also means off-spec in loot rules, e.g. [BIS>MS>OS].
    -- Mask those expressions only for matching; keep the displayed ad intact.
    -- Word boundaries here retain numbered raid names such as OS10/OS25.
    local raidText = text:gsub("%f[%w]ms[%s><=/+&%-]+os%f[%W]", " ")
        :gsub("%f[%w]os[%s><=/+&%-]+ms%f[%W]", " ")
    for _, raid in ipairs(raids) do
        for _, alias in ipairs(raid[2]) do
            if Has(raidText, alias) then groups[#groups + 1] = raid[1]; break end
        end
    end
    if #groups == 0 and (Has(text, "raid") or Has(text, "raids")) then
        groups[1] = "Sonstige Raids"
    end
    return groups
end

function M.Prune(now)
    for i = #M.entries, 1, -1 do
        if now - M.entries[i].time >= M.LIFETIME then table.remove(M.entries, i) end
    end
end

function M.Add(author, message, now)
    if type(author) ~= "string" or author == "" or type(message) ~= "string" then return false end
    M.Prune(now)
    local clean = M.Clean(message)
    -- Keep complete item link labels, then bound stored text.
    if #clean > 600 then clean = clean:sub(1, 600):gsub("[\128-\191]*$", ""):gsub("[\192-\244]$", "") end
    local groups = M.Classify(clean)
    if #groups == 0 then return false end
    local key = M.Normalize(clean) .. ItemKey(message)
    local linkedMessage = #message <= 4096 and #M.Clean(message) <= 600 and message or clean
    for _, entry in ipairs(M.entries) do
        if entry.author == author and entry.key == key then
            entry.time = now
            entry.linkedMessage = linkedMessage
            return true
        end
    end
    if #M.entries >= M.LIMIT then
        local oldest = 1
        for i = 2, #M.entries do
            if M.entries[i].time < M.entries[oldest].time then oldest = i end
        end
        table.remove(M.entries, oldest)
    end
    M.entries[#M.entries + 1] = {author = author, message = clean, linkedMessage = linkedMessage,
        key = key, groups = groups, time = now}
    return true
end

function M.Rows(filter, now)
    M.Prune(now)
    local buckets, names, rows = {}, {}, {}
    for _, entry in ipairs(M.entries) do
        for _, group in ipairs(entry.groups) do
            local trade = group == "Kaufen" or group == "Verkaufen"
            if filter == "Alle" or filter == group or (filter == "Raids" and not trade) then
                if not buckets[group] then buckets[group] = {}; names[#names + 1] = group end
                buckets[group][#buckets[group] + 1] = entry
            end
        end
    end
    local function rank(name) return name == "Kaufen" and 2 or name == "Verkaufen" and 3 or 1 end
    table.sort(names, function(a,b) if rank(a) ~= rank(b) then return rank(a) < rank(b) end return a < b end)
    for _, name in ipairs(names) do
        table.sort(buckets[name], function(a,b)
            if a.time ~= b.time then return a.time > b.time end
            return a.author < b.author
        end)
        rows[#rows + 1] = {header = name, count = #buckets[name]}
        for _, entry in ipairs(buckets[name]) do rows[#rows + 1] = {entry = entry} end
    end
    return rows
end
