extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var ParserScript := load("res://addons/irc_client/IrcParser.gd")
	if ParserScript == null or not (ParserScript is Script) or not (ParserScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing or invalid res://addons/irc_client/IrcParser.gd")
		return

	var parser = (ParserScript as Script).new()
	if parser == null or not parser.has_method("parse_line"):
		T.fail_and_quit(self, "IrcParser must implement parse_line(line: String)")
		return

	var m1 = parser.call("parse_line", "  PING :abc\r\n")
	if m1 == null:
		T.fail_and_quit(self, "parse_line returned null")
		return
	if not T.require_eq(self, String(m1.command), "PING", "leading spaces: command"):
		return
	if not T.require_eq(self, String(m1.trailing), "abc", "leading spaces: trailing"):
		return

	var m2 = parser.call("parse_line", "   :nick!u@h PRIVMSG #c :hi")
	if not T.require_eq(self, String(m2.prefix), "nick!u@h", "leading spaces: prefix"):
		return
	if not T.require_eq(self, String(m2.command), "PRIVMSG", "leading spaces: command 2"):
		return

	T.pass_and_quit(self)

