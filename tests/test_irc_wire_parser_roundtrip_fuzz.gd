extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _rand_token(rng: RandomNumberGenerator, alphabet: String, min_len: int, max_len: int) -> String:
	var n: int = int(rng.randi_range(min_len, max_len))
	var s := ""
	for _i in n:
		s += alphabet.substr(int(rng.randi_range(0, alphabet.length() - 1)), 1)
	return s

func _init() -> void:
	var WireScript := load("res://addons/irc_client/IrcWire.gd")
	if WireScript == null or not (WireScript is Script) or not (WireScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing or invalid res://addons/irc_client/IrcWire.gd")
		return
	var ParserScript := load("res://addons/irc_client/IrcParser.gd")
	if ParserScript == null or not (ParserScript is Script) or not (ParserScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing or invalid res://addons/irc_client/IrcParser.gd")
		return

	var wire = (WireScript as Script).new()
	var parser = (ParserScript as Script).new()
	if wire == null or parser == null:
		T.fail_and_quit(self, "Failed to instantiate IrcWire/IrcParser")
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = 1337

	var cmd_alphabet := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var param_alphabet := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789#&_+-"
	var trail_fragments := ["hello", "world", "héllo", "😺", "a b", "x", "测试"]

	for case_i in 200:
		var cmd := _rand_token(rng, cmd_alphabet, 3, 10)
		var params: Array = []
		var param_count: int = int(rng.randi_range(0, 3))
		for _j in param_count:
			params.append(_rand_token(rng, param_alphabet, 1, 8))

		var trailing := ""
		if rng.randi_range(0, 1) == 1:
			# Mix a few fragments with spaces to ensure trailing can carry whitespace/UTF-8.
			var a: String = String(trail_fragments[int(rng.randi_range(0, trail_fragments.size() - 1))])
			var b: String = String(trail_fragments[int(rng.randi_range(0, trail_fragments.size() - 1))])
			trailing = "%s %s" % [a, b]

		var line: String = wire.call("format", cmd, params, trailing)
		if not T.require_true(self, line != "", "case %s: wire.format must not fail" % str(case_i)):
			return

		var msg = parser.call("parse_line", line)
		if msg == null:
			T.fail_and_quit(self, "case %s: parse_line returned null" % str(case_i))
			return

		if not T.require_eq(self, String(msg.command), cmd, "case %s: command roundtrip" % str(case_i)):
			return
		if not T.require_eq(self, int(msg.params.size()), params.size(), "case %s: params count roundtrip" % str(case_i)):
			return
		for k in params.size():
			if not T.require_eq(self, String(msg.params[k]), String(params[k]), "case %s: param %s roundtrip" % [str(case_i), str(k)]):
				return
		if not T.require_eq(self, String(msg.trailing), trailing, "case %s: trailing roundtrip" % str(case_i)):
			return

	T.pass_and_quit(self)
