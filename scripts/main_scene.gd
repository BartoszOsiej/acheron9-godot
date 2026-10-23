# ACHERON-9: INCIDENT - Main Scene Bootstrap (Godot port of GameMode::BeginPlay + InitializeAcheron9Systems)
# Builds the scene tree at runtime: player, level generator, destruction system,
# AI, triggers, HUD, and CRT overlay. Wires all cross-component delegates.
class_name MainScene
extends Node3D

# Runtime singleton accessors (avoid class-name resolution conflicts in Godot 4.7.2)
@onready var _gm = get_node_or_null("/root/GameManager")
@onready var _qm = get_node_or_null("/root/QuestManager")
@onready var _sm = get_node_or_null("/root/SpeechManager")
@onready var _em = get_node_or_null("/root/EndingManager")
@onready var _pc = get_node_or_null("/root/PlayerController")
@onready var _am = get_node_or_null("/root/AudioManager")

@onready var player_scene: PackedScene = preload("res://scenes/player.tscn")
@onready var hud_scene: PackedScene = preload("res://scenes/hud.tscn")
@onready var ai_scene: PackedScene = preload("res://scenes/humanoid_ai.tscn")

var player: Player
var level_generator: LevelGenerator
var destruction_system: EnvironmentalDestructionSystem
var end_trigger: EndTrigger
var hud: CanvasLayer
var crt_overlay: ColorRect

func _ready() -> void:
	_ensure_audio_buses()
	_initialize_world()
	_spawn_level_generator()
	_spawn_player()
	_spawn_destruction_system()
	_spawn_end_trigger()
	_spawn_hud_and_crt()
	_spawn_enemies()
	_wire_systems()

	# Defer game start so all nodes are registered first
	call_deferred("_start_game")

	# Auto-quit after 3 seconds in headless mode for testing
	if OS.has_feature("headless"):
		var quit_timer = get_tree().create_timer(3.0)
		quit_timer.timeout.connect(func():
			print("[Acheron9] Headless test complete - quitting")
			get_tree().quit()
		)

func _ensure_audio_buses() -> void:
	# Create custom audio buses if they don't exist
	var voice_bus_idx = AudioServer.get_bus_index("Voice")
	if voice_bus_idx == -1:
		voice_bus_idx = AudioServer.get_bus_count()
		AudioServer.add_bus()
		AudioServer.set_bus_name(voice_bus_idx, "Voice")

	var sfx_bus_idx = AudioServer.get_bus_index("SFX")
	if sfx_bus_idx == -1:
		sfx_bus_idx = AudioServer.get_bus_count()
		AudioServer.add_bus()
		AudioServer.set_bus_name(sfx_bus_idx, "SFX")

	var music_bus_idx = AudioServer.get_bus_index("Music")
	if music_bus_idx == -1:
		music_bus_idx = AudioServer.get_bus_count()
		AudioServer.add_bus()
		AudioServer.set_bus_name(music_bus_idx, "Music")

func _initialize_world() -> void:
	# WorldEnvironment with fog, SDFGI, bloom
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.02, 0.02, 0.04, 1.0)
	env.environment.fog_enabled = true
	env.environment.fog_density = 0.002
	env.environment.fog_light_color = Color(0.05, 0.05, 0.08, 1.0)
	env.environment.sdfgi_enabled = true
	env.environment.glow_enabled = true
	env.environment.glow_intensity = 0.4
	env.environment.set("exposure_enabled", true)
	env.environment.set("exposure_min", 0.5)
	env.environment.set("exposure_max", 1.5)
	env.environment.tonemap_mode = 0  # TONE_MAPPER_LINEAR (integer to avoid enum resolution issues)
	add_child(env)

	# Directional light (sun)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.shadow_bias = 0.1
	add_child(sun)

	# Ambient light
	var ambient = WorldEnvironment.new()
	ambient.environment = Environment.new()
	ambient.environment.ambient_light_color = Color(0.1, 0.1, 0.15)
	ambient.environment.ambient_light_energy = 0.3
	add_child(ambient)

	# Navigation region for AI pathfinding
	var nav_region = NavigationRegion3D.new()
	nav_region.name = "NavigationRegion"
	var nav_mesh = NavigationMesh.new()
	nav_region.navigation_mesh = nav_mesh
	add_child(nav_region)

