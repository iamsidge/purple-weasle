extends Node

# ─── Audio Manager (Autoload as "AudioManager") ──────────────────────────────
# Central sound driver. Loads procedural WAVs at runtime, loops the ambient
# drone and a hunt heartbeat, and plays one-shots (footsteps, growls, pickups,
# the death sting). Positional sounds use a small pool of AudioStreamPlayer3D.

const AUDIO_DIR := "res://assets/audio/"

# Bus-less simple mixing via per-stream volume (dB)
const VOL_AMBIENT   := -10.0
const VOL_HEARTBEAT := -6.0
const VOL_FOOTSTEP  := -14.0
const VOL_GROWL     := -4.0
const VOL_PICKUP    := -5.0
const VOL_CAUGHT    := -2.0

# ─── Streams (loaded in _ready) ───────────────────────────────────────────────
var _stream : Dictionary = {}

# ─── Players ──────────────────────────────────────────────────────────────────
var _ambient   : AudioStreamPlayer
var _heartbeat : AudioStreamPlayer
var _oneshot   : AudioStreamPlayer            # non-positional one-shots
var _pool3d    : Array[AudioStreamPlayer3D] = []
const POOL_SIZE := 6

# ─── Hunt tracking — heartbeat plays while ≥1 creature is hunting ────────────
var _hunters : Dictionary = {}   # instance_id -> true

# ─── Lifecycle ────────────────────────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_streams()
	_build_players()

func _load_streams() -> void:
	for key in ["ambient_drone", "heartbeat", "footstep", "growl", "relic_pickup", "caught"]:
		var s := load(AUDIO_DIR + key + ".wav")
		if s is AudioStreamWAV:
			_stream[key] = s

	# Loop the sustained sounds
	_set_loop("ambient_drone")
	_set_loop("heartbeat")

func _set_loop(key: String) -> void:
	if not _stream.has(key):
		return
	var w : AudioStreamWAV = _stream[key]
	# Compute frame count so the loop point is the true end of the sample.
	# Our WAVs are 16-bit (2 bytes/sample) mono.
	var channels := 2 if w.stereo else 1
	var frames   := w.data.size() / (2 * channels)
	w.loop_mode  = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end   = maxi(frames - 1, 0)

func _build_players() -> void:
	_ambient = AudioStreamPlayer.new()
	_ambient.volume_db = VOL_AMBIENT
	_ambient.bus = "Master"
	add_child(_ambient)

	_heartbeat = AudioStreamPlayer.new()
	_heartbeat.volume_db = VOL_HEARTBEAT
	add_child(_heartbeat)

	_oneshot = AudioStreamPlayer.new()
	add_child(_oneshot)

	for i in POOL_SIZE:
		var p := AudioStreamPlayer3D.new()
		p.max_distance = 30.0
		p.unit_size    = 4.0
		add_child(p)
		_pool3d.append(p)

# ─── Ambient ──────────────────────────────────────────────────────────────────
func start_ambient() -> void:
	if _ambient and _stream.has("ambient_drone") and not _ambient.playing:
		_ambient.stream = _stream["ambient_drone"]
		_ambient.play()

func stop_ambient() -> void:
	if _ambient:
		_ambient.stop()

# ─── One-shots (non-positional) ──────────────────────────────────────────────
func play_footstep() -> void:
	if _stream.has("footstep"):
		_oneshot.stream     = _stream["footstep"]
		_oneshot.volume_db  = VOL_FOOTSTEP + randf_range(-1.5, 1.5)
		_oneshot.pitch_scale = randf_range(0.9, 1.12)
		_oneshot.play()

func play_pickup() -> void:
	if _stream.has("relic_pickup"):
		_oneshot.stream      = _stream["relic_pickup"]
		_oneshot.volume_db   = VOL_PICKUP
		_oneshot.pitch_scale = 1.0
		_oneshot.play()

func play_caught() -> void:
	stop_heartbeat()
	if _stream.has("caught"):
		_oneshot.stream      = _stream["caught"]
		_oneshot.volume_db   = VOL_CAUGHT
		_oneshot.pitch_scale = 1.0
		_oneshot.play()

# ─── Positional growl ─────────────────────────────────────────────────────────
func play_growl_at(pos: Vector3) -> void:
	if not _stream.has("growl"):
		return
	var p := _free_player()
	if p == null:
		return
	p.global_position = pos
	p.stream          = _stream["growl"]
	p.volume_db       = VOL_GROWL
	p.pitch_scale     = randf_range(0.85, 1.05)
	p.play()

func _free_player() -> AudioStreamPlayer3D:
	for p in _pool3d:
		if not p.playing:
			return p
	return _pool3d[0] if not _pool3d.is_empty() else null

# ─── Hunt heartbeat ───────────────────────────────────────────────────────────
func add_hunter(node: Node) -> void:
	_hunters[node.get_instance_id()] = true
	_refresh_heartbeat()

func remove_hunter(node: Node) -> void:
	_hunters.erase(node.get_instance_id())
	_refresh_heartbeat()

func _refresh_heartbeat() -> void:
	_prune_hunters()
	if _hunters.is_empty():
		stop_heartbeat()
	else:
		start_heartbeat()

func _prune_hunters() -> void:
	for id in _hunters.keys():
		if not is_instance_id_valid(id):
			_hunters.erase(id)

func start_heartbeat() -> void:
	if _heartbeat and _stream.has("heartbeat") and not _heartbeat.playing:
		_heartbeat.stream = _stream["heartbeat"]
		_heartbeat.play()

func stop_heartbeat() -> void:
	if _heartbeat:
		_heartbeat.stop()

# ─── Reset (called on scene change) ──────────────────────────────────────────
func reset() -> void:
	_hunters.clear()
	stop_heartbeat()
