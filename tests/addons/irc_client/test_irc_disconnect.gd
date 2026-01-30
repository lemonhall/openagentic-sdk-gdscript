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

	var client := (ClientScript as Script).new() as Node
	if not T.require_true(self, client != null, "Failed to instantiate IrcClient"):
		return
	get_root().add_child(client)
	await process_frame

	var fake := FakeStreamPeerTCP.new()
	client.call("set_peer", fake)

	if not client.has_method("quit"):
		T.fail_and_quit(self, "IrcClient must implement quit(reason := \"\")")
		return
	if not client.has_method("close_connection"):
		T.fail_and_quit(self, "IrcClient must implement close_connection()")
		return

	client.call("quit", "bye")
	var out1 := fake.take_outbound_text()
	if not T.require_true(self, out1.find("QUIT :bye\r\n") != -1, "quit() must send QUIT with trailing reason"):
		return
	if not T.require_eq(self, fake.status, StreamPeerTCP.STATUS_NONE, "quit() must close transport"):
		return

	# close_connection() should close without sending.
	fake = FakeStreamPeerTCP.new()
	client.call("set_peer", fake)
	client.call("close_connection")
	var out2 := fake.take_outbound_text()
	if not T.require_eq(self, out2, "", "close_connection() must not send any line"):
		return
	if not T.require_eq(self, fake.status, StreamPeerTCP.STATUS_NONE, "close_connection() must close transport"):
		return

	T.pass_and_quit(self)
