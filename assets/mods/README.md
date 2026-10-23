# Mods

Hier liegen Dateien, die die ausgelieferten Spieldaten **überschreiben**, ohne sie zu
ersetzen. Das Modding-Tool fasst diesen Ordner nie an.

## Was heute überschrieben werden kann

`building_rules.data` — die Regeln jedes Bauwerks und jeder Mauerfamilie: Rolle,
Trefferpunkte, Baukosten, Arbeitsplätze, Kapazität, Stufe. Die ausgelieferte Datei liegt in
`assets/world/buildings/building_rules.data`.

`economy_rules.data` — der Warenkatalog: welche Waren es gibt, wo sie liegen und wie viel ein
Träger auf einmal trägt (`Goods`). Die Rezepte der Gebäude stehen in `building_rules.data`
(`Recipes`). Die ausgelieferte Datei liegt in `assets/world/economy_rules.data`.

`target_picks.data` — wie viel ein Mann einer Klasse dem wert ist, der sein Ziel wählt: je Wähler
(`Melee`, `Shooter`) und Zielklasse (`TargetClass` des Typs in `animals.data`) ein Paar
`{"Quarters": a, "Px": b}`; ein Mann in Entfernung d ist `a · d / 4 + b` wert, der kleinste Wert
gewinnt. Die ausgelieferte Datei liegt in `assets/entities/target_picks.data` und nennt jede Klasse
für beide Wähler; ein Mod nennt nur die Paare, die er ändert. Die Zahlen sind Startwerte
(VERMUTUNG).

`tile_connection_rules.data` — welches Bild eine Kachelfamilie zeigt, sobald ihre Nachbarn
feststehen: die 256 Mauerkacheln und der Fluss. Die ausgelieferte Datei liegt in
`assets/world/terrain/tile_connection_rules.data`. Ein Beispiel steht in
`assets/mods/beispiel_fluss/`.

**Der Dateiname entscheidet, welcher Lader eine Moddatei sieht.** Jeder Lader nimmt nur
Dateien mit *seinem* Namen aus `mod_data`. Eine Datei mit einem anderen Namen wird von allen
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
| `Role` | `Scenery`, `Stockpile`, `Granary`, `Keep`, `Hovel`, `Woodcutter`, `Farm`, `Workshop`, `Barracks`, `Armory`, `Mine`, `Tower`, `Gate`, `Wall` | `Scenery` |
| `Hp` | Trefferpunkte | 100 |
| `Cost` | `{ "Wood": n, "Stone": n, "Iron": n, "Pitch": n, "Gold": n }`: ganze Einheiten je Bauwerk (je Zelle bei Mauer und Rampe); der Spieler zahlt sie im Spielmodus aus seinen Lagern, Gold aus seiner Kasse, der Editor baut gratis. Eine Ware, die `economy_rules.data` nicht kennt, bricht den Start ab | 0 |
| `QuarterCost` | `{ "Wood": n, "Stone": n, "Iron": n, "Pitch": n }`: Viertel einer Einheit je Mauerzelle und Rampenstück (2 ist ein halber Stein), für die Spalte, die `Cost` bei 0 lässt; eine Spalte, die `Cost` nennt, gewinnt. Gold gibt es hier nicht | 0 |
| `WorkerSlots` | gleichzeitige Arbeiter | 0 |
| `Capacity` | Fassungsvermögen von Kornspeicher und Waffenkammer in Stück, alle Waren zusammen; mit 0 oder weniger fasst der Speicher nichts | 0 |
| `Stacks` | Stapel eines Lagerplatzes (`Stockpile`); er fasst, was sie fassen (`Stack` je Ware in `economy_rules.data`), und `Capacity` zählt dort nicht; ohne `Stacks` fasst er nichts | 0 |
| `Tier` | Stufe in der Produktionskette | 0 |
| `Indestructible` | `true`: unzerstörbar. Ein Angriffsbefehl darauf wird verweigert, kein Schlag nimmt ihm Trefferpunkte, und im Spielmodus reißt der Spieler es nicht ab. Mauer, Tor, Turm und Rampe zählen nie als Stein, der eine Seite im Spiel hält, auch unzerstörbar nicht; jedes andere unzerstörbare Gebäude (das Gasthaus) hält seine Seite im Spiel | `false` |
| `Recipes` | Liste von Rezepten, Index 0 ist der Start: `{ "Inputs": { "wheat": 1 }, "Outputs": { "flour": 1 }, "WorkTicks": 400, "Bonus": false }`. `Bonus` ohne Angabe heißt: der Gefechtsbonus von +50 % gilt. Eine Mod ersetzt die Liste **ganz** (`[]` nimmt dem Gebäude sein Rezept) | keine |
| `Shelf` | Stück, die die Ablage am Gebäude von dem hält, was es herstellt | 0 |
| `Intake` | Stück, die das Gebäude von jeder Eingangsware annimmt | 0 |
| `Entrance` | Zelle, zu der Träger gehen, relativ zur Mitte, `"x,y"` | keine |
| `FallDamagePercent` | Prozent der vollen Trefferpunkte, die jeder Mann auf dem Grundriss verliert, wenn das Bauwerk fällt (0 bis 100); Turm und Torhaus ohne Angabe 50, jede andere Rolle 0. Nur für Bauwerke, Mauerstücke fallen ohne Schaden | Rolle |

