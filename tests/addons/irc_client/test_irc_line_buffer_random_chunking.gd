extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _feed_random_chunks(buf: RefCounted, bytes: PackedByteArray, seed: int, max_chunk: int) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out: Array[String] = []
	var i: int = 0
	while i < bytes.size():
		var n: int = int(rng.randi_range(1, max_chunk))
		n = min(n, bytes.size() - i)
		var chunk := bytes.slice(i, i + n)
		var lines: Array[String] = buf.call("push_bytes", chunk)
		for l in lines:
			out.append(l)
		i += n
	return out

func _init() -> void:
	var BufScript := load("res://addons/irc_client/IrcLineBuffer.gd")
	if BufScript == null or not (BufScript is Script) or not (BufScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing or invalid res://addons/irc_client/IrcLineBuffer.gd")
		return

	var buf = (BufScript as Script).new()
	if buf == null or not buf.has_method("push_bytes"):
		T.fail_and_quit(self, "IrcLineBuffer must implement push_bytes(chunk: PackedByteArray) -> Array[String]")
		return

	var expected: Array[String] = [
		"PING :abc",
		":nick!u@h PRIVMSG #c :hello world",
		"NOTICE #c :héllo 😺",
		"ERROR :bye",
	]

	var wire := ""
	for l in expected:
		wire += l + "\r\n"
	var bytes: PackedByteArray = wire.to_utf8_buffer()

	# Run a few deterministic seeds to cover many fragmentation patterns.
	for seed in [1, 2, 3, 4, 5]:
		buf = (BufScript as Script).new()
		var got: Array[String] = _feed_random_chunks(buf, bytes, seed, 7)
		if not T.require_eq(self, got.size(), expected.size(), "seed %s: line count" % str(seed)):
			return
		for idx in expected.size():
			if not T.require_eq(self, got[idx], expected[idx], "seed %s: line %s" % [str(seed), str(idx)]):
				return

	T.pass_and_quit(self)

