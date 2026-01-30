extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var LinkScript := load("res://vr_offices/core/desks/VrOfficesDeskIrcLink.gd")
	if LinkScript == null or not (LinkScript is Script) or not (LinkScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing or invalid res://vr_offices/core/desks/VrOfficesDeskIrcLink.gd")
		return

	var link := (LinkScript as Script).new() as Node
	if link == null:
		T.fail_and_quit(self, "Failed to instantiate VrOfficesDeskIrcLink")
		return
	get_root().add_child(link)
	await process_frame

	var save_id: String = "slot_test_desk_irc_log_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	var cfg := {
		"host": "example.test",
		"port": 6667,
		"tls": false,
		"server_name": "",
		"password": "",
		"nicklen_default": 9,
		"channellen_default": 50,
	}
	link.call("configure", cfg, save_id, "ws_1", "desk_1")
	await process_frame

	var snap0: Variant = link.call("get_debug_snapshot")
	if typeof(snap0) != TYPE_DICTIONARY:
		T.fail_and_quit(self, "Expected debug snapshot dict")
		return
	var snap := snap0 as Dictionary

	if not T.require_true(self, snap.has("log_file_user"), "Snapshot must include log_file_user"):
		return
	if not T.require_true(self, snap.has("log_file_abs"), "Snapshot must include log_file_abs"):
		return

	var user_path := String(snap.get("log_file_user", ""))
	if not T.require_true(self, user_path.begins_with("user://"), "Expected user:// log path"):
		return
	if not T.require_true(self, FileAccess.file_exists(user_path), "Expected desk IRC log file to exist"):
		return

	var f := FileAccess.open(user_path, FileAccess.READ)
	if f == null:
		T.fail_and_quit(self, "Failed to open desk IRC log file for read")
		return
	var txt := f.get_as_text()
	f.close()
	if not T.require_true(self, txt.find("config desk=") != -1, "Expected log to contain a configure line"):
		return

	get_root().remove_child(link)
	link.free()
	await process_frame
	T.pass_and_quit(self)
