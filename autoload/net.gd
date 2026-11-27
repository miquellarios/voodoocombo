extends Node

const SNAPSHOT_CODEC = preload("res://net/snapshot_codec.gd")

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
var snapshot_sequences: Dictionary = {}
var incoming_sequence := -1
var last_complete_sequence := -1
var incoming_chunks: Dictionary = {}
var snapshots_received := 0
var snapshots_lost := 0
var snapshot_loss_percent := 0.0
var snapshot_player_template: Array = []
var hosted_server_pid := -1
var hosted_server_ip := ""

func _ready() -> void:
	get_tree().root.tree_exiting.connect(stop_host_server, CONNECT_ONE_SHOT)
	multiplayer.connected_to_server.connect(func(): connected.emit())
	multiplayer.connection_failed.connect(func(): disconnected.emit("connect_failed"))
	multiplayer.server_disconnected.connect(func(): room.clear(); disconnected.emit("server_lost"))
	multiplayer.peer_connected.connect(func(id: int): if server_mode: log_line("connect %d" % id))
	multiplayer.peer_disconnected.connect(func(id: int):
		if server_mode:
			log_line("disconnect %d" % id)
			peer_left.emit(id)
	)

func start_host_server(port: int = GameConfig.NET_PORT) -> int:
	if hosted_server_pid > 0 and OS.is_process_running(hosted_server_pid): return hosted_server_pid
	var log_path := ProjectSettings.globalize_path("user://logs/servidor.log")
	hosted_server_pid = OS.create_process(OS.get_executable_path(), hosted_server_arguments(port, log_path, OS.has_feature("editor")))
	return hosted_server_pid

func hosted_server_arguments(port: int, log_path: String, from_editor: bool) -> PackedStringArray:
	var arguments: PackedStringArray = []
	if from_editor:
		arguments.append_array(["--path", ProjectSettings.globalize_path("res://")])
	arguments.append_array(["--headless", "--log-file", log_path, "--", "--server", "--port", str(port)])
	return arguments

func stop_host_server() -> void:
	if hosted_server_pid > 0:
		if OS.is_process_running(hosted_server_pid): OS.kill(hosted_server_pid)
		hosted_server_pid = -1
		hosted_server_ip = ""

func start_server(port: int = GameConfig.NET_PORT) -> Error:
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_server(port, GameConfig.NET_MAX_PEERS, GameConfig.NET_CHANNEL_COUNT)
	if error == OK:
		multiplayer.server_relay = false
		multiplayer.multiplayer_peer = peer
		server_mode = true
		log_line("listen UDP %d" % port)
	return error

func join_server(address: String, port: int = GameConfig.NET_PORT) -> Error:
	leave_server()
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port, GameConfig.NET_CHANNEL_COUNT)
	if error == OK: multiplayer.multiplayer_peer = peer
	return error

func leave_server() -> void:
	if peer != null: peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peer = null
	room.clear()
	server_mode = false
	incoming_sequence = -1
	last_complete_sequence = -1
	incoming_chunks.clear()
	snapshot_sequences.clear()
	snapshots_received = 0
	snapshots_lost = 0
	snapshot_loss_percent = 0.0
	snapshot_player_template.clear()

func log_line(message: String) -> void:
	print("[%s] %s" % [Time.get_datetime_string_from_system(), message])

func _receive(action: String, data: Dictionary) -> void:
	if server_mode:
		request_received.emit(multiplayer.get_remote_sender_id(), action, data)

@rpc("any_peer", "call_remote", "reliable")
func create_room(nick: String, character: String, cosmetics: Dictionary, version: String, mode: String = "voodoo") -> void:
	_receive("create", {"nick": nick, "character": character, "cosmetics": cosmetics, "version": version, "mode": mode})

@rpc("any_peer", "call_remote", "reliable")
func join_room(code: String, nick: String, character: String, cosmetics: Dictionary, version: String) -> void:
	_receive("join", {"code": code, "nick": nick, "character": character, "cosmetics": cosmetics, "version": version})

@rpc("any_peer", "call_remote", "reliable")
func leave_room() -> void:
	_receive("leave", {})

