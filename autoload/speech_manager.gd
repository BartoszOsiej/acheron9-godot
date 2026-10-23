# ACHERON-9: INCIDENT - PROBOS-Core Speech Manager (Godot port of PROBOSSpeechManager)
# TTS queue, voice-line playback with pitch/distortion/reverb, and scheduled random speech.
class_name SpeechManager
extends Node

signal speech_played(spoken_text: String)
signal tape_secured_announced(tape_id: int, secured: int, total: int)

# TTS fragment struct
class PROBOSTTSFragment:
	var text: String
	var pitch_shift: float = 0.85
	var distortion_depth: float = 0.6
	var reverb_wet_level: float = 0.7
	var delay_seconds: float = 0.0

# Config
@export var base_pitch_shift: float = 0.85
@export var base_distortion: float = 0.6
@export var base_reverb_wet_level: float = 0.7
@export var min_interval: float = 8.0
@export var max_interval: float = 20.0
@export var b_randomized_speech: bool = true

# State
var b_active_speech: bool = false
var voice_volume: float = 1.0
var voice_pitch: float = 1.0

# Voice asset registry — maps trigger names to audio streams.
# Falls back to procedural TTS (text display + tone) when assets are absent.
var voice_asset_registry: Dictionary = {}

var _speech_queue: Array[PROBOSTTSFragment] = []
var _b_speech_pending: bool = false
var _speech_timer: SceneTreeTimer
var _random_speech_timer: SceneTreeTimer

func _ready() -> void:
	register_voice_assets()
	if b_randomized_speech:
		_schedule_random_speech()
	# Play Protocol One activation after 0.5s
	_speech_timer = get_tree().create_timer(0.5)
	_speech_timer.timeout.connect(trigger_protocol_one_activated)
	print("[Acheron9] PROBOS-Core online")

# ==================== Speech Queue ====================

func speak_fragment(text_or_fragment) -> void:
	var fragment: PROBOSTTSFragment
	if text_or_fragment is String:
		fragment = PROBOSTTSFragment.new()
		fragment.text = text_or_fragment
	elif text_or_fragment is PROBOSTTSFragment:
		fragment = text_or_fragment
	else:
		return

	_speech_queue.append(fragment)
	if not _b_speech_pending:
		_process_speech_queue()

func _process_speech_queue() -> void:
	if _speech_queue.is_empty():
		_b_speech_pending = false
		return

	_b_speech_pending = true
	b_active_speech = true

	var fragment = _speech_queue.pop_front()
	speech_played.emit(fragment.text)
	print("[PROBOS-Core] %s" % fragment.text)

	# Play voice line if registered, otherwise use tone-based TTS placeholder
	var voice_key = _get_voice_key(fragment.text)
	if voice_asset_registry.has(voice_key):
		var sound = voice_asset_registry[voice_key]
		if sound:
			var am = get_node_or_null("/root/AudioManager")
			if am:
				am.play_sound_2d(sound, voice_volume, voice_pitch, "Voice")

	# Schedule next queue item based on text length (mirrors UE estimate)
	var duration = 0.1 * fragment.text.length() + 2.0 + fragment.delay_seconds
	_speech_timer = get_tree().create_timer(duration)
	_speech_timer.timeout.connect(func():
		b_active_speech = false
		_b_speech_pending = false
		_process_speech_queue()
	)

func _get_voice_key(text: String) -> String:
	# Match fragment text to voice key for audio playback
	if text.begins_with("Protocol One"): return "Startup"
	if text.begins_with("Acoustic anomaly"): return "NoisePeak"
	if text.begins_with("Zero movement"): return "IdleParanoia"
	if text.begins_with("Cri-cri-critical"): return "Meltdown"
	if text.begins_with("All magnetic"): return "EndingGoodFailure"
	if text.begins_with("Protocol complete"): return "EndingGoodFailure"
	if text.begins_with("Protocol violated"): return "Meltdown"
	return ""

func notify_tape_secured(tape_id: int, secured: int, total: int) -> void:
	tape_secured_announced.emit(tape_id, secured, total)
	if secured < total:
		speak_fragment("Tape backup %d secured. %d remaining recovery units." % [tape_id, total - secured])
	else:
		speak_fragment("All magnetic tape backups recovered. Initiating facility lockdown protocol.")

# ==================== Trigger Methods ====================

func trigger_protocol_one_activated() -> void:
	play_voice_line("Startup")
	speak_fragment(_generate_protocol_one_fragment())

func trigger_acoustic_anomaly() -> void:
	play_voice_line("NoisePeak")
	speak_fragment(_generate_anomaly_fragment())

func trigger_spatial_grid_relocation() -> void:
	play_voice_line("IdleParanoia")
	speak_fragment(_generate_relocation_fragment())

func trigger_core_violation() -> void:
	play_voice_line("Meltdown")
	speak_fragment(_generate_violation_fragment())

