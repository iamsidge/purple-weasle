extends Area2D

# ─── Shadow Zone ──────────────────────────────────────────────────────────────
# Place in a level to create dark areas where the player is harder to detect.
# Calls enter_shadow() / exit_shadow() on any node in the "player" group.

@export var zone_color : Color = Color(0.1, 0.0, 0.2, 0.5)

@onready var visual : ColorRect = $ColorRect

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if visual:
		visual.color = zone_color

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("enter_shadow"):
		body.enter_shadow()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("exit_shadow"):
		body.exit_shadow()
