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
		# IrcClient reads exactly `get_available_bytes()`, so returning all at once is enough.
		var bytes := inbound
		inbound = PackedByteArray()
		return [OK, bytes]

	func put_data(bytes: PackedByteArray) -> int:
		outbound.append_array(bytes)
		return OK

	func server_push_raw(text: String) -> void:
		inbound.append_array(text.to_utf8_buffer())

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

	# Configure client (v16 core) and start polling.
	client.call("set_nick", "nick_test")
	client.call("set_user", "user_test", "0", "*", "Real Name")
	var buf = (BufScript as Script).new()

	var got_nick := false
	var got_user := false
	var got_pong := false

	var deadline_ms: int = Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline_ms:
		var outbound_text := fake.server_take_outbound_text()
		if outbound_text != "":
			var lines: Array[String] = buf.call("push_chunk", outbound_text)
			for line in lines:
				if line.begins_with("NICK "):
					got_nick = true
				elif line.begins_with("USER "):
					got_user = true
				elif line.begins_with("PONG "):
					got_pong = true

		# Once registered, server sends PING to validate client PONG.
		if got_nick and got_user and not got_pong:
			fake.server_push_raw("PING :t\r\n")

		if got_nick and got_user and got_pong:
			T.pass_and_quit(self)
			return

		# Let the client poll.
		client.call("poll")
		await process_frame

	T.fail_and_quit(self, "timeout waiting for NICK/USER/PONG (got_nick=%s got_user=%s got_pong=%s)" % [str(got_nick), str(got_user), str(got_pong)])
