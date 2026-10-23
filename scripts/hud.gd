# ACHERON-9: INCIDENT - CRT HUD Manager (Godot port of AAcheron9HUDManager)
# Draws retro terminal-style HUD: timer, battery, tape counter, CRT scanlines,
# main menu, credits, and end screen.
class_name HUD
extends CanvasLayer

signal main_menu_selected(action: String)

# Runtime singleton accessors — untyped Variant to avoid class-type resolution
var _gm = null
var _qm = null
var _sm = null
var _em = null

# CRT state (mirrors UE)
var b_crt_enabled: bool = true
var crt_power_level: float = 1.0
var b_show_main_menu: bool = false
var b_show_credits: bool = false
var b_show_end_screen: bool = false
var end_screen_text: String = ""
var end_screen_good: bool = true
var _crt_blink_phase: int = 0

# Menu entries
var _menu_entries: Array[Dictionary] = []
var _selected_menu_index: int = 0

# UI nodes
@onready var crt_overlay: ColorRect = $CRTOverlay
@onready var timer_label: Label = $InGameHUD/TimerLabel
@onready var battery_label: Label = $InGameHUD/BatteryLabel
@onready var tape_label: Label = $InGameHUD/TapeLabel
@onready var power_label: Label = $InGameHUD/PowerLabel
@onready var menu_panel: VBoxContainer = $MainMenu
@onready var speech_label: Label = $SpeechLabel
@onready var credits_label: Label = $CreditsLabel
@onready var end_screen: ColorRect = $EndScreen
@onready var end_title: Label = $EndScreen/Title
@onready var end_subtext: Label = $EndScreen/SubText

var _crt_blink_timer: Timer
var _credits_scroll_offset: float = 0.0
var _credits_timer: Timer

func _ready() -> void:
	# Build menu entries (mirrors UE)
	_menu_entries = [
		{"label": "> INITIATE PROTOCOL", "action": "StartGame", "color": Color(0, 1, 0)},
		{"label": "  CONFIGURE TERMINAL", "action": "Settings", "color": Color(0.3, 1.0, 0.3)},
		{"label": "  EMERGENCY SHUTDOWN", "action": "Quit", "color": Color(1.0, 0.2, 0.2)},
	]

	# Resolve autoload singletons
	_gm = get_node_or_null("/root/GameManager")
	_qm = get_node_or_null("/root/QuestManager")
	_sm = get_node_or_null("/root/SpeechManager")
	_em = get_node_or_null("/root/EndingManager")

	# CRT blink timer (0.08s, simulates CRT refresh instability)
	_crt_blink_timer = Timer.new()
	_crt_blink_timer.wait_time = 0.08
	_crt_blink_timer.one_shot = false
	add_child(_crt_blink_timer)
	_crt_blink_timer.timeout.connect(_on_crt_blink_elapsed)
	_crt_blink_timer.autostart = true
	_crt_blink_timer.start()

	# Connect to game manager
	if _gm:
		if not _gm.is_connected("timer_updated", Callable(self, "_on_timer_updated")):
			_gm.connect("timer_updated", Callable(self, "_on_timer_updated"))
		if not _gm.is_connected("game_state_changed", Callable(self, "_on_game_state_changed")):
			_gm.connect("game_state_changed", Callable(self, "_on_game_state_changed"))

	# Initially show main menu
	b_show_main_menu = true
	_show_menu()
	_hide_ingame_hud()

func _on_crt_blink_elapsed() -> void:
	_crt_blink_phase = (_crt_blink_phase + 1) % 8

func _on_timer_updated(time_remaining: float) -> void:
	if timer_label and _gm:
		timer_label.text = "[TIMER] %s" % _gm.call("get_time_formatted")

func _on_game_state_changed(game_over: bool) -> void:
	if game_over:
		b_show_end_screen = true
		_show_end_screen()

func _draw() -> void:
	if not b_crt_enabled:
		return

	# CRT scanline static pattern
	if crt_overlay:
		var scan_alpha = _crt_blink_phase * 25
		var scan_color = Color(0.0, 0.4 + scan_alpha / 255.0, 0.0, 0.3 + scan_alpha / 510.0)
		crt_overlay.color = scan_color

# ==================== Drawing ====================

func _update_crt_shader() -> void:
	if crt_overlay and crt_overlay.material:
		crt_overlay.material.set_shader_parameter("scanline_color", Color(0.8, 0.1, 0.1, 1.0))

func _draw_main_menu() -> void:
	# CRT scanline static noise pattern
	var scan_alpha = _crt_blink_phase * 25
	var scan_color = Color(0.0, 0.4 + scan_alpha / 255.0, 0.0, 0.3 + scan_alpha / 510.0)
	if crt_overlay:
		crt_overlay.color = scan_color

	# Title
	if menu_panel:
		menu_panel.show()
		for i in _menu_entries.size():
			var entry = _menu_entries[i]
			var label = menu_panel.get_node_or_null("Item%d" % i) as Label
			if label:
				label.text = entry.label
				label.add_theme_color_override("font_color", entry.color)

