extends Node

signal room_found(room: Dictionary)
const PORT := 7778
var udp := PacketPeerUDP.new()
var advertiser := PacketPeerUDP.new()
var enabled := false
var room_info: Dictionary = {}
var announce_timer := 0.0
var advertising := false

func start_discovery() -> void:
	if udp.bind(PORT) == OK:
		enabled = true
		set_process(true)

func start_advertising(info: Dictionary) -> void:
	room_info = info
	advertiser.set_broadcast_enabled(true)
	advertiser.set_dest_address("255.255.255.255", PORT)
	advertising = true
	set_process(true)

func _process(delta: float) -> void:
	if enabled:
		while udp.get_available_packet_count() > 0:
			var packet: Variant = JSON.parse_string(udp.get_packet().get_string_from_utf8())
			if packet is Dictionary:
				room_found.emit(packet)
	announce_timer += delta
	if announce_timer >= 1.0 and advertising:
		announce_timer = 0.0
		advertiser.put_packet(JSON.stringify(room_info).to_utf8_buffer())
