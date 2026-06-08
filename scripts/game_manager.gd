extends Node

# ─── Game Manager (Autoload as "GameManager") ─────────────────────────────────
# Tracks level state and handles scene transitions.

signal level_complete
signal game_over

var current_level    : int = 1
var total_levels     : int = 3
var stealth_rating   : int = 3   # 1–3 stars
var alerts_triggered : int = 0

const SCENE_MENU     := "res://scenes/main_menu.tscn"
const SCENE_GAMEOVER := "res://scenes/game_over.tscn"
const LEVEL_SCENES   := [
	"res://scenes/level_01_3d.tscn",
	"res://scenes/level_02_3d.tscn",
	"res://scenes/level_03_3d.tscn",
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func start_game() -> void:
	current_level    = 1
	stealth_rating   = 3
	alerts_triggered = 0
	load_level(current_level)

func load_level(level_index: int) -> void:
	if level_index < 1 or level_index > total_levels:
		push_error("GameManager: invalid level index %d" % level_index)
		return
	get_tree().change_scene_to_file(LEVEL_SCENES[level_index - 1])

func on_level_complete() -> void:
	emit_signal("level_complete")
	await get_tree().create_timer(1.5).timeout
	if current_level < total_levels:
		current_level += 1
		load_level(current_level)
	else:
		get_tree().change_scene_to_file(SCENE_MENU)

func on_player_caught() -> void:
	emit_signal("game_over")
	await get_tree().create_timer(0.8).timeout
	get_tree().change_scene_to_file(SCENE_GAMEOVER)

func on_alert_triggered() -> void:
	alerts_triggered += 1
	stealth_rating = max(1, 3 - alerts_triggered)

func restart_level() -> void:
	alerts_triggered = 0
	stealth_rating   = 3
	load_level(current_level)

func go_to_menu() -> void:
	get_tree().change_scene_to_file(SCENE_MENU)