func _spawn_level_generator() -> void:
	level_generator = LevelGenerator.new()
	level_generator.name = "Acheron9_LevelGenerator"

	# Connect signals BEFORE adding to tree so _ready() emissions are caught
	level_generator.connect("level_generated", func():
		# Position player at spawn location
		if player:
			player.global_position = level_generator.get_player_spawn_location()
		# Move end trigger to reactor core location
		if end_trigger:
			end_trigger.global_position = level_generator.get_reactor_core_location()
		print("[Acheron9] Level generated: player at %s, reactor at %s" %
			[level_generator.get_player_spawn_location(), level_generator.get_reactor_core_location()])
	)
	level_generator.connect("nav_mesh_ready", func():
		if _qm and _qm.has_method("spawn_tape_backups"):
			_qm.spawn_tape_backups()
			print("[Acheron9] NavMesh ready -> spawning quest tapes")
	)

	add_child(level_generator)

func _spawn_player() -> void:
	player = player_scene.instantiate() as Player
	player.name = "Player"
	add_child(player)
	player.add_to_group("player")

	if _pc:
		_pc.player = player
		_pc.camera = player.get_node("Camera3D")

func _spawn_destruction_system() -> void:
	destruction_system = EnvironmentalDestructionSystem.new()
	destruction_system.name = "Acheron9_DestructionSystem"
	add_child(destruction_system)

func _spawn_end_trigger() -> void:
	end_trigger = EndTrigger.new()
	end_trigger.name = "EndingTrigger"
	end_trigger.ending_type = EndTrigger.EndingType.GOOD_ENDING
	add_child(end_trigger)

func _spawn_hud_and_crt() -> void:
	if hud_scene:
		hud = hud_scene.instantiate() as CanvasLayer
		hud.name = "HUD"
		add_child(hud)

	# CRT overlay (post-process scanlines)
	crt_overlay = ColorRect.new()
	crt_overlay.name = "CRTOverlay"
	crt_overlay.anchor_right = 1.0
	crt_overlay.anchor_bottom = 1.0
	crt_overlay.position = Vector2.ZERO
	crt_overlay.size = get_viewport().size
	crt_overlay.z_index = 100
	crt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var crt_mat = ShaderMaterial.new()
	crt_mat.shader = preload("res://shaders/crt_shader.gdshader")
	crt_mat.set_shader_parameter("scanline_intensity", 0.8)
	crt_mat.set_shader_parameter("scanline_frequency", 48.0)
	crt_mat.set_shader_parameter("curvature", 0.05)
	crt_mat.set_shader_parameter("chromatic_aberration", 0.02)
	crt_mat.set_shader_parameter("flicker_intensity", 0.1)
	crt_mat.set_shader_parameter("scanline_color", Color(0.8, 0.1, 0.1, 1.0))
	crt_overlay.material = crt_mat

	var hud_layer = CanvasLayer.new()
	hud_layer.layer = 100
	hud_layer.name = "HUDLayer"
	hud_layer.add_child(crt_overlay)
	add_child(hud_layer)

	# Screen fade rect
	var fade = ColorRect.new()
	fade.name = "ScreenFade"
	fade.anchor_right = 1.0
	fade.anchor_bottom = 1.0
	fade.position = Vector2.ZERO
	fade.size = get_viewport().size
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.z_index = 200
	fade.color = Color(0, 0, 0, 0)
	fade.hide()
	hud_layer.add_child(fade)

func _spawn_enemies() -> void:
	if not ai_scene:
		return
	for i in 3:
		var ai = ai_scene.instantiate() as HumanoidAI
		ai.name = "PurgeEntity_%d" % (i + 1)
		# Place enemies scattered around the level
		var angle = i * (TAU / 3.0)
		var spawn_pos = Vector3(cos(angle) * 800, 0, sin(angle) * 800) + player.position
		ai.position = spawn_pos
		add_child(ai)

