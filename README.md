# Bubu & Dudu 2

Second chapter of the Bubu & Dudu saga: a 2.5D puzzle adventure played with a pad.
Walk Bubu (and Dudu, on a second pad or following Bubu) around small 3D zones, talk to
what you find, solve puzzles for hearts, look for hidden cookies to buy hints, and open
the way to the next part of the story.

## Run

Open the folder in Godot 4.7 and press F5, or:

    godot --path . res://scenes/world/Game.tscn

Pad: left stick moves, Cross/A interacts and confirms, Options/Start opens the suitcase.

## Layout

- `data/puzzles.json` - puzzle sheets (kind `number` or `choice`, value, 3 hints + super hint).
- `data/chapters.json` - chapters: intro lines, zone size, hotspots (puzzle, cookie, gate).
- `scenes/world/Zone.gd` - the explorable 2.5D zone, players and hotspots.
- `scenes/world/Game.gd` - HUD, speech box, suitcase menu, chapter flow.
- `scenes/puzzle/Puzzle.gd` - the puzzle sheet.
- `scenes/core/GameState.gd` - save file and progress.

## Shared with the first game

Art, music, voices, pad input and the UI theme come from the first game's repository
(`BUBU-DUDU`), listed in `tools/shared.txt`. To pull its latest versions, with both
repositories side by side:

    sh tools/sync_shared.sh ../BUBU-DUDU

Everything else here is independent.
