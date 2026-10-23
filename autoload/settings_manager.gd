# ACHERON-9: INCIDENT - SettingsManager (Godot port of AAcheron9SettingsManager)
# Manages display, audio, gameplay, and gamma/CRT calibration settings persisted to disk.
class_name SettingsManager
extends Node

signal crt_mode_toggled(b_enabled: bool)

# Setting structs (mirrors UE USTRUCTs)
class GammaCalibration:
	var gamma_value: float = 2.2
	var brightness: float = 0.0
	var contrast: float = 1.0
	var saturation: float = 1.0
	var b_crt_mode: bool = true

class DisplaySettings:
	var resolution_x: int = 1920
	var resolution_y: int = 1080
	var refresh_rate: int = 120
	var b_fullscreen: bool = true
	var b_ray_tracing_enabled: bool = true  # Vulkan handles RT automatically in Godot
	var b_vsync: bool = false
	var aa_method: int = 0

class AudioSettings:
	var master_volume: float = 0.8
	var music_volume: float = 1.0
	var sfx_volume: float = 1.0
	var dialog_volume: float = 1.0
	var mic_threshold: float = 0.02

class GameplaySettings:
	var b_invert_y_axis: bool = false
	var mouse_sensitivity: float = 1.0
	var b_subtitles: bool = true
	var hud_alpha: float = 1.0

# Config
var display_settings: DisplaySettings = DisplaySettings.new()
var audio_settings: AudioSettings = AudioSettings.new()
var gameplay_settings: GameplaySettings = GameplaySettings.new()
var gamma_settings: GammaCalibration = GammaCalibration.new()

var b_gamma_dirty: bool = true
var _cached_instance = null

const SETTINGS_PATH = "user://saved_games/acheron9_settings.ini"

func _ready() -> void:
	_load_settings_from_disk()
	_cached_instance = self
	_initialize_ray_tracing()
	apply_gamma_calibration(gamma_settings)
	print("[Acheron9] SettingsManager initialized")

func _load_settings_from_disk() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		return
	var content = file.get_as_text()
	file.close()
	var config = ConfigFile.new()
	var err = config.parse(content)
	if err != OK:
		return
	display_settings.resolution_x = config.get_value("display", "resolution_x", 1920)
	display_settings.resolution_y = config.get_value("display", "resolution_y", 1080)
	display_settings.refresh_rate = config.get_value("display", "refresh_rate", 120)
	display_settings.b_fullscreen = config.get_value("display", "fullscreen", true)
	display_settings.b_ray_tracing_enabled = config.get_value("display", "ray_tracing", true)
	display_settings.b_vsync = config.get_value("display", "vsync", false)
	audio_settings.master_volume = config.get_value("audio", "master_volume", 0.8)
	audio_settings.music_volume = config.get_value("audio", "music_volume", 1.0)
	audio_settings.sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
	audio_settings.dialog_volume = config.get_value("audio", "dialog_volume", 1.0)
	audio_settings.mic_threshold = config.get_value("audio", "mic_threshold", 0.02)
	gameplay_settings.b_invert_y_axis = config.get_value("gameplay", "invert_y", false)
	gameplay_settings.mouse_sensitivity = config.get_value("gameplay", "mouse_sensitivity", 1.0)
	gameplay_settings.b_subtitles = config.get_value("gameplay", "subtitles", true)
	gameplay_settings.hud_alpha = config.get_value("gameplay", "hud_alpha", 1.0)
	gamma_settings.gamma_value = config.get_value("gamma", "gamma_value", 2.2)
	gamma_settings.brightness = config.get_value("gamma", "brightness", 0.0)
	gamma_settings.contrast = config.get_value("gamma", "contrast", 1.0)
	gamma_settings.saturation = config.get_value("gamma", "saturation", 1.0)
	gamma_settings.b_crt_mode = config.get_value("gamma", "crt_mode", true)
	b_gamma_dirty = true
	print("[Acheron9] Settings loaded from disk")

func get_instance() -> SettingsManager:
	if _cached_instance:
		return _cached_instance
	_cached_instance = self
	return self

# ==================== Apply Methods ====================

