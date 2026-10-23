# ACHERON-9: INCIDENT - EndingSequenceManager (Godot port of AAcheron9EndingSequenceManager)
# Orchestrates Good/Bad/Time-Expired ending sequences with post-processing effects.
class_name EndingManager
extends Node

signal ending_started(ending_type: int)
signal ending_complete

enum EndingSequence { NONE, GOOD_ENDING_SEQUENCE, BAD_ENDING_SEQUENCE, TIME_EXPIRED_ENDING }

# Config
@export var good_ending_fade_time: float = 5.0
@export var bad_ending_rotate_time: float = 3.0

var current_ending: int = EndingSequence.NONE
var ending_progress: float = 0.0

# Post-process references
var _crt_overlay: ColorRect
var _fade_rect: ColorRect

func _ready() -> void:
	_crt_overlay = get_tree().root.find_child("CRTOverlay", true, false) as ColorRect
	_fade_rect = get_tree().root.find_child("ScreenFade", true, false) as ColorRect
	if not _fade_rect:
		_fade_rect = ColorRect.new()
		_fade_rect.name = "ScreenFade"
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade_rect.z_index = 999
		get_tree().root.add_child.call_deferred(_fade_rect)
		_fade_rect.anchor_right = 1.0
		_fade_rect.anchor_bottom = 1.0
		_fade_rect.position = Vector2.ZERO
	if _fade_rect:
		_fade_rect.color = Color(0, 0, 0, 0)
		_fade_rect.hide()
	print("[Acheron9] Ending sequence manager online")

# ==================== Ending Triggers ====================

func trigger_good_ending() -> void:
	if current_ending != EndingSequence.NONE:
		return
	current_ending = EndingSequence.GOOD_ENDING_SEQUENCE
	ending_progress = 0.0
	_disable_player_input()
	_start_whiteout_post_process()
	ending_started.emit(current_ending)
	print(">>> GOOD ENDING INITIATED <<<")
	var music_path = "res://assets/audio/music/good_ending.ogg"
	if ResourceLoader.exists(music_path):
		var good_music = load(music_path) as AudioStream
		if good_music:
			var am = get_node_or_null("/root/AudioManager")
			if am:
				am.play_sound_2d(good_music, 1.0, 1.0, "Music")
	var sm = get_node_or_null("/root/SpeechManager")
	if sm:
		sm.speak_fragment("Protocol complete. Containment achieved. Facility entering safe state.")
	_fade_to_white(good_ending_fade_time)
	await get_tree().create_timer(good_ending_fade_time).timeout
	_complete_ending()

func trigger_bad_ending() -> void:
	if current_ending != EndingSequence.NONE:
		return
	current_ending = EndingSequence.BAD_ENDING_SEQUENCE
	ending_progress = 0.0
	_disable_player_input()
	_rotate_camera_180()
	_play_bone_crush_audio()
	_spawn_blood_splatter_decal()
	ending_started.emit(current_ending)
	print(">>> BAD ENDING INITIATED <<<")
	await get_tree().create_timer(bad_ending_rotate_time).timeout
	_complete_ending()

func trigger_time_expired_ending() -> void:
	if current_ending != EndingSequence.NONE:
		return
	current_ending = EndingSequence.TIME_EXPIRED_ENDING
	ending_progress = 0.0
	_disable_player_input()
	ending_started.emit(current_ending)
	print(">>> TIME EXPIRED - FACILITY LOCKDOWN <<<")
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.set_ending(GameManager.EndingType.TIME_EXPIRED)
	var sm = get_node_or_null("/root/SpeechManager")
	if sm:
		sm.trigger_core_violation()
	await get_tree().create_timer(10.0).timeout
	_complete_ending()

# ==================== Ending Helpers ====================

func _disable_player_input() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var player = get_tree().get_first_node_in_group("player") if get_tree() else null
	if player:
		var flashlight = player.get_node_or_null("FlashlightComponent") as Node
		if flashlight and flashlight.has_method("activate_act3_cutoff"):
			flashlight.activate_act3_cutoff()

func _play_bone_crush_audio() -> void:
	var am = get_node_or_null("/root/AudioManager")
	var sound = null
	if am and am.has_method("get_bone_crush_sound"):
		sound = am.get_bone_crush_sound()
	if sound:
		if am:
			am.play_sound_2d(sound, 1.0, 1.0, "SFX")

func _spawn_blood_splatter_decal() -> void:
	if _crt_overlay:
		if _crt_overlay.material and _crt_overlay.material is ShaderMaterial:
			_crt_overlay.material.set_shader_parameter("blood_overlay", true)
	if not _fade_rect:
		return
	_fade_rect.color = Color(0.12, 0.02, 0.02, 0.5)
	_fade_rect.show()

func _start_whiteout_post_process() -> void:
	if _crt_overlay:
		if _crt_overlay.material and _crt_overlay.material is ShaderMaterial:
			_crt_overlay.material.set_shader_parameter("whiteout", true)
			_crt_overlay.material.set_shader_parameter("whiteout_alpha", 1.0)

func _rotate_camera_180() -> void:
	var player = get_tree().get_first_node_in_group("player") if get_tree() else null
	if not player:
		return
	var cam = player.find_child("Camera3D", true, false) as Camera3D
	if not cam:
		return
	var start_yaw = cam.rotation_degrees.y
	var target_yaw = start_yaw + 180.0
	var elapsed = 0.0
	var steps = 60
	for step in steps:
		var t = float(step) / float(steps)
		elapsed = lerp(0.0, bad_ending_rotate_time, t)
		await get_tree().process_frame
		cam.rotation_degrees.y = lerp_angle(start_yaw, target_yaw, t)
	_on_bad_ending_rotation_complete()

func _on_bad_ending_rotation_complete() -> void:
	print("[Acheron9] Camera 180-degree rotation complete")

func _fade_to_white(duration: float) -> void:
	if not _fade_rect:
		return
	_fade_rect.show()
	var tween = create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, duration).set_trans(Tween.TRANS_SINE)

func _fade_to_black(duration: float) -> void:
	if not _fade_rect:
		return
	_fade_rect.show()
	_fade_rect.color = Color(0, 0, 0, 0)
	var tween = create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, duration).set_trans(Tween.TRANS_SINE)

func _complete_ending() -> void:
	if _fade_rect:
		_fade_rect.queue_free()
		_fade_rect = null
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.b_game_over = true
	ending_complete.emit()
	print("[Acheron9] Ending sequence complete - state locked")
