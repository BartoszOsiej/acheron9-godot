# ACHERON-9: INCIDENT - FearSanityComponent (Godot port of UAcheron9FearSanityComponent)
# Fear/sanity tracking: proximity, mic peaks, camera shake, heartbeat, battery drain multiplier.
class_name FearSanityComponent
extends Node

# Runtime singleton accessor — untyped to avoid class-type resolution
var _audio_mgr = null

signal fear_level_changed(new_fear: float)
signal heart_beat(intensity: float)
signal fear_critical

# Config
@export var fear_increase_rate: float = 0.5
@export var fear_decrease_rate: float = 0.3
@export var max_fear: float = 100.0
@export var mic_peak_multiplier: float = 3.0
@export var camera_shake_base: float = 0.5
@export var battery_drain_multiplier: float = 2.0

# Thresholds
@export var low_threshold: float = 25.0
@export var medium_threshold: float = 50.0
@export var high_threshold: float = 75.0
@export var critical_threshold: float = 90.0

# State
var current_fear: float = 0.0
var b_heart_beating: bool = false
var b_critical_triggered: bool = false

var _fear_timer: Timer

func _ready() -> void:
	current_fear = 0.0
	_fear_timer = Timer.new()
	_fear_timer.wait_time = 0.5
	# Resolve autoload singleton
	_audio_mgr = get_node_or_null("/root/AudioManager")
	_fear_timer.one_shot = false
	_fear_timer.autostart = true
	add_child(_fear_timer)
	_fear_timer.timeout.connect(_on_fear_timer_elapsed)

func _on_fear_timer_elapsed() -> void:
	if not _is_critical():
		decrease_fear(fear_decrease_rate)

	_update_camera_shake()
	_update_battery_drain()

	if b_heart_beating:
		_inject_heartbeat_audio()

func check_proximity(distance: float) -> void:
	if distance < 100.0:
		increase_fear(8.0)
	elif distance < 300.0:
		increase_fear(4.0)
	elif distance < 600.0:
		increase_fear(1.0)

func on_mic_peak_detected(volume: float) -> void:
	# Fear spikes from loud sounds
	var fear_increase = volume * mic_peak_multiplier
	increase_fear(fear_increase)

func increase_fear(amount: float) -> void:
	current_fear = clamp(current_fear + amount, 0.0, max_fear)
	fear_level_changed.emit(current_fear)

	if _is_critical() and not b_critical_triggered:
		b_critical_triggered = true
		fear_critical.emit()
		print("[Acheron9] FEAR CRITICAL - sanity breach detected")

	# Enable heartbeat when fear > low threshold
	if current_fear > low_threshold and not b_heart_beating:
		b_heart_beating = true
	elif current_fear < low_threshold and b_heart_beating:
		b_heart_beating = false

func decrease_fear(amount: float) -> void:
	var old_fear = current_fear
	current_fear = max(0.0, current_fear - amount)

	if floor(old_fear) != floor(current_fear):
		fear_level_changed.emit(current_fear)

	if current_fear < low_threshold:
		b_heart_beating = false

	if current_fear < critical_threshold:
		b_critical_triggered = false

func _update_camera_shake() -> void:
	var fear_pct = get_fear_percent()
	var shake_intensity = camera_shake_base * (fear_pct / 100.0)
	if shake_intensity > 0.1:
		var player = get_tree().get_first_node_in_group("player") if get_tree() else null
		if player and player is Node3D:
			var cam = player.find_child("Camera3D", true, false) as Camera3D
			if cam:
				# Simple camera offset shake
				cam.h_offset = randf_range(-shake_intensity * 2.0, shake_intensity * 2.0)
				cam.v_offset = randf_range(-shake_intensity * 2.0, shake_intensity * 2.0)

func _update_battery_drain() -> void:
	var player = get_tree().get_first_node_in_group("player") if get_tree() else null
	if player:
		var flashlight = player.get_node_or_null("FlashlightComponent") as FlashlightComponent
		if flashlight:
			var fear_pct = get_fear_percent()
			if fear_pct > medium_threshold:
				flashlight.drain_rate = 1.0 + (battery_drain_multiplier * (fear_pct / 100.0))
			else:
				flashlight.drain_rate = 1.0

func _inject_heartbeat_audio() -> void:
	var heart_rate = 60.0 + (get_fear_percent() * 2.0)
	heart_beat.emit(heart_rate)

	# Play heartbeat sound spatially
	var player = get_tree().get_first_node_in_group("player") if get_tree() else null
	if player and player is Node3D and _audio_mgr:
		var hb_sound = _audio_mgr.get_heartbeat_sound()
		if hb_sound:
			var player_pos = player.global_position if player is Node3D else Vector3.ZERO
			_audio_mgr.play_sound_at_location(hb_sound, player_pos, 0.5, 1.0, "SFX")

func get_fear_percent() -> float:
	return (current_fear / max_fear) * 100.0

func _is_critical() -> bool:
	return current_fear >= critical_threshold

func is_critical() -> bool:
	return _is_critical()
