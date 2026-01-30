extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var BufScript := load("res://addons/irc_client/IrcLineBuffer.gd")
	if BufScript == null or not (BufScript is Script) or not (BufScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing or invalid res://addons/irc_client/IrcLineBuffer.gd")
		return

	var buf = (BufScript as Script).new()
	if buf == null or not buf.has_method("set_max_buffer_bytes") or not buf.has_method("take_overflowed"):
		T.fail_and_quit(self, "IrcLineBuffer must implement set_max_buffer_bytes(int) and take_overflowed()")
		return

	buf.call("set_max_buffer_bytes", 8)
	var chunk := PackedByteArray([1,2,3,4,5,6,7,8,9]) # 9 bytes, no newline
	var out: Array[String] = buf.call("push_bytes", chunk)
	if not T.require_eq(self, out.size(), 0, "no newline yields no lines"):
		return
	var overflowed: bool = bool(buf.call("take_overflowed"))
	if not T.require_true(self, overflowed, "buffer should overflow when exceeding max without newline"):
		return

	# After overflow, buffer should reset so future valid input works.
	buf.call("set_max_buffer_bytes", 64)
	var out2: Array[String] = buf.call("push_chunk", "PING :a\r\n")
	if not T.require_eq(self, out2.size(), 1, "should recover after overflow"):
		return
	if not T.require_eq(self, out2[0], "PING :a", "recovered line content"):
		return

	T.pass_and_quit(self)
