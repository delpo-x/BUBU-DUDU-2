extends Node
## Autoload "GameState" for chapter 2: story progress, solved puzzles, cookies (hint money),
## found secrets and settings, saved to user://save.json. Shared scripts (Voices, UiTheme)
## read voices_enabled, reduce_motion and large_text from here, as in the first game.

const SAVE_PATH := "user://save.json"
const PUZZLES_PATH := "res://data/puzzles.json"
const CHAPTERS_PATH := "res://data/chapters.json"

var puzzles: Dictionary = {}       # id -> definition (data/puzzles.json)
var chapters: Array = []           # data/chapters.json

var chapter: int = 0
var zone: String = ""
var cookies: int = 0
var solved: Dictionary = {}        # puzzle id -> points earned
var tries: Dictionary = {}         # puzzle id -> wrong answers so far (sets the current value)
var hints: Dictionary = {}         # puzzle id -> hints bought (0..4, 4 = super hint)
var found: Dictionary = {}         # hotspot id -> true (cookies picked up, puzzles met)
var flags: Dictionary = {}

var voices_enabled: bool = true
var reduce_motion: bool = false
var large_text: bool = false


func _ready() -> void:
	puzzles = _read(PUZZLES_PATH, {})
	chapters = _read(CHAPTERS_PATH, [])
	load_game()


func _read(path: String, fallback: Variant) -> Variant:
	if not FileAccess.file_exists(path):
		return fallback
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return fallback if v == null else v


# --- Puzzles ---------------------------------------------------------------------------

func puzzle(id: String) -> Dictionary:
	return puzzles.get(id, {})


## Points the puzzle is worth right now: full value, minus a tenth per wrong answer,
## never below a third.
func value_now(id: String) -> int:
	var base := int(puzzle(id).get("value", 30))
	var lost := int(ceil(base * 0.1 * int(tries.get(id, 0))))
	return maxi(base - lost, int(ceil(base / 3.0)))


func is_solved(id: String) -> bool:
	return solved.has(id)


func total_points() -> int:
	var t := 0
	for v in solved.values():
		t += int(v)
	return t


func solved_count() -> int:
	return solved.size()


func mark_wrong(id: String) -> void:
	tries[id] = int(tries.get(id, 0)) + 1
	save_game()


func mark_solved(id: String) -> int:
	if not solved.has(id):
		solved[id] = value_now(id)
	save_game()
	return int(solved[id])


func hints_bought(id: String) -> int:
	return int(hints.get(id, 0))


func hint_cost(id: String) -> int:
	return 2 if hints_bought(id) == 3 else 1   # the super hint costs two


## Buys the next hint for a puzzle. Returns false when none is left or cookies run short.
func buy_hint(id: String) -> bool:
	var n := hints_bought(id)
	var cost := hint_cost(id)
	if n >= 4 or cookies < cost:
		return false
	cookies -= cost
	hints[id] = n + 1
	save_game()
	return true


# --- World -----------------------------------------------------------------------------

func get_chapter(i: int = -1) -> Dictionary:
	var k := chapter if i < 0 else i
	return chapters[k] if k >= 0 and k < chapters.size() else {}


func pick_up(hotspot: String, amount: int) -> bool:
	if found.has(hotspot):
		return false
	found[hotspot] = true
	cookies += amount
	save_game()
	return true


func set_flag(key: String, value: Variant = true) -> void:
	flags[key] = value
	save_game()


func get_flag(key: String, fallback: Variant = null) -> Variant:
	return flags.get(key, fallback)


# --- Save ------------------------------------------------------------------------------

func new_game() -> void:
	chapter = 0
	zone = ""
	cookies = 0
	solved = {}
	tries = {}
	hints = {}
	found = {}
	flags = {}
	save_game()


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"chapter": chapter, "zone": zone, "cookies": cookies, "solved": solved, "tries": tries,
		"hints": hints, "found": found, "flags": flags,
		"voices": voices_enabled, "reduce_motion": reduce_motion, "large_text": large_text,
	}))


func load_game() -> void:
	var d: Variant = _read(SAVE_PATH, {})
	if not d is Dictionary:
		return
	chapter = int(d.get("chapter", 0))
	zone = String(d.get("zone", ""))
	cookies = int(d.get("cookies", 0))
	solved = d.get("solved", {})
	tries = d.get("tries", {})
	hints = d.get("hints", {})
	found = d.get("found", {})
	flags = d.get("flags", {})
	voices_enabled = bool(d.get("voices", true))
	reduce_motion = bool(d.get("reduce_motion", false))
	large_text = bool(d.get("large_text", false))
