extends SceneTree

const T := preload("res://tests/_test_util.gd")

class FakeChunkedPeer:
	extends RefCounted

	var status: int = StreamPeerTCP.STATUS_CONNECTED
	var outbound: PackedByteArray = PackedByteArray() # client -> server
	var inbound_chunks: Array = [] # Array[PackedByteArray]

	func poll() -> void:
		pass

	func get_status() -> int:
		return status

	func put_data(bytes: PackedByteArray) -> int:
		outbound.append_array(bytes)
		return OK

	func get_available_bytes() -> int:
		if inbound_chunks.size() == 0:
			return 0
		return (inbound_chunks[0] as PackedByteArray).size()

	func get_data(n: int) -> Array:
		if inbound_chunks.size() == 0:
			return [OK, PackedByteArray()]
		var b: PackedByteArray = inbound_chunks.pop_front()
		if n < b.size():
			# Should not happen given get_available_bytes(), but keep behavior sane.
			var head := b.slice(0, n)
			var tail := b.slice(n)
			inbound_chunks.push_front(tail)
			return [OK, head]
		return [OK, b]

	func server_push_bytes(bytes: PackedByteArray) -> void:
		inbound_chunks.append(bytes)

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
	get_root().add_child(client)
	await process_frame

	var peer := FakeChunkedPeer.new()
	client.call("set_peer", peer)
	client.call("set_nick", "nick_test")
	client.call("set_user", "user_test", "0", "*", "Real Name")

	var raw_lines: Array[String] = []
	var got_ping_pong := false

	client.raw_line_received.connect(func(line: String) -> void:
		raw_lines.append(line)
	)

	# Server sends a multi-line burst, split into odd chunks to exercise framing+parsing.
	var burst := ":s 001 nick_test :Welcome\r\nPING :t1\r\n:someone!u@h PRIVMSG nick_test :hi\r\n"
	var burst_bytes: PackedByteArray = burst.to_utf8_buffer()
	peer.server_push_bytes(burst_bytes.slice(0, 5))
	peer.server_push_bytes(burst_bytes.slice(5, 13))
	peer.server_push_bytes(burst_bytes.slice(13))

	var buf = (BufScript as Script).new()
	var deadline_ms: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline_ms:
		client.call("poll")
		await process_frame

		var outbound_text := peer.server_take_outbound_text()
		if outbound_text != "":
			var lines: Array[String] = buf.call("push_chunk", outbound_text)
			for line in lines:
				if line.begins_with("PONG "):
					got_ping_pong = true

		if got_ping_pong and raw_lines.size() >= 3:
			break

	if not T.require_true(self, got_ping_pong, "client must reply to PING with PONG under burst+split input"):
		return
	if not T.require_eq(self, raw_lines.size(), 3, "should receive 3 raw lines"):
		return
	if not T.require_eq(self, raw_lines[0], ":s 001 nick_test :Welcome", "raw line 0"):
		return
	if not T.require_eq(self, raw_lines[1], "PING :t1", "raw line 1"):
		return
	if not T.require_eq(self, raw_lines[2], ":someone!u@h PRIVMSG nick_test :hi", "raw line 2"):
		return

	T.pass_and_quit(self)

