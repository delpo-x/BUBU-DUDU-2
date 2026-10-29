extends Node
## Chapter 2 main scene: runs the current chapter's zone, the HUD (cookies, hearts, puzzles
## solved), the speech box, puzzle sheets and the suitcase (pause) menu.
## `-- shot` saves user://shot_zone.png and quits; `-- shot_puzzle` does the same with a
## puzzle sheet open (for checks without a pad).

var _zone: Zone
var _ui: Control
var _hud: Label
var _talk: PanelContainer
var _talk_face: StickerView
var _talk_name: Label
var _talk_text: Label
var _lines: Array = []
var _after_talk: Callable = Callable()
var _suitcase: Control
var _busy := false


func _ready() -> void:
	var ch := GameState.get_chapter()
	_zone = Zone.new()
	add_child(_zone)
	_zone.setup(ch.get("zone", {}))
	_zone.interact.connect(_on_interact)
	_build_ui()
	Sfx.play_music(String(ch.get("music", "ch2")))
	if not GameState.get_flag("intro_%d" % GameState.chapter, false):
		_say(ch.get("intro", []), func() -> void: GameState.set_flag("intro_%d" % GameState.chapter))
	if GameState.solved_count() >= _gate_needs():
		_zone.open_gate()
	var args := OS.get_cmdline_user_args()
	if "shot" in args or "shot_puzzle" in args:
		_shot("shot_puzzle" in args)


func _gate_needs() -> int:
	for h: Dictionary in GameState.get_chapter().get("zone", {}).get("hotspots", []):
		if h.get("kind") == "gate":
			return int(h.get("needs", 0))
	return 0


# --- UI --------------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.theme = UiTheme.get_theme()
	layer.add_child(_ui)

	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override(&"panel", UiTheme.box(UiTheme.PANEL, 18, 0, Color.TRANSPARENT, 14))
	chip.position = Vector2(20, 20)
	_hud = UiTheme.label("", 22)
	chip.add_child(_hud)
	_ui.add_child(chip)
	var title := UiTheme.label(String(GameState.get_chapter().get("title", "")), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	title.add_theme_color_override(&"font_outline_color", UiTheme.INK)
	title.add_theme_constant_override(&"outline_size", 8)
	title.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	title.position = Vector2(-620, 26)
	title.size = Vector2(600, 40)
	_ui.add_child(title)

	_talk = PanelContainer.new()
	_talk.add_theme_stylebox_override(&"panel", UiTheme.lift(UiTheme.box(UiTheme.PANEL, 22, 0, Color.TRANSPARENT, 18)))
	_talk.position = Vector2(140, 500)
	_talk.custom_minimum_size = Vector2(1000, 190)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 18)
	_talk.add_child(row)
	_talk_face = StickerView.new("", Vector2(150, 150))
	row.add_child(_talk_face)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	_talk_name = UiTheme.label("", 26)
	col.add_child(_talk_name)
	_talk_text = UiTheme.label("", UiTheme.read_size(24))
	_talk_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_talk_text)
	_talk.visible = false
	_ui.add_child(_talk)
	_refresh_hud()


func _refresh_hud() -> void:
	_hud.text = "Biscottini %d    Cuoricini %d    Enigmi %d/%d" % [
		GameState.cookies, GameState.total_points(), GameState.solved_count(), GameState.puzzles.size()]


# --- Speech ----------------------------------------------------------------------------

## Shows lines [[who, text, mood], ...] one by one, then calls `done`.
func _say(lines: Array, done: Callable = Callable()) -> void:
	if lines.is_empty():
		if done.is_valid():
			done.call()
		return
	_lines = lines.duplicate()
	_after_talk = done
	_busy = true
	_zone.active = false
	_talk.visible = true
	UiTheme.pop_in(_talk)
	_next_line()


func _next_line() -> void:
	if _lines.is_empty():
		_talk.visible = false
		_busy = false
		_zone.active = true
		var cb := _after_talk
		_after_talk = Callable()
		if cb.is_valid():
			cb.call()
		return
	var l: Array = _lines.pop_front()
	var who := String(l[0])
	var mood := String(l[2]) if l.size() > 2 else ""
	var face := "%s_%s" % [who, mood]
	_talk_face.sticker = face if ResourceLoader.exists("res://art/stickers/%s.tres" % face) else ("bubu_shy" if who == "bubu" else "dudu_idle")
	_talk_name.text = who.capitalize()
	_talk_name.add_theme_color_override(&"font_color", UiTheme.BUBU if who == "bubu" else UiTheme.DUDU)
	_talk_text.text = String(l[1])
	if mood != "":
		Voices.emote(who, mood)
	Sfx.play("text", 0.0, -8.0)


