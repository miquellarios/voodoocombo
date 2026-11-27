extends Node

signal room_found(room: Dictionary)
const PORT := 7778
const PROTOCOL := 1
var udp := PacketPeerUDP.new()
var advertiser := PacketPeerUDP.new()
var enabled := false
var room_info: Dictionary = {}
var announce_timer := 0.0
var advertising := false
var last_rooms: Dictionary = {}

func start_discovery(listen_port: int = PORT) -> void:
	if enabled: return
	var bind_error := udp.bind(listen_port)
	if bind_error != OK and listen_port != 0: bind_error = udp.bind(0)
	if bind_error == OK:
		enabled = true
		set_process(true)

func start_advertising(info: Dictionary) -> void:
	update_advertisement(info)
	advertiser.set_broadcast_enabled(true)
	advertiser.set_dest_address("255.255.255.255", PORT)
	advertising = true
	set_process(true)

func update_advertisement(info: Dictionary) -> void:
	room_info = info.duplicate(true)
	room_info["protocol"] = PROTOCOL
	room_info["kind"] = str(room_info.get("kind", "room"))
	if room_info["kind"] == "room" and not room_info.is_empty(): last_rooms[str(room_info.get("code", ""))] = room_info

func stop_advertising() -> void:
	advertising = false
	room_info.clear()
	last_rooms.clear()

func request_room(code: String) -> void:
	start_discovery()
	udp.set_broadcast_enabled(true)
	udp.set_dest_address("255.255.255.255", PORT)
	udp.put_packet(JSON.stringify({"protocol": PROTOCOL, "kind": "query", "code": code.to_upper()}).to_utf8_buffer())

func request_rooms() -> void:
	start_discovery()
	udp.set_broadcast_enabled(true)
	udp.set_dest_address("255.255.255.255", PORT)
	udp.put_packet(JSON.stringify({"protocol": PROTOCOL, "kind": "list"}).to_utf8_buffer())

func _process(delta: float) -> void:
	if enabled:
		while udp.get_available_packet_count() > 0:
			var packet_bytes := udp.get_packet()
			var sender_ip := udp.get_packet_ip()
			var sender_port := udp.get_packet_port()
			var packet: Variant = JSON.parse_string(packet_bytes.get_string_from_utf8())
			if not packet is Dictionary or int(packet.get("protocol", 0)) != PROTOCOL: continue
			if packet.get("kind") in ["query", "list"]:
				if advertising:
					for info: Dictionary in _room_entries(room_info):
						if packet.get("kind") == "list" or str(packet.get("code", "")) == str(info.get("code", "")):
							udp.set_dest_address(sender_ip, sender_port)
							var response := info.duplicate(true)
							response["protocol"] = PROTOCOL
							response["kind"] = "room"
							udp.put_packet(JSON.stringify(response).to_utf8_buffer())
			elif packet.get("kind") == "room":
				_accept_room(packet)
			elif packet.get("kind") == "rooms":
				for info: Dictionary in packet.get("rooms", []): _accept_room(info)
		for code in last_rooms.keys():
			if Time.get_ticks_msec() - int(last_rooms[code].get("seen_at", 0)) > GameConfig.LAN_DISCOVERY_STALE_SECONDS * 1000.0: last_rooms.erase(code)
	announce_timer += delta
	if announce_timer >= GameConfig.LAN_DISCOVERY_INTERVAL_SECONDS and advertising:
		announce_timer = 0.0
		advertiser.put_packet(JSON.stringify(room_info).to_utf8_buffer())

func _room_entries(packet: Dictionary) -> Array:
	if packet.get("kind") == "rooms": return packet.get("rooms", [])
	if packet.get("kind") == "room": return [packet]
	return []

func _accept_room(info: Dictionary) -> void:
	var code := str(info.get("code", ""))
	if code.length() != GameConfig.ROOM_CODE_LENGTH: return
	var copy := info.duplicate(true)
	copy["seen_at"] = Time.get_ticks_msec()
	last_rooms[code] = copy
	room_found.emit(copy)
