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

	var fake := FakeStreamPeerTCP.new()
	client.call("set_peer", fake)
	client.call("set_cap_enabled", true)
	client.call("set_requested_caps", ["sasl", "message-tags"])
	client.call("set_nick", "nick_test")
	client.call("set_user", "user_test", "0", "*", "Real Name")

	var buf = (BufScript as Script).new()
	var sent: Array[String] = []

	# Start CAP.
	client.call("poll")
	await process_frame
	for l in (buf.call("push_chunk", fake.server_take_outbound_text()) as Array[String]):
		sent.append(l)
	if not T.require_true(self, sent.any(func(x: String) -> bool: return x == "CAP LS 302"), "Expected CAP LS 302 on start"):
		return

	# Multiline LS: first chunk contains value caps like sasl=PLAIN and indicates more with '*'.
	fake.server_push_line(":srv CAP * LS * :sasl=PLAIN foo")
	client.call("poll")
	await process_frame
	var out_ls1 := fake.server_take_outbound_text()
	if not T.require_true(self, out_ls1 == "" or out_ls1.find("CAP REQ") == -1, "Must not send CAP REQ until final LS"):
		return

	# Final LS chunk completes the list; client should REQ the intersection by *cap name* (not including '=...').
	fake.server_push_line(":srv CAP * LS :message-tags bar")
	client.call("poll")
	await process_frame
	var req_line := ""
	for l in (buf.call("push_chunk", fake.server_take_outbound_text()) as Array[String]):
		sent.append(l)
		if l.begins_with("CAP REQ "):
			req_line = l

	if not T.require_true(self, req_line != "", "Expected CAP REQ after final CAP LS"):
		return
	if not T.require_true(self, req_line.find("sasl") != -1 and req_line.find("message-tags") != -1, "CAP REQ should include requested cap names"):
		return
	if not T.require_true(self, req_line.find("sasl=PLAIN") == -1, "CAP REQ must not include server value suffixes"):
		return

	# Server ACK may include values too; client should still end CAP and proceed to registration.
	fake.server_push_line(":srv CAP * ACK :sasl=PLAIN message-tags")

	var deadline_ms: int = Time.get_ticks_msec() + 1500
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
	for i in range(sent.size()):
		if sent[i].begins_with("CAP REQ "):
			idx_req = i
			break
	if not T.require_true(self, idx_req != -1 and idx_req < idx_end, "CAP END must occur after CAP REQ"):
		return

	T.pass_and_quit(self)

