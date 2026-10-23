# ACHERON-9: INCIDENT - MicrophoneInputManager (Godot port of UMicrophoneInputManager)
# Tickless mic monitoring via Godot's AudioServer capture, with synthetic fallback.
class_name MicrophoneInputManager
extends Node

signal noise_detected(loudness_db: float)

# Config (mirrors UE)
@export var db_threshold: float = -40.0
@export var polling_interval: float = 0.15
@export var b_enable_mic_capture: bool = true

# State
var current_loudness: float = 0.0
var b_is_listening: bool = false

var _poll_timer: Timer
var _b_timer_active: bool = false
var _b_new_audio_data: bool = false
var _latest_audio_buffer: PackedFloat32Array = PackedFloat32Array()
var _capture_idx: int = -1
var _capture_frames: int = 0

func _ready() -> void:
	if b_enable_mic_capture:
		start_listening()
	else:
		print("[Acheron9] Mic capture disabled - synthetic noise triggers active")
		_start_synthetic_polling()

func _exit_tree() -> void:
	stop_listening()

func start_listening() -> void:
	if _b_timer_active:
		return
	if not b_enable_mic_capture:
		b_is_listening = false
		_start_synthetic_polling()
		return

	if not _is_mic_available():
		print("[Acheron9] No microphone detected - falling back to synthetic triggers")
		b_is_listening = false
		_start_synthetic_polling()
		return

	# Godot: use AudioServer capture
	# Capture from the default playback bus (bus 0) — or we can capture from a dedicated input bus.
	# Godot 4 provides AudioServer.get_bus_effect() for capture effects.
	# Here we use AudioServer.capture_* functions if available (Godot 4.2+ AudioEffectCapture).
	var input_bus = AudioServer.get_bus_index("Input")
	if input_bus == -1:
		# No input bus; create one
		input_bus = 0  # Use master bus for fallback

	# Godot 4.7.2 moved capture to AudioEffectCapture; check if legacy capture API exists
	if AudioServer.has_method("capture_start"):
		_capture_idx = AudioServer.call("capture_start", input_bus) as int
	else:
		_capture_idx = -1
	_capture_frames = 0
	if _capture_idx != -1:
		b_is_listening = true
		_b_timer_active = true
		_poll_timer = Timer.new()
		_poll_timer.wait_time = polling_interval
		_poll_timer.one_shot = false
		_poll_timer.autostart = true
		add_child(_poll_timer)
		_poll_timer.timeout.connect(_on_poll_mic_volume)
		_poll_timer.start()
		print("[Acheron9] Mic feed started at %.2fs poll interval" % polling_interval)
	else:
		b_is_listening = false
		_start_synthetic_polling()

func stop_listening() -> void:
	if _b_timer_active and _poll_timer:
		_poll_timer.stop()
	_b_timer_active = false
	if _capture_idx != -1 and AudioServer.has_method("capture_stop"):
		AudioServer.call("capture_stop")
		_capture_idx = -1
	b_is_listening = false

func _is_mic_available() -> bool:
	if not b_enable_mic_capture:
		return false
	# Check if an input bus exists with capture
	var input_bus = AudioServer.get_bus_index("Input")
	if input_bus != -1:
		return true
	return false

func _start_synthetic_polling() -> void:
	_b_timer_active = true
	_poll_timer = Timer.new()
	_poll_timer.wait_time = polling_interval
	_poll_timer.one_shot = false
	_poll_timer.autostart = true
	add_child(_poll_timer)
	_poll_timer.timeout.connect(_on_poll_mic_volume)
	_poll_timer.start()

func _on_poll_mic_volume() -> void:
	# Timer fires every 0.15s — NO PROCESS/TICK INTERACTION
	if b_is_listening and _capture_idx != -1:
		capture_and_calculate()

	# Check threshold
	if current_loudness > db_threshold:
		noise_detected.emit(current_loudness)

func capture_and_calculate() -> void:
	# Godot's AudioServer capture — use safe call pattern for API compatibility
	if _capture_idx == -1:
		return
	var stereo_buffer: PackedVector2Array
	if AudioServer.has_method("get_capture_buffer"):
		stereo_buffer = AudioServer.call("get_capture_buffer", _capture_idx) as PackedVector2Array
	else:
		current_loudness = -80.0
		return
	if stereo_buffer.size() == 0:
		current_loudness = -80.0
		return

	# Calculate RMS over the captured buffer
	var sum_squares := 0.0
	for i in stereo_buffer.size():
		var sample = stereo_buffer[i]
		sum_squares += sample * sample

	var mean_square = sum_squares / stereo_buffer.size()
	if mean_square < 1e-8:
		current_loudness = -80.0
	else:
		var rms = sqrt(mean_square)
		var db = 20.0 * log(rms) / log(10.0)  # natural log -> dB conversion
		current_loudness = max(db, -80.0)
