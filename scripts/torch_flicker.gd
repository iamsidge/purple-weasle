extends OmniLight3D

# ─── Torch Flicker ────────────────────────────────────────────────────────────
# Attach to any OmniLight3D for a natural flickering flame effect.

var base_energy : float
var time        : float = 0.0

func _ready() -> void:
	base_energy = light_energy

func _process(delta: float) -> void:
	time += delta
	var flicker := sin(time * 13.7) * 0.12 + sin(time * 7.3) * 0.08 + sin(time * 21.1) * 0.04
	light_energy = base_energy + flicker
	# Slight colour shift — warmer when bright, cooler when dim
	light_color = Color(
		1.0,
		0.50 + flicker * 0.4,
		0.10 + flicker * 0.2
	)
