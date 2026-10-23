# ACHERON-9: INCIDENT - EndingTriggerVolume (Godot port of AEndingTriggerVolume)
# Area3D that triggers an ending when the player enters, with optional delay.
class_name EndTrigger
extends Area3D

signal ending_triggered

enum EndingType { GOOD_ENDING, BAD_ENDING, TIME_EXPIRED }

@export var ending_type: int = EndingType.GOOD_ENDING
@export var b_auto_trigger: bool = true
@export var trigger_delay: float = 0.0
@export var b_play_once: bool = true

var b_triggered: bool = false
var _delay_timer: SceneTreeTimer
var _gm = null  # GameManager singleton (untyped for dynamic dispatch)

func _ready() -> void:
	# Add a collision shape if none exists (needed for Area3D to detect overlaps)
	if get_child_count() == 0 or not get_node_or_null("CollisionShape3D"):
		var shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(200, 200, 200)
		shape.shape = box
		shape.name = "CollisionShape3D"
		add_child(shape)

	# Resolve autoload singleton
	_gm = get_node_or_null("/root/GameManager")

	body_entered.connect(_on_body_entered)
	if b_auto_trigger:
		set_monitoring(true)

func _on_body_entered(body: Node3D) -> void:
	if b_triggered or not b_auto_trigger:
		return
	if not body:
		return
	# Check if it's the player
	if not (body.is_in_group("player") or body.name == "Player"):
		return

	if trigger_delay > 0.0:
		_delay_timer = get_tree().create_timer(trigger_delay)
		_delay_timer.timeout.connect(_on_trigger_delay_elapsed)
	else:
		_trigger_ending()

func _on_trigger_delay_elapsed() -> void:
	_trigger_ending()

func _trigger_ending() -> void:
	if b_triggered and b_play_once:
		return
	b_triggered = true

	if _gm:
		_gm.set_ending(ending_type)

	ending_triggered.emit()

	var ending_name: String
	match ending_type:
		EndingType.GOOD_ENDING: ending_name = "Good Ending"
		EndingType.BAD_ENDING: ending_name = "Bad Ending"
		EndingType.TIME_EXPIRED: ending_name = "Time Expired"
		_: ending_name = "Unknown"

	print("[Acheron9] Ending triggered: %s" % ending_name)
