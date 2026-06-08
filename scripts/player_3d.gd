extends CharacterBody3D

# ─── Third-Person Player ──────────────────────────────────────────────────────

const SPEED         := 5.0
const SPRINT_SPEED  := 9.0
const GRAVITY       := 12.0
const MOUSE_SENS_X  := 0.003
const MOUSE_SENS_Y  := 0.002
const TURN_SPEED    := 12.0
const CAM_PITCH_MIN := -0.6
const CAM_PITCH_MAX :=  0.3

# ─── Stamina ──────────────────────────────────────────────────────────────────
const STAMINA_MAX     := 100.0
const STAMINA_DRAIN   := 28.0   # per second while sprinting
const STAMINA_REGEN   := 18.0   # per second while not sprinting
const STAMINA_MIN_RUN := 12.0   # need at least this to start sprinting again

var stamina    := STAMINA_MAX
var exhausted  := false         # true until stamina recovers past MIN_RUN

# ─── Footsteps ────────────────────────────────────────────────────────────────
const STEP_INTERVAL_WALK   := 0.5
const STEP_INTERVAL_SPRINT := 0.32
var step_t := 0.0

var is_dead   := false
var cam_yaw   := 0.0
var cam_pitch := -0.25

signal died
signal stamina_changed(value: float, max_value: float)

@onready var pivot  : Node3D      = $CameraPivot
@onready var spring : SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera : Camera3D    = $CameraPivot/SpringArm3D/Camera3D
@onready var mesh   : Node3D      = $CharacterMesh

# ─── Setup ────────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if AudioManager:
		AudioManager.start_ambient()

# ─── Input ────────────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		cam_yaw   -= event.relative.x * MOUSE_SENS_X
		cam_pitch  = clampf(cam_pitch - event.relative.y * MOUSE_SENS_Y,
		                    CAM_PITCH_MIN, CAM_PITCH_MAX)
		pivot.rotation.y  = cam_yaw
		spring.rotation.x = cam_pitch

	if event.is_action_pressed("ui_cancel"):
		var mode := Input.MOUSE_MODE_VISIBLE \
		            if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED \
		            else Input.MOUSE_MODE_CAPTURED
		Input.set_mouse_mode(mode)

# ─── Physics ──────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	# Movement direction relative to camera yaw
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var yaw_basis := Basis(Vector3.UP, cam_yaw)
	var dir       := yaw_basis * Vector3(input_dir.x, 0.0, input_dir.y)
	if dir.length() > 0.01:
		dir = dir.normalized()

	var moving      := input_dir != Vector2.ZERO
	var wants_sprint := Input.is_action_pressed("dash") and moving
	var sprinting   := wants_sprint and not exhausted and stamina > 0.0

	_update_stamina(delta, sprinting)

	var speed  := SPRINT_SPEED if sprinting else SPEED
	velocity.x  = dir.x * speed
	velocity.z  = dir.z * speed
	move_and_slide()

	# Rotate mesh toward movement direction
	if moving and mesh:
		var target_angle := atan2(dir.x, dir.z)
		mesh.rotation.y   = lerp_angle(mesh.rotation.y, target_angle, TURN_SPEED * delta)

	_update_footsteps(delta, moving, sprinting)

# ─── Stamina ──────────────────────────────────────────────────────────────────
func _update_stamina(delta: float, sprinting: bool) -> void:
	if sprinting:
		stamina = maxf(stamina - STAMINA_DRAIN * delta, 0.0)
		if stamina <= 0.0:
			exhausted = true
	else:
		stamina = minf(stamina + STAMINA_REGEN * delta, STAMINA_MAX)
		if exhausted and stamina >= STAMINA_MIN_RUN:
			exhausted = false
	emit_signal("stamina_changed", stamina, STAMINA_MAX)

# ─── Footsteps ────────────────────────────────────────────────────────────────
func _update_footsteps(delta: float, moving: bool, sprinting: bool) -> void:
	if not (moving and is_on_floor()):
		step_t = 0.0
		return
	step_t -= delta
	if step_t <= 0.0:
		step_t = STEP_INTERVAL_SPRINT if sprinting else STEP_INTERVAL_WALK
		if AudioManager:
			AudioManager.play_footstep()

# ─── Death ────────────────────────────────────────────────────────────────────
func get_caught() -> void:
	if is_dead:
		return
	is_dead = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if AudioManager:
		AudioManager.play_caught()
		AudioManager.stop_ambient()
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 0.8, 0.4).set_ease(Tween.EASE_IN)
	await tween.finished
	emit_signal("died")
	GameManager.on_player_caught()
