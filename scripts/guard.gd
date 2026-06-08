extends CharacterBody2D

# ─── Alert States ─────────────────────────────────────────────────────────────
enum AlertState { UNAWARE, SUSPICIOUS, ALERT }

# ─── Constants ────────────────────────────────────────────────────────────────
const SPEED_PATROL    := 60.0
const SPEED_ALERT     := 100.0
const SUSPICION_RATE  := 40.0   # suspicion gained per second when player in cone
const SUSPICION_DECAY := 15.0   # suspicion lost per second when player not in cone
const SUSPICION_MAX   := 100.0
const ALERT_THRESHOLD := 70.0   # suspicion level that triggers ALERT state

# ─── Exported patrol config ───────────────────────────────────────────────────
@export var patrol_points : Array[NodePath] = []
@export var wait_time     : float           = 1.5
@export var facing_angle  : float           = 0.0

# ─── State ────────────────────────────────────────────────────────────────────
var alert_state      := AlertState.UNAWARE
var suspicion        := 0.0
var current_patrol   := 0
var wait_timer       := 0.0
var is_waiting       := false
var last_known_pos   := Vector2.ZERO
var player_ref       : Node2D = null

signal alert_state_changed(new_state: int)
signal player_spotted(player: Node2D)

# ─── References ───────────────────────────────────────────────────────────────
@onready var detection     : Node2D      = $DetectionCone
@onready var suspicion_bar : ProgressBar = $SuspicionBar
@onready var exclamation   : Label       = $ExclamationLabel

# ─── Lifecycle ────────────────────────────────────────────────────────────────
func _ready() -> void:
	rotation_degrees = facing_angle
	if suspicion_bar:
		suspicion_bar.max_value = SUSPICION_MAX
		suspicion_bar.value     = 0
	if exclamation:
		exclamation.visible = false

func _physics_process(delta: float) -> void:
	_update_suspicion(delta)
	_update_behaviour(delta)
	_update_ui()

# ─── Suspicion ────────────────────────────────────────────────────────────────
func _update_suspicion(delta: float) -> void:
	var player_visible := detection.can_see_player() if detection else false

	if player_visible:
		var multiplier := _get_visibility_multiplier()
		suspicion = minf(suspicion + SUSPICION_RATE * multiplier * delta, SUSPICION_MAX)
		if detection:
			last_known_pos = detection.player_position()
	else:
		suspicion = maxf(suspicion - SUSPICION_DECAY * delta, 0.0)

	var prev_state := alert_state
	if suspicion >= SUSPICION_MAX:
		alert_state = AlertState.ALERT
	elif suspicion >= ALERT_THRESHOLD:
		alert_state = AlertState.SUSPICIOUS
	else:
		alert_state = AlertState.UNAWARE

	if alert_state != prev_state:
		emit_signal("alert_state_changed", alert_state)
		if alert_state == AlertState.ALERT:
			emit_signal("player_spotted", player_ref)
			GameManager.on_alert_triggered()

func _get_visibility_multiplier() -> float:
	if player_ref == null:
		return 1.0
	var in_shadow  : bool = player_ref.get("is_in_shadow") or false
	var crouching  : bool = player_ref.get("is_crouching") or false
	if in_shadow and crouching:
		return 0.1
	if in_shadow:
		return 0.4
	if crouching:
		return 0.6
	return 1.0

# ─── Behaviour ────────────────────────────────────────────────────────────────
func _update_behaviour(delta: float) -> void:
	match alert_state:
		AlertState.UNAWARE, AlertState.SUSPICIOUS:
			_patrol(delta)
		AlertState.ALERT:
			_chase()

func _patrol(delta: float) -> void:
	if patrol_points.is_empty():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_waiting:
		wait_timer -= delta
		velocity = Vector2.ZERO
		if wait_timer <= 0.0:
			is_waiting = false
			current_patrol = (current_patrol + 1) % patrol_points.size()
		move_and_slide()
		return

	var target : Node2D = get_node(patrol_points[current_patrol])
	var direction := (target.global_position - global_position).normalized()
	velocity = direction * SPEED_PATROL
	_face_direction(direction)
	move_and_slide()

	if global_position.distance_to(target.global_position) < 8.0:
		is_waiting = true
		wait_timer = wait_time

func _chase() -> void:
	var target_pos := last_known_pos
	if player_ref:
		target_pos = player_ref.global_position

	var direction := (target_pos - global_position).normalized()
	velocity = direction * SPEED_ALERT
	_face_direction(direction)
	move_and_slide()

	if player_ref and global_position.distance_to(player_ref.global_position) < 16.0:
		player_ref.get_caught()

func _face_direction(dir: Vector2) -> void:
	if dir != Vector2.ZERO:
		rotation = dir.angle()

# ─── UI ───────────────────────────────────────────────────────────────────────
func _update_ui() -> void:
	if suspicion_bar:
		suspicion_bar.value   = suspicion
		suspicion_bar.visible = suspicion > 0

	if exclamation:
		match alert_state:
			AlertState.SUSPICIOUS:
				exclamation.text    = "?"
				exclamation.visible = true
			AlertState.ALERT:
				exclamation.text    = "!"
				exclamation.visible = true
			_:
				exclamation.visible = false

# ─── Called by DetectionCone to register the player node ─────────────────────
func register_player(player: Node2D) -> void:
	player_ref = player
