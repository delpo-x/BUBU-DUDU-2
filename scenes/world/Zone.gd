class_name Zone
extends Node3D
## One explorable 2.5D zone: a small 3D garden built from data/chapters.json, Bubu and Dudu
## as their animated stickers, and hotspots (puzzles, hidden cookies, the story gate).
## Bubu walks with p1; Dudu walks with p2 and otherwise follows Bubu, so one pad is enough.
## Emits `interact` when a player presses interact next to a hotspot.

signal interact(hotspot: Dictionary)

const PIXEL := 0.006           # sticker pixels -> metres (a 256 px sticker stands ~1.5 m)
const SPEED := 3.6
const REACH := 1.5             # metres from a hotspot's edge to use it
const CHARS := {
	"bubu": {"idle": "bubu_shy", "walk": "bubu_run", "prefix": "p1_"},
	"dudu": {"idle": "dudu_idle", "walk": "dudu_stroll", "prefix": "p2_"},
}
## Which way a sticker faces (1 right, -1 left, 0 front), as in StickerRig.LOOKS.
const LOOKS := {"bubu_run": 1}

const GRASS := Color(0.62, 0.82, 0.55)
const PATH := Color(0.95, 0.88, 0.74)
const WOOD := Color(0.78, 0.6, 0.45)
const PINK := Color(1.0, 0.72, 0.78)
const LEAF := Color(0.45, 0.72, 0.5)

## Set false while a puzzle or dialogue is open: players stop and ignore input.
var active := true
var _data: Dictionary = {}
var _players: Dictionary = {}  # who -> {body, sprite, facing, pose, p2_moved}
var _spots: Array = []         # [{def, node, mark, pos}]
var _near: Dictionary = {}     # the spot the player stands at, or {}
var _cam: Camera3D
var _gate_node: Node3D


func setup(data: Dictionary) -> void:
	_data = data
	_build_world()
	var sp: Array = data.get("spawn", [0, 0])
	_spawn("bubu", Vector3(float(sp[0]), 0.6, float(sp[1])))
	_spawn("dudu", Vector3(float(sp[0]) - 1.2, 0.6, float(sp[1]) + 0.4))
	for h: Dictionary in data.get("hotspots", []):
		_add_hotspot(h)
	_update_camera(0.0)


## Opens the story gate (lifts it out of the way).
func open_gate() -> void:
	if _gate_node == null:
		return
	var tw := create_tween()
	tw.tween_property(_gate_node, "position:y", _gate_node.position.y + 2.6, 1.2).set_trans(Tween.TRANS_QUAD)
	Sfx.play("gate_open")
	for s: Dictionary in _spots:
		if s["def"].get("kind") == "gate":
			s["def"]["kind"] = "end"


## A cookie was picked up: hide its sparkle.
func consume(id: String) -> void:
	for s: Dictionary in _spots:
		if s["def"]["id"] == id:
			s["mark"].visible = false
			s["def"]["kind"] = "empty"


func player_position(who: String) -> Vector3:
	return _players[who]["body"].position


# --- World ---------------------------------------------------------------------------

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.55, 0.75, 1.0)
	sm.sky_horizon_color = Color(1.0, 0.9, 0.92)
	sm.ground_horizon_color = Color(1.0, 0.9, 0.92)
	sm.ground_bottom_color = GRASS
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1.0, 0.95, 0.97)
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 0.6
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.shadow_enabled = true
	add_child(sun)

	var size: Array = _data.get("size", [20, 8])
	var w := float(size[0])
	var d := float(size[1])
	_box(Vector3(0, -0.5, 0), Vector3(w, 1, d), GRASS)
	_box(Vector3(0, 0.01, 0), Vector3(w, 0.02, 1.6), PATH, false)
	# Invisible fences on the four sides.
	_solid(self, null, Vector3(w * 0.5, 1, 0), Vector3(0.2, 2, d))
	_solid(self, null, Vector3(-w * 0.5, 1, 0), Vector3(0.2, 2, d))
	_solid(self, null, Vector3(0, 1, d * 0.5), Vector3(w, 2, 0.2))
	_solid(self, null, Vector3(0, 1, -d * 0.5), Vector3(w, 2, 0.2))
	# Back scenery for depth.
	for i in int(w / 4.0) + 1:
		_tree(Vector3(-w * 0.5 + i * 4.0, 0, -d * 0.5 - 0.8 - (i % 2) * 1.2))
	_hill(Vector3(-w * 0.2, -2, -d - 6), 8.0, Color(0.68, 0.84, 0.66))
	_hill(Vector3(w * 0.3, -2.5, -d - 9), 10.0, Color(0.74, 0.88, 0.7))

	_cam = Camera3D.new()
	_cam.fov = 45.0
	add_child(_cam)


