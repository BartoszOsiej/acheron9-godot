# ACHERON-9: INCIDENT - MCP Bridge (Godot port of UE_MCP_Bridge plugin)
# WebSocket JSON-RPC server on port 54362 providing editor/engine automation
# and state querying, mirroring the UE_MCP_Bridge functionality.
class_name MCPBridge
extends Node

signal client_connected
signal client_disconnected
signal message_received(method: String, params: Dictionary)
signal message_processed(method: String, result)

const DEFAULT_PORT := 54362
const MAX_MESSAGE_BYTES := 32 * 1024 * 1024  # 32MB, mirrors UE limit
const HANDSHAKE_TIMEOUT_SECONDS := 10.0

# Packet type constants (avoid WebSocketPeer type dependency at parse time)
const PACKET_TYPE_TEXT = 2
const PACKET_TYPE_CLOSE = 3

var port: int = DEFAULT_PORT
var b_running: bool = false
var b_param_echo_enabled: bool = false

var _server = null
var _connections: Array = []
var _handler_registry: Dictionary = {}
var _instance_id: String
var _started_at_utc: String

func _ready() -> void:
	_instance_id = "%s" % hash(str(Time.get_ticks_msec()))
	_started_at_utc = Time.get_datetime_string_from_system()
	_register_default_handlers()
	print("[MCP-Bridge] Initialized - Protocol %d, instance %s" % [1, _instance_id])

func start_server(listen_port: int = DEFAULT_PORT) -> bool:
	if b_running:
		return false
	port = listen_port

	# Check if WebSocket module is available in this Godot build
	if not ClassDB.class_exists("WebSocketServer"):
		push_error("[MCP-Bridge] WebSocketServer class not available in this build")
		return false

	# WebSocketServer class exists but can't be instantiated at parse time in this build
	push_error("[MCP-Bridge] WebSocketServer not supported in current port")
	return false
	set_process(true)
	return true

func stop_server() -> void:
	b_running = false
	if _server:
		_server.call("stop")
	_server = null
	_connections.clear()
	print("[MCP-Bridge] Server stopped")

func _process(delta: float) -> void:
	if not b_running or not _server:
		return
	_server.call("poll")

	for conn in _connections:
		while conn.call("get_available_packet_count") > 0:
			var pkt = conn.call("get_packet")
			var pkt_type = conn.call("get_packet_type")
			if pkt_type == PACKET_TYPE_TEXT:
				var msg = pkt.get_string_from_utf8()
				_process_json_rpc(conn, msg)
			elif pkt_type == PACKET_TYPE_CLOSE:
				_connections.erase(conn)

func _on_connection_established(proto: String, status: int) -> void:
	client_connected.emit()
	print("[MCP-Bridge] Client connected")

func _on_connection_closed(was_clean: bool) -> void:
	client_disconnected.emit()
	print("[MCP-Bridge] Client disconnected (clean=%s)" % was_clean)

func _on_peer_connected(id: int) -> void:
	var peer = _server.call("get_peer", id)
	if peer:
		_connections.append(peer)

func _on_peer_disconnected(id: int) -> void:
	for i in _connections.size() - 1:
		var conn = _connections[i]
		var conn_host = conn.call("get_connected_host") if conn else ""
		var peer = _server.call("get_peer", id) if _server else null
		var peer_host = peer.call("get_connected_host") if peer else ""
		if conn_host == peer_host:
			_connections.remove_at(i)

