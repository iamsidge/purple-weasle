extends CharacterBody3D

# ─── Third-Person Player ──────────────────────────────────────────────────────

const SPEED         := 5.0
const SPRINT_SPEED  := 9.0
const GRAVITY       := 12.0
const MOUSE_SENS_X  := 0.003
const MOUSE_SENS_Y  := 0.002
const TURN_SPEED    := 12.0   # how fast the mesh snaps to face movement dir
const CAM_PITCH_MIN := -0.6   # radians (~-35°)
const CAM_PITCH_MAX :=  0.3   # radians (~+17°)

var is_dead      := false
var cam_yaw      := 0.0
var cam_pitch    := -0.25     # start looking slightly down

signal died

@onready var pivot  : Node3D     = $CameraPivot
@onready var spring : SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera : Camera3D   = $CameraPivot/SpringArm3D/Camera3D
@onready var mesh   : Node3D     = $CharacterMesh

# ─── Setup ────────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# ─── Input ────────────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		cam_yaw   -= event.relative.x * MOUSE_SENS_X
		cam_pitch  = clampf(cam_pitch - event.relative.y * MOUSE_SENS_Y,
		                    CAM_PITCH_MIN, CAM_PITCH_MAX)
		pivot.rotation.y = cam_yaw
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

	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	# Move direction — relative to camera yaw
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var yaw_basis := Basis(Vector3.UP, cam_yaw)
	var dir       := yaw_basis * Vector3(input_dir.x, 0.0, input_dir.y)
	if dir.length() > 0.01:
		dir = dir.normalized()

	var speed  := SPRINT_SPEED if Input.is_action_pressed("dash") else SPEED
	velocity.x  = dir.x * speed
	velocity.z  = dir.z * speed

	move_and_slide()

	# Smoothly rotate the character mesh to face movement direction
	if dir.length() > 0.01 and mesh:
		var target_angle := atan2(dir.x, dir.z)
		var current      := mesh.rotation.y
		mesh.rotation.y   = lerp_angle(current, target_angle, TURN_SPEED * delta)

# ─── Death ────────────────────────────────────────────────────────────────────
func get_caught() -> void:
	if is_dead:
		return
	is_dead = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Slump to the ground
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 0.8, 0.4).set_ease(Tween.EASE_IN)
	await tween.finished
	emit_signal("died")
	GameManager.on_player_caught()
