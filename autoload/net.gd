extends Node

signal connection_message(text: String)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal lobby_snapshot(players: Array)

const PORT := 7777
const MAX_PLAYERS := 4
var peer := ENetMultiplayerPeer.new()
var is_host := false
var lobby_players: Dictionary = {}
var local_nick := "Jugador"

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(func():
		connection_message.emit("Conectado")
		request_join(local_nick)
	)
	multiplayer.connection_failed.connect(func(): connection_message.emit("No se pudo conectar"))
	multiplayer.server_disconnected.connect(func(): connection_message.emit("El anfitrión se desconectó"))
	if "--server" in OS.get_cmdline_user_args():
		create_server()

func create_server(nick: String = "Host") -> Error:
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, MAX_PLAYERS - 1)
	if error != OK:
		connection_message.emit("No se pudo crear la sala (%d)" % error)
		return error
	if not HttpEndpoint.server.is_listening():
		HttpEndpoint.start()
	multiplayer.multiplayer_peer = peer
	is_host = true
	local_nick = nick
	lobby_players[1] = {"name": nick, "ready": true, "shape": GameConfig.SHAPES[0], "color": GameConfig.COLORS[0]}
	LanDiscovery.start_advertising({"name": "VoodooCombo", "host_nick": nick, "players": 1, "version": "1.0"})
	return OK

func join_server(address: String, nick: String = "Jugador") -> Error:
	peer = ENetMultiplayerPeer.new()
	local_nick = nick
	var error := peer.create_client(address, PORT)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		is_host = false
	else:
		connection_message.emit("IP incorrecta o sala inaccesible")
	return error

func leave_server() -> void:
	multiplayer.multiplayer_peer = null
	lobby_players.clear()
	is_host = false

func request_join(nick: String, _cosmetics: Dictionary = {}, version: String = "1.0") -> void:
	if multiplayer.is_server():
		_register_player(multiplayer.get_unique_id(), nick, version)
	else:
		_submit_join.rpc_id(1, nick, version)

@rpc("any_peer", "reliable")
func _submit_join(nick: String, version: String) -> void:
	if not multiplayer.is_server(): return
	_register_player(multiplayer.get_remote_sender_id(), nick, version)

func _register_player(id: int, nick: String, version: String) -> void:
	if lobby_players.size() >= MAX_PLAYERS: return
	if version != "1.0":
		connection_message.emit("Versión distinta del juego")
		return
	var slot := lobby_players.size()
	lobby_players[id] = {"name": nick.substr(0, 18), "ready": false, "shape": GameConfig.SHAPES[slot], "color": GameConfig.COLORS[slot]}
	peer_joined.emit(id)
	_publish_lobby.rpc(lobby_players.values())

func request_lobby_ready() -> void:
	if multiplayer.is_server():
		if lobby_players.has(1): lobby_players[1].ready = not lobby_players[1].ready
		_publish_lobby.rpc(lobby_players.values())
	else:
		_set_ready.rpc_id(1)

@rpc("any_peer", "reliable")
func _set_ready() -> void:
	var id := multiplayer.get_remote_sender_id()
	if lobby_players.has(id):
		lobby_players[id].ready = not lobby_players[id].ready
		_publish_lobby.rpc(lobby_players.values())

@rpc("authority", "call_local", "reliable")
func _publish_lobby(players: Array) -> void:
	lobby_snapshot.emit(players)

@rpc("any_peer", "unreliable_ordered")
func submit_position(position: Vector2, velocity: Vector2, facing: Vector2) -> void:
	if not multiplayer.is_server(): return
	var sender := multiplayer.get_remote_sender_id()
	if not lobby_players.has(sender) or velocity.length() > GameConfig.PLAYER_SPEED * 2.0: return
	_publish_position.rpc(sender, position, velocity, facing)

@rpc("authority", "unreliable_ordered")
func _publish_position(_peer_id: int, _position: Vector2, _velocity: Vector2, _facing: Vector2) -> void:
	pass

func request_dash(direction: Vector2) -> void:
	if multiplayer.is_server():
		broadcast_event.rpc("dash", multiplayer.get_unique_id(), direction)
	else:
		_request_action.rpc_id(1, "dash", direction)

func request_use_item(direction: Vector2 = Vector2.ZERO) -> void:
	if multiplayer.is_server():
		broadcast_event.rpc("use_item", multiplayer.get_unique_id(), direction)
	else:
		_request_action.rpc_id(1, "use_item", direction)

func request_rematch() -> void:
	if multiplayer.is_server(): broadcast_event.rpc("rematch", multiplayer.get_unique_id(), Vector2.ZERO)
	else: _request_action.rpc_id(1, "rematch", Vector2.ZERO)

@rpc("any_peer", "reliable")
func _request_action(action: String, direction: Vector2) -> void:
	if multiplayer.is_server(): broadcast_event.rpc(action, multiplayer.get_remote_sender_id(), direction)

@rpc("authority", "call_local", "reliable")
func broadcast_event(action: String, peer_id: int, _direction: Vector2) -> void:
	connection_message.emit("%s:%d" % [action, peer_id])

func _on_peer_connected(_id: int) -> void:
	pass

func _on_peer_disconnected(id: int) -> void:
	lobby_players.erase(id)
	peer_left.emit(id)
	if multiplayer.is_server(): _publish_lobby.rpc(lobby_players.values())
