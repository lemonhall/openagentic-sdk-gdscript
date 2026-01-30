extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _is_not_headless() -> bool:
	return false

func _init() -> void:
	var DeskManagerScript := load("res://vr_offices/core/VrOfficesDeskManager.gd")
	if DeskManagerScript == null or not (DeskManagerScript is Script) or not (DeskManagerScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing or invalid res://vr_offices/core/VrOfficesDeskManager.gd")
		return

	var desk_scene := load("res://vr_offices/furniture/StandingDesk.tscn")
	if desk_scene == null or not (desk_scene is PackedScene):
		T.fail_and_quit(self, "Missing res://vr_offices/furniture/StandingDesk.tscn")
		return

	var mgr := (DeskManagerScript as Script).new() as RefCounted
	if mgr == null:
		T.fail_and_quit(self, "Failed to instantiate VrOfficesDeskManager")
		return

	var root := Node3D.new()
	root.name = "DeskRoot"
	get_root().add_child(root)
	await process_frame

	mgr.call("bind_scene", root, desk_scene, Callable(self, "_is_not_headless"), func() -> String: return "slot1")

	var ws_rect := Rect2(Vector2(-3, -3), Vector2(6, 6))
	var add: Dictionary = mgr.call("add_standing_desk", "ws_1", ws_rect, Vector3(0, 0, 0), 0.0)
	if not T.require_true(self, bool(add.get("ok", false)), "Expected desk placement ok"):
		return

	var cfg1 := {
		"host": "example.test",
		"port": 6667,
		"tls": false,
		"server_name": "",
		"password": "",
		"nicklen_default": 9,
		"channellen_default": 50,
		"test_nick": "t1",
		"test_channel": "#t",
	}
	mgr.call("set_irc_config", cfg1)
	await process_frame

	var irc0: Variant = mgr.get("_irc_config")
	if typeof(irc0) != TYPE_DICTIONARY:
		T.fail_and_quit(self, "Expected desk manager to store _irc_config dictionary")
		return
	var internal1 := irc0 as Dictionary
	if not T.require_true(self, not internal1.has("test_nick") and not internal1.has("test_channel"), "Desk manager _irc_config must ignore test-only fields"):
		return
	if not T.require_true(self, String(internal1.get("host", "")) == "example.test", "Expected host in desk _irc_config"):
		return

	# Changing test-only fields must NOT reconfigure desk links (no reconnect storm).
	var cfg2 := cfg1.duplicate(true)
	cfg2["test_nick"] = "t2"
	cfg2["test_channel"] = "#t2"
	mgr.call("set_irc_config", cfg2)
	await process_frame

	var irc1: Variant = mgr.get("_irc_config")
	if typeof(irc1) != TYPE_DICTIONARY:
		T.fail_and_quit(self, "Expected desk manager to store _irc_config dictionary after second set_irc_config")
		return
	var internal2 := irc1 as Dictionary
	if not T.require_eq(self, internal2, internal1, "Desk manager _irc_config must remain stable when only test fields change"):
		return

	get_root().remove_child(root)
	root.free()
	await process_frame
	T.pass_and_quit(self)
