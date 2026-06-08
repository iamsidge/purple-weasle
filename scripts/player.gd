extends CharacterBody2D

# ─── Constants ────────────────────────────────────────────────────────────────
const SPEED_NORMAL   := 120.0
const SPEED_CROUCH   := 60.0
const SPEED_DASH     := 300.0
const DASH_DURATION  := 0.15   # seconds
const DASH_COOLDOWN  := 1.0    # seconds
const NOISE_NORMAL   := 1.0    # noise radius multiplier when walking
const NOISE_CROUCH   := 0.3    # quieter when crouching
const NOISE_DASH     := 1.8    # louder when dashing

# ─── State ────────────────────────────────────────────────────────────────────
enum State { IDLE, WALKING, CROUCHING, DASHING, CAUGHT }

var state            := State.IDLE
var is_crouching     := false
var dash_timer       := 0.0
var dash_cooldown    := 0.0
var dash_direction   := Vector2.ZERO
var is_in_shadow     := false   # set by shadow zones via Area2D
var noise_radius     := 0.0     # broadcast to guards via DetectionManager

signal caught
signal noise_emitted(position: Vector2, radius: float)

# ─── References ───────────────────────────────────────────────────────────────
@onready var sprite          : AnimatedSprite2D = $AnimatedSprite2D
@onready var collision       : CollisionShape2D = $CollisionShape2D
@onready var crouch_collision: CollisionShape2D = $CrouchCollisionShape2D

# ─── Lifecycle ────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("player")
	if crouch_collision:
		crouch_collision.disabled = true

func _physics_process(delta: float) -> void:
	if state == State.CAUGHT:
		return

	_handle_dash_timer(delta)

	if state == State.DASHING:
		velocity = dash_direction * SPEED_DASH
		move_and_slide()
		return

	_handle_crouch()
	_handle_movement()
	_update_noise()
	move_and_slide()
	_update_animation()

# ─── Input handlers ───────────────────────────────────────────────────────────
func _handle_crouch() -> void:
	is_crouching = Input.is_action_pressed("crouch")
	if collision:
		collision.disabled = is_crouching
	if crouch_collision:
		crouch_collision.disabled = !is_crouching

func _handle_movement() -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0.0 and direction != Vector2.ZERO:
		_start_dash(direction)
		return

	var speed := SPEED_CROUCH if is_crouching else SPEED_NORMAL
	velocity = direction * speed

	if direction != Vector2.ZERO:
		state = State.CROUCHING if is_crouching else State.WALKING
	else:
		state = State.IDLE

func _start_dash(direction: Vector2) -> void:
	state          = State.DASHING
	dash_direction = direction.normalized()
	dash_timer     = DASH_DURATION
	dash_cooldown  = DASH_COOLDOWN
	emit_signal("noise_emitted", global_position, noise_radius * NOISE_DASH)

func _handle_dash_timer(delta: float) -> void:
	if dash_cooldown > 0.0:
		dash_cooldown -= delta
	if dash_timer > 0.0:
		dash_timer -= delta
		if dash_timer <= 0.0:
			state = State.IDLE

# ─── Noise ────────────────────────────────────────────────────────────────────
func _update_noise() -> void:
	match state:
		State.WALKING:
			noise_radius = 80.0 * NOISE_NORMAL
		State.CROUCHING:
			noise_radius = 80.0 * NOISE_CROUCH
		_:
			noise_radius = 0.0

# ─── Animation ────────────────────────────────────────────────────────────────
func _update_animation() -> void:
	if not sprite:
		return
	match state:
		State.IDLE:
			sprite.play("idle")
		State.WALKING:
			sprite.play("walk")
		State.CROUCHING:
			sprite.play("crouch")
		State.DASHING:
			sprite.play("dash")

	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0

# ─── Shadow detection (called by ShadowZone Area2D) ─────────────────────────
func enter_shadow() -> void:
	is_in_shadow = true

func exit_shadow() -> void:
	is_in_shadow = false

# ─── Called by Guard when caught ─────────────────────────────────────────────
func get_caught() -> void:
	state = State.CAUGHT
	velocity = Vector2.ZERO
	emit_signal("caught")
	GameManager.on_player_caught()
