extends CharacterBody3D

# ─── Warped Woodland Creature ─────────────────────────────────────────────────
# Wolfenstein-style billboard enemy.
# Patrols waypoints, detects the player by line-of-sight + angle, then chases.

enum State { IDLE, PATROL, ALERT, CHASE, ATTACK, DEAD }

# ─── Tuning ───────────────────────────────────────────────────────────────────
const SPEED_PATROL    := 2.2
const SPEED_CHASE     := 6.0
const DETECT_RANGE    := 20.0   # metres
const LOSE_RANGE      := 28.0   # give up chase beyond this
const ATTACK_RANGE    := 1.6
const FOV_HALF_DEG    := 65.0   # half-cone angle in degrees
const ALERT_PAUSE     := 1.0    # seconds frozen before chasing
const PATROL_WAIT     := 1.8

# ─── Exports ─────────────────────────────────────────────────────────────────
@export var patrol_nodes   : Array[Node3D] = []
@export var creature_type  : String        = "deer"   # "deer" | "rabbit"

# ─── State ────────────────────────────────────────────────────────────────────
var state          := State.PATROL
var current_patrol := 0
var patrol_wait    := 0.0
var alert_timer    := 0.0
var player_ref     : Node3D = null
var last_known_pos := Vector3.ZERO
var _was_hunting   := false

# ─── Refs (nullable) ──────────────────────────────────────────────────────────
@onready var sprite     : Sprite3D   = $Sprite3D
@onready var ray        : RayCast3D  = $RayCast3D
@onready var alert_label: Label3D    = $AlertLabel

# ─── Lifecycle ────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("creatures")
	if alert_label:
		alert_label.visible = false

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_sense(delta)
	_behave(delta)
	_sync_hunt()
	_update_visuals()
	if velocity.length() > 0.01:
		move_and_slide()

# ─── Sensing ──────────────────────────────────────────────────────────────────
func _sense(_delta: float) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p : Node3D = players[0]
	var to_p      := p.global_position - global_position
	var dist      := to_p.length()

	# Already chasing — only lose sight at long range
	if state == State.CHASE or state == State.ATTACK:
		if dist > LOSE_RANGE:
			state      = State.PATROL
			player_ref = null
		else:
			player_ref     = p
			last_known_pos = p.global_position
		return

	# Range check
	if dist > DETECT_RANGE:
		return

	# FOV angle check (flat plane only)
	var flat    := Vector3(to_p.x, 0.0, to_p.z).normalized()
	var forward := -global_transform.basis.z
	var dot     := flat.dot(forward)
	var angle   := rad_to_deg(acos(clampf(dot, -1.0, 1.0)))
	if angle > FOV_HALF_DEG:
		return

	# Raycast occlusion — blocked by walls?
	if ray:
		ray.target_position = to_local(p.global_position + Vector3(0, 0.8, 0))
		ray.force_raycast_update()
		if ray.is_colliding():
			var hit := ray.get_collider()
			if not hit.is_in_group("player"):
				return

	# Player spotted!
	player_ref     = p
	last_known_pos = p.global_position
	if state == State.PATROL or state == State.IDLE:
		state       = State.ALERT
		alert_timer = ALERT_PAUSE
		GameManager.on_alert_triggered()
		if AudioManager:
			AudioManager.play_growl_at(global_position)

# ─── Behaviour ────────────────────────────────────────────────────────────────
func _behave(delta: float) -> void:
	match state:
		State.IDLE:
			velocity = Vector3.ZERO

		State.PATROL:
			_do_patrol(delta)

		State.ALERT:
			velocity    = Vector3.ZERO
			alert_timer -= delta
			if alert_timer <= 0.0:
				state = State.CHASE if player_ref else State.PATROL

		State.CHASE:
			var target := player_ref.global_position if player_ref else last_known_pos
			_move_to(target, SPEED_CHASE)
			if player_ref and global_position.distance_to(player_ref.global_position) < ATTACK_RANGE:
				state       = State.ATTACK
				alert_timer = 0.35
				velocity    = Vector3.ZERO

		State.ATTACK:
			velocity    = Vector3.ZERO
			alert_timer -= delta
			if alert_timer <= 0.0:
				if player_ref and global_position.distance_to(player_ref.global_position) < ATTACK_RANGE * 1.4:
					player_ref.get_caught()
				else:
					state = State.CHASE

func _do_patrol(delta: float) -> void:
	if patrol_nodes.is_empty():
		velocity = Vector3.ZERO
		return
	if patrol_wait > 0.0:
		patrol_wait -= delta
		velocity     = Vector3.ZERO
		return
	var target := patrol_nodes[current_patrol]
	if not is_instance_valid(target):
		return
	_move_to(target.global_position, SPEED_PATROL)
	if global_position.distance_to(target.global_position) < 0.5:
		current_patrol = (current_patrol + 1) % patrol_nodes.size()
		patrol_wait    = PATROL_WAIT

func _move_to(target: Vector3, speed: float) -> void:
	var dir    := target - global_position
	dir.y       = 0.0
	if dir.length() > 0.05:
		dir         = dir.normalized()
		velocity.x  = dir.x * speed
		velocity.z  = dir.z * speed
		look_at(global_position + dir, Vector3.UP)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	velocity.y = velocity.y if not is_on_floor() else 0.0

# ─── Hunt tracking (drives the heartbeat audio) ──────────────────────────────
func _sync_hunt() -> void:
	var hunting := state == State.CHASE or state == State.ATTACK
	if hunting == _was_hunting:
		return
	_was_hunting = hunting
	if AudioManager:
		if hunting:
			AudioManager.add_hunter(self)
		else:
			AudioManager.remove_hunter(self)

func _exit_tree() -> void:
	if _was_hunting and AudioManager:
		AudioManager.remove_hunter(self)

# ─── Visuals ──────────────────────────────────────────────────────────────────
func _update_visuals() -> void:
	if sprite:
		match state:
			State.ALERT:
				sprite.modulate = Color(1.4, 0.9, 0.2, 1.0)   # yellow
			State.CHASE:
				sprite.modulate = Color(1.6, 0.35, 0.2, 1.0)  # angry red
			State.ATTACK:
				var pulse := abs(sin(Time.get_ticks_msec() * 0.01))
				sprite.modulate = Color(1.5 + pulse * 0.5, 0.2, 0.2, 1.0)
			_:
				sprite.modulate = Color.WHITE

	if alert_label:
		match state:
			State.ALERT:
				alert_label.text    = "!"
				alert_label.visible = true
			State.CHASE, State.ATTACK:
				alert_label.text    = "!!"
				alert_label.visible = true
			_:
				alert_label.visible = false
