extends Node3D

# ─── Level 01 (3D) — The Corrupted Wood ──────────────────────────────────────
# Builds a Wolfenstein-style maze at runtime from a string MAP.
#
# MAP key:
#   #  wall
#   .  open floor
#   P  player spawn
#   D  deer creature
#   R  rabbit creature
#   L  torch light
#   E  exit
#
# Cell size: 3.0 × 3.0 m, wall height: 3.2 m
# ─────────────────────────────────────────────────────────────────────────────

const CELL  := 3.0
const WALL_H := 3.2

const MAP := [
	"######################",
	"#P..#.....#..........#",
	"#...#..D..#...#####..#",
	"#...#.....#...#...#..#",
	"#...######....#.D.#..#",
	"#.............#...#..#",
	"##.###..D.....######.#",
	"#..#.#................#",
	"#..#.#....#####..D...#",
	"#..#.#....#....#.....#",
	"#....#....#.R..######",
	"###..#####.....#.....#",
	"#.D..........#.#..R..#",
	"#....#####...#.......#",
	"#....#...#...#########",
	"#....#.R.#...........#",
	"#....#...#...D.......E",
	"######################",
]

const CreatureScene := preload("res://scenes/creature.tscn")
const PlayerScene   := preload("res://scenes/fps_player.tscn")
const ExitScene     := preload("res://scenes/exit_zone_3d.tscn")

# ─── Materials (created once, reused) ────────────────────────────────────────
var mat_wall   : StandardMaterial3D
var mat_floor  : StandardMaterial3D
var mat_ceil   : StandardMaterial3D

# ─── Lifecycle ────────────────────────────────────────────────────────────────
func _ready() -> void:
	_create_materials()
	_build_level()
	_add_ambient_lights()

# ─── Material setup ───────────────────────────────────────────────────────────
func _create_materials() -> void:
	var wall_tex  := load("res://assets/sprites/wall_stone.png")  as Texture2D
	var floor_tex := load("res://assets/sprites/floor_dark.png")  as Texture2D

	mat_wall                      = StandardMaterial3D.new()
	mat_wall.albedo_texture        = wall_tex
	mat_wall.albedo_color          = Color(0.55, 0.45, 0.38)
	mat_wall.roughness             = 0.92
	mat_wall.metallic              = 0.0
	mat_wall.uv1_scale             = Vector3(1.0, 1.0, 1.0)

	mat_floor                      = StandardMaterial3D.new()
	mat_floor.albedo_texture        = floor_tex
	mat_floor.albedo_color          = Color(0.30, 0.38, 0.22)
	mat_floor.roughness             = 0.98
	mat_floor.uv1_scale             = Vector3(2.0, 2.0, 2.0)

	mat_ceil                       = StandardMaterial3D.new()
	mat_ceil.albedo_color           = Color(0.05, 0.04, 0.06)
	mat_ceil.roughness              = 1.0

