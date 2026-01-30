extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var Script := load("res://demo_irc/DemoIrcLogFormat.gd")
	if Script == null:
		T.fail_and_quit(self, "Missing res://demo_irc/DemoIrcLogFormat.gd")
		return

	var out: String = String((Script as GDScript).call("prepend", "01:02:03", "Hello"))
	if not T.require_eq(self, out, "[color=gray][lb]01:02:03[rb][/color] Hello", "timestamp formatting mismatch"):
		return

	T.pass_and_quit(self)