# --- Hotspots --------------------------------------------------------------------------

func _on_interact(h: Dictionary) -> void:
	if _busy:
		return
	match String(h.get("kind")):
		"puzzle":
			var id := String(h["puzzle"])
			if GameState.is_solved(id):
				_say([["bubu", "Questo l'abbiamo già risolto! %d cuoricini." % int(GameState.solved[id]), "smug"]])
			else:
				_say([h.get("line", ["bubu", "Un enigma!", "hey"])], _open_puzzle.bind(id))
		"cookie":
			var n := int(h.get("amount", 1))
			if GameState.pick_up(String(h["id"]), n):
				_zone.consume(String(h["id"]))
				Sfx.play("pickup")
				_refresh_hud()
				_say([["dudu", "Trovato%s %d biscottin%s aiuto!" % ["" if n == 1 else "i", n, "o" if n == 1 else "i"], "snack"]])
		"gate":
			var need := int(h.get("needs", 0))
			if GameState.solved_count() >= need:
				_zone.open_gate()
				_say([h.get("open", ["dudu", "Aperto!", "laugh"])])
			else:
				var l: Array = (h.get("locked", ["bubu", "Servono %d enigmi.", "sulk"]) as Array).duplicate()
				l[1] = String(l[1]) % need
				_say([l])
		"end":
			_say([["bubu", "Fine della demo del capitolo! Grazie per aver giocato.", "cute"]])


func _open_puzzle(id: String) -> void:
	_busy = true
	_zone.active = false
	var p := Puzzle.new()
	add_child(p)
	p.open(id)
	p.finished.connect(func(_solved: bool) -> void:
		_busy = false
		_zone.active = true
		_refresh_hud())


# --- Suitcase (pause) ------------------------------------------------------------------

func _open_suitcase() -> void:
	_busy = true
	_zone.active = false
	_suitcase = PanelContainer.new()
	_suitcase.add_theme_stylebox_override(&"panel", UiTheme.lift(UiTheme.box(UiTheme.PANEL, 22, 0, Color.TRANSPARENT, 26)))
	_suitcase.position = Vector2(340, 80)
	_suitcase.custom_minimum_size = Vector2(600, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 12)
	_suitcase.add_child(v)
	v.add_child(UiTheme.label("La valigia", 40, UiTheme.ACCENT_INK))
	v.add_child(UiTheme.label("Enigmi risolti", 22, UiTheme.MUTED))
	var ids := GameState.puzzles.keys()
	ids.sort()
	for id: String in ids:
		var line := "%s  %s" % [id.trim_prefix("p"), GameState.puzzle(id).get("title", "")]
		var done := GameState.is_solved(id)
		v.add_child(UiTheme.label(line + ("   %d cuoricini" % int(GameState.solved[id]) if done else "   ancora da trovare"), 20, UiTheme.INK if done else UiTheme.MUTED))
	var buttons: Array[Control] = [
		UiTheme.button("Riprendi", _close_suitcase),
		UiTheme.button("Ricomincia da capo", func() -> void:
			GameState.new_game()
			get_tree().reload_current_scene()),
		UiTheme.button("Esci dal gioco", func() -> void: get_tree().quit()),
	]
	for b in buttons:
		v.add_child(b)
	UiTheme.chain_focus(buttons)
	_ui.add_child(_suitcase)
	UiTheme.pop_in(_suitcase)
	buttons[0].call_deferred("grab_focus")


func _close_suitcase() -> void:
	_suitcase.queue_free()
	_suitcase = null
	_busy = false
	_zone.active = true


func _unhandled_input(event: InputEvent) -> void:
	if _talk.visible and UiTheme.is_advance(event):
		get_viewport().set_input_as_handled()
		_next_line()
	elif _suitcase != null and (UiTheme.is_back(event) or UiTheme.is_pause(event)):
		get_viewport().set_input_as_handled()
		_close_suitcase()
	elif not _busy and UiTheme.is_pause(event):
		get_viewport().set_input_as_handled()
		_open_suitcase()


# --- Checks ----------------------------------------------------------------------------

func _shot(puzzle: bool) -> void:
	for i in 60:
		await get_tree().process_frame
	_talk.visible = false
	_busy = false
	_zone.active = true
	if puzzle:
		_open_puzzle("p002")
		for i in 30:
			await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://shot_%s.png" % ("puzzle" if puzzle else "zone"))
	get_tree().quit()
