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

	func disconnect_from_host() -> void:
		status = StreamPeerTCP.STATUS_NONE

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

class FakePeerFactory:
	extends RefCounted

	var peers: Array = []
	var calls: Array = []

	func make_peer(host: String, port: int) -> Object:
		calls.append([host, port])
		var p := FakeStreamPeerTCP.new()
		peers.append(p)
		return p

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
	get_root().add_child(client)
	await process_frame

	var factory := FakePeerFactory.new()
	client.call("set_peer_factory", Callable(factory, "make_peer"))
	client.call("set_cap_enabled", false)
	client.call("set_nick", "nick_test")
	client.call("set_user", "user_test", "0", "*", "Real Name")

	client.call("set_auto_reconnect_enabled", true)
	client.call("set_reconnect_backoff_seconds", [0.0])

	client.call("connect_to", "example.test", 6667)
	if not T.require_eq(self, factory.peers.size(), 1, "Expected one peer after initial connect_to"):
		return

	var buf = (BufScript as Script).new()

	# Establish connected state + send registration.
	client.call("poll")
	await process_frame
	client.call("poll")
	await process_frame
	buf.call("push_chunk", factory.peers[0].server_take_outbound_text())

	# Server says ERROR and closes; client should auto-reconnect (not treat as user initiated).
	factory.peers[0].server_push_line("ERROR :Closing Link")
	client.call("poll")
	await process_frame

	# Next poll should perform reconnect attempt immediately (backoff 0.0).
	client.call("poll", 0.0)
	await process_frame
	if not T.require_eq(self, factory.peers.size(), 2, "Expected reconnect attempt after server ERROR"):
		return

	client.call("poll")
	await process_frame
	var out: Array[String] = buf.call("push_chunk", factory.peers[1].server_take_outbound_text())
	if not T.require_true(self, out.any(func(x: String) -> bool: return x.begins_with("NICK ")), "Expected NICK on reconnect peer"):
		return
	if not T.require_true(self, out.any(func(x: String) -> bool: return x.begins_with("USER ")), "Expected USER on reconnect peer"):
		return

	T.pass_and_quit(self)