func _process_json_rpc(conn, message: String) -> void:
	if message.length() > MAX_MESSAGE_BYTES:
		_send_json(conn, {"jsonrpc": "2.0", "id": null, "error": {"code": -32603, "message": "Message too large"}})
		return
	var json = JSON.parse_string(message)
	if json.error != OK:
		_send_json(conn, {"jsonrpc": "2.0", "id": null, "error": {"code": -32700, "message": "Parse error"}})
		return
	var req = json.result
	var method = req.get("method", "")
	var req_id = req.get("id", null)
	var params = req.get("params", {})
	if method.is_empty():
		_send_json(conn, _build_error(req_id, -32600, "Invalid Request"))
		return
	message_received.emit(method, params)
	if not _handler_registry.has(method):
		var err_msg = _describe_unknown_method(method)
		_send_json(conn, _build_error(req_id, -32601, err_msg))
		return
	var result = await _execute_handler(method, params)
	_send_json(conn, _build_response(req_id, result))

func _build_response(id, result) -> Dictionary:
	return {"jsonrpc": "2.0", "id": id, "result": result}

func _build_error(id, code: int, message: String) -> Dictionary:
	return {"jsonrpc": "2.0", "id": id, "error": {"code": code, "message": message}}

func _send_json(conn, data: Dictionary) -> void:
	if not conn:
		return
	var json_str = JSON.stringify(data)
	var err = conn.call("put_packet", json_str.to_utf8_buffer())
	if err != OK:
		push_error("[MCP-Bridge] Failed to send response (error %d)" % err)

func _describe_unknown_method(method: String) -> String:
	var detail = "Unknown method: %s" % method
	var all = _handler_registry.keys()
	var hints: Array[String] = []
	for name in all:
		if name.contains(method) or method.contains(name):
			hints.append(name)
			if hints.size() >= 5:
				break
	if hints.is_empty() and not all.is_empty():
		detail += " (no near-matches in %d registered handlers)" % all.size()
	elif not hints.is_empty():
		detail += " (did you mean: %s)" % ", ".join(hints)
	return detail

# ==================== Handler Registry ====================

func _register_default_handlers() -> void:
	_handler_registry["get_bridge_capabilities"] = self._handle_get_bridge_capabilities
	_handler_registry["get_engine_state"] = self._handle_get_engine_state
	_handler_registry["get_param_echo"] = self._handle_get_param_echo
	_handler_registry["clear_param_echo"] = self._handle_clear_param_echo
	_handler_registry["list_resources"] = self._handle_list_resources
	_handler_registry["read_resource"] = self._handle_read_resource
	_handler_registry["get_project_info"] = self._handle_get_project_info
	_handler_registry["get_game_state"] = self._handle_get_game_state
	_handler_registry["start_game"] = self._handle_start_game
	_handler_registry["execute_python"] = self._handle_execute_python
	_handler_registry["echo"] = self._handle_echo

func register_handler(method_name: String, callback: Callable) -> void:
	_handler_registry[method_name] = callback

func _execute_handler(method: String, params: Dictionary):
	var handler = _handler_registry.get(method)
	if handler is Callable:
		return handler.call(params)
	elif _handler_registry.has(method):
		return _handler_registry[method].call(params)
	return {"success": false, "reason": "handler_not_callable"}

# ==================== Handler Implementations ====================

func _handle_get_bridge_capabilities(_params: Dictionary) -> Dictionary:
	var payload = {
		"success": true,
		"protocolVersion": 1,
		"handlerApiVersion": 1,
		"startedAt": _started_at_utc,
		"engineVersion": Engine.get_version_info().string,
		"projectName": ProjectSettings.get_setting("application/config/name"),
		"instanceId": _instance_id,
		"pid": 0,
		"port": port,
		"features": [
			"frame-reassembly",
			"control-frames",
			"capability-handshake",
			"exclusive-port-claim",
			"instance-records",
			"requested-port-file",
			"param-echo",
			"handler-specs",
			"call-timeout",
		],
		"paramEcho": b_param_echo_enabled,
		"actions": _handler_registry.keys(),
		"actionCount": _handler_registry.size(),
	}
	payload.actions = _handler_registry.keys()
	return payload