# ─── Level builder ────────────────────────────────────────────────────────────
func _build_level() -> void:
	var rows := MAP.size()
	var cols := MAP[0].length()

	# Floor and ceiling slabs (one big quad each)
	_make_slab(Vector3(cols * CELL * 0.5, 0.0,       rows * CELL * 0.5),
	           Vector3(cols * CELL, 0.02, rows * CELL), mat_floor)
	_make_slab(Vector3(cols * CELL * 0.5, WALL_H,    rows * CELL * 0.5),
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
				"E": _spawn_exit(pos)

# ─── Wall ─────────────────────────────────────────────────────────────────────
func _place_wall(pos: Vector3) -> void:
	var body  := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask  = 0

	var col   := CollisionShape3D.new()
	var box   := BoxShape3D.new()
	box.size   = Vector3(CELL, WALL_H, CELL)
	col.shape  = box
	col.position = Vector3(0, WALL_H * 0.5, 0)
	body.add_child(col)

	var mesh_i  := MeshInstance3D.new()
	var box_m   := BoxMesh.new()
	box_m.size   = Vector3(CELL, WALL_H, CELL)
	box_m.material = mat_wall
	mesh_i.mesh  = box_m
	mesh_i.position = Vector3(0, WALL_H * 0.5, 0)
	body.add_child(mesh_i)

	body.position = pos
	add_child(body)

# ─── Floor/ceiling slab ───────────────────────────────────────────────────────
func _make_slab(pos: Vector3, size: Vector3, mat: StandardMaterial3D) -> void:
	var body  := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask  = 0

	var col  := CollisionShape3D.new()
	var box  := BoxShape3D.new()
	box.size  = size
	col.shape = box
	body.add_child(col)

	var mesh_i := MeshInstance3D.new()
	var box_m  := BoxMesh.new()
	box_m.size  = size
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
	# Hook death signal to HUD
	player.connect("died", _on_player_died)

func _on_player_died() -> void:
	pass  # GameManager handles scene transition

# ─── Creature ─────────────────────────────────────────────────────────────────
func _spawn_creature(pos: Vector3, type: String) -> void:
	var c := CreatureScene.instantiate()
	c.position      = Vector3(pos.x, 0.0, pos.z)
	c.creature_type = type

	# Swap texture for rabbit variant
	if type == "rabbit":
		var rabbit_tex := load("res://assets/sprites/creature_rabbit.png") as Texture2D
		add_child(c)  # must be in tree before accessing children
		var sp := c.get_node_or_null("Sprite3D") as Sprite3D
		if sp:
			sp.texture = rabbit_tex
		# Rabbits are faster and shorter
		c.set("SPEED_CHASE", 8.0)
		var col_node := c.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col_node and col_node.shape is CapsuleShape3D:
			(col_node.shape as CapsuleShape3D).height = 1.2
			col_node.position.y = 0.6
		var spr := c.get_node_or_null("Sprite3D") as Sprite3D
		if spr:
			spr.position.y = 0.6
			spr.pixel_size  = 0.032
		return  # already added

	# Patrol pair — wander ±4 cells from spawn
	var pa := Node3D.new(); pa.position = Vector3(pos.x - CELL * 3.5, 0, pos.z)
	var pb := Node3D.new(); pb.position = Vector3(pos.x + CELL * 3.5, 0, pos.z)
	pa.name = "CreaturePatrolA"; pb.name = "CreaturePatrolB"
	add_child(pa); add_child(pb)
	add_child(c)
	var points : Array[Node3D] = [pa, pb]
	c.patrol_nodes = points

# ─── Torch ────────────────────────────────────────────────────────────────────
func _place_torch(pos: Vector3) -> void:
	var light           := OmniLight3D.new()
	light.position       = Vector3(pos.x, WALL_H * 0.7, pos.z)
	light.light_color    = Color(1.0, 0.55, 0.15)
	light.light_energy   = 2.2
	light.omni_range     = CELL * 3.5
	light.shadow_enabled = true
	# Flicker via script
	light.set_script(load("res://scripts/torch_flicker.gd"))
	add_child(light)

# ─── Exit ─────────────────────────────────────────────────────────────────────
func _spawn_exit(pos: Vector3) -> void:
	# Simple trigger area — load 3D exit scene if it exists, else inline
	var area  := Area3D.new()
	var col   := CollisionShape3D.new()
	var box   := BoxShape3D.new()
	box.size   = Vector3(CELL, WALL_H, CELL)
	col.shape  = box
	col.position = Vector3(0, WALL_H * 0.5, 0)
	area.add_child(col)
	area.position = pos
	area.collision_layer = 0
	area.collision_mask  = 2
	area.body_entered.connect(func(body: Node3D) -> void:
		if body.is_in_group("player"):
			GameManager.on_level_complete()
	)

	# Visual — bright green column of light
	var mesh_i       := MeshInstance3D.new()
	var cyl          := CylinderMesh.new()
	cyl.top_radius    = 0.4
	cyl.bottom_radius = 0.4
	cyl.height        = WALL_H
	var exit_mat      := StandardMaterial3D.new()
	exit_mat.albedo_color         = Color(0.0, 1.0, 0.4, 0.6)
	exit_mat.emission_enabled      = true
	exit_mat.emission              = Color(0.0, 1.0, 0.4)
	exit_mat.emission_energy_multiplier = 3.0
	exit_mat.transparency          = BaseMaterial3D.TRANSPARENCY_ALPHA
	cyl.material                   = exit_mat
	mesh_i.mesh  = cyl
	mesh_i.position = Vector3(0, WALL_H * 0.5, 0)
	area.add_child(mesh_i)

	add_child(area)

# ─── Ambient scatter lights ───────────────────────────────────────────────────
func _add_ambient_lights() -> void:
	# A few eerie low-energy point lights scattered in the maze
	var light_positions := [
		Vector3(3*CELL, WALL_H*0.5, 3*CELL),
		Vector3(10*CELL, WALL_H*0.5, 8*CELL),
		Vector3(5*CELL,  WALL_H*0.5, 14*CELL),
		Vector3(16*CELL, WALL_H*0.5, 5*CELL),
		Vector3(18*CELL, WALL_H*0.5, 12*CELL),
	]
	for lp in light_positions:
		var light           := OmniLight3D.new()
		light.position       = lp
		light.light_color    = Color(0.3, 0.7, 0.25)   # sickly green
		light.light_energy   = 0.6
		light.omni_range     = CELL * 4.0
		light.shadow_enabled = false
		add_child(light)
