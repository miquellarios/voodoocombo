extends Node

const PORT := 8080
var server := TCPServer.new()
var clients: Array[StreamPeerTCP] = []
var results: Array[Dictionary] = []
var current_status: Dictionary = {"mode": "", "time": 0, "players": []}

func _ready() -> void:
	if "--server" in OS.get_cmdline_user_args() and "--no-http" not in OS.get_cmdline_user_args():
		var error := start()
		if error != OK:
			push_error("HTTP endpoint no pudo abrir el puerto %d (%d)" % [PORT, error])

func start() -> Error:
	return server.listen(PORT, "0.0.0.0")

func stop() -> void:
	server.stop()
	clients.clear()

func set_status(status: Dictionary) -> void:
	current_status = status

func add_result(result: Dictionary) -> void:
	results.push_front(result)
	if results.size() > 20: results.resize(20)

func _process(_delta: float) -> void:
	while server.is_connection_available():
		clients.append(server.take_connection())
	for i in range(clients.size() - 1, -1, -1):
		var client := clients[i]
		client.poll()
		if client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			clients.remove_at(i)
			continue
		if client.get_available_bytes() == 0: continue
		var request := client.get_utf8_string(client.get_available_bytes())
		var path := "/"
		var parts := request.split(" ")
		if parts.size() > 1: path = parts[1]
		var payload := ""
		var content_type := "application/json; charset=utf-8"
		match path:
			"/status": payload = JSON.stringify(current_status)
			"/results": payload = JSON.stringify(results)
			_:
				content_type = "text/html; charset=utf-8"
				payload = "<!doctype html><meta charset='utf-8'><title>VoodooCombo</title><body style='background:#160e22;color:white;font:24px sans-serif'><h1>VOODOO COMBO</h1><pre id='s'></pre><script>async function u(){let r=await fetch('/status');document.getElementById('s').textContent=JSON.stringify(await r.json(),null,2)}u();setInterval(u,1000)</script></body>"
		var body := payload.to_utf8_buffer()
		var header := "HTTP/1.1 200 OK\r\nContent-Type: %s\r\nContent-Length: %d\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n" % [content_type, body.size()]
		client.put_data(header.to_utf8_buffer())
		client.put_data(body)
		client.disconnect_from_host()
		clients.remove_at(i)
