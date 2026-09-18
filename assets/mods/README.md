# Mods

Hier liegen Dateien, die die ausgelieferten Spieldaten **überschreiben**, ohne sie zu
ersetzen. Das Modding-Tool fasst diesen Ordner nie an.

## Was heute überschrieben werden kann

`building_rules.data` — die Regeln jedes Bauwerks und jeder Mauerfamilie: Rolle,
Trefferpunkte, Baukosten, Arbeitsplätze, Kapazität, Stufe. Die ausgelieferte Datei liegt in
`assets/world/buildings/building_rules.data`.

`tile_connection_rules.data` — welches Bild eine Kachelfamilie zeigt, sobald ihre Nachbarn
feststehen: die 256 Mauerkacheln und der Fluss. Die ausgelieferte Datei liegt in
`assets/world/terrain/tile_connection_rules.data`. Ein Beispiel steht in
`assets/mods/beispiel_fluss/`.

**Der Dateiname entscheidet, welcher Lader eine Moddatei sieht.** Beide Lader nehmen nur
Dateien mit *ihrem* Namen aus `mod_data`. Eine Datei mit einem anderen Namen wird von beiden
übergangen — und nicht, wie früher, dem Bauregel-Parser vorgeworfen, der den Start mit einer
Meldung über Bauregeln abgebrochen hat.

## Wie ein Mod geladen wird

1. Eigenen Ordner anlegen, zum Beispiel `assets/mods/harte_tore/`.
2. Darin eine `building_rules.data` ablegen. Sie enthält **nur, was sich ändern soll**.
3. Den Pfad in `assets/castle_sim_data.assets.ron` unter `"mod_data"` eintragen:

```ron
    "mod_data": Files (
        paths: [
            "mods/harte_tore/building_rules.data",
        ],
    ),
```

Ohne diesen Eintrag lädt das Spiel die Datei nicht. Das ist Absicht: so steht die
Ladereihenfolge in einer Datei, die man lesen kann, und nicht in der Reihenfolge, in der
das Dateisystem einen Ordner aufzählt — zwei Mitspieler bekämen sonst verschiedene Regeln.

## Die Regeln des Überschreibens

- Zuerst wird die ausgelieferte Datei gelesen, dann jede Moddatei, **nach Pfad sortiert**.
- Zusammengeführt wird je Schlüssel **und je Feld**. Wer nur `Hp` von `gate_0` setzt,
  ändert nur das; Rolle, Kosten und Kapazität bleiben stehen.
- Auch innerhalb von `Cost` wird je Feld zusammengeführt: wer nur `Stone` setzt, macht das
  Bauwerk nicht holzfrei.
- Sagen zwei Mods dasselbe, gewinnt der **spätere Pfad**.
- Ein Schlüssel, den die ausgelieferte Datei nicht kennt, legt ein neues Bauwerk an.
- Ein Schlüssel, den keine Datei nennt, ist Kulisse: 100 Trefferpunkte, keine Kosten,
  keine Rolle.
- Ein Tippfehler in einem Feldnamen **bricht den Start ab** und nennt die Datei. Ein still
  übergangener Mod wäre schlimmer: zwei Spieler glaubten, dieselben Regeln zu haben.

## Felder

| Feld | Bedeutung | ohne Angabe |
|---|---|---|
| `Role` | `Scenery`, `Stockpile`, `Granary`, `Keep`, `Hovel`, `Woodcutter`, `Farm`, `Workshop`, `Barracks`, `Tower`, `Gate`, `Wall` | `Scenery` |
| `Hp` | Trefferpunkte | 100 |
| `Cost` | `{ "Wood": n, "Stone": n, "Gold": n }` | 0 |
| `WorkerSlots` | gleichzeitige Arbeiter | 0 |
| `Capacity` | Fassungsvermögen in Waren | 0 |
| `Tier` | Stufe in der Produktionskette | 0 |

Die Zahlen der ausgelieferten Datei sind **Platzhalter** in stimmiger Größenordnung
(Holzmauer schwächer als Steinmauer, Turm teurer als Mauer). Sie sind nicht aus einer
Quelle übernommen und werden mit den Wirtschaftskarten nachgezogen.
