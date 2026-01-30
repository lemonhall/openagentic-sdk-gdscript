extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var ParserScript := load("res://addons/irc_client/IrcParser.gd")
	if ParserScript == null or not (ParserScript is Script) or not (ParserScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing or invalid res://addons/irc_client/IrcParser.gd")
		return

	var parser = (ParserScript as Script).new()
	if not T.require_true(self, parser != null, "Failed to instantiate IrcParser"):
		return

	# Build a tag value containing all standard escapes + an unknown escape.
	var tag_val := ""
	tag_val += "\\:"   # -> ';'
	tag_val += "\\s"   # -> ' '
	tag_val += "\\r"   # -> CR
	tag_val += "\\n"   # -> LF
	tag_val += "\\\\"  # -> '\'
	tag_val += "\\x"   # unknown -> 'x'

	var line := "   @a=%s;b;c=ok :p CMD" % tag_val
	var msg = parser.call("parse_line", line)
	var tags: Dictionary = (msg as Object).get("tags")

	if not T.require_true(self, tags.has("a") and tags.has("b") and tags.has("c"), "Expected tags a/b/c"):
		return

	var expected_a := ";" + " " + "\r" + "\n" + "\\" + "x"
	if not T.require_true(self, String(tags["a"]) == expected_a, "Tag unescape mismatch"):
		return
	if not T.require_true(self, String(tags["b"]) == "", "Tag without '=' should map to empty string"):
		return
	if not T.require_true(self, String(tags["c"]) == "ok", "Tag c should be 'ok'"):
		return

	T.pass_and_quit(self)

