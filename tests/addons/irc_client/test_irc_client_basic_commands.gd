extends SceneTree

const T := preload("res://tests/_test_util.gd")

class FakeStreamPeerTCP:
	extends RefCounted

	var status: int = StreamPeerTCP.STATUS_CONNECTED
	var outbound: PackedByteArray = PackedByteArray()

	func poll() -> void:
		pass

	func get_status() -> int:
		return status

	func get_available_bytes() -> int:
		return 0

	func get_data(_n: int) -> Array:
		return [OK, PackedByteArray()]

	func put_data(bytes: PackedByteArray) -> int:
		outbound.append_array(bytes)
		return OK

	func disconnect_from_host() -> void:
		status = StreamPeerTCP.STATUS_NONE

	func take_outbound_text() -> String:
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
	var buf = (BufScript as Script).new()

	var client := (ClientScript as Script).new() as Node
	get_root().add_child(client)
	await process_frame

	var fake := FakeStreamPeerTCP.new()
	client.call("set_peer", fake)

	client.call("join", "#c")
	client.call("part", "#c", "bye")
	client.call("privmsg", "#c", "hello")
	client.call("privmsg", "#c", "")
	client.call("notice", "#c", "note")
	client.call("notice", "#c", "")
	client.call("quit", "later")

	var out := fake.take_outbound_text()
	var lines: Array[String] = buf.call("push_chunk", out)

	if not T.require_true(self, lines.has("JOIN #c"), "JOIN line"):
		return
	if not T.require_true(self, lines.has("PART #c :bye"), "PART line"):
		return
	if not T.require_true(self, lines.has("PRIVMSG #c :hello"), "PRIVMSG line"):
		return
	if not T.require_true(self, lines.has("PRIVMSG #c :"), "PRIVMSG empty trailing line"):
		return
	if not T.require_true(self, lines.has("NOTICE #c :note"), "NOTICE line"):
		return
	if not T.require_true(self, lines.has("NOTICE #c :"), "NOTICE empty trailing line"):
		return
	if not T.require_true(self, lines.has("QUIT :later"), "QUIT line"):
		return

	# Max line length enforcement (512 including CRLF). Use a fresh client to avoid accessing internals.
	var client2 := (ClientScript as Script).new() as Node
	get_root().add_child(client2)
	await process_frame
	var fake_long := FakeStreamPeerTCP.new()
	client2.call("set_peer", fake_long)
	client2.call("privmsg", "#c", "é".repeat(2000))
	var out2 := fake_long.take_outbound_text()
	var lines2: Array[String] = buf.call("push_chunk", out2)
	if not T.require_eq(self, lines2.size(), 1, "one PRIVMSG line"):
		return
	var b: PackedByteArray = (lines2[0] + "\r\n").to_utf8_buffer()
	if not T.require_true(self, b.size() <= 512, "PRIVMSG must be <= 512 bytes including CRLF"):
		return
	if not T.require_true(self, lines2[0].find("�") == -1, "truncation must remain valid UTF-8"):
		return

	T.pass_and_quit(self)
