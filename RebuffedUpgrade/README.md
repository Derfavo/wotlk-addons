# RebuffedUpgrade

Ergänzt Ausrüstungs-Tooltips um eine Einschätzung für die aktuelle Skillung. Grundlage sind die vorhandenen Wowhead-Gewichtungen in **Pawn 1.3.8 für WoW 3.3.5a**. Pawn muss zusätzlich installiert und aktiviert sein.

Die Skillung wird anhand der verteilten Talentpunkte erkannt und nach einem Dual-Spec-Wechsel aktualisiert. Für Feral-Tank und Feral-Schaden sowie Todesritter-Tank und Schaden werden zusätzlich Rolle, Gestalt oder Präsenz verwendet. Bei einer unklaren Zuordnung gibt es keine eindeutige Empfehlung.

## Anzeige

- **Upgrade:** Der Bewertungswert liegt über dem angelegten Item.
- **Kleines Upgrade:** Der Unterschied beträgt weniger als ein Prozent.
- **Kein Upgrade:** Der Wert ist für die gewählte Skillung niedriger.
- **Prüfen:** Anforderungen, Setboni, unbekannte Effekte oder ein Wechsel des Waffensets benötigen einen eigenen Vergleich.
- **Nicht tragbar:** Die erforderliche Charakterstufe ist noch nicht erreicht.

Bei Ringen und Schmuckstücken dient der schwächere angelegte Platz als Vergleich. Eine Zweihandwaffe wird mit Haupt- und Nebenhand zusammen verglichen. Titanengriff und identische einzigartig anlegbare Items werden berücksichtigt.

Die Prozentzahl beschreibt den Unterschied im Pawn-Wert. Sie ist keine Vorhersage für mehr Schaden oder Heilung. Beide Items werden ohne Verzauberungen und mit Pawns Sockelbewertung verglichen. Treffer- und Defensiv-Caps, Setboni, Schmuckstückeffekte und Gruppen-Lootregeln können eine andere Entscheidung sinnvoll machen.

## Befehle

| Befehl | Funktion |
| --- | --- |
| `/upgrade` | Verwendete Bewertung anzeigen |
| `/upgrade auto` | Automatische Skillungserkennung einschalten |
| `/upgrade skalen` | Vorhandene Pawn-Skalen auflisten |
| `/upgrade skala NAME` | Eine bestimmte Pawn-Skala verwenden, mit dem exakten Namen aus der Liste |

Die Auswahl wird pro Charakter gespeichert. Eigene Gewichtungen lassen sich in Pawn pflegen.

Berechnet werden nur angesehene Items. Ergebnisse werden zwischengespeichert und bei Ausrüstungs-, Talent- oder Pawn-Änderungen verworfen. Fehlende Itemdaten werden höchstens zwei Sekunden nachgeladen. Andere Spieler werden nicht untersucht.

Die Tooltip-Ergänzung berücksichtigt den Neuaufbau durch Pawn und Auctionator. Auctionator selbst wird nicht verändert. Das Addon würfelt, plündert oder kauft keine Items automatisch.
