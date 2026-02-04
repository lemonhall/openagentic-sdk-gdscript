extends SceneTree

const T := preload("res://tests/_test_util.gd")

class _MiniIrcServer:
	var _srv := TCPServer.new()
	var _clients: Array = []
	var _bufs: Dictionary = {} # peer_id -> String
	var _nick: Dictionary = {} # peer_id -> String
	var _have_user: Dictionary = {} # peer_id -> bool
	var _joined: Dictionary = {} # peer_id -> Dictionary(channel->true)

	var port: int = 0

	func start(host: String = "127.0.0.1", port_in: int = 0) -> bool:
		var err := _srv.listen(port_in, host)
		if err != OK:
			return false
		port = _srv.get_local_port()
		return true

	func stop() -> void:
		for c in _clients:
			var p := c as StreamPeerTCP
			if p != null:
				p.disconnect_from_host()
		_clients.clear()
		_srv.stop()

	func poll() -> void:
		while _srv.is_connection_available():
			var c := _srv.take_connection()
			if c == null:
				break
			_clients.append(c)
			_bufs[c.get_instance_id()] = ""
			_nick[c.get_instance_id()] = ""
			_have_user[c.get_instance_id()] = false
			_joined[c.get_instance_id()] = {}

		for c0 in _clients:
			var c := c0 as StreamPeerTCP
			if c == null:
				continue
			c.poll()
			if c.get_status() != StreamPeerTCP.STATUS_CONNECTED:
				continue
			var id := c.get_instance_id()
			while c.get_available_bytes() > 0:
				var chunk := c.get_utf8_string(c.get_available_bytes())
				_bufs[id] = String(_bufs.get(id, "")) + chunk
			_drain_lines(c)

	func _drain_lines(c: StreamPeerTCP) -> void:
		var id := c.get_instance_id()
		var buf := String(_bufs.get(id, ""))
		while true:
			var idx := buf.find("\n")
			if idx == -1:
				break
			var line := buf.substr(0, idx).strip_edges()
			buf = buf.substr(idx + 1)
			if line == "":
				continue
			_handle_line(c, line)
		_bufs[id] = buf

	func _send_line(c: StreamPeerTCP, line: String) -> void:
		if c == null:
			return
		var s := line.rstrip("\r\n") + "\r\n"
		c.put_data(s.to_utf8_buffer())

	func _handle_line(c: StreamPeerTCP, line: String) -> void:
		var id := c.get_instance_id()
		var parts := line.split(" ", false)
		if parts.is_empty():
			return
		var cmd := String(parts[0]).to_upper()
		if cmd == "NICK" and parts.size() >= 2:
			_nick[id] = String(parts[1]).strip_edges()
			_maybe_welcome(c)
			return
		if cmd == "USER":
			_have_user[id] = true
			_maybe_welcome(c)
			return
		if cmd == "PING" and parts.size() >= 2:
			_send_line(c, "PONG " + String(parts[1]))
			return
		if cmd == "JOIN" and parts.size() >= 2:
			var ch := String(parts[1]).strip_edges()
			var j: Dictionary = _joined.get(id, {})
			j[ch] = true
			_joined[id] = j
			_send_line(c, ":server 366 %s %s :End of /NAMES list." % [_nick.get(id, "u"), ch])
			return
		if cmd == "PRIVMSG" and parts.size() >= 3:
			var ch2 := String(parts[1]).strip_edges()
			var msg := ""
			var colon := line.find(" :")
			if colon != -1:
				msg = line.substr(colon + 2)
			_broadcast_privmsg(_nick.get(id, "u"), ch2, msg)
			return

	func _maybe_welcome(c: StreamPeerTCP) -> void:
		var id := c.get_instance_id()
		if String(_nick.get(id, "")).strip_edges() == "":
			return
		if not bool(_have_user.get(id, false)):
			return
		_send_line(c, ":server 001 %s :welcome" % String(_nick.get(id, "u")))

	func _broadcast_privmsg(nick: String, channel: String, msg: String) -> void:
		for c0 in _clients:
			var c := c0 as StreamPeerTCP
			if c == null or c.get_status() != StreamPeerTCP.STATUS_CONNECTED:
				continue
			var jid: Dictionary = _joined.get(c.get_instance_id(), {})
			if not bool(jid.get(channel, false)):
				continue
			_send_line(c, ":%s!u@h PRIVMSG %s :%s" % [nick, channel, msg])