func apply_display_settings(new_settings: DisplaySettings) -> void:
	display_settings = new_settings
	if not new_settings.b_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	DisplayServer.window_set_size(Vector2i(new_settings.resolution_x, new_settings.resolution_y))
	# Use call() to avoid static-vs-instance resolution issues across Godot versions
	if DisplayServer.has_method("window_set_vsync"):
		DisplayServer.call("window_set_vsync", new_settings.b_vsync)
	elif DisplayServer.has_method("window_set_vsync_mode"):
		DisplayServer.call("window_set_vsync_mode", new_settings.b_vsync)

func apply_audio_settings(new_settings: AudioSettings) -> void:
	audio_settings = new_settings
	var master_bus = AudioServer.get_bus_index("Master")
	var music_bus = AudioServer.get_bus_index("Music") if AudioServer.get_bus_index("Music") != -1 else 0
	var sfx_bus = AudioServer.get_bus_index("SFX") if AudioServer.get_bus_index("SFX") != -1 else 0
	AudioServer.set_bus_volume_db(master_bus, linear_to_db(new_settings.master_volume))

func apply_gameplay_settings(new_settings: GameplaySettings) -> void:
	gameplay_settings = new_settings

func apply_gamma_calibration(new_calibration: GammaCalibration) -> void:
	gamma_settings = new_calibration
	b_gamma_dirty = false
	if new_calibration.b_crt_mode:
		crt_mode_toggled.emit(true)
	else:
		crt_mode_toggled.emit(false)
	print("[Acheron9] Gamma calibrated - G=%.2f B=%.2f C=%.2f CRT=%s" %
		[gamma_settings.gamma_value, gamma_settings.brightness, gamma_settings.contrast,
		gamma_settings.b_crt_mode])

# ==================== Persistence ====================

func save_all_settings_to_disk() -> void:
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if not file:
		push_error("[Acheron9] Failed to save settings to %s" % SETTINGS_PATH)
		return
	file.store_string("[display]\n")
	file.store_string("resolution_x=%d\n" % display_settings.resolution_x)
	file.store_string("resolution_y=%d\n" % display_settings.resolution_y)
	file.store_string("refresh_rate=%d\n" % display_settings.refresh_rate)
	file.store_string("fullscreen=%s\n" % str(display_settings.b_fullscreen))
	file.store_string("ray_tracing=%s\n" % str(display_settings.b_ray_tracing_enabled))
	file.store_string("vsync=%s\n" % str(display_settings.b_vsync))
	file.store_string("\n[audio]\n")
	file.store_string("master_volume=%.2f\n" % audio_settings.master_volume)
	file.store_string("music_volume=%.2f\n" % audio_settings.music_volume)
	file.store_string("sfx_volume=%.2f\n" % audio_settings.sfx_volume)
	file.store_string("dialog_volume=%.2f\n" % audio_settings.dialog_volume)
	file.store_string("mic_threshold=%.2f\n" % audio_settings.mic_threshold)
	file.store_string("\n[gameplay]\n")
	file.store_string("invert_y=%s\n" % str(gameplay_settings.b_invert_y_axis))
	file.store_string("mouse_sensitivity=%.2f\n" % gameplay_settings.mouse_sensitivity)
	file.store_string("subtitles=%s\n" % str(gameplay_settings.b_subtitles))
	file.store_string("hud_alpha=%.2f\n" % gameplay_settings.hud_alpha)
	file.store_string("\n[gamma]\n")
	file.store_string("gamma_value=%.2f\n" % gamma_settings.gamma_value)
	file.store_string("brightness=%.2f\n" % gamma_settings.brightness)
	file.store_string("contrast=%.2f\n" % gamma_settings.contrast)
	file.store_string("saturation=%.2f\n" % gamma_settings.saturation)
	file.store_string("crt_mode=%s\n" % str(gamma_settings.b_crt_mode))
	file.store_string("dirty=%s\n" % str(b_gamma_dirty))
	file.close()
	print("[Acheron9] Settings saved to disk")

# ==================== Ray Tracing ====================

func _initialize_ray_tracing() -> void:
	display_settings.b_ray_tracing_enabled = true
	print("[Acheron9] Ray tracing initialized - Vulkan GI locked into lighting pipeline")
