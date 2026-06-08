extends Node3D

# ─── Level 01 (3D) — The Corrupted Wood ──────────────────────────────────────
# Builds an open-plan arena at runtime from a string MAP.
#
# MAP key:
#   #  wall          .  open floor    P  player spawn
#   D  deer creature R  rabbit        L  torch light
#   *  relic         E  exit
#
# Collect every relic to unlock the exit. Cell 3.0 m, wall height 3.2 m.
# ─────────────────────────────────────────────────────────────────────────────

const CELL   := 3.0
const WALL_H := 3.2

const MAP := [
	"######################",
	"#P........L.........*#",
	"#....................#",
	"#...##....D.....##...#",
	"#...##..........##...#",
	"#...................L#",
	"#....................#",
	"#..####.......####...#",
	"#..#....R....R....#..#",
	"#..#..............#..#",
	"#..####...*...####...#",
	"#....................#",
	"#L..................L#",
	"#...##..........##...#",
	"#...##....D.....##...#",
	"#....................#",
	"#*........R.........E#",
	"######################",
]

const CreatureScene := preload("res://scenes/creature.tscn")
const PlayerScene   := preload("res://scenes/player_3d.tscn")
const RelicScene    := preload("res://scenes/relic.tscn")

# ─── Materials ────────────────────────────────────────────────────────────────
var mat_wall  : StandardMaterial3D
var mat_floor : StandardMaterial3D
var mat_ceil  : StandardMaterial3D

# ─── Exit (gated by relics) ───────────────────────────────────────────────────
var _exit_mat   : StandardMaterial3D
var _exit_light : OmniLight3D
var _exit_open  := false

# ─── HUD refs ─────────────────────────────────────────────────────────────────
@onready var objective_label : Label       = get_node_or_null("HUD/ObjectiveLabel")
@onready var flash_label     : Label       = get_node_or_null("HUD/FlashLabel")
@onready var stamina_bar     : ProgressBar = get_node_or_null("HUD/StaminaBar")

# ─── Lifecycle ────────────────────────────────────────────────────────────────
func _ready() -> void:
	_create_materials()
	_build_level()
	_add_ambient_lights()
	GameManager.relics_changed.connect(_on_relics_changed)
	if flash_label:
		flash_label.modulate.a = 0.0
	_on_relics_changed(GameManager.relics_collected, GameManager.relics_total)

func _process(_delta: float) -> void:
	# Keep the exit visuals in sync with relic progress
	var open := GameManager.all_relics_collected()
	if open != _exit_open:
		_exit_open = open
		_update_exit_visual()

# ─── Materials ────────────────────────────────────────────────────────────────
func _create_materials() -> void:
	var wall_tex  := load("res://assets/sprites/wall_stone.png") as Texture2D
	var floor_tex := load("res://assets/sprites/floor_dark.png") as Texture2D

	mat_wall                = StandardMaterial3D.new()
	mat_wall.albedo_texture  = wall_tex
	mat_wall.albedo_color    = Color(0.55, 0.45, 0.38)
	mat_wall.roughness       = 0.92

	mat_floor               = StandardMaterial3D.new()
	mat_floor.albedo_texture = floor_tex
	mat_floor.albedo_color   = Color(0.30, 0.38, 0.22)
	mat_floor.roughness      = 0.98
	mat_floor.uv1_scale      = Vector3(2.0, 2.0, 2.0)

	mat_ceil               = StandardMaterial3D.new()
	mat_ceil.albedo_color   = Color(0.05, 0.04, 0.06)
	mat_ceil.roughness      = 1.0

