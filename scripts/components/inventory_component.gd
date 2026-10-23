# ACHERON-9: INCIDENT - InventoryComponent (Godot port of UAcheron9InventoryComponent)
# Quest item system: magnetic tapes, employee notebooks, readable items.
class_name InventoryComponent
extends Node

signal item_added(item: Dictionary)
signal tape_collected(count: int, max_tapes: int)

@export var max_tapes: int = 3

var collected_items: Array[Dictionary] = []
var magnetic_tapes_collected: int = 0

func add_item(item: Dictionary) -> void:
	collected_items.append(item)
	item_added.emit(item)

	if item.item_id == "TapeBackup":
		magnetic_tapes_collected += 1
		tape_collected.emit(magnetic_tapes_collected, max_tapes)

	print("[Acheron9] Inventory: Added '%s' (Total items: %d)" % [item.item_name, collected_items.size()])

func add_magnetic_tape() -> void:
	var tape: Dictionary = {
		"item_id": "TapeBackup",
		"item_name": "Magnetic Tape Backup",
		"description": "Digital storage medium containing facility data",
		"is_readable": false,
		"readable_text": "",
		"icon_path": "res://assets/ui/icons/tape_backup.png",
	}
	add_item(tape)

func add_employee_notebook(notebook_id: String, title: String, text_content: String) -> void:
	var notebook: Dictionary = {
		"item_id": notebook_id,
		"item_name": title,
		"description": "Employee record - contains sensitive facility information",
		"is_readable": true,
		"readable_text": text_content,
		"icon_path": "res://assets/ui/icons/notebook.png",
	}
	add_item(notebook)

func has_item(item_id: String) -> bool:
	for item in collected_items:
		if item.item_id == item_id:
			return true
	return false

func has_all_tapes() -> bool:
	return magnetic_tapes_collected >= max_tapes

func get_inventory() -> Array[Dictionary]:
	return collected_items
