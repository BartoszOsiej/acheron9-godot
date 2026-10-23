# ACHERON-9: INCIDENT - SaveSystem (Godot port of UAcheron9SaveGame)
# Persistent save/load using Godot Resource serialization to user:// directory.
class_name SaveSystem
extends Node

# Save data structure
class SaveData:
	var player_location: Vector3 = Vector3.ZERO
	var player_rotation: Vector3 = Vector3.ZERO
	var magnetic_tapes_collected: int = 0
	var total_tapes_available: int = 3
	var secured_tape_ids: Array[int] = []
	var inventory_items: Array[Dictionary] = []
	var flashlight_battery: float = 0.0
	var max_flashlight_battery: float = 0.0
	var time_remaining: float = 0.0
	var ending_type: int = 0
	var save_timestamp: String = ""
	var save_type: int = 0

# ==================== Persistence ====================

func save_to_slot(slot_name: String = "Acheron9_SaveGame") -> bool:
	var save = SaveData.new()
	var player = get_tree().get_first_node_in_group("player") if get_tree() else null
	if player and player is Node3D:
		save.player_location = player.global_position
		save.player_rotation = player.rotation
	if player:
		var flashlight = player.get_node_or_null("FlashlightComponent") as Node
		if flashlight and flashlight.has("current_battery"):
			save.flashlight_battery = flashlight.current_battery
		if flashlight and flashlight.has("max_battery"):
			save.max_flashlight_battery = flashlight.max_battery
	if player:
		var inventory = player.get_node_or_null("InventoryComponent") as Node
		if inventory and inventory.has("magnetic_tapes_collected"):
			save.magnetic_tapes_collected = inventory.magnetic_tapes_collected
			save.total_tapes_available = inventory.max_tapes if inventory.has("max_tapes") else 3
	# Quest/GameState
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		save.time_remaining = gm.time_remaining
		save.ending_type = int(gm.current_ending)
	save.save_timestamp = Time.get_date_string_from_system() + " " + Time.get_time_string_from_system()
	save.save_type = 1
	var json_data = JSON.stringify({
		"player_location": {"x": save.player_location.x, "y": save.player_location.y, "z": save.player_location.z},
		"player_rotation": {"x": save.player_rotation.x, "y": save.player_rotation.y, "z": save.player_rotation.z},
		"magnetic_tapes_collected": save.magnetic_tapes_collected,
		"total_tapes_available": save.total_tapes_available,
		"secured_tape_ids": save.secured_tape_ids,
		"inventory_items": save.inventory_items,
		"flashlight_battery": save.flashlight_battery,
		"max_flashlight_battery": save.max_flashlight_battery,
		"time_remaining": save.time_remaining,
		"ending_type": save.ending_type,
		"save_timestamp": save.save_timestamp,
		"save_type": save.save_type
	})
	var path = "user://saved_games/%s.json" % slot_name
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("saved_games"):
		dir.make_dir("saved_games")
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("[Acheron9] Failed to save game to slot: %s" % slot_name)
		return false
	file.store_string(json_data)
	file.close()
	print("[Acheron9] Game saved to slot: %s" % slot_name)
	return true

func load_from_slot(slot_name: String = "Acheron9_SaveGame") -> SaveData:
	var path = "user://saved_games/%s.json" % slot_name
	if not FileAccess.file_exists(path):
		return SaveData.new()
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return SaveData.new()
	var json_str = file.get_as_text()
	file.close()
	var result = JSON.parse_string(json_str)
	if result.error != OK:
		return SaveData.new()
	var data = result.result
	var save = SaveData.new()
	if data.has("player_location"):
		var loc = data.player_location
		save.player_location = Vector3(loc.x, loc.y, loc.z)
	if data.has("player_rotation"):
		var rot = data.player_rotation
		save.player_rotation = Vector3(rot.x, rot.y, rot.z)
	save.magnetic_tapes_collected = data.get("magnetic_tapes_collected", 0)
	save.total_tapes_available = data.get("total_tapes_available", 3)
	save.secured_tape_ids = data.get("secured_tape_ids", [])
	save.inventory_items = data.get("inventory_items", [])
	save.flashlight_battery = data.get("flashlight_battery", 0.0)
	save.max_flashlight_battery = data.get("max_flashlight_battery", 0.0)
	save.time_remaining = data.get("time_remaining", 0.0)
	save.ending_type = data.get("ending_type", 0)
	save.save_timestamp = data.get("save_timestamp", "")
	save.save_type = data.get("save_type", 0)
	return save

func delete_save(slot_name: String = "Acheron9_SaveGame") -> bool:
	var path = "user://saved_games/%s.json" % slot_name
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		return true
	return false
