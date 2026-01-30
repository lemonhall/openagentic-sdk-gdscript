extends SceneTree

const T := preload("res://tests/_test_util.gd")

class FakeStreamPeerTCP:
	extends RefCounted

	var status: int = StreamPeerTCP.STATUS_CONNECTED
	var outbound: PackedByteArray = PackedByteArray() # client -> server

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
	var buf = (BufScript as Script).new()

	var client := (ClientScript as Script).new() as Node
	get_root().add_child(client)
	await process_frame

	var fake := FakeStreamPeerTCP.new()
	client.call("set_peer", fake)

	if not client.has_method("set_password"):
		T.fail_and_quit(self, "IrcClient must implement set_password(password: String)")
		return

	client.call("set_password", "sekret")
	client.call("set_nick", "nick_test")
	client.call("set_user", "user_test", "0", "*", "Real Name")

	client.call("poll")
	await process_frame

	var out := fake.take_outbound_text()
	var lines: Array[String] = buf.call("push_chunk", out)
	if not T.require_true(self, lines.size() >= 3, "expected PASS/NICK/USER lines"):
		return
	if not T.require_true(self, lines[0].begins_with("PASS "), "PASS must be first"):
		return
	if not T.require_true(self, lines[1].begins_with("NICK "), "NICK must be second"):
		return
	if not T.require_true(self, lines[2].begins_with("USER "), "USER must be third"):
		return

	T.pass_and_quit(self)

