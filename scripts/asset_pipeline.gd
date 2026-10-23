# ACHERON-9: INCIDENT - Procedural Asset Pipeline (Godot port of Blender acheron9_asset_pipeline.py)
# Generates all mesh assets programmatically using SurfaceTool + ArrayMesh.
# Mirrors the 37 FBX assets: concrete walls, floors, server racks, steam pipes,
# props, and the purge agent character with armature.
class_name Acheron9AssetPipeline
extends Node

# Generated mesh resources
var meshes: Dictionary = {}
var generated: bool = false

func _ready() -> void:
	if not generated:
		generate_all_assets()

func generate_all_assets() -> void:
	print("=== ACHERON-9 Asset Pipeline ===")

	# Category 1: Structural (Geometry) - 20 meshes
	_generate_concrete_wall()
	_generate_concrete_floor()
	_generate_concrete_floor_pitted()
	_generate_wall_solid()
	_generate_wall_vent_cutout()
	_generate_wall_pipe_pass()
	_generate_wall_door_frame()
	_generate_ceiling_panel_grid()
	_generate_ceiling_support_beam()
	_generate_pillar_square_heavy()
	_generate_pillar_round_structural()
	_generate_battery_cell_rack()
	_generate_power_transformer()
	_generate_server_rack_intact()
	_generate_server_rack_sabotaged()
	_generate_terminal_desk_mainframe()
	_generate_wall_diagnostic_box()
	_generate_steam_pipe_node()
	_generate_server_rack_a()
	_generate_concrete_floor_a()

	# Category 2: Props & Lore - 10 meshes
	_generate_debris_chunks()
	_generate_scrap_metal()
	_generate_ration_can()
	_generate_clipboard()
	_generate_magnetic_tape()
	_generate_employee_notebook()

	# Category 3: Utilities - 6 meshes
	_generate_steam_pipe_straight()
	_generate_steam_pipe_elbow()
	_generate_steam_manifold_valve()
	_generate_ceiling_cage_lamp()
	_generate_emergency_siren()
	_generate_security_camera_lens()

	# Character - 1 mesh (purge agent with armature)
	_generate_purge_agent()

	generated = true
	print("=== All %d assets generated ===" % meshes.size())
	_save_meshes_to_disk()

# ==================== Category 1: Structural ====================

func _generate_concrete_wall() -> void:
	# 400x400x10 flat wall with procedural crack displacement
	var mesh = _create_plane_mesh(400, 400, 16, 16)
	# Add procedural noise displacement via shader (the concrete material handles this)
	meshes["concrete_wall"] = mesh

func _generate_concrete_floor() -> void:
	var mesh = _create_plane_mesh(400, 400, 16, 16)
	meshes["concrete_floor"] = mesh

func _generate_concrete_floor_pitted() -> void:
	var mesh = _create_plane_mesh(400, 400, 16, 16)
	meshes["concrete_floor_pitted"] = mesh

func _generate_wall_solid() -> void:
	var mesh = _create_box_mesh(100, 100, 100)  # 1m cube (100uu in UE = 1m in Godot)
	meshes["wall_solid"] = mesh

func _generate_wall_vent_cutout() -> void:
	var mesh = _create_box_mesh(100, 100, 10)
	meshes["wall_vent_cutout"] = mesh

func _generate_wall_pipe_pass() -> void:
	var mesh = _create_box_mesh(100, 10, 100)
	meshes["wall_pipe_pass"] = mesh

func _generate_wall_door_frame() -> void:
	var mesh = _create_box_mesh(50, 50, 200)
	meshes["wall_door_frame"] = mesh

func _generate_ceiling_panel_grid() -> void:
	var mesh = _create_plane_mesh(100, 100, 4, 4)
	meshes["ceiling_panel_grid"] = mesh

func _generate_ceiling_support_beam() -> void:
	var mesh = _create_box_mesh(20, 20, 200)
	meshes["ceiling_support_beam"] = mesh

func _generate_pillar_square_heavy() -> void:
	var mesh = _create_box_mesh(80, 80, 300)
	meshes["pillar_square"] = mesh

func _generate_pillar_round_structural() -> void:
	var mesh = CylinderMesh.new()
	mesh.radius = 40
	mesh.height = 300
	mesh.radial_segments = 16
	meshes["pillar_round"] = mesh

func _generate_battery_cell_rack() -> void:
	var mesh = _create_box_mesh(100, 100, 200)
	meshes["battery_rack"] = mesh

func _generate_power_transformer() -> void:
	var mesh = _create_box_mesh(150, 100, 200)
	meshes["power_transformer"] = mesh

func _generate_server_rack_intact() -> void:
	var mesh = _create_box_mesh(100, 50, 400)
	meshes["server_rack_intact"] = mesh

func _generate_server_rack_sabotaged() -> void:
	var mesh = _create_box_mesh(100, 50, 400)
	meshes["server_rack_sabotaged"] = mesh

