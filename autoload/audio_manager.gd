# ACHERON-9: INCIDENT - AudioManager (Godot port of Acheron9Audio3DAmbientManager)
# 3D spatial audio zones for ambient horror: sub-bass drone, steam bursts, sirens, water drips.
class_name AudioManager
extends Node

# Audio zones
class AudioZone:
	var zone_name: String
var zone_center: Vector3
var radius: float = 1000.0
var b_active: bool = false
var ambient_player: AudioStreamPlayer3D

signal audio_zone_entered(zone_name: String)
signal audio_zone_exited(zone_name: String)

# Config
var zone_update_interval: float = 0.1
var sub_bass_frequency: float = 40.0
var sub_bass_volume: float = 0.3
var water_drip_interval: float = 3.0
var steam_burst_interval: float = 8.0

# Audio assets (loaded safely at runtime — files may not exist in dev build)
var master_drone: AudioStream
var siren_sound: AudioStream
var steam_burst_sound: AudioStream
var rack_collapse_sound: AudioStream
var bone_crush_sound: AudioStream
var heartbeat_sound: AudioStream

# State
var audio_zones: Array[AudioZone] = []
var player_last_position: Vector3 = Vector3.ZERO
var _zone_timer: Timer
var _steam_timer: Timer
var _master_drone_player: AudioStreamPlayer3D

func _ready() -> void:
	# Setup timers
	_zone_timer = Timer.new()
	_zone_timer.wait_time = zone_update_interval
	_zone_timer.one_shot = false
	_zone_timer.autostart = true
	add_child(_zone_timer)
	_zone_timer.timeout.connect(_on_zone_update)

	_steam_timer = Timer.new()
	_steam_timer.wait_time = steam_burst_interval
	_steam_timer.one_shot = false
	_steam_timer.autostart = true
	add_child(_steam_timer)
	_steam_timer.timeout.connect(_on_steam_burst)

	# Load audio assets safely (files may not exist in a dev build)
	master_drone = _safe_load_audio("res://assets/audio/ambience/master_drone.ogg")
	siren_sound = _safe_load_audio("res://assets/audio/fx/siren_loop.ogg")
	steam_burst_sound = _safe_load_audio("res://assets/audio/fx/steam_burst.ogg")
	rack_collapse_sound = _safe_load_audio("res://assets/audio/fx/rack_collapse.ogg")
	bone_crush_sound = _safe_load_audio("res://assets/audio/fx/bone_crush.ogg")
	heartbeat_sound = _safe_load_audio("res://assets/audio/fx/heartbeat.ogg")

	# Start master drone
	_start_master_drone()

	print("[Acheron9] Audio 3D ambient manager online - sub-bass %dHz" % sub_bass_frequency)

func _start_master_drone() -> void:
	_master_drone_player = AudioStreamPlayer3D.new()
	_master_drone_player.stream = master_drone
	_master_drone_player.volume_db = linear_to_db(sub_bass_volume)
	_master_drone_player.bus = "Music"
	_master_drone_player.autoplay = true
	_master_drone_player.stream_paused = false
	add_child(_master_drone_player)
	_master_drone_player.play()

func _on_zone_update() -> void:
	var player = get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return
	var current_pos = player.global_position
	if not current_pos.distance_to(player_last_position) < 10.0:
		_check_zone_transitions(current_pos)
		player_last_position = current_pos

func _on_steam_burst() -> void:
	var player = get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return
	_trigger_steam_burst(player.global_position)

func register_zone(name: String, center: Vector3, radius: float) -> void:
	var zone = AudioZone.new()
	zone.zone_name = name
	zone.zone_center = center
	zone.radius = radius
	zone.b_active = false
	audio_zones.append(zone)

func unregister_zone(name: String) -> void:
	for i in audio_zones.size() - 1:
		if audio_zones[i].zone_name == name:
			audio_zones.remove_at(i)

