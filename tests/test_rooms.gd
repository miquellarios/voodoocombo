extends SceneTree

func _initialize() -> void:
	var service := RoomDirectory.new()
	var room := service.create(2, "Ana", "mago", {}, GameConfig.NET_VERSION)
	assert(not room.is_empty() and room.code.length() == 5)
	var code: String = room.code
	for id in [3, 4, 5]: assert(not service.join(id, code, "Jugador", "trol", {}, GameConfig.NET_VERSION).is_empty())
	assert(service.join(6, code, "Extra", "mago", {}, GameConfig.NET_VERSION).is_empty() and service.error == "full")
	service.leave(2)
	assert(room.host == 3)
	assert(service.join(6, code, "Extra", "mago", {}, "wrong").is_empty() and service.error == "version")
	for index in 5: service.join(7, "ZZZZZ", "Extra", "mago", {}, GameConfig.NET_VERSION)
	assert(service.join(7, code, "Extra", "mago", {}, GameConfig.NET_VERSION).is_empty() and service.error == "rate")
	room.phase = "playing"
	assert(service.join(8, code, "Extra", "mago", {}, GameConfig.NET_VERSION).is_empty() and service.error == "started")
	for id in [3, 4, 5]: service.leave(id)
	assert(service.step(300.0) == [code] and service.rooms.is_empty())
	print("Room capacity, version, rate, host migration and expiry passed")
	quit()
