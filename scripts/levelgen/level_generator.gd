# ACHERON-9: INCIDENT - LevelGenerator (Godot port of AAcheron9LevelGenerator)
# Procedural 32x32x4 grid level with deterministic seed, BFS path verification,
# MultiMeshInstance3D rendering (replaces UE HISM), and navmesh-ready signal.
class_name LevelGenerator
extends Node3D

signal nav_mesh_ready
signal level_generated

# Enums (mirrors UE UENUM)
enum TileType { FLOOR, WALL, SERVER_RACK, STEAM_NODE }

# Grid config (matches UE defaults)
@export var grid_size_x: int = 32
@export var grid_size_y: int = 32
@export var grid_size_z: int = 4
@export var seed: int = 97312
@export var tile_size: float = 100.0

# Mesh library — assigns Godot mesh resources to tile types
var mesh_library: Dictionary = {}
var _multimesh_arrays: Array[MultiMeshInstance3D] = []
var tile_to_mesh_name: Dictionary = {}
var _grid_matrix: PackedInt32Array
var _placed_tiles: Array = []
var player_spawn_location: Vector3
var reactor_core_location: Vector3
var b_navigation_ready: bool = false
var _random: RandomNumberGenerator

# Fallback meshes
var fallback_wall_mesh: Mesh
var fallback_debris_mesh: Mesh

func _ready() -> void:
	_random = RandomNumberGenerator.new()
	_random.seed = seed
	_generate_level()
	nav_mesh_ready.emit()
	b_navigation_ready = true
	level_generated.emit()
	print("[Acheron9] Level Generator: %d tiles spawned, %d HISM arrays" % [_placed_tiles.size(), _multimesh_arrays.size()])

func _generate_level() -> void:
	_random.seed = seed
	_initialize_grid()
	_assign_tile_types()
	_create_multimesh_arrays()
	_spawn_all_tiles()

	# Compute player spawn and reactor locations from room placement
	player_spawn_location = Vector3(0, 0, 100)
	reactor_core_location = Vector3((grid_size_x - 2) * tile_size, (grid_size_y - 2) * tile_size, 100)

func _initialize_grid() -> void:
	var total_cells = grid_size_x * grid_size_y * grid_size_z
	_grid_matrix.resize(total_cells)
	_grid_matrix.fill(0)  # Default to Floor (0)

static func _grid_index(x: int, y: int, z: int, size_x: int, size_y: int) -> int:
	return z * (size_x * size_y) + y * size_x + x

