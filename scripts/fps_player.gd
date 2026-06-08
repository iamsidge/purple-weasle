extends CharacterBody3D

# ─── FPS Player ───────────────────────────────────────────────────────────────

const SPEED        := 5.0
const SPRINT_SPEED := 9.0
const GRAVITY      := 12.0
const MOUSE_SENS   := 0.0022

# Bob settings
const BOB_FREQ  := 2.4
const BOB_AMP   := 0.06
var   bob_t     := 0.0

var is_dead := false

signal died

@onready var head      : Node3D     = $Head
@onready var camera    : Camera3D   = $Head/Camera3D
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight
@onready var footstep_timer : Timer = $FootstepTimer

# ─── Lifecycle ────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		head.rotate_y(-event.relative.x * MOUSE_SENS)
		camera.rotate_x(-event.relative.y * MOUSE_SENS)
		camera.rotation.x = clampf(camera.rotation.x, -PI * 0.44, PI * 0.44)

	if event.is_action_pressed("ui_cancel"):
		var mode := Input.MOUSE_MODE_VISIBLE if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED \
		            else Input.MOUSE_MODE_CAPTURED
		Input.set_mouse_mode(mode)

# ─── Physics ──────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var forward   := -head.global_transform.basis.z
	var right     :=  head.global_transform.basis.x
	var dir       := (forward * -input_dir.y + right * input_dir.x)
	dir.y = 0.0
	if dir.length() > 0.01:
		dir = dir.normalized()

	var speed := SPRINT_SPEED if Input.is_action_pressed("dash") else SPEED
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

	move_and_slide()
	_update_bob(delta, input_dir != Vector2.ZERO)

# ─── Camera head-bob ──────────────────────────────────────────────────────────
func _update_bob(delta: float, moving: bool) -> void:
	if moving and is_on_floor():
		bob_t += delta * BOB_FREQ
		camera.position.y = sin(bob_t) * BOB_AMP
		camera.position.x = cos(bob_t * 0.5) * BOB_AMP * 0.5
	else:
		bob_t = 0.0
		camera.position = camera.position.lerp(Vector3.ZERO, delta * 8.0)

# ─── Death ────────────────────────────────────────────────────────────────────
func get_caught() -> void:
	if is_dead:
		return
	is_dead = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Tip the camera like falling
	var tween := create_tween()
	tween.tween_property(camera, "rotation:z", 1.4, 0.5)
	tween.tween_property(camera, "position:y", -0.6, 0.4)
	await tween.finished
	emit_signal("died")
	GameManager.on_player_caught()
