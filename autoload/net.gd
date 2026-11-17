extends Node

signal connected
signal disconnected(reason: String)
signal request_received(sender: int, action: String, data: Dictionary)
signal peer_left(peer_id: int)
signal room_changed(state: Dictionary)
signal room_failed(reason: String)
signal snapshot_received(state: Dictionary)
signal events_received(events: Array)
signal pong_received(stamp: int)
var peer: ENetMultiplayerPeer
var room: Dictionary = {}
var server_mode := false

func _ready() -> void:
	multiplayer.connected_to_server.connect(func(): connected.emit())
	multiplayer.connection_failed.connect(func(): disconnected.emit("connect_failed"))
	multiplayer.server_disconnected.connect(func(): room.clear(); disconnected.emit("server_lost"))
	multiplayer.peer_connected.connect(func(id: int): if server_mode: log_line("connect %d" % id))
	multiplayer.peer_disconnected.connect(func(id: int):
		if server_mode:
			log_line("disconnect %d" % id)
			peer_left.emit(id)
	)

func start_server(port: int = GameConfig.NET_PORT) -> Error:
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_server(port, GameConfig.NET_MAX_PEERS, 3)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		server_mode = true
		log_line("listen UDP %d" % port)
	return error

func join_server(address: String, port: int = GameConfig.NET_PORT) -> Error:
	leave_server()
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port, 3)
	if error == OK: multiplayer.multiplayer_peer = peer
	return error

func leave_server() -> void:
	if peer != null: peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peer = null
	room.clear()
	server_mode = false

func log_line(message: String) -> void:
	print("[%s] %s" % [Time.get_datetime_string_from_system(), message])

func _receive(action: String, data: Dictionary) -> void:
	if server_mode:
		request_received.emit(multiplayer.get_remote_sender_id(), action, data)

@rpc("any_peer", "call_remote", "reliable")
func create_room(nick: String, character: String, cosmetics: Dictionary, version: String) -> void:
	_receive("create", {"nick": nick, "character": character, "cosmetics": cosmetics, "version": version})

@rpc("any_peer", "call_remote", "reliable")
func join_room(code: String, nick: String, character: String, cosmetics: Dictionary, version: String) -> void:
	_receive("join", {"code": code, "nick": nick, "character": character, "cosmetics": cosmetics, "version": version})

@rpc("any_peer", "call_remote", "reliable")
func leave_room() -> void:
	_receive("leave", {})

@rpc("any_peer", "call_remote", "reliable")
func lobby_action(action: String, data: Dictionary = {}) -> void:
	if action.length() <= 24: _receive(action, data)

@rpc("authority", "call_remote", "reliable")
func room_joined(code: String, state: Dictionary) -> void:
	state["code"] = code
	room_state(state)

@rpc("any_peer", "call_remote", "reliable")
func ping(stamp: int) -> void:
	_receive("ping", {"stamp": stamp})

@rpc("authority", "call_remote", "reliable")
func pong(stamp: int) -> void:
	pong_received.emit(stamp)

@rpc("authority", "call_remote", "reliable")
func room_state(state: Dictionary) -> void:
	room = state
	room_changed.emit(room)

@rpc("authority", "call_remote", "reliable")
func room_error(reason: String) -> void:
	room_failed.emit(reason)

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func match_snapshot(state: Dictionary) -> void:
	snapshot_received.emit(state)

@rpc("authority", "call_remote", "reliable", 2)
func match_events(events: Array) -> void:
	events_received.emit(events)
