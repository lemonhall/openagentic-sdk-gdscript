extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var WireScript := load("res://addons/irc_client/IrcWire.gd")
	if WireScript == null or not (WireScript is Script) or not (WireScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing or invalid res://addons/irc_client/IrcWire.gd")
		return

	var wire = (WireScript as Script).new()
	if wire == null or not wire.has_method("format"):
		T.fail_and_quit(self, "IrcWire must implement format(command: String, params: Array[String], trailing: String) -> String")
		return

	var s1: String = wire.call("format", "PING", [], "abc")
	if not T.require_eq(self, s1, "PING :abc", "PING trailing formatting"):
		return

	var s2: String = wire.call("format", "PRIVMSG", ["#c"], "hello world")
	if not T.require_eq(self, s2, "PRIVMSG #c :hello world", "PRIVMSG formatting"):
		return

	var s3: String = wire.call("format", "JOIN", ["#c"], "")
	if not T.require_eq(self, s3, "JOIN #c", "JOIN formatting"):
		return

	var s4: String = wire.call("format", "NOTICE", ["#c"], "hi\r\nEVIL")
	if not T.require_true(self, s4.find("\r") == -1 and s4.find("\n") == -1, "wire output must not contain CR/LF"):
		return
	if not T.require_eq(self, s4, "NOTICE #c :hiEVIL", "CRLF stripped from trailing"):
		return

	# Empty trailing is a meaningful protocol state for some commands (e.g. PRIVMSG/NOTICE).
	if not wire.has_method("format_with_max_bytes"):
		T.fail_and_quit(self, "IrcWire must implement format_with_max_bytes(command, params, trailing, max_bytes, force_trailing?)")
		return
	var s5: String = wire.call("format_with_max_bytes", "PRIVMSG", ["#c"], "", 510, true)
	if not T.require_eq(self, s5, "PRIVMSG #c :", "forced empty trailing must emit trailing marker"):
		return

	T.pass_and_quit(self)
