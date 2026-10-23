# ACHERON-9: INCIDENT - QuestManager (Godot port of AAcheron9QuestManager)
# Mission quest logic for Magnetic Tape Backup recovery.
class_name QuestManager
extends Node

signal tape_secured(tape_id: int)
signal quest_completed(b_success: bool)
signal tapes_all_secured
signal inventory_changed

# Enums
enum TapeState { HIDDEN, SPAWNED, SECURED }

# Config
@export var total_tapes_to_recover: int = 3
@export var grid_width: int = 16
@export var grid_height: int = 16
@export var grid_spacing: float = 400.0

# State
var tape_backups: Array[Dictionary] = []
var tapes_secured: int = 0
var b_quest_completed: bool = false
var max_tapes: int = 3

func _ready() -> void:
	tape_backups.resize(total_tapes_to_recover)
	print("[Acheron9] QuestManager online - %d tapes to recover" % total_tapes_to_recover)

func spawn_tape_backups() -> void:
	if not get_tree().current_scene:
		return
	tape_backups.clear()
	var used_positions: Dictionary = {}
	for i in total_tapes_to_recover:
		var grid_pos = _select_random_grid_position(used_positions)
		var linear_index = _grid_to_linear_index(grid_pos)
		used_positions[linear_index] = true
		var tape_data: Dictionary = {
			"grid_coordinate": grid_pos,
			"state": TapeState.SPAWNED,
			"tape_id": i + 1,
			"location_label": _generate_location_label(grid_pos),
			"spawned_actor": _spawn_tape_at_coordinate(grid_pos, i + 1),
		}
		tape_backups.append(tape_data)
		print("[Acheron9] Tape %d spawned at grid (%d,%d) - %s" %
			[i + 1, grid_pos.x, grid_pos.y, tape_data.location_label])
	print("[Acheron9] %d tape backups spawned across the facility" % total_tapes_to_recover)

func _select_random_grid_position(used: Dictionary) -> Vector2:
	var available: Array[int] = []
	for y in grid_height:
		for x in grid_width:
			var idx = y * grid_width + x
			if not used.has(idx):
				available.append(idx)
	if available.is_empty():
		return Vector2.ZERO
	var selected = available.pick_random()
	var x = selected % grid_width
	var y = selected / grid_width
	return Vector2(x, y)

func _spawn_tape_at_coordinate(grid_pos: Vector2, tape_id: int) -> Node3D:
	var spawn_location = Vector3(
		(grid_pos.x - grid_width / 2) * grid_spacing,
		0,
		(grid_pos.y - grid_height / 2) * grid_spacing
	)
	var tape_scene = preload("res://scenes/tape_pickup.tscn")
	var actor: Node3D
	if tape_scene:
		actor = tape_scene.instantiate()
	else:
		actor = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 3
		cyl.bottom_radius = 3
		cyl.height = 8
		actor.mesh = cyl
		actor.set_meta("tape_id", tape_id)
	actor.position = spawn_location
	actor.name = "TapeBackup_%d" % tape_id
	get_tree().current_scene.add_child.call_deferred(actor)
	return actor

func secure_tape(tape_id: int) -> void:
	if tape_id < 1 or tape_id > tape_backups.size():
		push_warning("[Acheron9] Invalid TapeID: %d" % tape_id)
		return
	var tape = tape_backups[tape_id - 1]
	if tape.state == TapeState.SECURED:
		return
	tape.state = TapeState.SECURED
	tapes_secured += 1
	if tape.spawned_actor and is_instance_valid(tape.spawned_actor):
		if tape.spawned_actor is Node3D:
			tape.spawned_actor.queue_free()
	tape_secured.emit(tape_id)
	# Notify PROBOS
	var sm = get_node_or_null("/root/SpeechManager")
	if sm:
		sm.notify_tape_secured(tape_id, tapes_secured, total_tapes_to_recover)
	print("[Acheron9] Tape %d SECURED at %s (%d/%d)" %
		[tape_id, tape.location_label, tapes_secured, total_tapes_to_recover])
	# Check completion
	if tapes_secured >= total_tapes_to_recover:
		b_quest_completed = true
		quest_completed.emit(true)
		tapes_all_secured.emit()
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			gm.set_ending(GameManager.EndingType.GOOD_ENDING)
		print("[Acheron9] ALL TAPE BACKUPS SECURED - Good Ending activated")

func check_inventory_for_tapes() -> bool:
	return tapes_secured == total_tapes_to_recover

func get_tapes_remaining() -> int:
	return total_tapes_to_recover - tapes_secured

func _grid_to_linear_index(grid_pos: Vector2) -> int:
	return int(grid_pos.y) * grid_width + int(grid_pos.x)

func _generate_location_label(grid_pos: Vector2) -> String:
	var zones: Array[String] = ["Alpha", "Bravo", "Charlie", "Delta"]
	var zone_idx = (int(grid_pos.x) + int(grid_pos.y)) % 4
	var dir: String
	if grid_pos.x < grid_width / 2 and grid_pos.y < grid_height / 2:
		dir = "NW"
	elif grid_pos.x >= grid_width / 2 and grid_pos.y < grid_height / 2:
		dir = "NE"
	elif grid_pos.x < grid_width / 2 and grid_pos.y >= grid_height / 2:
		dir = "SW"
	else:
		dir = "SE"
	return "Sector %s-%s" % [zones[zone_idx], dir]

func has_item(item_id: String) -> bool:
	return false

func has_all_tapes() -> bool:
	return tapes_secured >= max_tapes
