extends Node
## Loopback HTTP bridge for the Logitech plugin: GET /context, POST /events.
## Port must match BridgePorts.Http in the C# plugin (17421).

const PORT := 17421

var _server: TCPServer
var _clients: Array = []

var _snapshot_json: String = "{\"schema\":2,\"context\":{},\"options\":[]}"
var _pending_events: Array = []


func _ready() -> void:
	var tcp := TCPServer.new()
	var err := tcp.listen(PORT, "127.0.0.1")
	if err != OK:
		push_warning("MX bridge: could not bind 127.0.0.1:%d — %s" % [PORT, err])
		_server = null
		return
	_server = tcp
	print("[MX] HTTP bridge listening on 127.0.0.1:%d" % PORT)


func _exit_tree() -> void:
	if _server:
		_server.stop()
		_server = null
	_clients.clear()


func set_snapshot_json(json_text: String) -> void:
	_snapshot_json = json_text


func take_pending_events() -> Array:
	var out: Array = _pending_events.duplicate()
	_pending_events.clear()
	return out



func _process(_delta: float) -> void:
	if _server == null:
		return
	while _server.is_connection_available():
		var peer := _server.take_connection()
		_clients.append({"peer": peer, "buf": PackedByteArray()})
	var i := 0
	while i < _clients.size():
		var item: Dictionary = _clients[i]
		var peer: StreamPeerTCP = item["peer"]
		var avail := peer.get_available_bytes()
		if avail > 0:
			var res := peer.get_data(avail)
			if res[0] == OK:
				var acc: PackedByteArray = item["buf"]
				acc.append_array(res[1])
				item["buf"] = acc
		var buf: PackedByteArray = item["buf"]
		if buf.size() > 262144:
			peer.disconnect_from_host()
			_clients.remove_at(i)
			continue
		if _try_handle_request(peer, item):
			_clients.remove_at(i)
		else:
			i += 1


func _try_handle_request(peer: StreamPeerTCP, item: Dictionary) -> bool:
	var buf: PackedByteArray = item["buf"]
	if buf.is_empty():
		return false
	var s := buf.get_string_from_utf8()
	var sep := s.find("\r\n\r\n")
	if sep == -1:
		return false
	var header_end := sep + 4
	var head := s.substr(0, sep)
	var lines := head.split("\r\n")
	if lines.is_empty():
		_send_error(peer, 400)
		return true
	var parts := lines[0].split(" ", false, 2)
	if parts.size() < 2:
		_send_error(peer, 400)
		return true
	var method := parts[0]
	var path_full := parts[1]
	var path := path_full.split("?", false, 1)[0]
	var headers: Dictionary = {}
	for j in range(1, lines.size()):
		var line: String = lines[j]
		var c := line.find(": ")
		if c != -1:
			headers[line.substr(0, c).strip_edges().to_lower()] = line.substr(c + 2).strip_edges()
	var cl := int(headers.get("content-length", "0"))
	if buf.size() < header_end + cl:
		return false
	var body := ""
	if cl > 0:
		body = buf.slice(header_end, header_end + cl).get_string_from_utf8()

	if method == "GET" and path == "/context":
		_send_json(peer, _snapshot_json)
		peer.disconnect_from_host()
		return true
	if method == "POST" and path == "/events":
		_append_events_from_body(body)
		_send_no_content(peer)
		peer.disconnect_from_host()
		return true
	_send_error(peer, 404)
	peer.disconnect_from_host()
	return true


func _append_events_from_body(body: String) -> void:
	if body.is_empty():
		push_warning("[MX] bridge: POST /events with empty body")
		return
	var p := JSON.new()
	if p.parse(body) != OK:
		push_warning("[MX] bridge: POST /events JSON parse error: %s" % p.get_error_message())
		return
	var data = p.data
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("[MX] bridge: POST /events root is not an object")
		return
	var ev: Variant = (data as Dictionary).get("events", [])
	if typeof(ev) != TYPE_ARRAY:
		push_warning("[MX] bridge: POST /events missing \"events\" array")
		return
	var n := 0
	for e in (ev as Array):
		if typeof(e) != TYPE_DICTIONARY:
			continue
		_pending_events.append(e)
		n += 1


func _send_json(peer: StreamPeerTCP, json_text: String) -> void:
	var body := json_text.to_utf8_buffer()
	var hdr := ("HTTP/1.1 200 OK\r\nContent-Type: application/json; charset=utf-8\r\n" + \
		"Content-Length: %d\r\nConnection: close\r\n\r\n") % body.size()
	var packet := hdr.to_utf8_buffer()
	packet.append_array(body)
	peer.put_data(packet)


func _send_no_content(peer: StreamPeerTCP) -> void:
	var hdr := "HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n"
	peer.put_data(hdr.to_utf8_buffer())


func _send_error(peer: StreamPeerTCP, code: int) -> void:
	var hdr := "HTTP/1.1 %d Err\r\nContent-Length: 0\r\nConnection: close\r\n\r\n" % code
	peer.put_data(hdr.to_utf8_buffer())
