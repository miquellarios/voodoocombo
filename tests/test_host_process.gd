extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var net: Node = root.get_node("Net")
	var connected := [false]
	net.connected.connect(func() -> void: connected[0] = true)
	var server_pid: int = net.start_host_server(17777)
	if server_pid <= 0:
		push_error("Could not spawn the local dedicated server")
		quit(1)
		return
	await create_timer(0.8).timeout
	var connect_error: int = net.join_server("127.0.0.1", 17777)
	if connect_error == OK: await create_timer(2.0).timeout
	var did_connect: bool = connected[0]
	net.leave_server()
	net.stop_host_server()
	await create_timer(0.1).timeout
	var did_stop := not OS.is_process_running(server_pid)
	if not did_connect or not did_stop:
		push_error("Host lifecycle failed: connected=%s stopped=%s" % [did_connect, did_stop])
		quit(1)
		return
	print("Local host process test passed")
	quit(0)
