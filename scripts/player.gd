extends CharacterBody2D

# ─── Constants ────────────────────────────────────────────────────────────────
const SPEED_NORMAL  := 120.0
const SPEED_CROUCH  := 60.0
const SPEED_DASH    := 300.0
const DASH_DURATION := 0.15
const DASH_COOLDOWN := 1.0

# ─── State ────────────────────────────────────────────────────────────────────
enum State { IDLE, WALKING, CROUCHING, DASHING, CAUGHT }

var state         := State.IDLE
var is_crouching  := false
var is_in_shadow  := false
var dash_timer    := 0.0
var dash_cooldown := 0.0
var dash_dir      := Vector2.ZERO

signal caught

# ─── References (all nullable — safe without sprites) ─────────────────────────
@onready var sprite           : Sprite2D         = $Sprite2D
@onready var collision        : CollisionShape2D = $CollisionShape2D
@onready var crouch_collision : CollisionShape2D = $CrouchCollision

# ─── Lifecycle ────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("player")
	if crouch_collision:
		crouch_collision.disabled = true

func _physics_process(delta: float) -> void:
	if state == State.CAUGHT:
		return

	_tick_dash(delta)

	if state == State.DASHING:
		velocity = dash_dir * SPEED_DASH
		move_and_slide()
		_tint_sprite()
		return

	_handle_crouch()
	_handle_move()
	move_and_slide()
	_tint_sprite()

# ─── Input ────────────────────────────────────────────────────────────────────
func _handle_crouch() -> void:
	is_crouching = Input.is_action_pressed("crouch")
	if collision:       collision.disabled       = is_crouching
	if crouch_collision: crouch_collision.disabled = not is_crouching

func _handle_move() -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0.0 and dir != Vector2.ZERO:
		_start_dash(dir)
		return
	velocity = dir * (SPEED_CROUCH if is_crouching else SPEED_NORMAL)
	state = (State.CROUCHING if is_crouching else State.WALKING) if dir != Vector2.ZERO else State.IDLE

func _start_dash(dir: Vector2) -> void:
	state         = State.DASHING
	dash_dir      = dir.normalized()
	dash_timer    = DASH_DURATION
	dash_cooldown = DASH_COOLDOWN

func _tick_dash(delta: float) -> void:
	if dash_cooldown > 0.0: dash_cooldown -= delta
	if dash_timer    > 0.0:
		dash_timer -= delta
		if dash_timer <= 0.0:
			state = State.IDLE

# ─── Visual feedback ─────────────────────────────────────────────────────────
# Tint the sprite to show stealth state at a glance:
#   hidden in shadow + crouching = nearly invisible dark tint
#   crouching                    = slight dim
#   normal                       = full colour
func _tint_sprite() -> void:
	if not sprite:
		return
	if is_in_shadow and is_crouching:
		sprite.modulate = Color(0.3, 0.2, 0.5, 0.4)
	elif is_in_shadow:
		sprite.modulate = Color(0.6, 0.4, 0.8, 0.7)
	elif is_crouching:
		sprite.modulate = Color(0.8, 0.6, 1.0, 1.0)
	else:
		sprite.modulate = Color.WHITE

	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0

# ─── Shadow zone callbacks ────────────────────────────────────────────────────
func enter_shadow() -> void: is_in_shadow = true
func exit_shadow()  -> void: is_in_shadow = false

# ─── Called by Guard on catch ─────────────────────────────────────────────────
func get_caught() -> void:
	state    = State.CAUGHT
	velocity = Vector2.ZERO
	if sprite:
		sprite.modulate = Color(1, 0, 0, 0.8)
	emit_signal("caught")
	GameManager.on_player_caught()
