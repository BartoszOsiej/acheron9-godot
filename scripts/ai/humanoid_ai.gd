# ACHERON-9: INCIDENT - HumanoidAI (Godot port of AAcheron9HumanoidAI + AAcheron9HumanoidController)
# PROBOS Core Purge Entity — mic-driven pursuit with idle/investigate/chase states.
class_name HumanoidAI
extends CharacterBody3D

# Runtime singleton accessor — untyped to avoid class-type resolution
var _audio_mgr = null

# Config
@export var walk_speed: float = 120.0
@export var sprint_speed: float = 450.0
@export var sound_decay_rate: float = 0.3
@export var sprint_duration: float = 6.0
@export var chase_distance: float = 2000.0

# State
var b_is_sprinting: bool = false
var b_is_alert: bool = false
var last_known_sound_location: Vector3 = Vector3.ZERO

var _mic_manager: MicrophoneInputManager
var _sprint_reset_timer: SceneTreeTimer
var _sound_decay_timer: SceneTreeTimer

func _ready() -> void:
	# Find the player's microphone input manager and bind to noise events
	# Resolve autoload singleton
	_audio_mgr = get_node_or_null("/root/AudioManager")
	var player = get_tree().get_first_node_in_group("player") if get_tree() else null
	if player:
		_mic_manager = player.get_node_or_null("MicrophoneInputManager") as MicrophoneInputManager
		if _mic_manager:
			_mic_manager.noise_detected.connect(_on_noise_from_mic)

	_set_alert_state(false)
	print("[Acheron9] HumanoidAI spawned - Purge Entity online")

func _on_noise_from_mic(loudness_db: float) -> void:
	var player = get_tree().get_first_node_in_group("player") if get_tree() else null
	if player:
		_on_noise_detected(loudness_db, player.global_position)

func _on_noise_detected(loudness: float, sound_location: Vector3) -> void:
	if b_is_alert:
		return
	print("[Acheron9] Humanoid detected noise (%.1f dB) at position" % loudness)
	_set_alert_state(true)
	_sprint_to_sound(sound_location)

func _sprint_to_sound(sound_location: Vector3) -> void:
	last_known_sound_location = sound_location
	_set_alert_state(true)
	_update_movement_speed(sprint_speed)

	var my_location = global_position
	var distance = my_location.distance_to(sound_location)
	if distance > chase_distance:
		_update_movement_speed(walk_speed)

	# Navigate using Godot's NavigationAgent3D
	var nav_agent = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if nav_agent:
		nav_agent.target_location = sound_location
		nav_agent.set("path_requested_distance", 100.0)
	else:
		# Fallback: simple move toward sound
		var direction = (sound_location - my_location).normalized()
		velocity = direction * sprint_speed

	# Schedule sprint reset timer
	_sprint_reset_timer = get_tree().create_timer(sprint_duration)
	_sprint_reset_timer.timeout.connect(_on_sprint_reset_timer_elapsed)

	# Schedule sound decay timer (8s)
	_sound_decay_timer = get_tree().create_timer(8.0)
	_sound_decay_timer.timeout.connect(_on_sound_decay_timer_elapsed)

func investigate_last_sound() -> void:
	if not last_known_sound_location.is_zero_approx():
		var nav_agent = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
		if nav_agent:
			nav_agent.set_target_location(last_known_sound_location)

func _enter_idle_state() -> void:
	_set_alert_state(false)
	_update_movement_speed(walk_speed)

	# Clear timers
	if _sprint_reset_timer:
		_sprint_reset_timer = null
	if _sound_decay_timer:
		_sound_decay_timer = null

func _on_sprint_reset_timer_elapsed() -> void:
	_update_movement_speed(walk_speed)
	b_is_sprinting = false

	# Continue investigating or go idle
	var nav_agent = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if nav_agent and not last_known_sound_location.is_zero_approx():
		nav_agent.set_target_location(last_known_sound_location)

func _on_sound_decay_timer_elapsed() -> void:
	if not b_is_alert:
		return
	var player = get_tree().get_first_node_in_group("player") if get_tree() else null
	if not player:
		_enter_idle_state()
		return

	var distance = global_position.distance_to(player.global_position)
	if distance > chase_distance:
		_enter_idle_state()

func _set_alert_state(b_new_alert: bool) -> void:
	if b_is_alert == b_new_alert:
		return
	b_is_alert = b_new_alert
	if b_is_alert:
		print("[Acheron9] Humanoid ALERT - sprinting toward player")
		# Play alert sound
		if _audio_mgr:
			var siren = _audio_mgr.get_siren_sound()
			if siren:
				_audio_mgr.play_sound_at_location(siren, global_position, 1.0, 1.0, "SFX")
	else:
		print("[Acheron9] Humanoid returning to idle")

func _update_movement_speed(new_speed: float) -> void:
	var player = get_tree().get_first_node_in_group("player") if get_tree() else null
	if not player:
		return
	# Move toward player if alert, otherwise idle
	var target_pos: Vector3
	if b_is_alert and not last_known_sound_location.is_zero_approx():
		target_pos = last_known_sound_location
	elif b_is_alert and player:
		target_pos = player.global_position
	else:
		return

	var direction = (target_pos - global_position).normalized()
	velocity = direction * new_speed
	b_is_sprinting = new_speed >= sprint_speed

	if b_is_alert and player is Node3D:
		# Notify fear system of proximity
		var fear_comp = player.get_node_or_null("FearSanityComponent") as FearSanityComponent
		if fear_comp:
			fear_comp.check_proximity(global_position.distance_to(player.global_position))

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	move_and_slide()
