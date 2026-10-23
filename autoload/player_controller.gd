# ACHERON-9: INCIDENT - PlayerController (Godot port of AAcheron9PlayerController)
# Handles input mapping (mirrors UE EnhancedInput), camera look, and CRT toggle.
class_name PlayerController
extends Node

signal toggle_crt_scanlines
signal interaction_triggered

var player: CharacterBody3D
var camera: Camera3D
var hud_root: CanvasLayer

var b_crt_scanlines_enabled: bool = true
var mouse_sensitivity: float = 0.07

# Camera limits
const MAX_PITCH := 80.0
const MIN_PITCH := -80.0

func _ready() -> void:
	# Capture mouse for FPS look
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Register input callbacks
	set_process_input(true)
	set_process(true)
	print("[Acheron9] PlayerController online")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if camera:
			var look_axis := Vector2.ZERO
			if event is InputEventMouseMotion:
				look_axis = event.relative
			# Apply look
			camera.rotate_y(-look_axis.x * mouse_sensitivity)
			# Clamp pitch by rotating the yaw (camera.y) — we do it on the CharacterBody
			var current_rotation = camera.rotation_degrees
			current_rotation.x = clamp(current_rotation.x - look_axis.y * mouse_sensitivity * 100.0, -MAX_PITCH, MAX_PITCH)
			camera.rotation_degrees = current_rotation

func _process(delta: float) -> void:
	# Handle discrete input actions
	if Input.is_action_just_pressed("interact"):
		interaction_triggered.emit()

	if Input.is_action_just_pressed("toggle_crt"):
		b_crt_scanlines_enabled = !b_crt_scanlines_enabled
		toggle_crt_scanlines.emit()

	# Mouse look handled in _input for smoothness
	_handle_mouse_look()

func _handle_mouse_look() -> void:
	# Mouse motion handled above in _input
	pass

# ==================== Input Helpers ====================

func get_move_input() -> Vector2:
	return Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)

func get_jumped() -> bool:
	return Input.is_action_just_pressed("jump")

func get_slide_pressed() -> bool:
	return Input.is_action_pressed("slide")

func set_mouse_mode(mode: int) -> void:
	Input.set_mouse_mode(mode)
