class_name Puzzle
extends CanvasLayer
## Full-screen puzzle sheet, driven by pad focus. Left: number, title, current value and the
## question. Right: the answer control ("number" = minus / value / plus, "choice" = one
## button per option) and the hints bought so far. Each wrong answer lowers the value;
## hints cost cookies (the fourth, the super hint, costs two).
## Emits `finished(solved)` when the player leaves the sheet.

signal finished(solved: bool)

var _id: String = ""
var _def: Dictionary = {}
var _number := 0
var _number_label: Label
var _value_label: Label
var _hint_box: VBoxContainer
var _hint_button: Button
var _cookies_label: Label
var _root: Control
var _sheet: Control
var _result: Control
var _first: Control


func open(id: String) -> void:
	_id = id
	_def = GameState.puzzle(id)
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.get_theme()
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = UiTheme.BG
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_sheet = _build_sheet()
	_root.add_child(_sheet)
	UiTheme.pop_in(_sheet)
	_first.call_deferred("grab_focus")
	Sfx.play("chapter", 0.0, -6.0)


func _card(min_size: Vector2, at: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override(&"panel", UiTheme.lift(UiTheme.box(UiTheme.PANEL, 22, 0, Color.TRANSPARENT, 28)))
	p.custom_minimum_size = min_size
	p.position = at
	return p


func _build_sheet() -> Control:
	var panel := _card(Vector2(1120, 600), Vector2(80, 60))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override(&"separation", 36)
	panel.add_child(cols)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(560, 0)
	left.add_theme_constant_override(&"separation", 14)
	cols.add_child(left)
	left.add_child(UiTheme.label("Enigma %s" % _id.trim_prefix("p"), 22, UiTheme.MUTED))
	left.add_child(UiTheme.label(String(_def.get("title", "")), 38, UiTheme.ACCENT_INK))
	_value_label = UiTheme.label("", 22, UiTheme.ACCENT_INK)
	left.add_child(_value_label)
	var q := UiTheme.label(String(_def.get("text", "")), UiTheme.read_size(24))
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(q)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override(&"separation", 12)
	cols.add_child(right)
	right.add_child(UiTheme.label("La vostra risposta", 22, UiTheme.MUTED))
	var focus: Array[Control] = []
	if String(_def.get("kind")) == "choice":
		var opts: Array = _def.get("options", [])
		for i in opts.size():
			var b := UiTheme.button(String(opts[i]), _answer.bind(i))
			right.add_child(b)
			focus.append(b)
	else:
		_number = int(_def.get("min", 0))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override(&"separation", 16)
		var minus := UiTheme.button("−", _step.bind(-1))
		var plus := UiTheme.button("+", _step.bind(1))
		for b: Button in [minus, plus]:
			b.custom_minimum_size = Vector2(72, 72)
		_number_label = UiTheme.label("", 52, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER)
		_number_label.custom_minimum_size = Vector2(120, 0)
		row.add_child(minus)
		row.add_child(_number_label)
		row.add_child(plus)
		right.add_child(row)
		var ok := UiTheme.button("Rispondi", func() -> void: _answer(_number))
		right.add_child(ok)
		focus.append(plus)
		focus.append(ok)
		_step(0)
		# Left/right on the pad move between minus and plus; up/down go through the list.
		minus.focus_neighbor_right = minus.get_path_to(plus)
		plus.focus_neighbor_left = plus.get_path_to(minus)
		minus.focus_neighbor_bottom = minus.get_path_to(ok)

	right.add_child(HSeparator.new())
	_cookies_label = UiTheme.label("", 20, UiTheme.MUTED)
	right.add_child(_cookies_label)
	_hint_button = UiTheme.button("", _buy_hint)
	right.add_child(_hint_button)
	_hint_box = VBoxContainer.new()
	_hint_box.add_theme_constant_override(&"separation", 6)
	right.add_child(_hint_box)
	var leave := UiTheme.button("Ci penso dopo", _close.bind(false))
	right.add_child(leave)
	focus.append(_hint_button)
	focus.append(leave)
	UiTheme.chain_focus(focus)
	_first = focus[0]
	_refresh()
	return panel


func _step(by: int) -> void:
	_number = clampi(_number + by, int(_def.get("min", 0)), int(_def.get("max", 99)))
	_number_label.text = str(_number)


func _refresh() -> void:
	_value_label.text = "Vale %d cuoricini" % GameState.value_now(_id)
	_cookies_label.text = "Biscottini aiuto: %d" % GameState.cookies
	var n := GameState.hints_bought(_id)
	_hint_button.disabled = n >= 4
	if n >= 4:
		_hint_button.text = "Niente altri aiuti"
	elif n == 3:
		_hint_button.text = "Super aiuto (2 biscottini)"
	else:
		_hint_button.text = "Aiuto %d (1 biscottino)" % (n + 1)
	for c in _hint_box.get_children():
		c.queue_free()
	var texts: Array = _def.get("hints", [])
	for i in mini(n, texts.size()):
		var tag := "Super aiuto: " if i == 3 else "Aiuto %d: " % (i + 1)
		var l := UiTheme.label(tag + String(texts[i]), UiTheme.read_size(18))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(440, 0)
		_hint_box.add_child(l)


func _buy_hint() -> void:
	if not GameState.buy_hint(_id):
		Sfx.play("nope")
		_cookies_label.text = "Servono più biscottini! Cercateli in giro."
		return
	Sfx.play("collect", 0.0, -4.0)
	_refresh()


func _answer(given: int) -> void:
	if given == int(_def.get("answer", -1)):
		var pts := GameState.mark_solved(_id)
		Sfx.play("collect")
		_show_result(true, "%s\n\n+%d cuoricini" % [String(_def.get("right", "Esatto!")), pts])
	else:
		GameState.mark_wrong(_id)
		Sfx.play("nope")
		_show_result(false, String(_def.get("wrong", "Sbagliato!")))


func _show_result(right: bool, text: String) -> void:
	_sheet.visible = false
	_result = _card(Vector2(640, 0), Vector2(320, 90))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override(&"separation", 14)
	_result.add_child(v)
	v.add_child(UiTheme.label("Giusto!" if right else "Sbagliato...", 44, UiTheme.ACCENT_INK, HORIZONTAL_ALIGNMENT_CENTER))
	var st := StickerView.new("both_cheers" if right else "bubu_sad", Vector2(240, 220))
	st.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(st)
	var l := UiTheme.label(text, UiTheme.read_size(24), UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	var buttons: Array[Control] = []
	if right:
		buttons.append(UiTheme.button("Continua", _close.bind(true)))
	else:
		buttons.append(UiTheme.button("Riprova", _retry))
		buttons.append(UiTheme.button("Ci penso dopo", _close.bind(false)))
	for b in buttons:
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(b)
	UiTheme.chain_focus(buttons)
	_root.add_child(_result)
	UiTheme.pop_in(_result)
	buttons[0].call_deferred("grab_focus")


func _retry() -> void:
	_result.queue_free()
	_sheet.visible = true
	_refresh()
	_first.grab_focus()


func _close(solved: bool) -> void:
	finished.emit(solved)
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if UiTheme.is_back(event) and _sheet.visible:
		get_viewport().set_input_as_handled()
		_close(false)