# ─── Level builder ────────────────────────────────────────────────────────────
func _build_level() -> void:
	var rows := MAP.size()
	var cols := MAP[0].length()
	var relic_total := 0

	_make_slab(Vector3(cols * CELL * 0.5, 0.0,    rows * CELL * 0.5),
	           Vector3(cols * CELL, 0.02, rows * CELL), mat_floor)
	_make_slab(Vector3(cols * CELL * 0.5, WALL_H, rows * CELL * 0.5),
	           Vector3(cols * CELL, 0.02, rows * CELL), mat_ceil)

	for row in rows:
		for col in MAP[row].length():
			var ch  : String  = MAP[row][col]
			var pos : Vector3 = Vector3(col * CELL + CELL * 0.5, 0.0, row * CELL + CELL * 0.5)
			match ch:
				"#": _place_wall(pos)
				"P": _spawn_player(pos)
				"D": _spawn_creature(pos, "deer")
				"R": _spawn_creature(pos, "rabbit")
				"L": _place_torch(pos)
				"*": _spawn_relic(pos); relic_total += 1
				"E": _spawn_exit(pos)

	GameManager.set_relic_total(relic_total)

# ─── Wall ─────────────────────────────────────────────────────────────────────
func _place_wall(pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask  = 0

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(CELL, WALL_H, CELL)
	col.shape = box
	col.position = Vector3(0, WALL_H * 0.5, 0)
	body.add_child(col)

	var mesh_i := MeshInstance3D.new()
	var box_m  := BoxMesh.new()
	box_m.size = Vector3(CELL, WALL_H, CELL)
	box_m.material = mat_wall
	mesh_i.mesh = box_m
	mesh_i.position = Vector3(0, WALL_H * 0.5, 0)
	body.add_child(mesh_i)

	body.position = pos
	add_child(body)

# ─── Floor/ceiling slab ───────────────────────────────────────────────────────
func _make_slab(pos: Vector3, size: Vector3, mat: StandardMaterial3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask  = 0

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	body.add_child(col)

	var mesh_i := MeshInstance3D.new()
	var box_m  := BoxMesh.new()
	box_m.size = size
	box_m.material = mat
	mesh_i.mesh = box_m
	body.add_child(mesh_i)

	body.position = pos
	add_child(body)

# ─── Player ───────────────────────────────────────────────────────────────────
func _spawn_player(pos: Vector3) -> void:
	var player := PlayerScene.instantiate()
	player.position = Vector3(pos.x, 0.0, pos.z)
	add_child(player)
	player.connect("died", _on_player_died)
	if player.has_signal("stamina_changed"):
		player.connect("stamina_changed", _on_stamina_changed)

func _on_player_died() -> void:
	pass

# ─── Creature ─────────────────────────────────────────────────────────────────
func _spawn_creature(pos: Vector3, type: String) -> void:
	var c := CreatureScene.instantiate()
	c.position      = Vector3(pos.x, 0.0, pos.z)
	c.creature_type = type   # creature.gd handles its own per-type tuning

	if type == "rabbit":
		# Rabbits lurk in place and ambush when they spot you — no patrol route
		add_child(c)
		return

	# Deer patrol back and forth around their spawn
	var pa := Node3D.new(); pa.position = Vector3(pos.x - CELL * 3.0, 0, pos.z)
	var pb := Node3D.new(); pb.position = Vector3(pos.x + CELL * 3.0, 0, pos.z)
	pa.name = "CreaturePatrolA"; pb.name = "CreaturePatrolB"
	add_child(pa); add_child(pb)
	add_child(c)
	var points : Array[Node3D] = [pa, pb]
	c.patrol_nodes = points

# ─── Relic ────────────────────────────────────────────────────────────────────
func _spawn_relic(pos: Vector3) -> void:
	var r := RelicScene.instantiate()
	r.position = Vector3(pos.x, 0.0, pos.z)
	add_child(r)

# ─── Torch ────────────────────────────────────────────────────────────────────
func _place_torch(pos: Vector3) -> void:
	var light := OmniLight3D.new()
	light.position       = Vector3(pos.x, WALL_H * 0.7, pos.z)
	light.light_color    = Color(1.0, 0.55, 0.15)
	light.light_energy   = 2.2
	light.omni_range     = CELL * 3.5
	light.shadow_enabled = true
	light.set_script(load("res://scripts/torch_flicker.gd"))
	add_child(light)

# ─── Exit (relic-gated) ───────────────────────────────────────────────────────
func _spawn_exit(pos: Vector3) -> void:
	var area := Area3D.new()
	var col  := CollisionShape3D.new()
	var box  := BoxShape3D.new()
	box.size = Vector3(CELL, WALL_H, CELL)
	col.shape = box
	col.position = Vector3(0, WALL_H * 0.5, 0)
	area.add_child(col)
	area.position = pos
	area.collision_layer = 0
	area.collision_mask  = 2
	area.body_entered.connect(_on_exit_entered)

	var mesh_i := MeshInstance3D.new()
	var cyl    := CylinderMesh.new()
	cyl.top_radius    = 0.5
	cyl.bottom_radius = 0.5
	cyl.height        = WALL_H

	_exit_mat = StandardMaterial3D.new()
	_exit_mat.transparency   = BaseMaterial3D.TRANSPARENCY_ALPHA
	_exit_mat.emission_enabled = true
	cyl.material = _exit_mat
	mesh_i.mesh = cyl
	mesh_i.position = Vector3(0, WALL_H * 0.5, 0)
	area.add_child(mesh_i)

	_exit_light = OmniLight3D.new()
	_exit_light.position   = Vector3(0, WALL_H * 0.5, 0)
	_exit_light.omni_range = CELL * 4.0
	area.add_child(_exit_light)

	add_child(area)
	_update_exit_visual()

func _on_exit_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if GameManager.all_relics_collected():
		GameManager.on_level_complete()
	else:
		var left := GameManager.relics_total - GameManager.relics_collected
		flash("The way is sealed — %d relic%s remain" % [left, "s" if left != 1 else ""])

func _update_exit_visual() -> void:
	if _exit_mat == null:
		return
	if _exit_open:
		_exit_mat.albedo_color   = Color(0.0, 1.0, 0.4, 0.6)
		_exit_mat.emission       = Color(0.0, 1.0, 0.4)
		_exit_mat.emission_energy_multiplier = 3.0
		if _exit_light:
			_exit_light.light_color  = Color(0.0, 1.0, 0.4)
			_exit_light.light_energy = 2.5
	else:
		_exit_mat.albedo_color   = Color(1.0, 0.1, 0.1, 0.5)
		_exit_mat.emission       = Color(0.8, 0.0, 0.0)
		_exit_mat.emission_energy_multiplier = 1.5
		if _exit_light:
			_exit_light.light_color  = Color(1.0, 0.1, 0.1)
			_exit_light.light_energy = 1.2

# ─── HUD ──────────────────────────────────────────────────────────────────────
func _on_relics_changed(collected: int, total: int) -> void:
	if objective_label:
		if total == 0:
			objective_label.text = ""
		elif collected >= total:
			objective_label.text = "All relics gathered — reach the exit!"
		else:
			objective_label.text = "Relics: %d / %d" % [collected, total]

func _on_stamina_changed(value: float, max_value: float) -> void:
	if stamina_bar:
		stamina_bar.max_value = max_value
		stamina_bar.value     = value

func flash(text: String) -> void:
	if not flash_label:
		return
	flash_label.text = text
	flash_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(flash_label, "modulate:a", 0.0, 0.8)

# ─── Ambient scatter lights ───────────────────────────────────────────────────
func _add_ambient_lights() -> void:
	var light_positions := [
		Vector3(5*CELL,  WALL_H*0.5, 5*CELL),
		Vector3(15*CELL, WALL_H*0.5, 8*CELL),
		Vector3(8*CELL,  WALL_H*0.5, 14*CELL),
		Vector3(17*CELL, WALL_H*0.5, 3*CELL),
	]
	for lp in light_positions:
		var light := OmniLight3D.new()
		light.position       = lp
		light.light_color    = Color(0.3, 0.7, 0.25)
		light.light_energy   = 0.5
		light.omni_range     = CELL * 4.0
		light.shadow_enabled = false
		add_child(light)
