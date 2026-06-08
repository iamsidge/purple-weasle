extends Control

# ─── Horror Main Menu ─────────────────────────────────────────────────────────
# Dark, fog-bound title screen. The title flickers like a failing bulb and a
# dim creature lurks in the background, breathing in and out of the shadows.

@onready var title    : Label       = $Title
@onready var deer      : TextureRect = $LurkingDeer
@onready var play_btn  : Button      = $Menu/PlayButton
@onready var quit_btn  : Button      = $Menu/QuitButton

var _t          := 0.0
var _next_flick := 0.0   # time of next sharp flicker dip

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	play_btn.pressed.connect(_on_play_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	if AudioManager:
		AudioManager.reset()          # clear any leftover hunt heartbeat
		AudioManager.start_ambient()  # dread underscore on the menu too

func _process(delta: float) -> void:
	_t += delta

	# Title flicker — steady hum with the occasional dying-bulb stutter
	if title:
		var f := 0.84 + 0.10 * sin(_t * 8.5) + 0.05 * sin(_t * 21.0)
		if _t >= _next_flick:
			_next_flick = _t + randf_range(1.5, 4.5)
			f = 0.35                  # sudden dip
		title.modulate.a = clampf(f, 0.3, 1.0)

	# Lurking creature — slow breathing scale + fading presence
	if deer:
		var s := 1.0 + 0.025 * sin(_t * 0.8)
		deer.scale = Vector2(s, s)
		deer.modulate.a = 0.10 + 0.05 * sin(_t * 1.3)

func _on_play_pressed() -> void:
	GameManager.start_game()

func _on_quit_pressed() -> void:
	get_tree().quit()
