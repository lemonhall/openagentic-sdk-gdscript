extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var BufScript := load("res://addons/irc_client/IrcLineBuffer.gd")
	if BufScript == null or not (BufScript is Script):
		T.fail_and_quit(self, "Missing or invalid res://addons/irc_client/IrcLineBuffer.gd")
		return
	if not (BufScript as Script).can_instantiate():
		T.fail_and_quit(self, "Failed to load res://addons/irc_client/IrcLineBuffer.gd (cannot instantiate)")
		return

	var buf = (BufScript as Script).new()
	if buf == null or not buf.has_method("push_chunk"):
		T.fail_and_quit(self, "IrcLineBuffer must implement push_chunk(chunk: String) -> Array[String]")
		return

	var out1: Array[String] = buf.call("push_chunk", "PING :a")
	if not T.require_eq(self, out1.size(), 0, "partial chunk should yield no lines"):
		return

	var out2: Array[String] = buf.call("push_chunk", "bc\r\n")
	if not T.require_eq(self, out2.size(), 1, "completed line should yield one line"):
		return
	if not T.require_eq(self, out2[0], "PING :abc", "line content"):
		return

	var out3: Array[String] = buf.call("push_chunk", "A\r\nB\r\n")
	if not T.require_eq(self, out3.size(), 2, "two CRLF lines"):
		return
	if not T.require_eq(self, out3[0], "A", "line A"):
		return
	if not T.require_eq(self, out3[1], "B", "line B"):
		return

	var out4: Array[String] = buf.call("push_chunk", "C\nD\n")
	if not T.require_eq(self, out4.size(), 2, "two LF lines (tolerated)"):
		return
	if not T.require_eq(self, out4[0], "C", "line C"):
		return
	if not T.require_eq(self, out4[1], "D", "line D"):
		return

	T.pass_and_quit(self)

