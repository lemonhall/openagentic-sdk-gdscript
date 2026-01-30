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

	var save_id := "slot_test_desk_mgr_irc_log_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	mgr.call("bind_scene", root, desk_scene, Callable(self, "_is_not_headless"), func() -> String: return save_id)

	var ws_rect := Rect2(Vector2(-3, -3), Vector2(6, 6))
	var add: Dictionary = mgr.call("add_standing_desk", "ws_1", ws_rect, Vector3(0, 0, 0), 0.0)
	if not T.require_true(self, bool(add.get("ok", false)), "Expected desk placement ok"):
		return

	# Configure desks IRC (in headless tests, desk links still log config to disk).
	var cfg := {
		"host": "example.test",
		"port": 6667,
		"tls": false,
		"server_name": "",
		"password": "",
		"nicklen_default": 9,
		"channellen_default": 50,
	}
	mgr.call("set_irc_config", cfg)
	await process_frame

	var snaps0: Variant = mgr.call("list_desk_irc_snapshots")
	if not (snaps0 is Array):
		T.fail_and_quit(self, "Expected desk snapshots array")
		return
	var snaps := snaps0 as Array
	if not T.require_eq(self, snaps.size(), 1, "Expected one desk snapshot"):
		return
	var snap0: Variant = snaps[0]
	if typeof(snap0) != TYPE_DICTIONARY:
		T.fail_and_quit(self, "Expected snapshot dict")
		return
	var snap := snap0 as Dictionary

	if not T.require_true(self, snap.has("log_file_user"), "Desk snapshot must include log_file_user"):
		return
	if not T.require_true(self, snap.has("log_file_abs"), "Desk snapshot must include log_file_abs"):
		return
	var log_user := String(snap.get("log_file_user", ""))
	var log_abs := String(snap.get("log_file_abs", ""))
	if not T.require_true(self, log_user.begins_with("user://") and log_user.ends_with("/irc.log"), "Expected user log path to look like user://.../irc.log"):
		return
	if not T.require_true(self, log_abs.strip_edges() != "" and not log_abs.begins_with("user://"), "Expected absolute log path to be non-empty"):
		return

	get_root().remove_child(root)
	root.free()
	await process_frame
	T.pass_and_quit(self)
