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

	# Max bytes excluding CRLF (IRC total is 512 including CRLF).
	var max_no_crlf: int = 510

	# ASCII truncation.
	var long_trailing: String = "a".repeat(2000)
	var out1: String = wire.call("format_with_max_bytes", "PRIVMSG", ["#c"], long_trailing, max_no_crlf)
	var out1_bytes: PackedByteArray = out1.to_utf8_buffer()
	if not T.require_true(self, out1_bytes.size() <= max_no_crlf, "wire line must be <= max bytes (no CRLF)"):
		return
	if not T.require_true(self, out1.begins_with("PRIVMSG #c :"), "must keep command/params/trailing marker"):
		return

	# UTF-8 safe truncation (don't split multibyte codepoints).
	var multibyte: String = "é".repeat(2000) # 2 bytes each in UTF-8
	var out2: String = wire.call("format_with_max_bytes", "NOTICE", ["#c"], multibyte, max_no_crlf)
	var out2_bytes: PackedByteArray = out2.to_utf8_buffer()
	if not T.require_true(self, out2_bytes.size() <= max_no_crlf, "wire line must be <= max bytes (UTF-8)"):
		return
	# Ensure output round-trips without replacement characters.
	if not T.require_true(self, out2.find("�") == -1, "UTF-8 truncation must not create replacement characters"):
		return

	# Impossible to fit: very long command token should fail.
	var out3: String = wire.call("format_with_max_bytes", "X".repeat(600), [], "", max_no_crlf)
	if not T.require_eq(self, out3, "", "should refuse to format when fixed parts exceed max"):
		return

	T.pass_and_quit(self)