@rpc("any_peer", "call_remote", "reliable")
func lobby_action(action: String, data: Dictionary = {}) -> void:
	if action in ["ready", "bots", "mode", "cosmetics", "vote", "social", "rematch", "team", "duration"]: _receive(action, data)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func submit_input(seq: int, move: Vector2, dash: bool, spell: bool) -> void:
	_receive("input", {"seq": seq, "move": move, "dash": dash, "spell": spell})

@rpc("any_peer", "call_remote", "reliable", 2)
func intent(seq: int, action: String) -> void:
	if action in ["dash", "spell"]: _receive("intent", {"seq": seq, "action": action})

@rpc("authority", "call_remote", "reliable")
func room_joined(code: String, state: Dictionary) -> void:
	state["code"] = code
	room_state(state)

@rpc("any_peer", "call_remote", "unreliable", GameConfig.NET_PING_CHANNEL)
func ping(stamp: int) -> void:
	_receive("ping", {"stamp": stamp})

@rpc("authority", "call_remote", "unreliable", GameConfig.NET_PING_CHANNEL)
func pong(stamp: int) -> void:
	pong_received.emit(stamp)

@rpc("authority", "call_remote", "reliable")
func room_state(state: Dictionary) -> void:
	room = state
	if state.get("initial", {}).has("players"):
		snapshot_player_template = state.initial.players.duplicate(true)
	room_changed.emit(room)

@rpc("authority", "call_remote", "reliable")
func room_error(reason: String) -> void:
	room_failed.emit(reason)

func can_send(id: int) -> bool:
	return peer != null and id in multiplayer.get_peers() and peer.get_peer(id).get_state() == ENetPacketPeer.STATE_CONNECTED

func send_snapshot(id: int, state: Dictionary) -> void:
	if not can_send(id): return
	var serial := int(snapshot_sequences.get(id, 0)) + 1
	snapshot_sequences[id] = serial
	var raw := var_to_bytes(state)
	var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)
	if packed.size() > GameConfig.NET_CHUNK_BYTES: push_warning("Snapshot de %d B: supera el límite de un paquete" % packed.size())
	var total := ceili(float(packed.size()) / GameConfig.NET_CHUNK_BYTES)
	for part in total:
		snapshot_chunk.rpc_id(id, serial, part, total, raw.size(), packed.slice(part * GameConfig.NET_CHUNK_BYTES, (part + 1) * GameConfig.NET_CHUNK_BYTES))

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func snapshot_chunk(serial: int, part: int, total: int, raw_size: int, data: PackedByteArray) -> void:
	if serial < incoming_sequence or raw_size < 1 or raw_size > GameConfig.NET_MAX_SNAPSHOT_BYTES or total < 1 or total > 64 or part < 0 or part >= total or data.size() > GameConfig.NET_CHUNK_BYTES: return
	if serial > incoming_sequence:
		if last_complete_sequence >= 0 and serial > last_complete_sequence + 1:
			snapshots_lost += serial - last_complete_sequence - 1
		incoming_sequence = serial
		incoming_chunks.clear()
	incoming_chunks[part] = data
	if incoming_chunks.size() != total: return
	var packed := PackedByteArray()
	for index in total: packed.append_array(incoming_chunks[index])
	var decoded: Variant = bytes_to_var(packed.decompress(raw_size, FileAccess.COMPRESSION_ZSTD))
	incoming_chunks.clear()
	if decoded is Dictionary:
		last_complete_sequence = serial
		snapshots_received += 1
		var observed := snapshots_received + snapshots_lost
		snapshot_loss_percent = 100.0 * float(snapshots_lost) / maxf(1.0, float(observed))
		var restored := SNAPSHOT_CODEC.restore(decoded)
		if restored.has("pv") and not snapshot_player_template.is_empty():
			restored["players"] = SNAPSHOT_CODEC.expand_players(restored, snapshot_player_template)
			restored.erase("pv")
		snapshot_received.emit(restored)

@rpc("authority", "call_remote", "reliable", 2)
func match_events(events: Array) -> void:
	for event: Dictionary in events:
		if event.get("snapshot", {}).has("players"):
			snapshot_player_template = event.snapshot.players.duplicate(true)
	events_received.emit(events)
