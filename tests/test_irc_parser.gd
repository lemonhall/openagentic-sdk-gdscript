extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var ParserScript := load("res://addons/irc_client/IrcParser.gd")
	if ParserScript == null or not (ParserScript is Script):
		T.fail_and_quit(self, "Missing or invalid res://addons/irc_client/IrcParser.gd")
		return
	if not (ParserScript as Script).can_instantiate():
		T.fail_and_quit(self, "Failed to load res://addons/irc_client/IrcParser.gd (cannot instantiate)")
		return

	var parser = (ParserScript as Script).new()
	if parser == null or not parser.has_method("parse_line"):
		T.fail_and_quit(self, "IrcParser must implement parse_line(line: String)")
		return

	var m1 = parser.call("parse_line", "PING :abc\r\n")
	if m1 == null:
		T.fail_and_quit(self, "parse_line returned null")
		return

	if not T.require_eq(self, String(m1.prefix), "", "PING prefix"):
		return
	if not T.require_eq(self, String(m1.command), "PING", "PING command"):
		return
	if not T.require_eq(self, int(m1.params.size()), 0, "PING params"):
		return
	if not T.require_eq(self, String(m1.trailing), "abc", "PING trailing"):
		return

	var m2 = parser.call("parse_line", ":nick!user@host PRIVMSG #chan :hello world")
	if not T.require_eq(self, String(m2.prefix), "nick!user@host", "PRIVMSG prefix"):
		return
	if not T.require_eq(self, String(m2.command), "PRIVMSG", "PRIVMSG command"):
		return
	if not T.require_eq(self, int(m2.params.size()), 1, "PRIVMSG params count"):
		return
	if not T.require_eq(self, String(m2.params[0]), "#chan", "PRIVMSG param0"):
		return
	if not T.require_eq(self, String(m2.trailing), "hello world", "PRIVMSG trailing"):
		return

	var m3 = parser.call("parse_line", ":server 001 nick :Welcome")
	if not T.require_eq(self, String(m3.prefix), "server", "001 prefix"):
		return
	if not T.require_eq(self, String(m3.command), "001", "001 command"):
		return
	if not T.require_eq(self, int(m3.params.size()), 1, "001 params count"):
		return
	if not T.require_eq(self, String(m3.params[0]), "nick", "001 param0"):
		return
	if not T.require_eq(self, String(m3.trailing), "Welcome", "001 trailing"):
		return

	T.pass_and_quit(self)
