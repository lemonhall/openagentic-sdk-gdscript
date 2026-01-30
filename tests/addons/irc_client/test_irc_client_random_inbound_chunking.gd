extends SceneTree

const T := preload("res://tests/_test_util.gd")

class FakeChunkQueuePeer:
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
			var head := b.slice(0, n)
			var tail := b.slice(n)
			inbound_chunks.push_front(tail)
			return [OK, head]
		return [OK, b]

	func push_chunk(bytes: PackedByteArray) -> void:
		inbound_chunks.append(bytes)

	func take_outbound_text() -> String:
		var s := outbound.get_string_from_utf8()
		outbound = PackedByteArray()
		return s

func _split_random(bytes: PackedByteArray, seed: int, max_chunk: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out: Array = []
	var i: int = 0
	while i < bytes.size():
		var n: int = int(rng.randi_range(1, max_chunk))
		n = min(n, bytes.size() - i)
		out.append(bytes.slice(i, i + n))
		i += n
	return out

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

	var peer := FakeChunkQueuePeer.new()
	client.call("set_peer", peer)

	var expected_in: Array[String] = [
		"PING :t1",
		":s 001 nick :Welcome",
		"PING a b",
		":someone!u@h PRIVMSG nick :hi",
		"PING",
	]

	var wire := ""
	for l in expected_in:
		wire += l + "\r\n"
	var bytes: PackedByteArray = wire.to_utf8_buffer()

	for c in _split_random(bytes, 4242, 9):
		peer.push_chunk(c)

	var got_raw: Array[String] = []
	client.raw_line_received.connect(func(line: String) -> void:
		got_raw.append(line)
	)

	var buf = (BufScript as Script).new()
	var got_pongs: Array[String] = []

	var deadline_ms: int = Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline_ms:
		client.call("poll")
		await process_frame

		var out := peer.take_outbound_text()
		if out != "":
			var lines: Array[String] = buf.call("push_chunk", out)
			for line in lines:
				if line.begins_with("PONG"):
					got_pongs.append(line)

		if got_raw.size() == expected_in.size() and got_pongs.size() >= 3:
			break

	if not T.require_eq(self, got_raw.size(), expected_in.size(), "raw line count"):
		return
	for i in expected_in.size():
		if not T.require_eq(self, got_raw[i], expected_in[i], "raw line %s" % str(i)):
			return

	# Must produce PONGs for the 3 PINGs.
	if not T.require_true(self, got_pongs.has("PONG :t1"), "PONG for trailing PING"):
		return
	if not T.require_true(self, got_pongs.has("PONG a b"), "PONG for multi-param PING"):
		return
	if not T.require_true(self, got_pongs.has("PONG"), "PONG for empty PING"):
		return

	T.pass_and_quit(self)