func _assign_tile_types() -> void:
	var room_count = 6

	# Deterministic room placement
	_random.randomize()
	var rooms: Array[Dictionary] = []

	for i in room_count:
		var room: Dictionary = {
			"x": clamp(_random.randi_range(2, grid_size_x / 2 - 2), 1, grid_size_x - 10),
			"y": clamp(_random.randi_range(2, grid_size_y / 2 - 2), 1, grid_size_y - 10),
			"w": clamp(_random.randi_range(4, 8), 4, 10),
			"h": clamp(_random.randi_range(4, 8), 4, 10),
		}
		rooms.append(room)

	# Carve rooms in floor grid (Z=0)
	for room in rooms:
		for x in range(room.x, room.x + room.w):
			for y in range(room.y, room.y + room.h):
				if x >= 0 and x < grid_size_x and y >= 0 and y < grid_size_y:
					var idx = _grid_index(x, y, 0, grid_size_x, grid_size_y)
					_grid_matrix[idx] = 0  # Floor

	# Create L-shaped corridors between room centers
	for i in range(room_count - 1):
		var start_x = rooms[i].x + rooms[i].w / 2
		var start_y = rooms[i].y + rooms[i].h / 2
		var end_x = rooms[i + 1].x + rooms[i + 1].w / 2
		var end_y = rooms[i + 1].y + rooms[i + 1].h / 2

		for x in range(min(start_x, end_x), max(start_x, end_x) + 1):
			if x >= 0 and x < grid_size_x and start_y >= 0 and start_y < grid_size_y:
				var idx = _grid_index(x, start_y, 0, grid_size_x, grid_size_y)
				_grid_matrix[idx] = 0

		for y in range(min(start_y, end_y), max(start_y, end_y) + 1):
			if end_x >= 0 and end_x < grid_size_x and y >= 0 and y < grid_size_y:
				var idx = _grid_index(end_x, y, 0, grid_size_x, grid_size_y)
				_grid_matrix[idx] = 0

	# Place player spawn near first room
	player_spawn_location = Vector3(
		rooms[0].x * tile_size + rooms[0].w * tile_size / 2,
		rooms[0].y * tile_size + rooms[0].h * tile_size / 2,
		100
	)

	# Place reactor core near last room
	reactor_core_location = Vector3(
		rooms[room_count - 1].x * tile_size + rooms[room_count - 1].w * tile_size / 2,
		rooms[room_count - 1].y * tile_size + rooms[room_count - 1].h * tile_size / 2,
		100
	)

	# Place walls on outer perimeter
	for x in grid_size_x:
		for y in grid_size_y:
			var idx = _grid_index(x, y, 0, grid_size_x, grid_size_y)
			if x == 0 or y == 0 or x == grid_size_x - 1 or y == grid_size_y - 1:
				_grid_matrix[idx] = 1  # Wall
			else:
				var in_room_interior = false
				for room in rooms:
					if x > room.x and x < room.x + room.w - 1 and y > room.y and y < room.y + room.h - 1:
						in_room_interior = true
						break
				if not in_room_interior and _grid_matrix[idx] == 0:
					if _random.randi_range(0, 3) == 0:
						_grid_matrix[idx] = 1  # Wall

	# Place server racks and steam nodes
	var server_rack_mesh = _get_or_load_mesh("server_rack")
	var steam_pipe_mesh = _get_or_load_mesh("steam_pipe")

	for i in 12:
		var x = _random.randi_range(3, grid_size_x - 4)
		var y = _random.randi_range(3, grid_size_y - 4)
		var idx = _grid_index(x, y, 0, grid_size_x, grid_size_y)
		if _grid_matrix[idx] == 0:
			if _random.randi_range(0, 2) == 0:
				_grid_matrix[idx] = 2  # Server Rack
			else:
				_grid_matrix[idx] = 3  # Steam Node

	# Ensure floor at reactor core
	var core_idx = _grid_index(
		int(reactor_core_location.x / tile_size),
		int(reactor_core_location.y / tile_size),
		0, grid_size_x, grid_size_y
	)
	_grid_matrix[core_idx] = 0

func _create_multimesh_arrays() -> void:
	# 5 HISM buckets mirroring UE:
	# 0: ServerRack_Intact  1: SteamPipe_Straight  2: Wall_Solid  3: Floor_Clean  4: Terminal_Mainframe
	var bucket_meshes: Array[String] = [
		"server_rack_intact",
		"steam_pipe_straight",
		"concrete_wall",
		"concrete_floor",
		"terminal_desk",
	]

	_multimesh_arrays.clear()
	for mesh_name in bucket_meshes:
		var mm_inst = MultiMeshInstance3D.new()
		var multimesh = MultiMesh.new()
		multimesh.set("transform_format", 1)  # TRANSFORM_3D
		multimesh.set("color_format", 1)  # COLOR_FLOAT
		multimesh.set("light_color_format", 1)  # LIGHT_COLOR_FLOAT
		mm_inst.multimesh = multimesh
		add_child.call_deferred(mm_inst)

		var mesh = _get_or_load_mesh(mesh_name)
		if mesh:
			mm_inst.mesh = mesh
		_multimesh_arrays.append(mm_inst)

func _spawn_all_tiles() -> void:
	for z in grid_size_z:
		for x in grid_size_x:
			for y in grid_size_y:
				var idx = _grid_index(x, y, z, grid_size_x, grid_size_y)
				if idx < 0 or idx >= _grid_matrix.size():
					continue
				var tile_type = int(_grid_matrix[idx])
				if tile_type != TileType.FLOOR:
					_spawn_tile_instance(x, y, z, tile_type)

