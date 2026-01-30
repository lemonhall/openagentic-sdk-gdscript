extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var Script := load("res://demo_irc/DemoIrcConfig.gd")
	if Script == null:
		T.fail_and_quit(self, "Missing res://demo_irc/DemoIrcConfig.gd")
		return

	var cfg = (Script as GDScript).new()
	if cfg == null:
		T.fail_and_quit(self, "Failed to instantiate DemoIrcConfig")
		return

	cfg.host = "irc.example.org"
	cfg.port = 6697
	cfg.tls_enabled = true
	cfg.nick = "nick1"
	cfg.user = "user1"
	cfg.realname = "Real Name"
	cfg.channel = "#test"

	cfg.save_to_user()

	var cfg2 = (Script as GDScript).new()
	cfg2.load_from_user()

	if not T.require_eq(self, cfg2.host, cfg.host, "host mismatch"):
		return
	if not T.require_eq(self, cfg2.port, cfg.port, "port mismatch"):
		return
	if not T.require_eq(self, cfg2.tls_enabled, cfg.tls_enabled, "tls_enabled mismatch"):
		return
	if not T.require_eq(self, cfg2.nick, cfg.nick, "nick mismatch"):
		return
	if not T.require_eq(self, cfg2.user, cfg.user, "user mismatch"):
		return
	if not T.require_eq(self, cfg2.realname, cfg.realname, "realname mismatch"):
		return
	if not T.require_eq(self, cfg2.channel, cfg.channel, "channel mismatch"):
		return

	T.pass_and_quit(self)

