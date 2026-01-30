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
	client.call("set_cap_enabled", false)
	client.call("set_nick", "nick_test")
	client.call("set_user", "user_test", "0", "*", "Real Name")

	var buf = (BufScript as Script).new()

	client.call("poll")
	await process_frame
	var sent: Array[String] = buf.call("push_chunk", fake.server_take_outbound_text())

	if not T.require_true(self, sent.any(func(x: String) -> bool: return x.begins_with("NICK ")), "Expected NICK when CAP disabled"):
		return
	if not T.require_true(self, sent.any(func(x: String) -> bool: return x.begins_with("USER ")), "Expected USER when CAP disabled"):
		return
	if not T.require_true(self, not sent.any(func(x: String) -> bool: return x.begins_with("CAP ")), "Did not expect CAP messages when disabled"):
		return

	T.pass_and_quit(self)

