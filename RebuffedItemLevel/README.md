# RebuffedItemLevel

Zeigt das durchschnittliche angelegte Itemlevel und den GearScore im eigenen Charakterfenster, beim Untersuchen und neben dem Namen im Spieler-Tooltip. Nach der Installation ist keine Einrichtung nötig.

## Anzeige

Im eigenen Charakterfenster stehen die Werte unter der Titelauswahl. Beim Untersuchen erscheinen sie unter der Charakterbeschreibung. Im Spieler-Tooltip sieht die Ergänzung beispielsweise so aus: `[iLvl 232.5 | GS 5000]`.

- `...`: Die Daten werden noch geladen.
- `?`: Es liegen keine Daten vor oder der Spieler kann gerade nicht untersucht werden.
- `*`: Der gespeicherte Wert eines anderen Spielers ist älter als zehn Minuten.

Für fremde Spieler muss der Server zunächst Ausrüstungsdaten liefern. Dafür in der Nähe bleiben und kurz mit der Maus auf den Spieler zeigen. Im Kampf beginnt keine automatische Untersuchung. Ein geöffnetes Untersuchenfenster hat Vorrang.

## Berechnung

Das Itemlevel ist der Durchschnitt über 17 Ausrüstungsplätze einschließlich Fernkampfwaffe oder Relikt. Hemd und Wappenrock zählen nicht. Leere Plätze zählen als null. Eine Zweihandwaffe zählt bei leerer Nebenhand für beide Waffenplätze.

Der GearScore verwendet die klassische [GearScoreLite-Formel und ihre Gewichte](https://github.com/Arcitec/GearScoreLite_Reborn), ohne Abzug für fehlende Verzauberungen. Jägerwaffen, Titanengriff und Erbstücke werden gesondert berücksichtigt. Andere GearScore-Versionen können abweichende Werte liefern. Ein zusätzliches GearScore-Addon ist nicht erforderlich.

## Abfragen

Andere Spieler werden pro Hover höchstens einmal automatisch untersucht. Ergebnisse bleiben zehn Minuten aktuell und werden während dieser Zeit wiederverwendet. Zwischen automatischen Untersuchungen liegen mindestens zwei Sekunden. Eine ausbleibende Antwort beendet die Abfrage nach fünf Sekunden; für einen neuen Versuch die Maus weg- und zurückbewegen.

Die eigene Ausrüstung wird bei passenden Spielereignissen neu berechnet. Fehlende Itemdaten werden zeitlich begrenzt nachgeladen. Fremde Spielerdaten werden nur für die laufende Sitzung gespeichert.

RebuffedRaidMarket kann den eigenen GearScore über `RebuffedItemLevel_GetPlayerGearScore()` auslesen. Der Aufruf liest den gespeicherten Wert und startet keinen neuen Ausrüstungsscan.
