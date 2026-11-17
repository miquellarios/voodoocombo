extends SceneTree

func _initialize() -> void:
	assert(not RpcRules.valid("input", {"seq": 1, "move": Vector2(NAN, 0), "dash": false, "spell": false}))
	assert(not RpcRules.valid("bots", {"count": "four"}))
	assert(not RpcRules.cosmetics_valid({"frame": "almas"}, 1))
	assert(RpcRules.cosmetics_valid({"frame": "almas"}, 10))
	assert(not RpcRules.cosmetics_valid({"social": ["missing"]}, 10))
	assert(not RpcRules.valid("unknown", {}))
	assert(RpcRules.valid("input", {"seq": 1, "move": Vector2(5, 0), "dash": false, "spell": false}))
	print("RPC schema, finite movement and authoritative cosmetic level passed")
	quit()
