extends CharacterBody2D

enum AlertState { UNAWARE, SUSPICIOUS, ALERT }

# ─── Constants ────────────────────────────────────────────────────────────────
const SPEED_PATROL    := 55.0
const SPEED_ALERT     := 100.0
const SUSPICION_RATE  := 40.0
const SUSPICION_DECAY := 15.0
const SUSPICION_MAX   := 100.0
const ALERT_THRESHOLD := 70.0

# ─── Exports ─────────────────────────────────────────────────────────────────
@export var patrol_points : Array[NodePath] = []
@export var wait_time     : float           = 1.5
@export var facing_angle  : float           = 0.0

# ─── State ────────────────────────────────────────────────────────────────────
var alert_state    := AlertState.UNAWARE
var suspicion      := 0.0
var current_patrol := 0
var wait_timer     := 0.0
var is_waiting     := false
var last_known_pos := Vector2.ZERO
var player_ref     : Node2D = null

signal alert_state_changed(new_state: int)

# ─── References (nullable) ────────────────────────────────────────────────────
@onready var sprite        : Sprite2D    = $Sprite2D
@onready var detection     : Node2D      = $DetectionCone
@onready var suspicion_bar : ProgressBar = $SuspicionBar
@onready var exclamation   : Label       = $ExclamationLabel

# ─── Lifecycle ────────────────────────────────────────────────────────────────
func _ready() -> void:
	rotation_degrees = facing_angle
	if suspicion_bar:
		suspicion_bar.max_value      = SUSPICION_MAX
		suspicion_bar.value          = 0
		suspicion_bar.show_percentage = false
	if exclamation:
		exclamation.visible = false

func _physics_process(delta: float) -> void:
	_update_suspicion(delta)
	_update_behaviour(delta)
	_update_ui()
	_tint_sprite()

# ─── Suspicion logic ─────────────────────────────────────────────────────────
func _update_suspicion(delta: float) -> void:
	var can_see : bool = detection.can_see_player() if detection else false

	if can_see:
		suspicion = minf(suspicion + SUSPICION_RATE * _visibility_mult() * delta, SUSPICION_MAX)
		if detection:
			last_known_pos = detection.player_position()
	else:
		suspicion = maxf(suspicion - SUSPICION_DECAY * delta, 0.0)

	var prev := alert_state
	if   suspicion >= SUSPICION_MAX:   alert_state = AlertState.ALERT
	elif suspicion >= ALERT_THRESHOLD: alert_state = AlertState.SUSPICIOUS
	else:                              alert_state = AlertState.UNAWARE

	if alert_state != prev:
		emit_signal("alert_state_changed", alert_state)
		if alert_state == AlertState.ALERT:
			GameManager.on_alert_triggered()

func _visibility_mult() -> float:
	if not player_ref: return 1.0
	var shadow   : bool = player_ref.get("is_in_shadow") or false
	var crouched : bool = player_ref.get("is_crouching") or false
	if shadow and crouched: return 0.1
	if shadow:              return 0.4
	if crouched:            return 0.6
	return 1.0

# ─── Behaviour ───────────────────────────────────────────────────────────────
func _update_behaviour(delta: float) -> void:
	match alert_state:
		AlertState.UNAWARE, AlertState.SUSPICIOUS: _patrol(delta)
		AlertState.ALERT:                          _chase()

func _patrol(delta: float) -> void:
	if patrol_points.is_empty():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_waiting:
		wait_timer -= delta
		velocity    = Vector2.ZERO
		if wait_timer <= 0.0:
			is_waiting     = false
			current_patrol = (current_patrol + 1) % patrol_points.size()
		move_and_slide()
		return

	var target    : Node2D = get_node(patrol_points[current_patrol])
	var dir       := (target.global_position - global_position).normalized()
	velocity = dir * SPEED_PATROL
	_face(dir)
	move_and_slide()

	if global_position.distance_to(target.global_position) < 8.0:
		is_waiting = true
		wait_timer = wait_time

func _chase() -> void:
	var target := player_ref.global_position if player_ref else last_known_pos
	var dir    := (target - global_position).normalized()
	velocity = dir * SPEED_ALERT
	_face(dir)
	move_and_slide()

	if player_ref and global_position.distance_to(player_ref.global_position) < 16.0:
		player_ref.get_caught()

func _face(dir: Vector2) -> void:
	if dir != Vector2.ZERO:
		rotation = dir.angle()

# ─── UI & visual feedback ────────────────────────────────────────────────────
func _update_ui() -> void:
	if suspicion_bar:
		suspicion_bar.value   = suspicion
		suspicion_bar.visible = suspicion > 0.0

	if exclamation:
		match alert_state:
			AlertState.SUSPICIOUS: exclamation.text = "?"; exclamation.visible = true
			AlertState.ALERT:      exclamation.text = "!"; exclamation.visible = true
			_:                     exclamation.visible = false

func _tint_sprite() -> void:
	if not sprite: return
	match alert_state:
		AlertState.SUSPICIOUS: sprite.modulate = Color(1.0, 0.9, 0.2)
		AlertState.ALERT:      sprite.modulate = Color(1.0, 0.2, 0.2)
		_:                     sprite.modulate = Color.WHITE

# ─── Called by DetectionCone ─────────────────────────────────────────────────
func register_player(p: Node2D) -> void:
	player_ref = p
