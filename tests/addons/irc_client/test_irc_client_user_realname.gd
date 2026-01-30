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

	client.call("set_nick", "nick_test")
	client.call("set_user", "user_test", "0", "*", "Real Name")
	client.call("poll")
	await process_frame

	var out := fake.take_outbound_text()
	var lines: Array[String] = buf.call("push_chunk", out)
	var found_user := false
	for line in lines:
		if line.begins_with("USER "):
			found_user = true
			if not T.require_true(self, line.find(" :Real Name") != -1, "USER must include realname as trailing"):
				return
	if not T.require_true(self, found_user, "expected USER line"):
		return

	T.pass_and_quit(self)

