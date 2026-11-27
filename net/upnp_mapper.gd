class_name UPNPMapper
extends RefCounted

signal finished(result: Dictionary)

var thread := Thread.new()
var working := false
var mapped := false
var external_port := GameConfig.NET_PORT
var external_address := ""

func start(port: int = GameConfig.NET_PORT) -> void:
	if working: return
	external_port = port
	working = true
	thread.start(_discover_and_map)

func poll() -> void:
	if not working or thread.is_alive(): return
	var result: Dictionary = thread.wait_to_finish()
	working = false
	mapped = bool(result.get("mapped", false))
	external_address = str(result.get("ip", ""))
	finished.emit(result)

func close() -> void:
	if working:
		while thread.is_alive(): OS.delay_msec(10)
		var result: Dictionary = thread.wait_to_finish()
		mapped = bool(result.get("mapped", false))
		working = false
	if mapped:
		thread.start(_delete_mapping)
		thread.wait_to_finish()
		mapped = false

func _discover_and_map() -> Dictionary:
	var upnp := UPNP.new()
	var error := upnp.discover(GameConfig.UPNP_DISCOVERY_TIMEOUT_MS, 2, "InternetGatewayDevice")
	if error != OK: return {"mapped": false, "error": error}
	var map_error := upnp.add_port_mapping(external_port, external_port, "VoodooCombo", "UDP")
	if map_error != OK: return {"mapped": false, "error": map_error}
	return {"mapped": true, "ip": upnp.query_external_address(), "error": OK}

func _delete_mapping() -> bool:
	var upnp := UPNP.new()
	var error := upnp.discover(2000, 2, "InternetGatewayDevice")
	if error != OK: return false
	return upnp.delete_port_mapping(external_port, "UDP") == OK
