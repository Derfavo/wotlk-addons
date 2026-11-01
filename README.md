# WotLK Addons

Vier Addons für World of Warcraft 3.3.5a (Interface 30300), entwickelt für Whitemane Frostmourne Rebuffed.

| Addon | Version | Wofür? |
| --- | --- | --- |
| [ChronixHeal](ChronixHeal) | 0.6.2 | Heilfenster mit Klickbelegungen, Zaubervorschlägen und eigenen Buffs |
| [RebuffedItemLevel](RebuffedItemLevel) | 1.2.3 | Itemlevel und GearScore im Charakterfenster, beim Untersuchen und im Spieler-Tooltip |
| [RebuffedRaidMarket](RebuffedRaidMarket) | 1.2.0 | Raid- und Handelsanzeigen aus einem Chatkanal sammeln und eigene Anzeigen posten |
| [RebuffedUpgrade](RebuffedUpgrade) | 1.0.1 | Ausrüstung beim Darüberfahren mit der Maus für die aktuelle Skillung bewerten |

## Installation

1. Oben auf **Code → Download ZIP** klicken und das Archiv entpacken.
2. WoW vollständig schließen.
3. Die gewünschten Addon-Ordner direkt nach `World of Warcraft/Interface/AddOns/` kopieren. Zum Beispiel muss dort `AddOns/ChronixHeal/ChronixHeal.toc` liegen.
4. WoW starten und die Addons in der Charakterauswahl aktivieren.

Der äußere Ordner `wotlk-addons-main` gehört nicht ins Addon-Verzeichnis. Bei einem Update den jeweiligen Addon-Ordner ersetzen. Einstellungen liegen im WTF-Ordner und bleiben dabei erhalten.

ChronixHeal und RebuffedItemLevel laufen einzeln. RebuffedRaidMarket benötigt RebuffedItemLevel für den GearScore in eigenen Anzeigen; die Kanalübersicht funktioniert auch ohne. RebuffedUpgrade benötigt zusätzlich **Pawn 1.3.8 für WoW 3.3.5a**. Pawn ist hier nicht enthalten.

## Bedienung

| Addon | Einstieg |
| --- | --- |
| ChronixHeal | Minimap-Symbol oder `…` im Heilfenster |
| RebuffedItemLevel | Charakterfenster öffnen oder mit der Maus auf einen Spieler zeigen |
| RebuffedRaidMarket | `/raidmarkt`, `/rrm` oder Minimap-Symbol; `/raidpost` öffnet die eigene Anzeige |
| RebuffedUpgrade | Mit der Maus auf ein Ausrüstungsitem zeigen; `/upgrade` zeigt die verwendete Bewertung |

Die einzelnen READMEs erklären die Einstellungen und Grenzen. Die Addons sind für den alten 3.3.5a-Client gedacht. Retail und neuere Classic-Clients werden nicht unterstützt. Abweichungen der Server-API können einzelne Funktionen beeinflussen.

## Fehler melden

Bitte im Issue das Addon, seine Version und die Schritte zum Fehler nennen. Hilfreich sind die Clientsprache, beteiligte andere Addons und der Lua-Fehlertext. Bei einer falsch sortierten Chatanzeige reicht die betreffende Nachricht ohne Spielernamen.

Das Repository enthält die Addon-Dateien und Dokumentation. Gespeicherte Charakterdaten und andere installierte Addons sind nicht enthalten.
