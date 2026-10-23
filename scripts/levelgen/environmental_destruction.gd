# ACHERON-9: INCIDENT - EnvironmentalDestructionSystem (Godot port of AEnvironmentalDestructionSystem)
# Physics-based debris with non-linear gravity, mass scaling, and cleanup for sabotage events.
class_name EnvironmentalDestructionSystem
extends Node3D

signal destruction_triggered(asset_name: String)
signal asset_destroyed(asset_name: String, asset_index: int)

# Destructible types (mirrors UE enum)
enum DestructibleType { SERVER_RACK, LIGHT_FIXTURE, PIPE, STORAGE_UNIT }
enum DestructionImpulse { LIGHT, MEDIUM, HEAVY, CATASTROPHIC }

# Destructible profile (mirrors UE FDestructibleProfile)
class DestructibleProfile:
	var type: int = DestructibleType.SERVER_RACK
	var mass_kg: float = 100.0
	var impulse_strength: float = 1000.0
	var impulse_tier: int = DestructionImpulse.HEAVY
	var b_enable_physics_on_drop: bool = true
	var linear_damping: float = 0.1
	var angular_damping: float = 0.1
	var gravity_scale: Vector3 = Vector3(0, 0, -980.0)
	var mesh: Mesh = null

# Config
@export var max_concurrent_physics: int = 50
@export var physics_cleanup_interval: float = 5.0

# State
var destructible_profiles: Dictionary = {}
var active_physics_actors: Array[Node3D] = []

var _cleanup_timer: Timer

func _ready() -> void:
	initialize_profiles()

	_cleanup_timer = Timer.new()
	_cleanup_timer.wait_time = physics_cleanup_interval
	_cleanup_timer.one_shot = false
	_cleanup_timer.autostart = true
	add_child(_cleanup_timer)
	_cleanup_timer.timeout.connect(_on_physics_cleanup_timer_elapsed)

func initialize_profiles() -> void:
	# Server Rack - heavy, high mass, catastrophic impulse
	var server_rack = DestructibleProfile.new()
	server_rack.type = DestructibleType.SERVER_RACK
	server_rack.mass_kg = 250.0
	server_rack.impulse_strength = 5000.0
	server_rack.impulse_tier = DestructionImpulse.CATASTROPHIC
	server_rack.linear_damping = 0.05
	server_rack.angular_damping = 0.08
	server_rack.gravity_scale = Vector3(0, 0, -1200.0)
	destructible_profiles["SM_Server_Rack_A"] = server_rack

	# Light fixture - light mass
	var light = DestructibleProfile.new()
	light.type = DestructibleType.LIGHT_FIXTURE
	light.mass_kg = 15.0
	light.impulse_strength = 500.0
	light.impulse_tier = DestructionImpulse.LIGHT
	light.linear_damping = 0.1
	light.angular_damping = 0.2
	light.gravity_scale = Vector3(0, 0, -980.0)
	destructible_profiles["SM_Light_Fixture"] = light

	# Pipe - medium, rolls
	var pipe = DestructibleProfile.new()
	pipe.type = DestructibleType.PIPE
	pipe.mass_kg = 80.0
	pipe.impulse_strength = 2000.0
	pipe.impulse_tier = DestructionImpulse.MEDIUM
	pipe.linear_damping = 0.02
	pipe.angular_damping = 0.05
	pipe.gravity_scale = Vector3(0, 0, -980.0)
	destructible_profiles["SM_Pipe"] = pipe

func trigger_sabotage(profile_name: String, location: Vector3, rotation: Vector3) -> void:
	if not destructible_profiles.has(profile_name):
		push_warning("[Acheron9] No destructible profile found for: %s" % profile_name)
		return

	var profile = destructible_profiles[profile_name]
	var asset_index = active_physics_actors.size()
	destruction_triggered.emit(profile_name)
	_spawn_destructible_asset(profile, location, rotation, asset_index)
	print("[Acheron9] Sabotage triggered: %s at (%d, %d, %d)" % [profile_name, location.x, location.y, location.z])

func trigger_server_rack_drop(location: Vector3, rotation: Vector3) -> void:
	trigger_sabotage("SM_Server_Rack_A", location, rotation)

func trigger_hallway_collapse(locations: Array[Vector3]) -> void:
	for i in locations.size():
		var drop_loc = locations[i]
		# Stagger drops for dramatic effect using deferred calls
		call_deferred("_trigger_server_rack_drop_deferred", drop_loc, Vector3.ZERO)

func _trigger_server_rack_drop_deferred(drop_loc: Vector3, drop_rot: Vector3) -> void:
	trigger_server_rack_drop(drop_loc, drop_rot)

