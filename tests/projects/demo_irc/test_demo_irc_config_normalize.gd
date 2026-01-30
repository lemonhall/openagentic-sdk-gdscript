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

	# Defaults
	if not T.require_eq(self, cfg.port, 6667, "default port must be 6667"):
		return
	if not T.require_eq(self, cfg.tls_enabled, false, "default tls_enabled must be false"):
		return

	# Normalization: user/realname derived from nick; channel prefix added.
	cfg.nick = "lemon_test"
	cfg.user = ""
	cfg.realname = ""
	cfg.channel = "ai-collab-test"
	cfg.normalize()

	if not T.require_eq(self, cfg.user, "lemon_test", "user must default to nick"):
		return
	if not T.require_eq(self, cfg.realname, "lemon_test", "realname must default to nick"):
		return
	if not T.require_eq(self, cfg.channel, "#ai-collab-test", "channel must be prefixed with #"):
		return

	# Normalization: do not clobber already-prefixed channels.
	cfg.channel = "&local"
	cfg.normalize()
	if not T.require_eq(self, cfg.channel, "&local", "channel prefix must be preserved"):
		return

	T.pass_and_quit(self)