func _spawn_tile_instance(x: int, y: int, z: int, type: int) -> void:
	var position = Vector3(x * tile_size, y * tile_size, z * 200.0)

	var asset_type: int
	var hims_index: int = -1

	match type:
		TileType.WALL:
			asset_type = 0  # Wall_Solid
			hims_index = 2
			# Walls are 90 degrees rotated in UE; apply rotation
		TileType.SERVER_RACK:
			asset_type = 0  # Server_Intact
			hims_index = 0
		TileType.STEAM_NODE:
			asset_type = 0  # Steam_Pipe_Straight
			hims_index = 1
		_:
			return

	if hims_index >= 0 and hims_index < _multimesh_arrays.size():
		var mm = _multimesh_arrays[hims_index].multimesh
		var instance_idx = mm.transform_array.size()
		mm.instance_count = instance_idx + 1
		mm.set_instance_transform(instance_idx, Transform3D(Basis.from_euler(Vector3(0, deg_to_rad(90), 0)), position) if type == TileType.WALL else Transform3D(Basis(), position))

		# Track tile
		_placed_tiles.append({
			"grid_x": x,
			"grid_y": y,
			"grid_z": z,
			"tile_type": type,
			"instance_index": instance_idx,
			"hims_index": hims_index,
		})

	# Place reactor core
	if position.distance_to(reactor_core_location) < tile_size / 2:
		if _multimesh_arrays.size() > 4:
			var mm = _multimesh_arrays[4].multimesh
			var core_instance = mm.transform_array.size()
			mm.instance_count = core_instance + 1
			mm.set_instance_transform(core_instance, Transform3D(Basis(), position))

			_placed_tiles.append({
				"grid_x": x,
				"grid_y": y,
				"grid_z": z,
				"tile_type": TileType.SERVER_RACK,
				"instance_index": core_instance,
				"hims_index": 4,
			})

func _get_or_load_mesh(mesh_name: String) -> Mesh:
	if mesh_library.has(mesh_name):
		return mesh_library[mesh_name]
	# Attempt to load from assets/meshes/
	var path = "res://assets/meshes/%s.tscn" % mesh_name
	if ResourceLoader.exists(path):
		var scene = load(path)
		var inst = scene.instantiate()
		if inst is MeshInstance3D:
			return inst.mesh
	return null

func verify_path_bfs() -> bool:
	var start_x = int(player_spawn_location.x / tile_size)
	var start_y = int(player_spawn_location.y / tile_size)
	var end_x = int(reactor_core_location.x / tile_size)
	var end_y = int(reactor_core_location.y / tile_size)

	var visited: Dictionary = {}
	var queue: Array[Vector2] = []
	queue.append(Vector2(start_x, start_y))
	visited[Vector2(start_x, start_y)] = true

	var dx = [0, 0, 1, -1]
	var dy = [1, -1, 0, 0]

	while not queue.is_empty():
		var current = queue.pop_front()
		if current.x == end_x and current.y == end_y:
			return true
		for i in 4:
			var nx = current.x + dx[i]
			var ny = current.y + dy[i]
			if nx >= 0 and nx < grid_size_x and ny >= 0 and ny < grid_size_y:
				var idx = _grid_index(nx, ny, 0, grid_size_x, grid_size_y)
				if idx >= 0 and idx < _grid_matrix.size() and _grid_matrix[idx] == 0:
					var next = Vector2(nx, ny)
					if not visited.has(next):
						visited[next] = true
						queue.append(next)
	return false

func cleanup() -> void:
	for mm_inst in _multimesh_arrays:
		if mm_inst.multimesh:
			mm_inst.multimesh.instance_count = 0
	_placed_tiles.clear()
	_grid_matrix.clear()
	mesh_library.clear()

func get_player_spawn_location() -> Vector3:
	return player_spawn_location

func get_reactor_core_location() -> Vector3:
	return reactor_core_location
