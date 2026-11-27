extends SceneTree

const Invite = preload("res://core/invite_code.gd")
const Addresses = preload("res://core/network_addresses.gd")

func _initialize() -> void:
	var code := Invite.encode("KWET7", "192.168.1.42")
	var decoded := Invite.decode(code)
	assert(decoded.room == "KWET7" and decoded.ip == "192.168.1.42" and decoded.port == 7777)
	var custom := Invite.decode(Invite.encode("AB234", "26.4.8.16", 8888))
	assert(custom.room == "AB234" and custom.ip == "26.4.8.16" and custom.port == 8888)
	assert(Invite.decode("KWET7-B2QX4MA").is_empty() == false)
	assert(Invite.decode("BAD-B2QX4MA").is_empty())
	var choices := Addresses.candidates([
		{"name": "vEthernet (WSL)", "addresses": ["172.24.1.2"]},
		{"name": "Ethernet", "addresses": ["192.168.1.42"]},
		{"name": "Tailscale", "addresses": ["100.88.9.3"]},
		{"name": "Wi-Fi", "addresses": ["10.0.0.12"]}
	])
	assert(choices.size() == 3)
	assert(choices[0].ip == "100.88.9.3")
	assert(choices[1].ip == "192.168.1.42")
	print("Invite code and address tests passed")
	quit()
