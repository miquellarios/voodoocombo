extends Node

var rooms: Dictionary = {}
var accumulator := 0.0

func _ready() -> void:
	Net.request_received.connect(_request)
	Net.peer_left.connect(_depart)
	var port := GameConfig.NET_PORT
	var args := OS.get_cmdline_user_args()
	var index := args.find("--port")
	if index >= 0 and index + 1 < args.size(): port = int(args[index + 1])
	var error := Net.start_server(port)
	if error != OK:
		push_error("ENet: %s" % error_string(error))
		get_tree().quit(1)

func _process(delta: float) -> void:
	accumulator += minf(delta, GameConfig.NET_MAX_FRAME)
	while accumulator >= GameConfig.NET_TICK:
		accumulator -= GameConfig.NET_TICK
		for room: Dictionary in rooms.values():
			if room.get("sim") is MatchSim:
				var inputs: Array[Dictionary] = []
				room.sim.step(GameConfig.NET_TICK, inputs)

func _request(sender: int, action: String, data: Dictionary) -> void:
	if action == "ping": Net.pong.rpc_id(sender, int(data.stamp))

func _depart(_sender: int) -> void:
	pass
