# ACHERON-9: INCIDENT - GameManager (replaces AAcheron9GameMode + AAcheron9GameState)
# Manages game lifecycle, 60-minute purge timer, ending triggers, and system initialization.
class_name GameManager
extends Node

# Enums mirroring UE counterparts
enum EndingType { NONE, GOOD_ENDING, BAD_ENDING, TIME_EXPIRED }

signal timer_updated(time_remaining: float)
signal game_state_changed(game_over: bool)
signal ending_sequence_started(ending_type: EndingType)
signal game_started()
signal game_ended()

# === Config ===
@export var game_duration_minutes: float = 60.0
@export var b_use_real_time: bool = false  # False = game-time timer, True = wall-clock

# === State ===
var b_game_started: bool = false
var b_proactive_destruction_active: bool = false
var current_ending: EndingType = EndingType.NONE
var b_game_over: bool = false
var time_remaining: float = 3600.0
var total_time_seconds: float = 3600.0

# System references (mirrors GameMode's subsystem pointers)
var asset_setup: Node = null
var level_generator: Node = null
var quest_manager_ref: Node = null
var destruction_system: Node = null
var ending_manager: Node = null
var settings_manager: Node = null
var speech_manager: Node = null
var audio_manager: Node = null
var player_reference: Node = null

var _game_timer: Timer
var _delta_accumulator: float = 0.0

func _ready() -> void:
	total_time_seconds = game_duration_minutes * 60.0
	time_remaining = total_time_seconds
	_init_game_timer()
	# Resolve autoload singletons at runtime via singleton lookup
	call_deferred("_resolve_singletons")
	print("[Acheron9] GameManager online - Protocol One initializing")

func _resolve_singletons() -> void:
	asset_setup = get_node_or_null("/root/AssetSetup")
	settings_manager = get_node_or_null("/root/SettingsManager")
	speech_manager = get_node_or_null("/root/SpeechManager")
	quest_manager_ref = get_node_or_null("/root/QuestManager")
	audio_manager = get_node_or_null("/root/AudioManager")
	ending_manager = get_node_or_null("/root/EndingManager")

func _init_game_timer() -> void:
	_game_timer = Timer.new()
	_game_timer.wait_time = 1.0
	_game_timer.one_shot = false
	_game_timer.autostart = false
	add_child(_game_timer)
	_game_timer.timeout.connect(_on_game_tick)

func start_game() -> void:
	if b_game_started:
		return
	b_game_started = true
	time_remaining = total_time_seconds
	current_ending = EndingType.NONE
	b_game_over = false
	_game_timer.start()
	game_started.emit()
	print("[Acheron9] Game started - purge loop timer activated (60 min)")

func end_game() -> void:
	b_game_started = false
	_game_timer.stop()
	game_ended.emit()
	print("[Acheron9] Game ended")

func stop_timer() -> void:
	_game_timer.stop()

func set_ending(ending: EndingType) -> void:
	if b_game_over:
		return
	current_ending = ending
	b_game_over = true
	stop_timer()
	game_state_changed.emit(true)
	ending_sequence_started.emit(ending)

	# Notify speech manager
	if speech_manager:
		match ending:
			EndingType.TIME_EXPIRED:
				speech_manager.trigger_core_violation()
			EndingType.GOOD_ENDING:
				speech_manager.speak_fragment("Protocol complete. Containment achieved. Facility entering safe state.")
			EndingType.BAD_ENDING:
				speech_manager.speak_fragment("Protocol violated. Termination sequence initiated.")

# ==================== Timer ====================

func _on_game_tick() -> void:
	if b_game_over or current_ending != EndingType.NONE:
		return
	time_remaining -= 1.0
	if time_remaining <= 0.0:
		time_remaining = 0.0
		set_ending(EndingType.TIME_EXPIRED)
	else:
		timer_updated.emit(time_remaining)

func get_time_formatted() -> String:
	var minutes := int(time_remaining / 60.0)
	var seconds := int(time_remaining) % 60
	return "%02d:%02d" % [minutes, seconds]

func is_game_over() -> bool:
	return b_game_over

