# ACHERON-9: INCIDENT - Player Character (Godot port of AAcheron9Character + PlayerController input)
# CharacterBody3D with flashlight, inventory, interaction, fear sanity, and mic input.
# Movement mirrors UE CharacterMovementComponent: walk, sprint, jump, crouch/slide.
# Mouse look handled by PlayerController autoload.
class_name Player
extends CharacterBody3D

# Runtime singleton accessors — untyped Variant to avoid class-type resolution
var _settings_mgr = null
var _player_ctrl = null

# Movement config (mirrors UE)
@export var walk_speed: float = 200.0
@export var sprint_speed: float = 600.0
@export var jump_velocity: float = 450.0
@export var gravity: float = 980.0

var b_is_sprinting: bool = false
var b_is_crouching: bool = false

# Component references
@onready var camera: Camera3D = $Camera3D
@onready var flashlight_light: SpotLight3D = $Camera3D/FlashlightLight
@onready var flashlight_component: FlashlightComponent = $FlashlightComponent
@onready var inventory_component: InventoryComponent = $InventoryComponent
@onready var interaction_component: InteractionComponent = $InteractionComponent
@onready var fear_component: FearSanityComponent = $FearSanityComponent
@onready var mic_input: MicrophoneInputManager = $MicrophoneInputManager

func _ready() -> void:
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	flashlight_light.visible = false
	flashlight_light.light_energy = 0.0
	# Resolve autoload singletons
	_settings_mgr = get_node_or_null("/root/SettingsManager")
	_player_ctrl = get_node_or_null("/root/PlayerController")

func _initialize_systems() -> void:
	if _settings_mgr:
		var adjusted_speed = walk_speed * _settings_mgr.gameplay_settings.mouse_sensitivity
		walk_speed = adjusted_speed

	if mic_input:
		mic_input.start_listening()

	if interaction_component:
		interaction_component.start_interaction_loop()

	if mic_input and fear_component:
		mic_input.noise_detected.connect(fear_component.on_mic_peak_detected)

	# Assign player to PlayerController autoload
	if _player_ctrl:
		_player_ctrl.player = self

	print("[Acheron9] Player systems initialized")

func _physics_process(delta: float) -> void:
	_handle_movement(delta)

func _handle_movement(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

	# Determine target speed
	var target_speed = walk_speed
	if Input.is_action_pressed("sprint") and not b_is_crouching:
		target_speed = sprint_speed
		b_is_sprinting = true
	elif not b_is_crouching:
		b_is_sprinting = false

	# Get input direction
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * target_speed
		velocity.z = direction.z * target_speed
	else:
		velocity.x = move_toward(velocity.x, 0, target_speed)
		velocity.z = move_toward(velocity.z, 0, target_speed)

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Crouch/slide (Ctrl)
	b_is_crouching = Input.is_action_pressed("slide")

	move_and_slide()

func toggle_crouch() -> void:
	b_is_crouching = not b_is_crouching

func interact() -> void:
	if interaction_component:
		interaction_component.perform_interaction()
	if flashlight_component:
		flashlight_component.toggle_flashlight()

func save_game_data() -> Dictionary:
	var save_data: Dictionary = {
		"player_location": global_position,
		"player_rotation": rotation,
	}
	if flashlight_component:
		save_data["flashlight_battery"] = flashlight_component.current_battery
		save_data["max_flashlight_battery"] = flashlight_component.max_battery
	if inventory_component:
		save_data["magnetic_tapes_collected"] = inventory_component.magnetic_tapes_collected
	return save_data

func load_game_data(data: Dictionary) -> void:
	if data.has("player_location"):
		global_position = data["player_location"]
		rotation = data["player_rotation"]
	if flashlight_component:
		flashlight_component.current_battery = data.get("flashlight_battery", flashlight_component.max_battery)
		flashlight_component.max_battery = data.get("max_flashlight_battery", flashlight_component.max_battery)
	if inventory_component:
		inventory_component.magnetic_tapes_collected = data.get("magnetic_tapes_collected", 0)
