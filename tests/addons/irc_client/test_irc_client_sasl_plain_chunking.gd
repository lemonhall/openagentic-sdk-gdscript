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

func _sasl_plain_b64(user: String, password: String) -> String:
	var payload := PackedByteArray([0])
	payload.append_array(user.to_utf8_buffer())
	payload.append(0)
	payload.append_array(password.to_utf8_buffer())
	return Marshalls.raw_to_base64(payload)

func _split400(s: String) -> Array[String]:
	var out: Array[String] = []
	var i: int = 0
	while i < s.length():
		var remaining: int = s.length() - i
		var n: int = 400 if remaining > 400 else remaining
		out.append(s.substr(i, n))
		i += n
	return out

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

	var user := "u".repeat(200)
	var password_str := "p".repeat(200)
	var expected_b64 := _sasl_plain_b64(user, password_str)
	if not T.require_true(self, expected_b64.length() > 400, "Test setup must exceed 400 chars"):
		return
	var chunks := _split400(expected_b64)

	var fake := FakeStreamPeerTCP.new()
	client.call("set_peer", fake)
	client.call("set_cap_enabled", true)
	client.call("set_requested_caps", ["sasl"])
	client.call("set_sasl_plain", user, password_str)

	client.call("set_nick", "nick_test")
	client.call("set_user", "user_test", "0", "*", "Real Name")

	var buf = (BufScript as Script).new()
	var sent: Array[String] = []

	# CAP start.
	client.call("poll")
	await process_frame
	for l in (buf.call("push_chunk", fake.server_take_outbound_text()) as Array[String]):
		sent.append(l)

	# CAP LS -> CAP REQ :sasl
	fake.server_push_line(":srv CAP * LS :sasl")
	client.call("poll")
	await process_frame
	for l in (buf.call("push_chunk", fake.server_take_outbound_text()) as Array[String]):
		sent.append(l)

	# CAP ACK -> AUTHENTICATE PLAIN
	fake.server_push_line(":srv CAP * ACK :sasl")
	client.call("poll")
	await process_frame
	for l in (buf.call("push_chunk", fake.server_take_outbound_text()) as Array[String]):
		sent.append(l)

	if not T.require_true(self, sent.any(func(x: String) -> bool: return x == "AUTHENTICATE PLAIN"), "Expected AUTHENTICATE PLAIN after ACK"):
		return

	# AUTHENTICATE + -> payload chunking (<= 400 chars each).
	fake.server_push_line("AUTHENTICATE +")
	client.call("poll")
	await process_frame

	var auth_lines: Array[String] = []
	for l in (buf.call("push_chunk", fake.server_take_outbound_text()) as Array[String]):
		sent.append(l)
		if l.begins_with("AUTHENTICATE ") and l != "AUTHENTICATE PLAIN":
			auth_lines.append(l)

	var expected_lines: Array[String] = []
	for c in chunks:
		expected_lines.append("AUTHENTICATE %s" % c)
	if expected_b64.length() % 400 == 0:
		expected_lines.append("AUTHENTICATE +")

	if not T.require_true(self, auth_lines.size() == expected_lines.size(), "Expected AUTHENTICATE lines to match chunk count"):
		return
	for i in range(expected_lines.size()):
		if not T.require_true(self, auth_lines[i] == expected_lines[i], "AUTHENTICATE line %d mismatch" % i):
			return

	T.pass_and_quit(self)
