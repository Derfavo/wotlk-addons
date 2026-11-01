# ChronixHeal

ChronixHeal zeigt Gruppe und Raid in einem Heilfenster mit bis zu 40 Spielern. Klickbelegungen wirken die eingestellten Zauber; Vorschläge helfen bei der Auswahl von Heilungen, Entzauberungen und Tankbuffs. Die Texte sind auf Deutsch und Englisch verfügbar.

## Heilfenster

Die Schaltflächen **S**, **M** und **F** wechseln zwischen Safe Mana, Mixed und Full Heal. Safe Mana bevorzugt sparsame Heilungen, Mixed nutzt die eingestellten Schwellen und Full Heal reagiert schon auf kleinere Lebensdefizite. Der Wechsel ist auch im Kampf möglich.

`…`, das Minimap-Symbol oder **Interface → AddOns → ChronixHeal** öffnen die Einstellungen. Dort lassen sich gelernte Zauber den Klickkombinationen zuweisen. Änderungen an diesen Belegungen sind nur außerhalb des Kampfes möglich. Die Belegung steht unter dem Spielernamen und im Tooltip.

Das Fenster lässt sich an der Kopfzeile verschieben, wenn es in den Einstellungen entsperrt ist. Ein Rechtsklick auf das Minimap-Symbol zeigt und zentriert es außerhalb des Kampfes.

Die Heilvorschläge unterstützen Wiederherstellungsschamanen, Heiligpaladine, Disziplin- und Heiligpriester sowie Wiederherstellungsdruiden. Magier können Flüche entfernen. Andere Klassen können das Gruppenfenster zur Zielauswahl verwenden.

## Tanks und Rollen

Die automatische Tankauswahl verwendet zugewiesene Dungeonfinder-Rollen und die Haupttank-Zuweisung des Raidleaders. Im Tankmenü kann ein Spieler auch manuell gewählt werden. Ohne Tankzuweisung dient der Fokus als Ersatz, solo der eigene Charakter.

Totenkopf und Kreuz kennzeichnen Tanks und Heiler innerhalb des Heilfensters. Sie setzen keine gemeinsamen Raid-Zielmarkierungen. Andere Spieler werden dafür nicht fortlaufend auf ihre Talente untersucht.

## Eigene Buffs

Eine separate Leiste zeigt kleine, dauerhaft anklickbare Buff-Icons. Die Auswahl folgt automatisch der Klasse und dem Talentbaum mit den meisten Punkten. Angeboten werden nur erlernte Zauber.

Ein roter Rand bedeutet: Der Buff fehlt oder hat nur noch eine Ladung. Aktive Buffs bleiben mit neutralem Rand sichtbar. Ein Linksklick erneuert den jeweiligen Buff auf dir oder verwendet das Gift bzw. den Waffenbuff auf dem vorgesehenen Waffenplatz. Die Icons funktionieren auch im Kampf. Mit gedrückter rechter Maustaste lässt sich die ganze Leiste außerhalb des Kampfes unabhängig vom Heilfenster verschieben.

| Klasse | Beispiele |
| --- | --- |
| Schamane | Wasser- oder Blitzschlagschild und Waffenbuffs passend zur Skillung |
| Schurke | Sofort wirkendes Gift auf der Haupthand und Tödliches Gift auf der Nebenhand, soweit vorhanden |
| Priester | Inneres Feuer, Seelenstärke, Willenskraft und Schattenschutz; bei Schatten auch Schattenform und Vampirumarmung |
| Paladin | Siegel, Aura und Segen; bei Schutz auch Zorn der Gerechtigkeit |
| Magier | Rüstung und Intelligenz |
| Hexenmeister | Rüstung und erlernte Seelenverbindung bei lebendem Begleiter |
| Druide | Mal der Wildnis; bei Wildem Kampf auch Dornen |
| Krieger | Schlacht- oder Befehlsruf |
| Jäger | Aspekt und erlernte Aura des Volltreffers |
| Todesritter | Präsenz und Horn des Winters |

Gifte müssen in den Taschen liegen. Der ursprüngliche Client kann den genauen Typ eines vorhandenen temporären Waffenbuffs nicht zuverlässig liefern; ein vorhandener Effekt wird deshalb akzeptiert. Permanente Verzauberungen und Runenschmiede-Runen werden nicht überwacht.

## Befehle und Mana-Warnung

- `/chheal mode safe`
- `/chheal mode mixed`
- `/chheal mode full`

`/chronixheal` kann statt `/chheal` verwendet werden. Die automatische Meldung „Out of Mana!“ erscheint nur in einer Gruppe oder einem Raid im Rufkanal, höchstens einmal pro anhaltender Mana-Notlage.

## Grenzen

Die Vorschläge beruhen auf festen Prioritäten. Sie berechnen weder bevorstehende Bossfähigkeiten noch Sichtlinie, fremde eingehende Heilungen oder die genauen Abstände zwischen Gruppenmitgliedern. Die Entzauberungs-Ausnahmen sind nicht vollständig. Ob ein vorgeschlagener Zauber in der Situation passt, entscheidet der Spieler. Heilungen und Buffs benötigen immer einen eigenen Klick.

Die Prioritäten orientieren sich an den Warmane-Guides für [Schamanen](https://forum.warmane.com/printthread.php?page=1&pp=15&t=271702), [Paladine](https://forum.warmane.com/showthread.php?t=325569), [Disziplinpriester](https://forum.warmane.com/showthread.php?t=334926), Heiligpriester ([Guide 1](https://forum.warmane.com/showthread.php?t=448147), [Guide 2](https://forum.warmane.com/showthread.php?t=56440)) und [Druiden](https://forum.warmane.com/showthread.php?t=325633). Die Modi sind eine eigene Umsetzung dieser Grundlagen.

Die Waffenbuff-Abfrage und sicheren Klickaktionen folgen den Schnittstellen des Blizzard-UI-Codes für 3.3.5: [BuffFrame.lua](https://github.com/tekkub/wow-ui-source/blob/3.3.5/FrameXML/BuffFrame.lua) und [SecureTemplates.lua](https://github.com/tekkub/wow-ui-source/blob/3.3.5/FrameXML/SecureTemplates.lua).
