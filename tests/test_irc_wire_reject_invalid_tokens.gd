extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var WireScript := load("res://addons/irc_client/IrcWire.gd")
	if WireScript == null or not (WireScript is Script) or not (WireScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing or invalid res://addons/irc_client/IrcWire.gd")
		return

	var wire = (WireScript as Script).new()
	if wire == null or not wire.has_method("format_with_max_bytes"):
		T.fail_and_quit(self, "IrcWire must implement format_with_max_bytes(command, params, trailing, max_bytes)")
		return

	var max_no_crlf: int = 510

	# Internal whitespace in tokens must be rejected (not silently removed/mutated).
	var out1: String = wire.call("format_with_max_bytes", "PRIVMSG", ["#a b"], "hi", max_no_crlf)
	if not T.require_eq(self, out1, "", "param token with spaces must be rejected"):
		return

	var out2: String = wire.call("format_with_max_bytes", "PRIVMSG", ["#a\tb"], "hi", max_no_crlf)
	if not T.require_eq(self, out2, "", "param token with tabs must be rejected"):
		return

	# Tokens starting with ':' would change meaning (becoming a trailing param); reject.
	var out3: String = wire.call("format_with_max_bytes", "JOIN", [":#chan"], "", max_no_crlf)
	if not T.require_eq(self, out3, "", "param token starting with ':' must be rejected"):
		return

	# Command must be a token too (no whitespace).
	var out4: String = wire.call("format_with_max_bytes", "PRI VMSG", ["#c"], "hi", max_no_crlf)
	if not T.require_eq(self, out4, "", "command token with spaces must be rejected"):
		return

	# Leading/trailing whitespace may be trimmed, but internal whitespace still invalid.
	var out5: String = wire.call("format_with_max_bytes", "  PRIVMSG  ", ["  #c  "], "hi", max_no_crlf)
	if not T.require_eq(self, out5, "PRIVMSG #c :hi", "leading/trailing whitespace should be trimmed"):
		return

	T.pass_and_quit(self)