Die Zahlen der ausgelieferten `building_rules.data` sind **Platzhalter** in stimmiger Größenordnung
(Holzmauer schwächer als Steinmauer, Turm teurer als Mauer). Sie sind nicht aus einer
Quelle übernommen und werden mit den Wirtschaftskarten nachgezogen.

## Waren (`economy_rules.data`)

Eine Datei mit dem Schlüssel `Goods`, je Ware ein Eintrag; zusammengeführt wird wie bei den
Bauregeln je Ware und je Feld, nach Pfad sortiert.

| Feld | Bedeutung | ohne Angabe |
|---|---|---|
| `Store` | Rolle des Gebäudes, das die Ware lagert (`Stockpile`, `Granary`, `Armory`) | keine: die Ware wird nur weitergereicht |
| `Stack` | Stück je Stapel eines Lagerplatzes: ein Stapel hat 96 Teile, ein Stück belegt 96 / `Stack` davon. `Stack` muss 96 teilen (1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48 oder 96), sonst bricht das Laden mit dem Dateinamen ab. `0`: ein Stück belegt ein Teil. Kornspeicher und Waffenkammer zählen Stück und lesen es nicht | 0 |
| `Load` | Stück, die ein Träger je Gang trägt, mindestens 1 | Fehler |
| `CarriedBy` | Einheitentyp aus `animals.data`, der die Ware trägt | `peasant` |

Die Waren werden nach Namen sortiert, und die Stelle in dieser Reihenfolge ist die Nummer der
Ware (`WareId`): wer eine Ware hinzufügt, verschiebt die Nummern der späteren, bei allen
Mitspielern gleich, solange sie dieselben Dateien laden. Höchstens 32 Waren.

Dazu zwei Schlüssel neben `Goods`: `StartGoods` (`{ "wood": 80 }`, Stück je Ware, die jedes Team beim Wechsel ins Spiel in seine Lager gelegt bekommt, bis es sie hat) und `StartGold`. Eine Ware, die es nicht gibt oder die kein Lager hält, bricht den Start ab. Die Zahlen der ausgelieferten Datei sind Platzhalter.

Der Start bricht mit dem Dateinamen ab bei: einer Ware mit `Load` 0, einem `CarriedBy`, das kein
Einheitentyp ist, mehr als 32 Waren, einer Ware, die ein Rezept nicht kennt, einem Rezept mit
mehr als 3 Eingängen oder 2 Ausgängen, einem Rezept ganz ohne Ein- und Ausgang, einer Menge 0 in
einem Rezept, einer Ware ohne `Store`, die kein Rezept als Eingang nennt, und einem Preis in einer Ware,
die der Katalog nicht führt.

Das nächste Glied einer Kette ist jedes Gebäude, dessen Rezept die Ware als Eingang nennt; ein
Feld „Next“ gibt es nicht.

Die Ladungen und Stapel der ausgelieferten `economy_rules.data` sind Crusaders Werte, ausser der
Ladung 1 der Waffen (VERMUTUNG); die Arbeitszeiten (`WorkTicks`) der Rezepte sind Platzhalter.
