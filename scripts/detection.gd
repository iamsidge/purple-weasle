extends Node2D

# ─── Detection Cone ───────────────────────────────────────────────────────────
# Attached to a Guard node. Casts a triangular field-of-view cone and checks
# whether the player falls inside it, with raycast wall occlusion.

@export var fov_angle    : float = 70.0    # total cone width in degrees
@export var fov_distance : float = 150.0   # how far the guard can see
@export var ray_count    : int   = 12      # rays cast across the cone for the visual

var _player          : Node2D  = null
var _player_in_range : bool    = false
var _player_visible  : bool    = false
var _player_pos      : Vector2 = Vector2.ZERO

@onready var fov_area    : Area2D         = $FOVArea
@onready var raycast     : RayCast2D      = $RayCast2D
@onready var fov_polygon : Polygon2D      = $FOVPolygon

func _ready() -> void:
	if fov_area:
		fov_area.body_entered.connect(_on_body_entered)
		fov_area.body_exited.connect(_on_body_exited)
	_build_fov_polygon()

func _process(_delta: float) -> void:
	_check_visibility()
	_draw_fov()

# ─── Visibility check ────────────────────────────────────────────────────────
func _check_visibility() -> void:
	_player_visible = false
	if _player == null or not _player_in_range:
		return

	var to_player := _player.global_position - global_position
	var dist      := to_player.length()

	if dist > fov_distance:
		return

	# Angle check relative to guard's facing direction
	var angle_to_player := rad_to_deg(to_player.angle() - global_rotation)
	while angle_to_player > 180.0:  angle_to_player -= 360.0
	while angle_to_player < -180.0: angle_to_player += 360.0

	if abs(angle_to_player) > fov_angle * 0.5:
		return

	# Raycast — blocked by walls?
	if raycast:
		raycast.target_position = to_local(_player.global_position)
		raycast.force_raycast_update()
		if raycast.is_colliding():
			var collider := raycast.get_collider()
			if collider != _player:
				return

	_player_visible = true
	_player_pos     = _player.global_position

# ─── Public API ──────────────────────────────────────────────────────────────
func can_see_player() -> bool:
	return _player_visible

func player_position() -> Vector2:
	return _player_pos

# ─── FOV polygon ─────────────────────────────────────────────────────────────
func _build_fov_polygon() -> void:
	if not fov_polygon:
		return
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	var half := fov_angle * 0.5
	for i in range(ray_count + 1):
		var angle := deg_to_rad(-half + (fov_angle / ray_count) * i)
		points.append(Vector2(cos(angle), sin(angle)) * fov_distance)
	fov_polygon.polygon = points

func _draw_fov() -> void:
	if not fov_polygon:
		return
	var guard := get_parent()
	if guard and "alert_state" in guard:
		match guard.alert_state:
			1:  fov_polygon.color = Color(1, 1, 0, 0.25)   # suspicious
			2:  fov_polygon.color = Color(1, 0, 0, 0.35)   # alert
			_:  fov_polygon.color = Color(0, 1, 0, 0.15)   # unaware

# ─── Area2D signals ──────────────────────────────────────────────────────────
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player          = body
		_player_in_range = true
		if get_parent().has_method("register_player"):
			get_parent().register_player(body)

func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player_in_range = false
		_player_visible  = false
