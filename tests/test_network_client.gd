extends SceneTree

var net: Node
var timeout := 0.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	net = root.get_node("Net")
	net.connected.connect(func(): net.ping.rpc_id(1, 42))
	net.pong_received.connect(func(stamp: int):
		if stamp != 42: quit(1)
		else:
			print("ENet round trip passed")
			net.leave_server()
			quit()
	)
	net.disconnected.connect(func(_reason: String): quit(1))
	if net.join_server("127.0.0.1", 17777) != OK: quit(1)

func _process(delta: float) -> bool:
	timeout += delta
	if timeout > 10.0: quit(1)
	return false