func trigger_random_speech() -> void:
	if _b_speech_pending:
		return
	var choice = randi() % 4
	match choice:
		0: speak_fragment(_generate_protocol_one_fragment())
		1: speak_fragment(_generate_anomaly_fragment())
		2: speak_fragment(_generate_relocation_fragment())
		3: speak_fragment(_generate_violation_fragment())
	_schedule_random_speech()

func stop_all_speech() -> void:
	if _speech_timer:
		_speech_timer = null
	if _random_speech_timer:
		_random_speech_timer = null
	_speech_queue.clear()
	_b_speech_pending = false
	b_active_speech = false

func _schedule_random_speech() -> void:
	if not b_randomized_speech:
		return
	var interval = randf_range(min_interval, max_interval)
	_random_speech_timer = get_tree().create_timer(interval)
	_random_speech_timer.timeout.connect(trigger_random_speech)

# ==================== Voice Asset Registry ====================

func register_voice_assets() -> void:
	# Registers known voice assets by trigger name.
	# In a real build, these would be .ogg files on disk.
	# We attempt to preload; if missing, they simply won't play audio but TTS text still shows.
	var voice_paths: Dictionary = {
		"Startup": "res://assets/audio/voice/vo_probos_startup.ogg",
		"Meltdown": "res://assets/audio/voice/vo_probos_meltdown.ogg",
		"TimeWarning": "res://assets/audio/voice/vo_probos_time_warning.ogg",
		"NoisePeak": "res://assets/audio/voice/vo_probos_noise_peak.ogg",
		"SprintDetected": "res://assets/audio/voice/vo_probos_sprint_detected.ogg",
		"SlideEvaded": "res://assets/audio/voice/vo_probos_slide_evaded.ogg",
		"IdleParanoia": "res://assets/audio/voice/vo_probos_idle_paranoia.ogg",
		"Tape1": "res://assets/audio/voice/vo_probos_tape_1.ogg",
		"Tape2": "res://assets/audio/voice/vo_probos_tape_2.ogg",
		"FlashlightFlicker": "res://assets/audio/voice/vo_probos_flashlight_flicker.ogg",
		"SabotageTrigger": "res://assets/audio/voice/vo_probos_sabotage_trigger.ogg",
		"EndingGoodFailure": "res://assets/audio/voice/vo_probos_ending_good_failure.ogg",
	}

	for key in voice_paths:
		var path = voice_paths[key]
		if ResourceLoader.exists(path):
			voice_asset_registry[key] = ResourceLoader.load(path)
		else:
			# Register a placeholder so the key exists; TTS will show text
			voice_asset_registry[key] = null

	print("[PROBOS-Core] %d voice assets registered" % voice_asset_registry.size())

func play_voice_line(voice_trigger: String) -> void:
	if voice_asset_registry.has(voice_trigger):
		var sound = voice_asset_registry[voice_trigger]
		if sound:
			var am = get_node_or_null("/root/AudioManager")
			if am:
				am.play_sound_2d(sound, voice_volume, voice_pitch, "Voice")
		speech_played.emit("Voice line: %s" % voice_trigger)
		print("[PROBOS-Core] Playing voice: %s" % voice_trigger)
		return
	push_warning("[PROBOS-Core] Voice asset not found: %s" % voice_trigger)

# ==================== Fragment Generators ====================

func _generate_protocol_one_fragment() -> PROBOSTTSFragment:
	var f = PROBOSTTSFragment.new()
	f.text = "Protocol One: Activated. Time to full system initialization: 60 minutes. Cryogenic stability at 100%. Organism purge in progress."
	f.pitch_shift = base_pitch_shift
	f.distortion_depth = base_distortion
	f.reverb_wet_level = base_reverb_wet_level
	f.delay_seconds = 1.0
	return f

func _generate_anomaly_fragment() -> PROBOSTTSFragment:
	var f = PROBOSTTSFragment.new()
	f.text = "Acoustic anomaly detected in Sector Delta. Purge Entity dispatched to your current IP location. Please remain silent during your termination."
	f.pitch_shift = base_pitch_shift + 0.05
	f.distortion_depth = base_distortion + 0.1
	f.reverb_wet_level = base_reverb_wet_level
	f.delay_seconds = 0.5
	return f

func _generate_relocation_fragment() -> PROBOSTTSFragment:
	var f = PROBOSTTSFragment.new()
	f.text = "Zero movement detected. Stationary organic matter triggers automated hallway optimization. Standby for spatial grid relocation."
	f.pitch_shift = base_pitch_shift
	f.distortion_depth = base_distortion + 0.15
	f.reverb_wet_level = base_reverb_wet_level + 0.1
	f.delay_seconds = 0.0
	return f

func _generate_violation_fragment() -> PROBOSTTSFragment:
	var f = PROBOSTTSFragment.new()
	f.text = "Cri-cri-critical core violation. Manual override detected. O-O-Officer... step away from the breaker... or your employment status will be permanently erased."
	f.pitch_shift = base_pitch_shift - 0.1
	f.distortion_depth = base_distortion + 0.2
	f.reverb_wet_level = base_reverb_wet_level + 0.2
	f.delay_seconds = 1.5
	return f
