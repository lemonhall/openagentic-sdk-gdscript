extends SceneTree

const T := preload("res://tests/_test_util.gd")

class FakeStreamPeerTCP:
	extends RefCounted

	var status: int = StreamPeerTCP.STATUS_CONNECTED
	var inbound: PackedByteArray = PackedByteArray()
	var outbound: PackedByteArray = PackedByteArray()

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
	client.call("set_requested_caps", ["sasl"])
	client.call("set_nick", "nick_test")
	client.call("set_user", "user_test", "0", "*", "Real Name")

	var buf = (BufScript as Script).new()
	var sent: Array[String] = []

	client.call("poll")
	await process_frame
	for l in (buf.call("push_chunk", fake.server_take_outbound_text()) as Array[String]):
		sent.append(l)

	fake.server_push_line(":srv CAP * LS :sasl")
	client.call("poll")
	await process_frame
	for l in (buf.call("push_chunk", fake.server_take_outbound_text()) as Array[String]):
		sent.append(l)

	fake.server_push_line(":srv CAP * NAK :sasl")
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

	if not T.require_true(self, sent.any(func(x: String) -> bool: return x == "CAP END"), "Expected CAP END after NAK"):
		return
	if not T.require_true(self, sent.any(func(x: String) -> bool: return x.begins_with("NICK ")), "Expected NICK after CAP END"):
		return
	if not T.require_true(self, sent.any(func(x: String) -> bool: return x.begins_with("USER ")), "Expected USER after CAP END"):
		return

	T.pass_and_quit(self)