func _add_hotspot(h: Dictionary) -> void:
	var at: Array = h.get("at", [0, 0])
	var pos := Vector3(float(at[0]), 0, float(at[1]))
	var kind := String(h.get("kind"))
	var node := _prop(String(h.get("prop", "")), pos)
	if kind == "gate":
		_gate_node = node
	var mark := Label3D.new()
	mark.text = {"puzzle": "?", "cookie": "✦"}.get(kind, "!")
	mark.font_size = 96
	mark.pixel_size = 0.006
	mark.outline_size = 18
	mark.modulate = PINK if kind == "puzzle" else Color(1.0, 0.9, 0.4)
	mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mark.position = pos + Vector3(0, 2.3, 0)
	# Cookies are secret: their sparkle only shows up close.
	mark.visible = kind != "cookie"
	add_child(mark)
	if kind == "cookie" and GameState.found.has(String(h["id"])):
		h["kind"] = "empty"
	_spots.append({"def": h, "node": node, "mark": mark, "pos": pos})


func _prop(kind: String, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = at
	add_child(root)
	match kind:
		"bench":
			_box(Vector3(0, 0.45, 0), Vector3(1.8, 0.12, 0.6), WOOD, true, root)
			_box(Vector3(0, 0.85, -0.28), Vector3(1.8, 0.5, 0.08), WOOD, false, root)
			_box(Vector3(0, 0.2, 0), Vector3(1.6, 0.4, 0.4), WOOD.darkened(0.3), false, root)
		"fountain":
			var c := CylinderMesh.new()
			c.top_radius = 1.1
			c.bottom_radius = 1.2
			c.height = 0.6
			_solid(root, _mesh(c, Vector3.ZERO, Color(0.85, 0.85, 0.9)), Vector3(0, 0.3, 0), Vector3(2.2, 0.6, 2.2))
			var water := CylinderMesh.new()
			water.top_radius = 0.95
			water.bottom_radius = 0.95
			water.height = 0.05
			var wm := _mesh(water, Vector3.ZERO, Color(0.55, 0.8, 1.0))
			wm.position = Vector3(0, 0.6, 0)
			root.add_child(wm)
		"taxi":
			var spr := AnimatedSprite3D.new()
			spr.sprite_frames = Stickers.frames("both_taxi")
			spr.pixel_size = PIXEL * 1.1
			spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			spr.shaded = false
			var anim: StringName = spr.sprite_frames.get_animation_names()[0]
			spr.position.y = spr.sprite_frames.get_frame_texture(anim, 0).get_height() * PIXEL * 1.1 * 0.5
			spr.play(anim)
			root.add_child(spr)
			_solid(root, null, Vector3(0, 0.5, 0), Vector3(2.0, 1.0, 1.0))
		"tree":
			_tree(Vector3.ZERO, root)
			_solid(root, null, Vector3(0, 0.7, 0), Vector3(0.4, 1.4, 0.4))
		"bush":
			var s := SphereMesh.new()
			s.radius = 0.55
			s.height = 0.8
			var b := _mesh(s, Vector3.ZERO, LEAF)
			b.position = Vector3(0, 0.35, 0)
			root.add_child(b)
		"lamp":
			_box(Vector3(0, 1.1, 0), Vector3(0.1, 2.2, 0.1), Color(0.3, 0.3, 0.35), true, root)
			var bulb := SphereMesh.new()
			bulb.radius = 0.18
			bulb.height = 0.36
			var bm := _mesh(bulb, Vector3.ZERO, Color(1.0, 0.95, 0.7))
			bm.position = Vector3(0, 2.25, 0)
			root.add_child(bm)
		"gate":
			var depth := float((_data.get("size", [20, 8]) as Array)[1])
			_box(Vector3(0, 1.25, 0), Vector3(0.4, 2.5, depth), WOOD.darkened(0.15), true, root)
			_box(Vector3(0, 2.6, 0), Vector3(0.5, 0.2, depth), PINK, false, root)
	return root


func _box(at: Vector3, size: Vector3, color: Color, solid := true, parent: Node3D = null) -> void:
	var m := _mesh(BoxMesh.new(), size, color)
	var host: Node3D = self if parent == null else parent
	if not solid:
		m.position = at
		host.add_child(m)
		return
	_solid(host, m, at, size)


func _solid(host: Node3D, m: MeshInstance3D, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var s := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	s.shape = b
	body.add_child(s)
	if m != null:
		body.add_child(m)
	host.add_child(body)


func _mesh(mesh: PrimitiveMesh, size: Vector3, color: Color) -> MeshInstance3D:
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi


func _tree(at: Vector3, parent: Node3D = null) -> void:
	var host: Node3D = self if parent == null else parent
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.12
	trunk.bottom_radius = 0.16
	trunk.height = 1.4
	var t := _mesh(trunk, Vector3.ZERO, WOOD)
	t.position = at + Vector3(0, 0.7, 0)
	host.add_child(t)
	var crown := SphereMesh.new()
	crown.radius = 0.8
	crown.height = 1.4
	var c := _mesh(crown, Vector3.ZERO, LEAF)
	c.position = at + Vector3(0, 1.8, 0)
	host.add_child(c)


func _hill(at: Vector3, r: float, color: Color) -> void:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 1.2
	var h := _mesh(s, Vector3.ZERO, color)
	h.position = at
	add_child(h)


# --- Players -------------------------------------------------------------------------

func _spawn(who: String, at: Vector3) -> void:
	var body := CharacterBody3D.new()
	body.position = at
	var s := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.0
	s.shape = cap
	body.add_child(s)
	var spr := AnimatedSprite3D.new()
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.shaded = false
	body.add_child(spr)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.4
	disc.bottom_radius = 0.4
	disc.height = 0.01
	var sh := _mesh(disc, Vector3.ZERO, Color(0, 0, 0, 0.25))
	(sh.mesh.material as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sh.position = Vector3(0, -0.47, 0)
	body.add_child(sh)
	add_child(body)
	_players[who] = {"body": body, "sprite": spr, "facing": 1, "pose": "", "p2_moved": false}
	_pose(who, "idle")


func _pose(who: String, pose: String) -> void:
	var p: Dictionary = _players[who]
	if p["pose"] == pose:
		return
	p["pose"] = pose
	var spr: AnimatedSprite3D = p["sprite"]
	spr.sprite_frames = Stickers.frames(CHARS[who][pose])
	spr.play(spr.sprite_frames.get_animation_names()[0])
	# Feet on the ground: the sprite is centred, so lift it by half its height.
	var tex := spr.sprite_frames.get_frame_texture(spr.animation, 0)
	spr.pixel_size = PIXEL
	spr.position.y = tex.get_height() * PIXEL * 0.5 - 0.5


func _physics_process(delta: float) -> void:
	for who in _players:
		_move(who, delta)
	_update_near()
	_update_camera(delta)


func _move(who: String, delta: float) -> void:
	var p: Dictionary = _players[who]
	var body: CharacterBody3D = p["body"]
	var pre: String = CHARS[who]["prefix"]
	var dir := Vector2.ZERO
	if active:
		dir = Vector2(Input.get_axis(pre + "left", pre + "right"), Input.get_axis(pre + "up", pre + "down"))
	if who == "dudu":
		if dir.length() > 0.1:
			p["p2_moved"] = true
		elif active and not p["p2_moved"]:
			dir = _follow(body.position, player_position("bubu"))
	if dir.length() > 1.0:
		dir = dir.normalized()
	body.velocity.x = move_toward(body.velocity.x, dir.x * SPEED, SPEED * 10.0 * delta)
	body.velocity.z = move_toward(body.velocity.z, dir.y * SPEED, SPEED * 10.0 * delta)
	body.velocity.y = 0.0 if body.is_on_floor() else body.velocity.y - 18.0 * delta
	body.move_and_slide()
	if absf(dir.x) > 0.1:
		p["facing"] = 1 if dir.x > 0.0 else -1
	var pose := "walk" if Vector2(body.velocity.x, body.velocity.z).length() > 0.4 else "idle"
	_pose(who, pose)
	var looks: int = LOOKS.get(CHARS[who][pose], 0)
	(p["sprite"] as AnimatedSprite3D).flip_h = looks != 0 and looks != p["facing"]


## Dudu trails Bubu a little behind, without crowding.
func _follow(from: Vector3, to: Vector3) -> Vector2:
	var gap := Vector2(to.x - from.x, to.z - from.z)
	return Vector2.ZERO if gap.length() < 1.6 else gap.normalized() * clampf((gap.length() - 1.6) * 1.2, 0.0, 1.0)


func _update_near() -> void:
	var best: Dictionary = {}
	var best_d := REACH
	for s: Dictionary in _spots:
		var kind := String(s["def"].get("kind"))
		if kind == "empty":
			continue
		var pos: Vector3 = s["pos"]
		for who in _players:
			var me := player_position(who)
			# Props are wide: measure to their edge, roughly.
			var d := Vector2(pos.x, pos.z).distance_to(Vector2(me.x, me.z)) - 0.8
			if kind == "cookie":
				s["mark"].visible = d < REACH + 1.5
			if d < best_d:
				best_d = d
				best = s
	for s: Dictionary in _spots:
		var m: Label3D = s["mark"]
		m.scale = Vector3.ONE * (1.3 if s == best else 1.0)
		if String(s["def"].get("kind")) == "puzzle" and GameState.is_solved(String(s["def"]["puzzle"])):
			m.modulate = Color(0.6, 0.6, 0.65)
	_near = best


func _unhandled_input(event: InputEvent) -> void:
	if not active or _near.is_empty():
		return
	if event.is_action_pressed(&"p1_interact") or event.is_action_pressed(&"p2_interact"):
		get_viewport().set_input_as_handled()
		interact.emit(_near["def"])


func _update_camera(delta: float) -> void:
	var a := player_position("bubu")
	var b := player_position("dudu")
	var mid := (a + b) * 0.5
	var spread := clampf(absf(a.x - b.x) * 0.5, 0.0, 5.0)
	var target := mid + Vector3(0, 3.4 + spread * 0.3, 7.5 + spread)
	_cam.position = target if delta <= 0.0 else _cam.position.lerp(target, clampf(delta * 3.0, 0.0, 1.0))
	_cam.look_at(mid + Vector3(0, 0.6, 0))
