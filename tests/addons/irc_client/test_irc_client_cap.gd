extends SceneTree

const T := preload("res://tests/_test_util.gd")

class FakeStreamPeerTCP:
	extends RefCounted

	var status: int = StreamPeerTCP.STATUS_CONNECTED
	var inbound: PackedByteArray = PackedByteArray() # server -> client
	var outbound: PackedByteArray = PackedByteArray() # client -> server

	func poll() -> void:
		pass

	func get_status() -> int:
		return status

	func get_available_bytes() -> int:
		return inbound.size()

	func get_data(_n: int) -> Array:
		var bytes := inbound
		inbound = PackedByteArray()
		return [OK, bytes]

	func put_data(bytes: PackedByteArray) -> int:
		outbound.append_array(bytes)
		return OK

	func server_push_line(line: String) -> void:
		inbound.append_array((line + "\r\n").to_utf8_buffer())

	func server_take_outbound_text() -> String:
		var s := outbound.get_string_from_utf8()
		outbound = PackedByteArray()
		return s

func _init() -> void:
	var ClientScript := load("res://addons/irc_client/IrcClient.gd")
	if ClientScript == null or not (ClientScript is Script) or not (ClientScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing or invalid res://addons/irc_client/IrcClient.gd")
		return

	var BufScript := load("res://addons/irc_client/IrcLineBuffer.gd")
	if BufScript == null or not (BufScript is Script) or not (BufScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing or invalid res://addons/irc_client/IrcLineBuffer.gd")
		return

	var client := (ClientScript as Script).new() as Node
	if not T.require_true(self, client != null, "Failed to instantiate IrcClient"):
		return
	get_root().add_child(client)
	await process_frame

	if not T.require_true(self, client.has_method("set_peer"), "IrcClient must implement set_peer(peer)"):
		return
	if not T.require_true(self, client.has_method("set_cap_enabled"), "IrcClient must implement set_cap_enabled(enabled: bool)"):
		return
	if not T.require_true(self, client.has_method("set_requested_caps"), "IrcClient must implement set_requested_caps(caps: Array[String])"):
		return

	var fake := FakeStreamPeerTCP.new()
	client.call("set_peer", fake)
	client.call("set_cap_enabled", true)
	client.call("set_requested_caps", ["sasl", "message-tags"])

	client.call("set_nick", "nick_test")
	client.call("set_user", "user_test", "0", "*", "Real Name")

	var buf = (BufScript as Script).new()
	var sent: Array[String] = []

	# First poll should start CAP (and NOT send NICK/USER yet).
	client.call("poll")
	await process_frame
	var out1: String = fake.server_take_outbound_text()
	for l in (buf.call("push_chunk", out1) as Array[String]):
		sent.append(l)

	if not T.require_true(self, sent.any(func(x: String) -> bool: return x == "CAP LS 302"), "Expected CAP LS 302 on start"):
		return

	# Server advertises capabilities; client should REQ the intersection.
	fake.server_push_line(":srv CAP * LS :sasl message-tags other")
	client.call("poll")
	await process_frame
	var out2: String = fake.server_take_outbound_text()
	var req_line := ""
	for l in (buf.call("push_chunk", out2) as Array[String]):
		sent.append(l)
		if l.begins_with("CAP REQ "):
			req_line = l
	if not T.require_true(self, req_line != "", "Expected CAP REQ after CAP LS"):
		return
	if not T.require_true(self, req_line.find("sasl") != -1 and req_line.find("message-tags") != -1, "CAP REQ should include requested caps"):
		return

	# Server ACK; client should CAP END, then proceed with registration.
	fake.server_push_line(":srv CAP * ACK :sasl message-tags")
	var deadline_ms: int = Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < deadline_ms:
		client.call("poll")
		await process_frame
		var out: String = fake.server_take_outbound_text()
		if out != "":
			for l in (buf.call("push_chunk", out) as Array[String]):
				sent.append(l)
		if sent.any(func(x: String) -> bool: return x == "CAP END") and sent.any(func(x: String) -> bool: return x.begins_with("NICK ")) and sent.any(func(x: String) -> bool: return x.begins_with("USER ")):
			break

	if not T.require_true(self, sent.any(func(x: String) -> bool: return x == "CAP END"), "Expected CAP END after ACK"):
		return

	var idx_end: int = sent.find("CAP END")
	var idx_req: int = -1
	var idx_nick: int = -1
	var idx_user: int = -1
	for i in range(sent.size()):
		if idx_req == -1 and sent[i].begins_with("CAP REQ "):
			idx_req = i
		if idx_nick == -1 and sent[i].begins_with("NICK "):
			idx_nick = i
		if idx_user == -1 and sent[i].begins_with("USER "):
			idx_user = i
	if not T.require_true(self, idx_end != -1 and idx_req != -1 and idx_nick != -1 and idx_user != -1, "Expected CAP REQ + CAP END + NICK + USER"):
		return
	if not T.require_true(self, idx_req < idx_end, "CAP END must occur after CAP REQ"):
		return

	T.pass_and_quit(self)