func _spawn_destructible_asset(profile: DestructibleProfile, location: Vector3, rotation: Vector3, asset_index: int) -> void:
	if active_physics_actors.size() >= max_concurrent_physics:
		_cleanup_finished_physics()

	var mesh = profile.mesh
	if not mesh:
		mesh = get_editor_interface_or_fallback_cube()

	var debris = RigidBody3D.new()
	debris.name = "Debris_%d" % asset_index
	debris.position = location
	debris.rotation = rotation

	var mesh_comp = MeshInstance3D.new()
	mesh_comp.mesh = mesh
	debris.add_child(mesh_comp)
	debris.set_meta("mesh_comp", mesh_comp)

	# Configure physics
	_configure_physics(debris, profile, mesh_comp)
	get_tree().current_scene.add_child.call_deferred(debris)
	active_physics_actors.append(debris)

func _configure_physics(asset: RigidBody3D, profile: DestructibleProfile, mesh_comp: MeshInstance3D) -> void:
	# Set mass
	asset.mass = _calculate_non_linear_mass(profile.mass_kg, asset.global_position.distance_to(Vector3.ZERO))

	# Apply initial impulse for "drop" effect
	var impulse = Vector3(
		randf_range(-profile.impulse_strength * 0.1, profile.impulse_strength * 0.1),
		randf_range(-profile.impulse_strength * 0.1, profile.impulse_strength * 0.1),
		-profile.impulse_strength * 0.5
	)
	if profile.b_enable_physics_on_drop:
		asset.apply_central_impulse(impulse)

	# Apply non-linear gravity manually (Godot's RigidBody has fixed gravity)
	asset.gravity_scale = abs(profile.gravity_scale.y) / 980.0  # Scale relative to default

func _calculate_non_linear_mass(base_mass: float, distance_from_origin: float) -> float:
	# Exponentially scale mass for heavier objects dropping faster
	var distance_factor = clamp(pow(distance_from_origin / 10000.0, 0.3), 0.7, 2.0)
	return base_mass * distance_factor

func _calculate_gravity_velocity(current_position: Vector3, origin: Vector3, mass: float) -> Vector3:
	var direction = origin - current_position
	var distance = direction.length()
	direction = direction.normalized()
	var gravity_magnitude = -980.0 * mass * (1.0 + clamp(10000.0 / (distance + 100.0), 1.0, 5.0))
	return direction * gravity_magnitude

func apply_non_linear_gravity(target: Node3D, delta_time: float) -> void:
	if not target or not target is RigidBody3D:
		return
	var rb = target as RigidBody3D
	if not rb:
		return
	var current_pos = rb.global_position
	var mass = rb.mass
	var gravity_vel = _calculate_gravity_velocity(current_pos, Vector3.ZERO, mass)
	rb.apply_central_force(gravity_vel * mass * delta_time * 60.0)

func _on_physics_cleanup_timer_elapsed() -> void:
	_cleanup_finished_physics()

func _cleanup_finished_physics() -> void:
	for i in active_physics_actors.size() - 1:
		var actor = active_physics_actors[i]
		if not is_instance_valid(actor):
			active_physics_actors.remove_at(i)
			continue

		if not actor is RigidBody3D:
			active_physics_actors.remove_at(i)
			continue

		var mesh_comp = actor.get_meta("mesh_comp", null) as MeshInstance3D
		if mesh_comp and mesh_comp is MeshInstance3D:
			if actor.linear_velocity.length() < 1.0:
				asset_destroyed.emit(actor.name, i)
				if actor.global_position.y < -500.0:
					actor.queue_free()
					active_physics_actors.remove_at(i)

func is_asset_registered(asset_name: String) -> bool:
	for actor in active_physics_actors:
		if is_instance_valid(actor) and actor.name.contains(asset_name):
			return true
	return false

func stop_all_physics() -> void:
	for i in active_physics_actors.size() - 1:
		var actor = active_physics_actors[i]
		if is_instance_valid(actor) and actor is RigidBody3D:
			actor.linear_velocity = Vector3.ZERO
			actor.angular_velocity = Vector3.ZERO
			actor.gravity_scale = 0.0
			actor.queue_free()
	active_physics_actors.clear()

	if _cleanup_timer:
		_cleanup_timer.stop()
	print("[Acheron9] All physics simulation halted")

func get_editor_interface_or_fallback_cube() -> Mesh:
	# Create a simple cube mesh as fallback
	var cube = BoxMesh.new()
	cube.size = Vector3(100, 100, 100)
	return cube
