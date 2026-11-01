# RebuffedRaidMarket

RebuffedRaidMarket sammelt Raidgesuche und Handelsanzeigen aus einem einstellbaren Chat. Das Fenster sortiert Raidanzeigen nach Raidnamen und Handelsanzeigen unter **Kaufen** oder **Verkaufen**. Ein Klick auf eine Anzeige öffnet eine Flüsternachricht an den Verfasser.

## Chat auswählen

Das Minimap-Symbol, `/raidmarkt` oder `/rrm` öffnen das Fenster. Oben den Kanalnamen oder die Kanalnummer eintragen. Als Vorgabe ist `world` eingetragen. Möglich sind auch Gilden-, Gruppen-, Raid- und Sagen-Chat, zum Beispiel `g`, `p`, `raid` oder `s`.

Das Addon tritt keinem Kanal selbst bei. Es erfasst nur neue Nachrichten aus dem ausgewählten Chat. Nach `/reload` oder einem Kanalwechsel ist die Liste zunächst leer.

Die Erkennung verwendet deutsche und englische Schlüsselwörter. Anzeigen für mehrere Raids erscheinen in den jeweiligen Rubriken. Nachrichten werden nach 15 Minuten entfernt; die Liste enthält höchstens 300 Einträge. Wiederholungen derselben Anzeige aktualisieren den Zeitstempel.

Raidmarkierungen wie `{star}` oder `{rt1}` werden als Symbole angezeigt. Itemlinks lassen sich mit der Maus ansehen. Das Minimap-Symbol lässt sich mit gedrückter linker Maustaste verschieben.

## Eigene Anzeige

**Eigene Anzeige** oder `/raidpost` öffnen den Entwurf. Dort LFM oder LFG, Klasse bzw. Skillung, Rolle und die gewünschten Raids auswählen. Mehrere Raids sind möglich. Größe und Schwierigkeit lassen sich je Raid einstellen; „Beliebig“ lässt die jeweilige Angabe weg.

Der GearScore stammt aus RebuffedItemLevel und wird auf eine Nachkommastelle in Tausendern gerundet, etwa `3.6k GS`. Für diese Funktion muss RebuffedItemLevel aktiviert sein und bereits einen gültigen Wert liefern.

Die erzeugte Nachricht ist auf Englisch. Bekannte deutsche Klassen, Skillungen und Zusatzangaben werden übersetzt. Freitext ist auf bekannte Begriffe begrenzt. Unbekannte Wörter verhindern den Start und müssen angepasst werden; eine allgemeine Textübersetzung findet nicht statt.

**Start** sendet die Anzeige sofort in den ausgewählten Chat und danach alle fünf Minuten. Die Wiederholung endet, sobald du einer Gruppe oder einem Raid beitrittst oder **Stopp** drückst. Auch LFM-Anzeigen können nur außerhalb einer Gruppe gestartet werden. Das Schließen des Fensters beendet die Wiederholung nicht.

Änderungen am Entwurf oder Kanal stoppen die laufende Anzeige. Nach `/reload`, einem Neustart oder dem Verlassen einer Gruppe muss sie von Hand gestartet werden. Der Entwurf wird pro Charakter gespeichert. Nachrichten über 255 Bytes werden nicht gesendet.

## Grenzen

Die Einordnung folgt dem Nachrichtentext und kann bei Abkürzungen oder ungewöhnlichen Formulierungen falsch liegen. Es gibt keine Suche im bisherigen Chatverlauf und keine Prüfung, ob eine Anzeige noch freie Plätze hat. Die Kanalübersicht benötigt keine weiteren Addons.