static func _sha256_hex(b: PackedByteArray) -> String:
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	hc.update(b)
	return hc.finish().hex_encode()

func _init() -> void:
	var Paths := load("res://addons/openagentic/core/OAPaths.gd")
	var FsScript := load("res://addons/openagentic/core/OAWorkspaceFs.gd")
	var MediaRefScript := load("res://addons/openagentic/core/OAMediaRef.gd")
	if Paths == null or FsScript == null or MediaRefScript == null:
		T.fail_and_quit(self, "Missing core scripts")
		return

	var tools: Array = OAStandardTools.tools()
	var upload = _find_tool(tools, "MediaUpload")
	var fetch = _find_tool(tools, "MediaFetch")
	if not T.require_true(self, upload != null and fetch != null, "Missing MediaUpload/MediaFetch tools"):
		return

	var server := _MiniIrcServer.new()
	if not server.start("127.0.0.1", 0):
		T.fail_and_quit(self, "Failed to start IRC server")
		return

	var bearer := "e2e-token"
	var store: Dictionary = {} # id -> bytes
	var id_counter := 0
	var transport := func(req: Dictionary) -> Dictionary:
		var method := String(req.get("method", ""))
		var url := String(req.get("url", ""))
		var headers: Dictionary = req.get("headers", {})
		var body: PackedByteArray = req.get("body", PackedByteArray())
		if method == "POST" and url.ends_with("/upload"):
			if String(headers.get("authorization", "")) != "Bearer " + bearer:
				return {"ok": true, "status": 403, "headers": {}, "body": "{\"ok\":false}".to_utf8_buffer()}
			id_counter += 1
			var id := "img_e2e_%d" % id_counter
			store[id] = body
			var sha := _sha256_hex(body)
			var meta := {"ok": true, "id": id, "kind": "image", "mime": "image/png", "bytes": body.size(), "sha256": sha}
			return {"ok": true, "status": 200, "headers": {"content-type": "application/json"}, "body": JSON.stringify(meta).to_utf8_buffer()}
		if method == "GET":
			var idx := url.find("/media/")
			if idx != -1:
				if String(headers.get("authorization", "")) != "Bearer " + bearer:
					return {"ok": true, "status": 403, "headers": {}, "body": PackedByteArray()}
				var id2 := url.substr(idx + "/media/".length())
				var b: PackedByteArray = store.get(id2, PackedByteArray())
				if b.is_empty():
					return {"ok": true, "status": 404, "headers": {}, "body": PackedByteArray()}
				return {"ok": true, "status": 200, "headers": {"content-type": "image/png"}, "body": b}
		return {"ok": true, "status": 404, "headers": {}, "body": PackedByteArray()}

	# Sender/receiver workspaces.
	var save_id: String = "slot_test_e2e_media_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	var a_id := "npc_a"
	var b_id := "npc_b"
	var a_root: String = (Paths as Script).call("npc_workspace_dir", save_id, a_id)
	var b_root: String = (Paths as Script).call("npc_workspace_dir", save_id, b_id)
	var a_fs = (FsScript as Script).new(a_root)
	var b_fs = (FsScript as Script).new(b_root)

	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 1, 0, 1))
	var png_bytes := img.save_png_to_buffer()
	a_fs.call("write_bytes", "in/a.png", png_bytes)

	var ctx_a := {"save_id": save_id, "npc_id": a_id, "session_id": a_id, "workspace_root": a_root, "media_base_url": "http://media.local", "media_bearer_token": bearer, "media_transport": transport}
	var ctx_b := {"save_id": save_id, "npc_id": b_id, "session_id": b_id, "workspace_root": b_root, "media_base_url": "http://media.local", "media_bearer_token": bearer, "media_transport": transport}

	# Upload -> OAMEDIA1 line (must not include token).
	var up: Dictionary = await upload.run_async({"file_path": "in/a.png"}, ctx_a)
	if not T.require_true(self, bool(up.get("ok", false)), "Upload failed"):
		return
	var media_line := String(up.get("media_ref", ""))
	if not T.require_true(self, media_line.begins_with("OAMEDIA1 "), "Expected OAMEDIA1"):
		return
	if not T.require_true(self, media_line.find(bearer) == -1, "Bearer token must not appear in chat line"):
		return

	# Send over IRC in safe fragments.
	var MediaRef := MediaRefScript as Script
	var send_lines: Array[String] = MediaRef.call("irc_encode_lines", media_line, 120)
	if not T.require_true(self, send_lines.size() >= 1, "Expected irc_encode_lines"):
		return

	var ch := "#test"
	var a := await _connect_irc_client("127.0.0.1", server.port, "a")
	var b := await _connect_irc_client("127.0.0.1", server.port, "b")
	if a == null or b == null:
		T.fail_and_quit(self, "Failed to connect IRC clients")
		return
	_send_irc_line(a, "JOIN " + ch)
	_send_irc_line(b, "JOIN " + ch)

	# Drain join/welcome.
	for _i in range(30):
		server.poll()
		_drain_client(a)
		_drain_client(b)
		await process_frame

	for l in send_lines:
		_send_irc_line(a, "PRIVMSG %s :%s" % [ch, l])

	# Receiver: reassemble and fetch into workspace.
	var parts: Dictionary = {}
	var mid := ""
	var total := 0
	var got_line := ""
	for _i in range(200):
		server.poll()
		_drain_client(a)
		var recv := _drain_client(b)
		for line0 in recv:
			var msg0 := _extract_privmsg_trailing(String(line0))
			if msg0 == "":
				continue
			if msg0.begins_with("OAMEDIA1 "):
				got_line = msg0
				break
			if msg0.begins_with("OAMEDIA1F "):
				var frag: Dictionary = MediaRef.call("irc_parse_fragment", msg0)
				if bool(frag.get("ok", false)):
					mid = String(frag.get("message_id", mid))
					total = int(frag.get("total", total))
					parts[int(frag.get("index", 0))] = String(frag.get("payload_part", ""))
					if parts.size() >= total and mid != "" and total > 0:
						var rr: Dictionary = MediaRef.call("irc_reassemble", mid, total, parts)
						if bool(rr.get("ok", false)):
							got_line = String(rr.get("line", ""))
							break
		if got_line != "":
			break
		await process_frame

	if not T.require_true(self, got_line.begins_with("OAMEDIA1 "), "Did not receive media line"):
		return

	var out: Dictionary = await fetch.run_async({"media_ref": got_line}, ctx_b)
	if not T.require_true(self, bool(out.get("ok", false)), "Fetch failed"):
		return
	var rel := String(out.get("file_path", "")).strip_edges()
	if not T.require_true(self, rel != "" and rel.find("..") == -1 and not rel.begins_with("/") and rel.find(":") == -1, "Expected workspace-relative path"):
		return
	var got: Dictionary = b_fs.call("read_bytes", rel)
	if not T.require_true(self, bool(got.get("ok", false)), "Expected downloaded bytes readable"):
		return
	if not T.require_true(self, (got.get("bytes", PackedByteArray()) as PackedByteArray) == png_bytes, "Bytes mismatch"):
		return

	# Cleanup.
	server.stop()
	T.pass_and_quit(self)

