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

	func server_push_raw(text: String) -> void:
		inbound.append_array(text.to_utf8_buffer())

	func take_outbound_text() -> String:
		var s := outbound.get_string_from_utf8()
		outbound = PackedByteArray()
		return s

func _expect_pong(client: Node, fake: FakeStreamPeerTCP, buf: RefCounted, ping_line: String, want_prefix: String) -> bool:
	fake.server_push_raw(ping_line + "\r\n")
	client.call("poll")
	await process_frame
	var out := fake.take_outbound_text()
	var lines: Array[String] = buf.call("push_chunk", out)
	for line in lines:
		if line.begins_with(want_prefix):
			return true
	T.fail_and_quit(self, "expected PONG (%s) for %s, got %s" % [want_prefix, ping_line, str(lines)])
	return false

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

	# Establish connected state.
	client.call("poll")
	await process_frame

	if not await _expect_pong(client, fake, buf, "PING :abc", "PONG :abc"):
		return
	if not await _expect_pong(client, fake, buf, "PING abc", "PONG abc"):
		return
	if not await _expect_pong(client, fake, buf, "PING a b", "PONG a b"):
		return
	if not await _expect_pong(client, fake, buf, "PING a b c", "PONG a b c"):
		return
	if not await _expect_pong(client, fake, buf, "PING", "PONG"):
		return

	T.pass_and_quit(self)
