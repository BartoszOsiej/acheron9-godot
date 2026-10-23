# ACHERON-9: INCIDENT - Material and Input Asset Setup Helper
# Godot port of Acheron9AssetSetup.cpp/h
# Creates runtime materials (brutalist concrete, blood decal) and registers input actions.
class_name AssetSetup
extends Node

# === Materials ===
var brutalist_concrete_material: ShaderMaterial
var blood_decal_material: ShaderMaterial

# === Input action config ===
# Maps UE EnhancedInput actions to Godot input map keys.
# In Godot, input is handled via InputMap in project.godot + Input singleton.
# This singleton mirrors Acheron9AssetSetup's getter pattern for compatibility.
var input_actions: Dictionary = {}

func _ready() -> void:
	create_materials()
	create_input_actions()
	print("[Acheron9] AssetSetup online - PROBOS-Core assets initialized")

# ==================== MATERIALS ====================

func create_materials() -> void:
	create_brutalist_concrete_material()
	create_blood_decal_material()

func create_brutalist_concrete_material() -> ShaderMaterial:
	var material = ShaderMaterial.new()
	material.shader = preload("res://shaders/concrete_material.gdshader")
	material.set_shader_parameter("roughness", 0.9)
	material.set_shader_parameter("metallic", 0.05)
	material.set_shader_parameter("base_color", Color(0.32, 0.32, 0.35, 1.0))
	material.set_shader_parameter("dirt_amount", 0.3)
	material.set_shader_parameter("moisture_amount", 0.0)
	material.set_shader_parameter("normal_scale", 0.8)
	brutalist_concrete_material = material
	return material

func create_blood_decal_material() -> ShaderMaterial:
	var material = ShaderMaterial.new()
	material.shader = preload("res://shaders/blood_decal.gdshader")
	material.set_shader_parameter("roughness", 0.75)
	material.set_shader_parameter("metallic", 0.0)
	material.set_shader_parameter("specular", 0.05)
	material.set_shader_parameter("opacity", 0.8)
	material.set_shader_parameter("base_color", Color(0.12, 0.02, 0.02, 1.0))
	blood_decal_material = material
	return material

# ==================== INPUT ====================

func create_input_actions() -> void:
	# In Godot 4, the InputMap is defined in project.godot.
	# We mirror the UE EnhancedInput actions as a lookup table
	# so other systems can query bindings programmatically.
	input_actions = {
		"move": ["w", "a", "s", "d", "up", "left", "down", "right"],
		"look": ["mouse_motion"],
		"jump": ["space"],
		"slide": ["ctrl"],
		"interact": ["f"],
		"toggle_crt": ["f11"],
	}
	print("[Acheron9] Input actions registered (WASD, mouse look, jump, slide, interact)")

# ==================== GETTERS ====================

func get_brutalist_concrete_material() -> ShaderMaterial:
	if not brutalist_concrete_material:
		create_brutalist_concrete_material()
	return brutalist_concrete_material

func get_blood_decal_material() -> ShaderMaterial:
	if not blood_decal_material:
		create_blood_decal_material()
	return blood_decal_material
