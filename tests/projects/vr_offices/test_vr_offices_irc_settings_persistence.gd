extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var WorldStateScript := load("res://vr_offices/core/state/VrOfficesWorldState.gd")
	if WorldStateScript == null or not (WorldStateScript is Script) or not (WorldStateScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing res://vr_offices/core/state/VrOfficesWorldState.gd")
		return
	var IrcSettingsScript := load("res://vr_offices/core/irc/VrOfficesIrcSettings.gd")
	if IrcSettingsScript == null or not (IrcSettingsScript is Script) or not (IrcSettingsScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing res://vr_offices/core/irc/VrOfficesIrcSettings.gd")
		return

	var ws = (WorldStateScript as Script).new()
	var s = (IrcSettingsScript as Script).new()
	if not T.require_true(self, ws != null, "Failed to instantiate VrOfficesWorldState"):
		return
	if not T.require_true(self, s != null, "Failed to instantiate VrOfficesIrcSettings"):
		return

	var cfg := {
		"host": "irc.example.net",
		"port": 6667,
		"tls": false,
		"server_name": "",
		"password": "pw",
		"nicklen_default": 9,
		"channellen_default": 50,
		"test_nick": "tester",
		"test_channel": "#test",
	}
	s.call("set_config", cfg)

	var st: Dictionary = ws.call("build_state", "slot_test", "zh-CN", 0, null, [], 0, [], 0, s.call("to_state_dict"))
	if not T.require_true(self, st.has("irc"), "Expected state.irc"):
		return

	var s2 = (IrcSettingsScript as Script).new()
	s2.call("load_from_state_dict", st)
	var cfg2: Dictionary = s2.call("get_config")
	if not T.require_true(self, not cfg2.has("enabled"), "Expected `enabled` to be removed from persisted IRC config"):
		return
	if not T.require_eq(self, String(cfg2.get("host", "")), "irc.example.net", "Expected host to persist"):
		return
	if not T.require_eq(self, int(cfg2.get("port", 0)), 6667, "Expected port to persist"):
		return
	if not T.require_eq(self, String(cfg2.get("test_channel", "")), "#test", "Expected test_channel to persist"):
		return

	T.pass_and_quit(self)