func _wire_systems() -> void:
	# GameManager system references
	if _gm:
		_gm.player_reference = player
		_gm.level_generator = level_generator
		_gm.quest_manager_ref = _qm
		_gm.destruction_system = destruction_system
		_gm.ending_manager = _em
		_gm.speech_manager = _sm
		_gm.audio_manager = _am

	# Quest -> Ending wiring (mirrors UE GameMode cross-component wiring)
	if _qm and _qm.has_signal("tapes_all_secured"):
		if not _qm.is_connected("tapes_all_secured", Callable(_em, "trigger_good_ending")):
			_qm.connect("tapes_all_secured", Callable(_em, "trigger_good_ending"))

	# Quest -> Speech wiring
	if _qm and _qm.has_signal("tape_secured"):
		_qm.connect("tape_secured", func(tape_id: int):
			if _sm:
				_sm.notify_tape_secured(tape_id, _qm.tapes_secured, _qm.total_tapes_to_recover)
		)

	# GameManager timer -> HUD
	if _gm and _gm.has_signal("timer_updated"):
		if not _gm.is_connected("timer_updated", Callable(hud, "_on_timer_updated")):
			_gm.connect("timer_updated", Callable(hud, "_on_timer_updated"))
	if _gm and _gm.has_signal("game_state_changed"):
		if not _gm.is_connected("game_state_changed", Callable(hud, "_on_game_state_changed")):
			_gm.connect("game_state_changed", Callable(hud, "_on_game_state_changed"))

	# Speech -> HUD
	if _sm and _sm.has_signal("speech_played") and hud and hud.has_method("_on_speech_played"):
		if not _sm.is_connected("speech_played", Callable(hud, "_on_speech_played")):
			_sm.connect("speech_played", Callable(hud, "_on_speech_played"))

	# Connect player mic to AI enemies
	if player and player.has_method("get") and player.get("mic_input"):
		for child in get_children():
			if child is HumanoidAI:
				if not player.get("mic_input").is_connected("noise_detected", Callable(child, "_on_noise_from_mic")):
					player.get("mic_input").noise_detected.connect(child._on_noise_from_mic)

	# EndTrigger -> GameManager
	if end_trigger and end_trigger.has_signal("ending_triggered"):
		end_trigger.connect("ending_triggered", func():
			if _gm:
				_gm.set_ending(GameManager.EndingType.GOOD_ENDING)
		)

	# CRT toggle
	if _pc:
		_pc.connect("toggle_crt_scanlines", Callable(self, "_on_toggle_crt"))
		_pc.connect("interaction_triggered", Callable(self, "_on_interaction"))

	print("[Acheron9] All systems wired")

func _start_game() -> void:
	# Start the 60-minute timer
	if _gm:
		_gm.start_game()

	# Play intro speech
	if _sm and _sm.has_method("trigger_protocol_one_activated"):
		_sm.trigger_protocol_one_activated()

	# Initialize player systems (deferred so physics is ready)
	if player:
		player.call_deferred("_initialize_systems")

	# Auto-quit after 3 seconds for headless testing
	var args = OS.get_cmdline_args()
	if "--quit" in args or "--headless" in args or OS.has_feature("headless"):
		print("[DEBUG] Headless mode detected, scheduling auto-quit")
		get_tree().create_timer(3.0).timeout.connect(func():
			print("[Acheron9] Headless test complete - exiting")
			get_tree().quit()
		)

func _on_toggle_crt() -> void:
	if crt_overlay and crt_overlay.material:
		var enabled = crt_overlay.material.get_shader_parameter("enabled") as bool
		crt_overlay.material.set_shader_parameter("enabled", not enabled)
		print("[Acheron9] CRT scanlines toggled: %s" % str(not enabled))

func _on_interaction() -> void:
	if player:
		player.interact()

func _process(delta: float) -> void:
	# Update CRT flicker (simulates CRT refresh instability)
	if crt_overlay and crt_overlay.material:
		var flicker = 0.1 + 0.02 * sin(Time.get_ticks_msec() / 100.0)
		crt_overlay.material.set_shader_parameter("flicker_intensity", flicker)
