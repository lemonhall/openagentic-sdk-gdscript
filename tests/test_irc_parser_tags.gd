extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var ParserScript := load("res://addons/irc_client/IrcParser.gd")
	if ParserScript == null or not (ParserScript is Script) or not (ParserScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing or invalid res://addons/irc_client/IrcParser.gd")
		return

	var parser = (ParserScript as Script).new()
	var line := "@a=1;empty;space=hello\\sworld;semi=hello\\:world;bs=hello\\\\world :nick PRIVMSG #c :hi"
	var m = parser.call("parse_line", line)
	if m == null:
		T.fail_and_quit(self, "parse_line returned null")
		return

	# Basic parse should still work.
	if not T.require_eq(self, String(m.prefix), "nick", "prefix"):
		return
	if not T.require_eq(self, String(m.command), "PRIVMSG", "command"):
		return

	# Tags should exist and be parsed/unescaped.
	var tags = (m as Object).get("tags")
	if not T.require_true(self, tags is Dictionary, "tags must be a Dictionary"):
		return
	var d: Dictionary = tags
	if not T.require_eq(self, String(d.get("a", "")), "1", "tag a"):
		return
	if not T.require_eq(self, String(d.get("empty", "MISSING")), "", "tag empty"):
		return
	if not T.require_eq(self, String(d.get("space", "")), "hello world", "tag space"):
		return
	if not T.require_eq(self, String(d.get("semi", "")), "hello;world", "tag semi"):
		return
	if not T.require_eq(self, String(d.get("bs", "")), "hello\\world", "tag bs"):
		return

	T.pass_and_quit(self)