func _find_tool(tools: Array, name: String):
	for t in tools:
		if t != null and typeof(t) == TYPE_OBJECT and String(t.name) == name:
			return t
	return null

func _connect_irc_client(host: String, port: int, nick: String) -> StreamPeerTCP:
	var c := StreamPeerTCP.new()
	var err := c.connect_to_host(host, port)
	if err != OK:
		return null
	for _i in range(60):
		c.poll()
		if c.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			break
		await process_frame
	if c.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return null
	_send_irc_line(c, "NICK " + nick)
	_send_irc_line(c, "USER " + nick + " 0 * :" + nick)
	return c

func _send_irc_line(c: StreamPeerTCP, line: String) -> void:
	var s := line.rstrip("\r\n") + "\r\n"
	c.put_data(s.to_utf8_buffer())

func _drain_client(c: StreamPeerTCP) -> Array[String]:
	var out: Array[String] = []
	if c == null:
		return out
	c.poll()
	while c.get_available_bytes() > 0:
		var chunk := c.get_utf8_string(c.get_available_bytes())
		for l in chunk.split("\n", false):
			var s := String(l).strip_edges()
			if s != "":
				out.append(s)
	return out

func _extract_privmsg_trailing(line: String) -> String:
	var idx := line.find(" PRIVMSG ")
	if idx == -1:
		return ""
	var colon := line.find(" :")
	if colon == -1:
		return ""
	return line.substr(colon + 2).strip_edges()
