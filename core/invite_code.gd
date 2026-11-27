class_name InviteCode
extends RefCounted

const ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const DEFAULT_PORT := 7777

static func encode(room: String, ip: String, port: int = DEFAULT_PORT) -> String:
	var parts := ip.split(".")
	if parts.size() != 4 or room.length() != GameConfig.ROOM_CODE_LENGTH or port < 1 or port > 65535:
		return ""
	for character in room.to_upper():
		if ALPHABET.find(character) < 0: return ""
	var address := 0
	for part in parts:
		if not part.is_valid_int() or int(part) < 0 or int(part) > 255:
			return ""
		address = (address << 8) | int(part)
	var encoded := ""
	for index in GameConfig.INVITE_ADDRESS_LENGTH:
		var shift := (GameConfig.INVITE_ADDRESS_LENGTH - index - 1) * 5
		encoded += ALPHABET[(address >> shift) & 31]
	var result := room.to_upper() + "-" + encoded
	if port != DEFAULT_PORT:
		result += ":%d" % port
	return result

static func decode(text: String) -> Dictionary:
	var clean := text.strip_edges().to_upper()
	var separator := clean.find("-")
	if separator < 0:
		return {}
	var room := clean.substr(0, separator)
	var tail := clean.substr(separator + 1)
	var port := DEFAULT_PORT
	var colon := tail.find(":")
	if colon >= 0:
		var port_text := tail.substr(colon + 1)
		if not port_text.is_valid_int(): return {}
		port = int(port_text)
		tail = tail.substr(0, colon)
	if room.length() != GameConfig.ROOM_CODE_LENGTH or tail.length() != GameConfig.INVITE_ADDRESS_LENGTH or port < 1 or port > 65535:
		return {}
	for character in room:
		if ALPHABET.find(character) < 0: return {}
	var address: int = 0
	for character in tail:
		var digit := ALPHABET.find(character)
		if digit < 0: return {}
		address = (address << 5) | digit
	if address > 4294967295: return {}
	var ip := "%d.%d.%d.%d" % [(address >> 24) & 255, (address >> 16) & 255, (address >> 8) & 255, address & 255]
	return {"room": room, "ip": ip, "port": port}
