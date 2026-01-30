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

	if not T.require_true(self, client.has_method("set_sasl_plain"), "IrcClient must implement set_sasl_plain(user: String, password: String)"):
		return

	var fake := FakeStreamPeerTCP.new()
	client.call("set_peer", fake)
	client.call("set_cap_enabled", true)
	client.call("set_requested_caps", ["sasl"])
	client.call("set_sasl_plain", "u", "p")

	client.call("set_nick", "nick_test")
	client.call("set_user", "user_test", "0", "*", "Real Name")

	var buf = (BufScript as Script).new()
	var sent: Array[String] = []

	var deadline_ms: int = Time.get_ticks_msec() + 2000

	# Kick things off.
	client.call("poll")
	await process_frame
	for l in (buf.call("push_chunk", fake.server_take_outbound_text()) as Array[String]):
		sent.append(l)
	if not T.require_true(self, sent.any(func(x: String) -> bool: return x == "CAP LS 302"), "Expected CAP LS 302 on start"):
		return

	# CAP LS -> client CAP REQ :sasl
	fake.server_push_line(":srv CAP * LS :sasl")
	client.call("poll")
	await process_frame
	for l in (buf.call("push_chunk", fake.server_take_outbound_text()) as Array[String]):
		sent.append(l)
	if not T.require_true(self, sent.any(func(x: String) -> bool: return x.begins_with("CAP REQ ") and x.find("sasl") != -1), "Expected CAP REQ :sasl"):
		return

	# CAP ACK -> client AUTHENTICATE PLAIN
	fake.server_push_line(":srv CAP * ACK :sasl")
	client.call("poll")
	await process_frame
	for l in (buf.call("push_chunk", fake.server_take_outbound_text()) as Array[String]):
		sent.append(l)
	if not T.require_true(self, sent.any(func(x: String) -> bool: return x == "AUTHENTICATE PLAIN"), "Expected AUTHENTICATE PLAIN after ACK"):
		return

	# AUTHENTICATE + -> client AUTHENTICATE <b64>
	fake.server_push_line("AUTHENTICATE +")
	client.call("poll")
	await process_frame
	var b64 := _sasl_plain_b64("u", "p")
	var expected := "AUTHENTICATE %s" % b64
	for l in (buf.call("push_chunk", fake.server_take_outbound_text()) as Array[String]):
		sent.append(l)
	if not T.require_true(self, sent.any(func(x: String) -> bool: return x == expected), "Expected SASL PLAIN payload"):
		return

	# SASL success numeric -> client CAP END (eventually).
	fake.server_push_line(":srv 903 nick_test :SASL success")
	while Time.get_ticks_msec() < deadline_ms:
		client.call("poll")
		await process_frame
		var out := fake.server_take_outbound_text()
		if out != "":
			for l in (buf.call("push_chunk", out) as Array[String]):
				sent.append(l)
		if sent.any(func(x: String) -> bool: return x == "CAP END"):
			break

	if not T.require_true(self, sent.any(func(x: String) -> bool: return x == "CAP END"), "Expected CAP END after SASL success"):
		return

	# CAP END should not precede SASL payload.
	var idx_end: int = sent.find("CAP END")
	var idx_payload: int = sent.find(expected)
	if not T.require_true(self, idx_payload != -1 and idx_end != -1 and idx_payload < idx_end, "CAP END must be after SASL payload"):
		return

	T.pass_and_quit(self)

