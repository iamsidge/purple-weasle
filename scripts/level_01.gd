extends Node2D

# ─── Level 01: The Museum Lobby ───────────────────────────────────────────────
# Builds the level at runtime from the MAP string array.
# Each character encodes a tile type:
#   #  wall (StaticBody2D)
#   .  floor (visual only)
#   P  player spawn
#   G  guard spawn (patrols col 6 ↔ col 35)
#   S  shadow zone (96×96, centred on tile)
#   E  exit zone
#
# TILE = 32 px. Level is 40 × 18 tiles (1280 × 576 px).
# ─────────────────────────────────────────────────────────────────────────────

const TILE := 32

const MAP := [
	"########################################",
	"#......................................#",
	"#.SS...................................#",
	"#......................................#",
	"#....###...............................#",
	"#....#.#...............................#",
	"#....###...............................#",
	"#......................................#",
	"#P..................G..................E",
	"#......................................#",
	"#....###...............................#",
	"#....#.#...............................#",
	"#....###...............................#",
	"#......................................#",
	"#.SS...................................#",
	"#......................................#",
	"#......................................#",
	"########################################",
]

# Guard patrols between these columns (same row as 'G' character)
const PATROL_COL_A := 6
const PATROL_COL_B := 35

const GuardScene      := preload("res://scenes/guard.tscn")
const ShadowZoneScene := preload("res://scenes/shadow_zone.tscn")
const ExitZoneScene   := preload("res://scenes/exit_zone.tscn")

@onready var player : CharacterBody2D = $Player

func _ready() -> void:
	_build_level()
	_connect_signals()

# ─── Level builder ────────────────────────────────────────────────────────────
func _build_level() -> void:
	for row in MAP.size():
		var line : String = MAP[row]
		for col in line.length():
			var ch  : String  = line[col]
			var pos : Vector2 = _tile_center(col, row)
			match ch:
				"#": _place_wall(pos)
				".": _place_floor(pos)
				"P": if player: player.global_position = pos
				"G": _place_guard(pos, row)
				"S": _place_shadow(pos)
				"E": _place_exit(pos)

func _tile_center(col: int, row: int) -> Vector2:
	return Vector2(col * TILE + TILE * 0.5, row * TILE + TILE * 0.5)

# ─── Tile spawners ────────────────────────────────────────────────────────────
func _place_wall(pos: Vector2) -> void:
	var body  := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect  := RectangleShape2D.new()
	rect.size  = Vector2(TILE, TILE)
	shape.shape = rect
	body.collision_layer = 1
	body.collision_mask  = 0

	var visual       := ColorRect.new()
	visual.size       = Vector2(TILE, TILE)
	visual.position   = Vector2(-TILE * 0.5, -TILE * 0.5)
	visual.color      = Color(0.15, 0.10, 0.22)

	body.position = pos
	body.add_child(shape)
	body.add_child(visual)
	body.z_index = 1
	add_child(body)

func _place_floor(pos: Vector2) -> void:
	var visual       := ColorRect.new()
	visual.size       = Vector2(TILE, TILE)
	visual.position   = pos - Vector2(TILE * 0.5, TILE * 0.5)
	visual.color      = Color(0.07, 0.05, 0.10)
	visual.z_index    = -2
	add_child(visual)

func _place_guard(pos: Vector2, row: int) -> void:
	# Create patrol waypoints as direct Node2D references — no NodePath needed
	var pa := Node2D.new()
	var pb := Node2D.new()
	pa.name     = "PatrolA"
	pb.name     = "PatrolB"
	pa.position = _tile_center(PATROL_COL_A, row)
	pb.position = _tile_center(PATROL_COL_B, row)
	add_child(pa)
	add_child(pb)

	var guard : CharacterBody2D = GuardScene.instantiate()
	guard.position        = pos
	guard.collision_layer = 4
	guard.collision_mask  = 1
	add_child(guard)

	# Assign after add_child so the guard is in the scene tree
	var points : Array[Node2D] = [pa, pb]
	guard.patrol_points = points

func _place_shadow(pos: Vector2) -> void:
	var zone := ShadowZoneScene.instantiate()
	zone.position = pos
	add_child(zone)

func _place_exit(pos: Vector2) -> void:
	var exit := ExitZoneScene.instantiate()
	exit.position = pos
	add_child(exit)

# ─── Signals ─────────────────────────────────────────────────────────────────
func _connect_signals() -> void:
	if player and player.has_signal("caught"):
		pass  # GameManager.on_player_caught() is called inside player.gd
