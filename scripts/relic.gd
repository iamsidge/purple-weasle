extends Area3D

# ─── Relic ────────────────────────────────────────────────────────────────────
# A floating, glowing collectible. Bobs and spins. Collect all of them to
# unlock the level exit.

const BOB_HEIGHT := 0.25
const BOB_SPEED  := 2.0
const SPIN_SPEED := 1.4

var _base_y    := 0.0
var _t         := randf() * TAU   # random phase so relics don't bob in sync
var _collected := false

@onready var mesh  : MeshInstance3D = $Mesh
@onready var light : OmniLight3D    = $OmniLight3D

func _ready() -> void:
	_base_y = mesh.position.y if mesh else 1.0
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _collected:
		return
	_t += delta
	if mesh:
		mesh.position.y = _base_y + sin(_t * BOB_SPEED) * BOB_HEIGHT
		mesh.rotate_y(SPIN_SPEED * delta)
	if light:
		light.light_energy = 1.6 + sin(_t * 4.0) * 0.4   # gentle pulse

func _on_body_entered(body: Node3D) -> void:
	if _collected or not body.is_in_group("player"):
		return
	_collected = true
	GameManager.collect_relic()
	if AudioManager:
		AudioManager.play_pickup()
	_play_collect_fx()

func _play_collect_fx() -> void:
	set_deferred("monitoring", false)
	var tween := create_tween().set_parallel(true)
	if mesh:
		tween.tween_property(mesh, "scale", Vector3.ZERO, 0.3).set_ease(Tween.EASE_IN)
		tween.tween_property(mesh, "position:y", _base_y + 1.2, 0.3)
	if light:
		tween.tween_property(light, "light_energy", 0.0, 0.3)
	await tween.finished
	queue_free()
