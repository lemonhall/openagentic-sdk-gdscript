extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var ParserScript := load("res://addons/irc_client/IrcParser.gd")
	if ParserScript == null or not (ParserScript is Script) or not (ParserScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing or invalid res://addons/irc_client/IrcParser.gd")
		return

	var InfoScript := load("res://addons/irc_client/IrcClientServerInfo.gd")
	if InfoScript == null or not (InfoScript is Script) or not (InfoScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing or invalid res://addons/irc_client/IrcClientServerInfo.gd")
		return

	var parser = (ParserScript as Script).new()
	var info = (InfoScript as Script).new()
	if not T.require_true(self, parser != null, "Failed to instantiate IrcParser"):
		return
	if not T.require_true(self, info != null, "Failed to instantiate IrcClientServerInfo"):
		return

	var line := ":irc.example.net 005 testnick CHANNELLEN=50 NICKLEN=9 NETWORK=ExampleNet :are supported by this server"
	var msg = parser.call("parse_line", line)
	if not T.require_true(self, msg != null, "Parser returned null msg"):
		return

	if not info.has_method("on_isupport"):
		T.fail_and_quit(self, "IrcClientServerInfo must implement on_isupport(msg)")
		return
	info.call("on_isupport", msg)

	if not info.has_method("get_int"):
		T.fail_and_quit(self, "IrcClientServerInfo must implement get_int(key, default_value)")
		return

	if not T.require_eq(self, int(info.call("get_int", "NICKLEN", 0)), 9, "NICKLEN should parse to int"):
		return
	if not T.require_eq(self, int(info.call("get_int", "CHANNELLEN", 0)), 50, "CHANNELLEN should parse to int"):
		return

	T.pass_and_quit(self)