# ==================== System Initialization ====================
# Mirrors AAcheron9GameMode::InitializeAcheron9Systems

func initialize_systems() -> void:
	print("[Acheron9] Initializing PROBOS-Core systems...")

	# Asset Setup — already resolved in _resolve_singletons
	if not asset_setup:
		asset_setup = get_node_or_null("/root/AssetSetup")
	# Settings Manager — already resolved in _resolve_singletons
	if not settings_manager:
		settings_manager = get_node_or_null("/root/SettingsManager")
	# Speech Manager (PROBOS) — already resolved
	if not speech_manager:
		speech_manager = get_node_or_null("/root/SpeechManager")
	# Quest Manager
	if not quest_manager_ref:
		quest_manager_ref = get_node_or_null("/root/QuestManager")
	# Audio Manager — already resolved
	if not audio_manager:
		audio_manager = get_node_or_null("/root/AudioManager")
	# Ending Manager
	if not ending_manager:
		ending_manager = get_node_or_null("/root/EndingManager")
	# Destruction System
	if not destruction_system:
		destruction_system = get_tree().root.find_child("DestructionSystem", true, false)

	# Wire cross-component callbacks
	if quest_manager_ref and ending_manager:
		if quest_manager_ref.has_signal("tapes_all_secured"):
			if not quest_manager_ref.is_connected("tapes_all_secured", Callable(ending_manager, "trigger_good_ending")):
				quest_manager_ref.connect("tapes_all_secured", Callable(ending_manager, "trigger_good_ending"))

	if ending_manager and destruction_system:
		if ending_manager.has_signal("ending_sequence_started"):
			if not ending_manager.is_connected("ending_sequence_started", Callable(destruction_system, "stop_all_physics")):
				ending_manager.connect("ending_sequence_started", Callable(destruction_system, "stop_all_physics"))

	# Initialize ray tracing (Godot has no DXR; emit shader quality instead)
	_initialize_rendering()

	# Spawn level generator (deferred so navmesh / scene tree is ready)
	call_deferred("_spawn_level_generator")

func _spawn_level_generator() -> void:
	if not level_generator:
		level_generator = preload("res://scripts/levelgen/level_generator.gd").new()
		level_generator.name = "Acheron9_LevelGenerator"
		get_tree().current_scene.add_child(level_generator)
		print("[Acheron9] Level generator online - 32x32x4 grid, seed=97312")

		# When navmesh/level is ready, tell quest manager to spawn tapes
		if level_generator.has_signal("nav_mesh_ready"):
			level_generator.connect("nav_mesh_ready", func():
				if quest_manager_ref and quest_manager_ref.has_method("spawn_tape_backups"):
					quest_manager_ref.spawn_tape_backups()
					print("[Acheron9] NavMesh ready -> spawning quest tapes")
			)

func _initialize_rendering() -> void:
	# Godot uses Vulkan; ray tracing is handled automatically.
	# We simulate the UE DXR init by ensuring SDFGI / reflections are enabled.
	var env = get_tree().root.find_node("WorldEnvironment", true, false) as WorldEnvironment
	if env and env.environment:
		env.environment.sdfgi_enabled = true
		env.environment.glow_enabled = true
		env.environment.ss_rfl_enabled = true
	print("[Acheron9] Rendering pipeline locked: SDFGI + reflections + glow")

# ==================== Sabotage Events ====================

func trigger_infrastructure_sabotage() -> void:
	b_proactive_destruction_active = true
	if destruction_system and destruction_system.has_method("trigger_hallway_collapse"):
		var rack_locations: Array[Vector3] = []
		for i in 3:
			rack_locations.append(Vector3(0, i * 400.0, 300.0))
		destruction_system.trigger_hallway_collapse(rack_locations)
	print("[Acheron9] Sabotage event triggered")

func drop_rack_cabinets() -> void:
	if destruction_system and destruction_system.has_method("trigger_server_rack_drop"):
		destruction_system.trigger_server_rack_drop(Vector3.ZERO, Vector3.ZERO)
	print("[Acheron9] Rack cabinets dropped")
