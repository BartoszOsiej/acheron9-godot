# ACHERON-9: INCIDENT - WallRotationParanoiaSystem (Godot port of AWallRotationParanoiaSystem)
# Dot-product paranoia: hallway swaps to solid block when player's back is >90 degrees from wall forward.
class_name WallRotationParanoiaSystem
extends Node3D

# Config
@export var b_start_as_hallway: bool = true
@export var swap_angle_threshold: float = 90.0
@export var swap_delay: float = 0.5
@export var restore_delay: float = 3.0

# State
var b_is_swapped: bool = false
var b_is_animating: bool = false
var _b_swap_pending: bool = false

@onready var visible_wall: MeshInstance3D = $VisibleWall
@onready var swap_wall: MeshInstance3D = $SwapWall

var _tracked_player: Node3D
var _swap_timer: SceneTreeTimer
var _restore_timer: SceneTreeTimer

func _ready() -> void:
	initialize_paranoia()

func initialize_paranoia() -> void:
	_find_player()

func _find_player() -> void:
	if get_tree():
		_tracked_player = get_tree().get_first_node_in_group("player") as Node3D
		if _tracked_player:
			print("[Acheron9] Paranoia system locked onto player: %s" % _tracked_player.name)
		else:
			print("[Acheron9] Paranoia system: player not found, retrying next frame")

func check_player_orientation() -> void:
	if not _tracked_player:
		_find_player()
		if not _tracked_player:
			return

	if b_is_animating:
		return

	var dot = _get_dot_product_to_player()
	var angle_deg = rad2deg(acos(clamp(dot, -1.0, 1.0)))

	# If wall forward is >90 deg from player forward, swap hallway to solid block
	if angle_deg > swap_angle_threshold and not b_is_swapped and not _b_swap_pending:
		_b_swap_pending = true
		_swap_timer = get_tree().create_timer(swap_delay)
		_swap_timer.timeout.connect(_on_swap_timer_elapsed)
	elif angle_deg <= swap_angle_threshold and b_is_swapped:
		_restore_timer = get_tree().create_timer(restore_delay)
		_restore_timer.timeout.connect(_on_restore_timer_elapsed)

func _on_swap_timer_elapsed() -> void:
	_b_swap_pending = false
	_execute_hallucination_swap()

func _on_restore_timer_elapsed() -> void:
	_restore_original_layout()

func _get_dot_product_to_player() -> float:
	if not _tracked_player:
		return 1.0
	var player_forward = -_tracked_player.global_transform.basis.z
	var wall_forward = -global_transform.basis.z
	return player_forward.dot(wall_forward)

func execute_hallucination_swap() -> void:
	if b_is_animating or b_is_swapped:
		return
	b_is_animating = true
	b_is_swapped = true

	# Hallway becomes solid concrete block behind player
	if visible_wall:
		visible_wall.visible = false
	if swap_wall:
		swap_wall.visible = true
		# Rotate 180 on Y
		var target_rotation = swap_wall.rotation
		target_rotation.y += PI
		swap_wall.rotation = target_rotation

	print("[Acheron9] WAL-ROT PARANOIA: Hallway swapped to solid concrete block")
	b_is_animating = false

func restore_original_layout() -> void:
	if b_is_animating or not b_is_swapped:
		return
	b_is_animating = true
	b_is_swapped = false

	if visible_wall:
		visible_wall.visible = true
	if swap_wall:
		swap_wall.visible = false
		var target_rotation = swap_wall.rotation
		target_rotation.y -= PI
		swap_wall.rotation = target_rotation

	print("[Acheron9] WAL-ROT PARANOIA: Hallway layout restored")
	b_is_animating = false

func async_move_mesh(mesh_comp: MeshInstance3D, new_location: Vector3, new_rotation: Vector3) -> void:
	if not mesh_comp:
		return
	mesh_comp.global_transform = Transform3D(Basis.from_euler(new_rotation), new_location)
