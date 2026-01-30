extends SceneTree

const T := preload("res://tests/_test_util.gd")

class FakeStreamPeerTCP:
	extends RefCounted

	var status: int = StreamPeerTCP.STATUS_CONNECTED
	var outbound: PackedByteArray = PackedByteArray()
	var inbound: PackedByteArray = PackedByteArray()

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

	func take_outbound_text() -> String:
		var s := outbound.get_string_from_utf8()
		outbound = PackedByteArray()
		return s

	func server_push_raw(text: String) -> void:
		inbound.append_array(text.to_utf8_buffer())

func _init() -> void:
	var ClientScript := load("res://addons/irc_client/IrcClient.gd")
	if ClientScript == null or not (ClientScript is Script) or not (ClientScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing or invalid res://addons/irc_client/IrcClient.gd")
		return

	var BufScript := load("res://addons/irc_client/IrcLineBuffer.gd")
	var buf = (BufScript as Script).new()

	var client := (ClientScript as Script).new() as Node
	get_root().add_child(client)
	await process_frame

	var fake := FakeStreamPeerTCP.new()
	client.call("set_peer", fake)
	client.call("set_cap_enabled", true)
	client.call("set_requested_caps", ["multi-prefix"])
	client.call("set_password", "sekret")
	client.call("set_nick", "nick_test")
	client.call("set_user", "user_test", "0", "*", "Real Name")

	# First poll: client sends CAP LS 302 (cap pre-registration).
	client.call("poll")
	await process_frame

	# Server responds with supported caps.
	fake.server_push_raw("CAP * LS :multi-prefix\r\n")
	client.call("poll")
	await process_frame

	# Server ACKs requested cap; client sends CAP END and then registration.
	fake.server_push_raw("CAP * ACK :multi-prefix\r\n")
	client.call("poll")
	await process_frame

	# Trigger additional on_message calls after CAP is complete; must not resend NICK/USER.
	for _i in range(3):
		fake.server_push_raw("PING :t\r\n")
		client.call("poll")
		await process_frame

	var out := fake.take_outbound_text()
	var lines: Array[String] = buf.call("push_chunk", out)
	var nick_count := 0
	var user_count := 0
	var pass_count := 0
	for line in lines:
		if line.begins_with("PASS "):
			pass_count += 1
		if line.begins_with("NICK "):
			nick_count += 1
		if line.begins_with("USER "):
			user_count += 1

	if not T.require_eq(self, pass_count, 1, "PASS must be sent once"):
		return
	if not T.require_eq(self, nick_count, 1, "NICK must be sent once"):
		return
	if not T.require_eq(self, user_count, 1, "USER must be sent once"):
		return

	T.pass_and_quit(self)