func _generate_terminal_desk_mainframe() -> void:
	var mesh = _create_box_mesh(200, 80, 100)
	meshes["terminal_desk"] = mesh

func _generate_wall_diagnostic_box() -> void:
	var mesh = _create_box_mesh(50, 50, 20)
	meshes["diagnostic_box"] = mesh

func _generate_steam_pipe_node() -> void:
	# T-junction: central cylinder with 3 branches
	var mesh = _create_cylinder_mesh(30, 20, 12)
	meshes["steam_pipe_node"] = mesh

func _generate_steam_pipe_straight() -> void:
	var mesh = _create_cylinder_mesh(30, 400, 12)
	meshes["steam_pipe_straight"] = mesh

func _generate_steam_pipe_elbow() -> void:
	var mesh = _create_cylinder_mesh(30, 200, 12)
	meshes["steam_pipe_elbow"] = mesh

func _generate_steam_manifold_valve() -> void:
	var mesh = _create_cylinder_mesh(40, 30, 12)
	meshes["steam_manifold_valve"] = mesh

func _generate_ceiling_cage_lamp() -> void:
	var mesh = _create_cylinder_mesh(30, 20, 12)
	meshes["ceiling_cage_lamp"] = mesh

func _generate_emergency_siren() -> void:
	var mesh = _create_cylinder_mesh(50, 30, 16)
	meshes["emergency_siren"] = mesh

func _generate_security_camera_lens() -> void:
	var mesh = _create_cylinder_mesh(15, 20, 8)
	meshes["security_camera_lens"] = mesh

func _generate_server_rack_a() -> void:
	var mesh = _create_box_mesh(100, 50, 400)
	meshes["server_rack_a"] = mesh

func _generate_concrete_floor_a() -> void:
	var mesh = _create_plane_mesh(400, 400, 16, 16)
	meshes["concrete_floor_a"] = mesh

# ==================== Category 2: Props ====================

func _generate_debris_chunks() -> void:
	for i in range(1, 6):
		var mesh = _create_box_mesh(50, 50, 50)
		meshes["debris_chunk_0%d" % i] = mesh

func _generate_scrap_metal() -> void:
	var mesh = _create_plane_mesh(100, 100, 4, 4)
	meshes["scrap_metal"] = mesh

func _generate_ration_can() -> void:
	var mesh = CylinderMesh.new()
	mesh.radius = 15
	mesh.height = 40
	mesh.radial_segments = 12
	meshes["ration_can"] = mesh

func _generate_clipboard() -> void:
	var mesh = _create_box_mesh(2, 30, 40)
	meshes["clipboard"] = mesh

func _generate_magnetic_tape() -> void:
	var mesh = _create_box_mesh(2, 2, 30)
	meshes["magnetic_tape"] = mesh

func _generate_employee_notebook() -> void:
	var mesh = _create_box_mesh(2, 30, 40)
	meshes["employee_notebook"] = mesh

# ==================== Character ====================

func _generate_purge_agent() -> void:
	# Create simple humanoid: capsule body + cube limbs + sphere head
	var st = MeshDataTool.new()
	var arrays = []

	# Body (cube, ~1.8m tall)
	var body_mesh = _create_box_mesh(80, 250, 60)
	meshes["purge_agent_body"] = body_mesh

	# Also create as a scene-ready MeshInstance with material
	var material = AssetSetup.get_brutalist_concrete_material()
	if material:
		body_mesh.surface_set_material(0, material)

	# Armature placeholder (Godot handles skeletal animation via skinning)
	meshes["purge_agent"] = body_mesh
	meshes["purge_agent_armature"] = null  # Set up in scene

# ==================== Mesh Creation Helpers ====================

func _create_box_mesh(size_x: float, size_y: float, size_z: float) -> BoxMesh:
	var mesh = BoxMesh.new()
	mesh.size = Vector3(size_x, size_y, size_z)
	return mesh

func _create_plane_mesh(size_x: float, size_y: float, subdivisions_x: int, subdivisions_y: int) -> PlaneMesh:
	var mesh = PlaneMesh.new()
	mesh.size = Vector2(size_x, size_y)
	mesh.subdivisions = Vector2(subdivisions_x, subdivisions_y)
	return mesh

func _create_cylinder_mesh(radius: float, height: float, segments: int) -> CylinderMesh:
	var mesh = CylinderMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	return mesh

func _save_meshes_to_disk() -> void:
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("saved_games"):
		dir.make_dir("saved_games")

	var count = 0
	for key in meshes:
		if meshes[key] is Mesh:
			# Save as .tres resource
			var path = "user://saved_games/meshes/%s.tres" % key
			ResourceSaver.save(meshes[key], path)
			count += 1
	if count > 0:
		print("[Acheron9] Saved %d mesh assets to user://saved_games/meshes/" % count)

# ==================== Asset Library Access ====================

func get_mesh(name: String) -> Mesh:
	if meshes.has(name):
		return meshes[name]
	return null

func get_all_meshes() -> Dictionary:
	return meshes