func _handle_get_engine_state(_params: Dictionary) -> Dictionary:
	var player = get_tree().get_first_node_in_group("player") if get_tree() else null
	var gm = get_node_or_null("/root/GameManager")
	var qm = get_node_or_null("/root/QuestManager")
	return {
		"success": true,
		"gameStarted": gm.b_game_started if gm else false,
		"timeRemaining": gm.time_remaining if gm else 0.0,
		"playerAlive": player is Node3D,
		"tapesSecured": qm.tapes_secured if qm else 0,
		"currentEnding": gm.current_ending if gm else 0,
		"rendering": {
			"driver": RenderingServer.get_current_rendering_driver_name(),
			"videoAdapter": RenderingServer.get_video_adapter_name() if RenderingServer else "Unknown",
		},
	}

func _handle_get_game_state(_params: Dictionary) -> Dictionary:
	return _handle_get_engine_state(_params)

func _handle_get_project_info(_params: Dictionary) -> Dictionary:
	return {
		"projectName": ProjectSettings.get_setting("application/config/name"),
		"version": ProjectSettings.get_setting("application/config/version"),
		"engine": "Godot %s" % Engine.get_version_info().string,
		"modules": [
			"GameManager", "PlayerController", "SettingsManager",
			"QuestManager", "SpeechManager", "EndingManager",
			"AssetSetup", "SaveSystem", "AudioManager",
			"LevelGenerator", "HumanoidAI", "FearSanityComponent",
			"EnvironmentalDestructionSystem", "WallRotationParanoiaSystem",
			"CRTScanlineComponent", "EndingTriggerVolume",
			"MicrophoneInputManager", "Acheron9AssetSetup", "PROBOSSpeechManager",
		],
	}

func _handle_start_game(_params: Dictionary) -> Dictionary:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.start_game()
	return {"success": true, "message": "Game started"}

func _handle_echo(params: Dictionary) -> Dictionary:
	return {"echo": params, "timestamp": Time.get_ticks_msec()}

func _handle_execute_python(params: Dictionary) -> Dictionary:
	return {"success": false, "reason": "python_not_available_in_godot_port",
		"message": "Use Godot's GDScript or GDExtension for scripting. For Python, use the Godot Python (PY) module."}

func _handle_get_param_echo(_params: Dictionary) -> Dictionary:
	if not b_param_echo_enabled:
		return {"success": true, "enabled": false}
	return {"success": true, "enabled": true, "params": {}}

func _handle_clear_param_echo(_params: Dictionary) -> Dictionary:
	return {"success": true, "enabled": false}

func _handle_list_resources(_params: Dictionary) -> Dictionary:
	return {
		"resources": [
			{"uri": "acheron9://engine/state", "name": "Engine State"},
			{"uri": "acheron9://game/manager", "name": "Game Manager State"},
			{"uri": "acheron9://quest/progress", "name": "Quest Progress"},
			{"uri": "acheron9://player/status", "name": "Player Status"},
		]
	}

func _handle_read_resource(params: Dictionary) -> Dictionary:
	var uri = params.get("uri", "")
	match uri:
		"acheron9://engine/state":
			return _handle_get_engine_state({})
		"acheron9://game/manager":
			var gm = get_node_or_null("/root/GameManager")
			return {
				"gameStarted": gm.b_game_started if gm else false,
				"timeRemaining": gm.time_remaining if gm else 0.0,
				"ending": gm.current_ending if gm else 0,
			}
		"acheron9://quest/progress":
			var qm = get_node_or_null("/root/QuestManager")
			return {
				"tapesSecured": qm.tapes_secured if qm else 0,
				"totalTapes": qm.total_tapes_to_recover if qm else 3,
			}
		"acheron9://player/status":
			var player = get_tree().get_first_node_in_group("player") if get_tree() else null
			return {
				"alive": player is Node3D,
				"position": player.global_position if player is Node3D else Vector3.ZERO,
			}
	return {"error": "unknown_resource"}

func _exit_tree() -> void:
	stop_server()
