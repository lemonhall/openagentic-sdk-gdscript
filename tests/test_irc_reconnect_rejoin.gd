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
	if not T.require_true(self, client != null, "Failed to instantiate IrcClient"):
		return
	get_root().add_child(client)
	await process_frame

	if not T.require_true(self, client.has_method("set_peer_factory"), "IrcClient must implement set_peer_factory(peer_factory: Callable)"):
		return
	if not T.require_true(self, client.has_method("set_auto_reconnect_enabled"), "IrcClient must implement set_auto_reconnect_enabled(enabled: bool)"):
		return
	if not T.require_true(self, client.has_method("set_reconnect_backoff_seconds"), "IrcClient must implement set_reconnect_backoff_seconds(backoff: Array)"):
		return
	if not T.require_true(self, client.has_method("set_auto_rejoin_enabled"), "IrcClient must implement set_auto_rejoin_enabled(enabled: bool)"):
		return

	# Setup deterministic connection using a factory (no real sockets).
	var factory := FakePeerFactory.new()
	client.call("set_peer_factory", Callable(factory, "make_peer"))
	client.call("set_cap_enabled", false)
	client.call("set_nick", "nick_test")
	client.call("set_user", "user_test", "0", "*", "Real Name")

	client.call("set_auto_reconnect_enabled", true)
	client.call("set_auto_rejoin_enabled", true)
	client.call("set_reconnect_backoff_seconds", [0.5])

	client.call("connect_to", "example.test", 6667)
	if not T.require_eq(self, factory.peers.size(), 1, "Expected one peer after initial connect_to"):
		return

	var buf = (BufScript as Script).new()

	# Connected -> should register on first poll.
	client.call("poll")
	await process_frame
	var out1: Array[String] = buf.call("push_chunk", factory.peers[0].server_take_outbound_text())
	if not T.require_true(self, out1.any(func(x: String) -> bool: return x.begins_with("NICK ")), "Expected NICK on connect"):
		return
	if not T.require_true(self, out1.any(func(x: String) -> bool: return x.begins_with("USER ")), "Expected USER on connect"):
		return

	# Join once manually.
	client.call("join", "#c")
	var out_join: Array[String] = buf.call("push_chunk", factory.peers[0].server_take_outbound_text())
	if not T.require_true(self, out_join.any(func(x: String) -> bool: return x == "JOIN #c"), "Expected JOIN #c when join() called"):
		return

	# Force disconnect; should NOT reconnect immediately (backoff 0.5s).
	factory.peers[0].status = StreamPeerTCP.STATUS_ERROR
	client.call("poll", 0.0)
	await process_frame
	client.call("poll", 0.4)
	await process_frame
	if not T.require_eq(self, factory.peers.size(), 1, "Should not reconnect before backoff elapsed"):
		return

	# Advance time past backoff; should reconnect and re-register.
	client.call("poll", 0.2)
	await process_frame
	if not T.require_eq(self, factory.peers.size(), 2, "Expected reconnect attempt after backoff"):
		return

	client.call("poll")
	await process_frame
	var out2: Array[String] = buf.call("push_chunk", factory.peers[1].server_take_outbound_text())
	if not T.require_true(self, out2.any(func(x: String) -> bool: return x.begins_with("NICK ")), "Expected NICK on reconnect"):
		return
	if not T.require_true(self, out2.any(func(x: String) -> bool: return x.begins_with("USER ")), "Expected USER on reconnect"):
		return
	if not T.require_true(self, not out2.any(func(x: String) -> bool: return x == "JOIN #c"), "Did not expect rejoin before welcome"):
		return

	# After welcome (001), client should re-join deterministically.
	factory.peers[1].server_push_line(":srv 001 nick_test :welcome")
	client.call("poll")
	await process_frame
	var out3: Array[String] = buf.call("push_chunk", factory.peers[1].server_take_outbound_text())
	if not T.require_true(self, out3.any(func(x: String) -> bool: return x == "JOIN #c"), "Expected JOIN #c after 001 welcome"):
		return

	T.pass_and_quit(self)

