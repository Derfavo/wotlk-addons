local addonName, addon = ...

addon.config = {
    -- Abstand der Aktualisierungen in Sekunden. 0.15 entspricht etwa 7 Aktualisierungen pro Sekunde.
    updateInterval = 0.15,

    -- Breite und Höhe eines Gruppenmitglieds, jeweils in UI-Pixeln.
    width = 128,
    height = 50,

    -- Höhe des schmalen Lebensbalkens am unteren Rand eines Feldes.
    healthBarHeight = 10,

    -- Deckkraft des Lebensbalkens über dem Feldhintergrund.
    healthBarAlpha = 0.2,

    -- Fünf Einträge je Spalte, maximal acht Spalten für 40 Schlachtzugsmitglieder.
    rows = 5,
    gap = 2,

    -- Unter diesem Manaanteil werden sparsame Heilvorschläge bevorzugt.
    lowMana = 0.25,

    -- Unter diesem Lebensanteil gilt ein Ziel als akut gefährdet.
    criticalHealth = 0.35,

    -- Mindestanteil fehlenden Lebens für Heilvorschläge. Dies verhindert Hinweise bei minimalem Schaden.
    minimumDeficit = 0.08,

    -- Unter diesem Lebensanteil wird ein entfernbarer Debuff zugunsten einer Notheilung zurückgestellt.
    emergencyHealth = 0.25,

    -- Zeitkonstante des geglätteten Netto-Lebensverlusts. Es handelt sich um eine Schätzung.
    damageWindow = 2.0,

    -- Erdschild bzw. Flamme des Glaubens/Geheiligten Schild nur auf dem Fokus vorschlagen.
    recommendFocusBuffs = true,

    -- Eigene Schutzfähigkeiten, Notfall- und Mana-Cooldowns vorschlagen.
    recommendCooldowns = true,

    -- Tankbuffs vor Ablauf und Erdschild bei dieser Restladungszahl erneuern.
    buffRefreshSeconds = 5,
    earthShieldCharges = 1,

    -- Unter diesem Manaanteil geeignete Manaregeneration vorschlagen.
    manaCooldownThreshold = 0.35,

    -- Basissprüche gefährlicher Debuffs; der lokalisierte Name erfasst alle Ränge.
    -- Instabiles Gebrechen, Vampirberührung und Mutierte Infektion nicht blind entfernen.
    blockedDispelIds = { 30108, 34914, 69674 },

    -- Gruppenheilung anhand verletzter Mitglieder empfehlen. Abstände zwischen Zielen bleiben eine Annahme.
    recommendGroupHeals = true,

    -- Standardmodus für neue Installationen. Die letzte Auswahl wird danach gespeichert.
    defaultMode = "mixed",

    -- Reihenfolge beim Umschalten über die Modus-Schaltfläche im Grid.
    modeOrder = { "safe", "mixed", "full" },

    -- Die Schwellen betreffen Empfehlungen. Notheilung und verfügbare Entfernungszauber bleiben aktiv.
    modes = {
        safe = {
            -- Kleine Defizite abwarten und auch bei hohem Mana sparsame Vorschläge verwenden.
            label = "STR_MODE_SAFE",
            description = "STR_MODE_SAFE_DESCRIPTION",
            -- Mindestzahl verletzter Ziele, erwartetes Lebensdefizit und Mana für Gruppenheilung.
            groupCount = 3,
            groupDeficit = .25,
            groupMana = .30,
            minimumDeficit = 0.20,
            lowMana = 0.45,
            alwaysConserve = true,
            conserveHealth = 0.80,
            waveHealth = 0.80,
            hotDeficit = 0.20,
            shieldHealth = 0.60,
        },
        mixed = {
            -- Ausgewogene Schwellen; minimumDeficit und lowMana übernehmen die allgemeinen Einstellungen.
            label = "STR_MODE_MIXED",
            description = "STR_MODE_MIXED_DESCRIPTION",
            -- Mindestzahl verletzter Ziele, erwartetes Lebensdefizit und Mana für Gruppenheilung.
            groupCount = 3,
            groupDeficit = .15,
            groupMana = .25,
            conserveHealth = 0.80,
            waveHealth = 0.65,
            hotDeficit = 0.15,
            shieldHealth = 0.75,
        },
        full = {
            -- Bereits ab einem Prozent fehlendem Leben heilen; keine freiwillige Manaspar-Pause.
            label = "STR_MODE_FULL",
            description = "STR_MODE_FULL_DESCRIPTION",
            -- Mindestzahl verletzter Ziele, erwartetes Lebensdefizit und Mana für Gruppenheilung.
            groupCount = 2,
            groupDeficit = .10,
            groupMana = 0,
            minimumDeficit = 0.01,
            lowMana = 0,
            ignoreConservation = true,
            conserveHealth = 1,
            waveHealth = 0.50,
            hotDeficit = 0.05,
            shieldHealth = 0.35,
        },
    },

}