func _check_zone_transitions(player_pos: Vector3) -> void:
	for zone in audio_zones:
		var distance = player_pos.distance_to(zone.zone_center)
		var b_inside = distance <= zone.radius
		if b_inside and not zone.b_active:
			zone.b_active = true
			audio_zone_entered.emit(zone.zone_name)
			print("[Acheron9] Entered audio zone: %s" % zone.zone_name)
		elif not b_inside and zone.b_active:
			zone.b_active = false
			audio_zone_exited.emit(zone.zone_name)
			print("[Acheron9] Exited audio zone: %s" % zone.zone_name)

func _trigger_steam_burst(location: Vector3) -> void:
	var player = get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return
	var steam_player = AudioStreamPlayer3D.new()
	steam_player.stream = steam_burst_sound
	steam_player.position = location
	steam_player.bus = "SFX"
	add_child(steam_player)
	steam_player.play()
	# Auto-queue free after sound finishes
	steam_player.finished.connect(func(): steam_player.queue_free())

func play_sound_at_location(sound: AudioStream, location: Vector3, volume: float = 1.0, pitch: float = 1.0, bus: String = "SFX") -> void:
	if not sound:
		return
	var player = AudioStreamPlayer3D.new()
	player.stream = sound
	player.position = location
	player.volume_linear = volume
	player.pitch_scale = pitch
	player.bus = bus
	add_child(player)
	player.play()
	player.finished.connect(func(): player.queue_free())

func play_sound_2d(sound: AudioStream, volume: float = 1.0, pitch: float = 1.0, bus: String = "SFX") -> void:
	if not sound:
		return
	var player = AudioStreamPlayer.new()
	player.stream = sound
	player.volume_linear = volume
	player.pitch_scale = pitch
	player.bus = bus
	add_child(player)
	player.play()
	player.finished.connect(func(): player.queue_free())

func is_player_in_zone(zone_name: String) -> bool:
	for zone in audio_zones:
		if zone.zone_name == zone_name and zone.b_active:
			return true
	return false

func update_zones() -> void:
	_on_zone_update()

# ==================== Sound Accessors ====================

func get_siren_sound() -> AudioStream:
	return siren_sound

func get_steam_burst_sound() -> AudioStream:
	return steam_burst_sound

func get_bone_crush_sound() -> AudioStream:
	return bone_crush_sound

func get_rack_collapse_sound() -> AudioStream:
	return rack_collapse_sound

func get_heartbeat_sound() -> AudioStream:
	return heartbeat_sound

func _safe_load_audio(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	# Create a procedural tone as fallback (simple sine wave for 1 second)
	return _create_procedural_tone(220.0, 1.0)

func _create_procedural_tone(freq: float, duration: float) -> AudioStream:
	var sample_rate = 44100
	var num_samples = int(sample_rate * duration)
	# Convert float samples to 16-bit signed integer bytes for AudioStreamWAV
	# In Godot 4.7.2, AudioStreamWAV.data is PackedByteArray (16-bit signed per sample for FORMAT_MONO)
	var byte_data: PackedByteArray = PackedByteArray()
	byte_data.resize(num_samples * 4)  # 2 channels x 2 bytes per sample for stereo 16-bit
	for i in num_samples:
		var sample = sin(2.0 * PI * freq * i / sample_rate) * 0.3
		var int_sample = int(clamp(sample * 32767.0, -32768.0, 32767.0))
		# Left channel
		byte_data[i * 4] = int_sample & 0xFF
		byte_data[i * 4 + 1] = (int_sample >> 8) & 0xFF
		# Right channel (same as left for mono source)
		byte_data[i * 4 + 2] = int_sample & 0xFF
		byte_data[i * 4 + 3] = (int_sample >> 8) & 0xFF

	var wav = AudioStreamWAV.new()
	wav.format = 0  # FORMAT_STEREO (16-bit stereo gives ffp=8)
	wav.stereo = true
	wav.data = byte_data
	wav.mix_rate = sample_rate
	return wav
