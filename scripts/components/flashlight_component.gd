# ACHERON-9: INCIDENT - FlashlightComponent (Godot port of UAcheron9FlashlightComponent)
# Dynamic battery drain with tickless flickering, Act 3 cutoff, low-battery effects.
class_name FlashlightComponent
extends Node

# Runtime singleton accessor — untyped to avoid class-type resolution
var _settings_mgr = null

enum FlashlightState { OFF, ON, FLICKERING, DEAD }

signal battery_changed(battery_percent: float)
signal flashlight_state_changed(new_state: int)

# Config (mirrors UE UPROPERTY EditAnywhere)
@export var max_battery: float = 120.0
@export var current_battery: float = 0.0
@export var drain_rate: float = 1.0
@export var flicker_threshold: float = 30.0
@export var movement_anomaly_threshold: float = 500.0
@export var light_intensity: float = 5000.0
@export var light_color: Color = Color(0.8, 0.7, 0.4, 1.0)

# State
var flashlight_state: int = FlashlightState.OFF
var b_act3_cutoff: bool = false

# Timers
var _battery_timer: Timer
var _flicker_timer: Timer

@onready var _light: SpotLight3D = get_node_or_null("../Camera3D/FlashlightLight")

func _ready() -> void:
	current_battery = max_battery
	flashlight_state = FlashlightState.OFF

	# Resolve autoload singleton
	_settings_mgr = get_node_or_null("/root/SettingsManager")

	# Battery drain timer (0.5s, tickless)
	_battery_timer = Timer.new()
	_battery_timer.wait_time = 0.5
	_battery_timer.one_shot = false
	_battery_timer.autostart = true
	add_child(_battery_timer)
	_battery_timer.timeout.connect(_on_battery_timer_elapsed)

	# Sync with settings
	if _settings_mgr:
		var sens = _settings_mgr.gameplay_settings.mouse_sensitivity
		# Battery drain is independent of mouse sensitivity in UE

func toggle_flashlight() -> void:
	if b_act3_cutoff or flashlight_state == FlashlightState.DEAD:
		return
	if flashlight_state == FlashlightState.ON:
		turn_off()
	elif flashlight_state == FlashlightState.OFF or flashlight_state == FlashlightState.FLICKERING:
		turn_on()

func turn_on() -> void:
	if b_act3_cutoff or flashlight_state == FlashlightState.DEAD:
		return
	_set_flashlight_state(FlashlightState.ON)
	_update_light_visibility(true)

	# Start flicker evaluation timer (0.25s)
	if not _flicker_timer:
		_flicker_timer = Timer.new()
		_flicker_timer.wait_time = 0.25
		_flicker_timer.one_shot = false
		add_child(_flicker_timer)
		_flicker_timer.timeout.connect(_on_flicker_timer_elapsed)
	_flicker_timer.start()

func turn_off() -> void:
	_set_flashlight_state(FlashlightState.OFF)
	_update_light_visibility(false)
	if _flicker_timer:
		_flicker_timer.stop()

func activate_act3_cutoff() -> void:
	b_act3_cutoff = true
	_set_flashlight_state(FlashlightState.DEAD)
	_update_light_visibility(false)
	if _flicker_timer:
		_flicker_timer.stop()
	print("[Acheron9] Flashlight - Act 3 cutoff activated. Emergency lighting override.")

func recharge_battery(amount: float) -> void:
	current_battery = min(max_battery, current_battery + amount)
	battery_changed.emit(get_battery_percent())
	if flashlight_state == FlashlightState.DEAD and current_battery > 0:
		_set_flashlight_state(FlashlightState.OFF)

func get_battery_percent() -> float:
	return (current_battery / max_battery) * 100.0

# ==================== Timer Callbacks ====================

func _on_battery_timer_elapsed() -> void:
	_evaluate_flicker_state()

func _on_flicker_timer_elapsed() -> void:
	_evaluate_flicker_state()

func _evaluate_flicker_state() -> void:
	if b_act3_cutoff or flashlight_state == FlashlightState.OFF or flashlight_state == FlashlightState.DEAD:
		return

	# Drain battery
	current_battery -= drain_rate * 0.5

	if current_battery <= 0.0:
		current_battery = 0.0
		_set_flashlight_state(FlashlightState.DEAD)
		_update_light_visibility(false)
		if _flicker_timer:
			_flicker_timer.stop()
		return

	battery_changed.emit(get_battery_percent())

	# Flicker when battery is low
	if current_battery < flicker_threshold:
		if _check_movement_anomaly():
			_set_flashlight_state(FlashlightState.FLICKERING)
			_apply_flicker_effect()
		else:
			_set_flashlight_state(FlashlightState.ON)
	else:
		_set_flashlight_state(FlashlightState.ON)

func _check_movement_anomaly() -> bool:
	if not get_parent() or not (get_parent() is CharacterBody3D):
		return false
	var body = get_parent() as CharacterBody3D
	if not body:
		return false
	var speed = body.velocity.length()
	return speed > movement_anomaly_threshold and randf() < 0.3

func _apply_flicker_effect() -> void:
	var flicker_power = clamp(1.0 - (current_battery / flicker_threshold), 0.1, 1.0)
	print("[Acheron9] Flashlight flicker: power=%.2f battery=%.1f" % [flicker_power, current_battery])

	# Apply flicker to light intensity
	if _light:
		var base_intensity = light_intensity * flicker_power
		_light.light_energy = base_intensity * randf_range(0.5, 1.0)

func _set_flashlight_state(new_state: int) -> void:
	if flashlight_state == new_state:
		return
	flashlight_state = new_state
	flashlight_state_changed.emit(new_state)

func _update_light_visibility(visible: bool) -> void:
	if _light:
		_light.visible = visible
