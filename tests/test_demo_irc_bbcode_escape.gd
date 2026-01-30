extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var Script := load("res://demo_irc/DemoIrcInbound.gd")
	if Script == null:
		T.fail_and_quit(self, "Missing res://demo_irc/DemoIrcInbound.gd")
		return

	var inbound = (Script as GDScript).new()
	if inbound == null:
		T.fail_and_quit(self, "Failed to instantiate DemoIrcInbound")
		return

	var escaped: String = String(inbound.call("_escape_bbcode", "[432] Nickname too long, max. 9 characters"))
	if not T.require_eq(self, escaped, "[lb]432[rb] Nickname too long, max. 9 characters", "bbcode escape mismatch"):
		return
	if not T.require_true(self, escaped.find("[lb[rb]") == -1, "escape must not self-corrupt (found '[lb[rb]')"):
		return

	T.pass_and_quit(self)