func _draw_credits_roll() -> void:
	var credits_lines: Array[String] = [
		"ACHRON-9: INCIDENT",
		"",
		"DIRECTOR: PROTOCOL ENGINEERING",
		"LEAD ARCHITEECT: HARTWELL LABS",
		"",
		"SECURITY CHIEF: EYES ONLY",
		"FACILITY ADMINISTRATOR: REDACTED",
		"AUDIO DIRECTOR: PROBOS-CORE",
		"",
		"SPECIAL THANKS:",
		"- THE AWAKENING PROTOCOL",
		"- CLASSIFIED SUBJECTS",
		"- THE VOID BETWEEN STARS",
		"",
		"THIS FACILITY IS NOW UNDER CONTAINMENT",
		"ALL PERSONNEL REPORT TO DESIGNATED SHELTERS",
		"DO NOT ATTEMPT TO ACCESS THE CORE",
		"",
		"END LOG // SESSION TERMINATED //",
	]

	if credits_label:
		credits_label.show()
		var text = ""
		for line in credits_lines:
			text += line + "\n"
		credits_label.text = text
		credits_label.position.y = -_credits_scroll_offset + get_viewport().size.y

	# Start scroll timer
	if not _credits_timer:
		_credits_timer = Timer.new()
		_credits_timer.wait_time = 0.05
		_credits_timer.one_shot = false
		add_child(_credits_timer)
		_credits_timer.timeout.connect(_on_credits_tick)
	_credits_timer.start()

func _on_credits_tick() -> void:
	_credits_scroll_offset += 10.0

	if _credits_scroll_offset > 1000.0:
		_credits_timer.stop()
		b_show_credits = false
		credits_label.hide()

func _draw_end_screen(message: String = "", b_good: bool = true) -> void:
	if end_screen:
		end_screen.show()
	if end_title:
		end_title.text = "PROTOCOL COMPLETE" if b_good else "PROTOCOL VIOLATED"
		end_title.add_theme_color_override("font_color", Color(1, 1, 1) if b_good else Color(0.8, 0.1, 0.1))
	if end_subtext:
		end_subtext.text = message

# ==================== State Methods ====================

func show_main_menu() -> void:
	b_show_main_menu = true
	_hide_ingame_hud()
	menu_panel.show()
	_draw_main_menu()

func hide_main_menu() -> void:
	b_show_main_menu = false
	menu_panel.hide()
	_show_ingame_hud()

func show_ingame_hud() -> void:
	_hide_menu()
	_show_ingame_hud()

func _show_ingame_hud() -> void:
	if timer_label: timer_label.show()
	if battery_label: battery_label.show()
	if tape_label: tape_label.show()
	if power_label: power_label.show()
	b_show_main_menu = false

func _hide_ingame_hud() -> void:
	if timer_label: timer_label.hide()
	if battery_label: battery_label.hide()
	if tape_label: tape_label.hide()
	if power_label: power_label.hide()

func _hide_menu() -> void:
	if menu_panel:
		menu_panel.hide()

func start_credits_roll() -> void:
	b_show_credits = true
	_credits_scroll_offset = 0.0
	_hide_ingame_hud()
	_draw_credits_roll()

func draw_end_screen(message: String, b_good_ending: bool) -> void:
	b_show_end_screen = true
	end_screen_text = message
	end_screen_good = b_good_ending
	_draw_end_screen(message, b_good_ending)

func toggle_main_menu() -> void:
	b_show_main_menu = not b_show_main_menu
	if b_show_main_menu:
		_show_menu()
	else:
		_hide_menu()
		_show_ingame_hud()

func _input(event: InputEvent) -> void:
	if b_show_main_menu and event.is_action_pressed("ui_accept"):
		_on_menu_accept()
	if b_show_main_menu and event.is_action_pressed("ui_up"):
		_selected_menu_index = max(0, _selected_menu_index - 1)
		_update_menu_highlight()
	if b_show_main_menu and event.is_action_pressed("ui_down"):
		_selected_menu_index = min(_menu_entries.size() - 1, _selected_menu_index + 1)
		_update_menu_highlight()

func _on_menu_accept() -> void:
	var action = _menu_entries[_selected_menu_index]["action"]
	match action:
		"StartGame":
			b_show_main_menu = false
			_hide_menu()
			_show_ingame_hud()
		"Settings":
			print("[Acheron9] Configure Terminal (settings menu not yet implemented in Godot port)")
		"Quit":
			get_tree().quit()

func _on_speech_played(spoken_text: String) -> void:
	if speech_label:
		speech_label.text = "[PROBOS-Core] %s" % spoken_text
		speech_label.show()
		# Auto-hide after 8 seconds
		var timer = get_tree().create_timer(8.0)
		timer.timeout.connect(func():
			if speech_label:
				speech_label.hide()
		)

func _show_menu() -> void:
	if menu_panel:
		menu_panel.show()
		_selected_menu_index = 0
		_update_menu_highlight()
		for i in _menu_entries.size():
			var entry = _menu_entries[i]
			var label = menu_panel.get_node_or_null("Item%d" % i) as Label
			if label:
				label.text = entry.label
				label.add_theme_color_override("font_color", entry.color)

func _update_menu_highlight() -> void:
	if not menu_panel:
		return
	for i in _menu_entries.size():
		var label = menu_panel.get_node_or_null("Item%d" % i) as Label
		if label:
			if i == _selected_menu_index:
				label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
				label.text = "> " + _menu_entries[i].label
			else:
				label.add_theme_color_override("font_color", _menu_entries[i].color)
				label.text = _menu_entries[i].label

func _show_end_screen() -> void:
	if _gm and _gm.current_ending == GameManager.EndingType.GOOD_ENDING:
		draw_end_screen("Containment achieved. Facility entering safe state.", true)
	elif _gm and _gm.current_ending == GameManager.EndingType.TIME_EXPIRED:
		draw_end_screen("Purge loop complete. All personnel terminated.", false)
	else:
		draw_end_screen("Protocol violated.", false)
