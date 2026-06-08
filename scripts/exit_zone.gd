extends Area2D

# ─── Exit Zone ────────────────────────────────────────────────────────────────
# When the player walks into this Area2D the level is complete.

@onready var glow : ColorRect = $Glow

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Pulse the glow to draw attention to the exit
	if glow:
		var tween := create_tween().set_loops()
		tween.tween_property(glow, "modulate:a", 0.3, 0.8)
		tween.tween_property(glow, "modulate:a", 1.0, 0.8)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		GameManager.on_level_complete()
