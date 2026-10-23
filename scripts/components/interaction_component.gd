# ACHERON-9: INCIDENT - InteractionComponent (Godot port of UAcheron9InteractionComponent)
# Tickless raycast-based interaction: updates target every 0.1s, performs interact on request.
class_name InteractionComponent
extends Node

# Runtime singleton accessor — untyped to avoid class-type resolution
var _quest_mgr = null

signal target_changed(new_target: Node3D)
signal interacted(target: Node3D)

# Config
@export var trace_distance: float = 200.0
@export var interaction_interval: float = 0.1

# State
var current_target: Node3D

var _interaction_timer: Timer

func _ready() -> void:
	_interaction_timer = Timer.new()
	_interaction_timer.wait_time = interaction_interval
	_interaction_timer.one_shot = false
	_interaction_timer.autostart = true
	add_child(_interaction_timer)
	_interaction_timer.timeout.connect(_on_interaction_timer_elapsed)

	# Resolve autoload singleton
	_quest_mgr = get_node_or_null("/root/QuestManager")

func start_interaction_loop() -> void:
	if _interaction_timer:
		_interaction_timer.start()

func stop_interaction_loop() -> void:
	if _interaction_timer:
		_interaction_timer.stop()
	current_target = null

func _on_interaction_timer_elapsed() -> void:
	_update_current_target()

func _update_current_target() -> void:
	var player = get_tree().get_first_node_in_group("player") if get_tree() else null
	if not player:
		return
	var cam = player.find_child("Camera3D", true, false) as Camera3D
	if not cam:
		return

	var start = cam.global_position
	var forward = -cam.global_transform.basis.z
	var end = start + forward * trace_distance

	var space_state = get_viewport().world_3d.direct_space_state
	var query = PhysicsRayQueryParameters3D.create(start, end)
	query.collide_with_areas = true
	var result = space_state.intersect_ray(query)

	if result and result.collider:
		var hit_actor = result.collider
		if hit_actor != current_target:
			current_target = hit_actor
			target_changed.emit(current_target)
	else:
		if current_target:
			current_target = null
			target_changed.emit(null)

func perform_interaction() -> void:
	if not current_target:
		return

	# Check for tape pickup (mirrors UE quest interaction)
	if _quest_mgr:
		var target_name = current_target.name
		if "TapeBackup" in target_name or "MagneticTape" in target_name:
			# Find tape in QuestManager and secure it
			for tape in _quest_mgr.tape_backups:
				if tape.spawned_actor == current_target and tape.state != QuestManager.TapeState.SECURED:
					_quest_mgr.secure_tape(tape.tape_id)

					# Update inventory
					var player = get_tree().get_first_node_in_group("player") if get_tree() else null
					if player:
						var inv = player.get_node_or_null("InventoryComponent") as InventoryComponent
						if inv:
							inv.add_magnetic_tape()
					interacted.emit(current_target)
					return

	# Generic interaction signal
	interacted.emit(current_target)
