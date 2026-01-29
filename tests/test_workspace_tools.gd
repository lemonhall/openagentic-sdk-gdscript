extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var PathsScript := load("res://addons/openagentic/core/OAPaths.gd")
	var FsScript := load("res://addons/openagentic/core/OAWorkspaceFs.gd")
	if PathsScript == null or FsScript == null:
		T.fail_and_quit(self, "Missing OAPaths/OAWorkspaceFs")
		return

	var save_id: String = "slot_test_ws_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	var npc_id := "npc_1"
	var root: String = PathsScript.npc_workspace_dir(save_id, npc_id)

	var fs = (FsScript as Script).new(root)
	if fs == null:
		T.fail_and_quit(self, "Failed to instantiate OAWorkspaceFs")
		return

	# Basic write/read within workspace.
	var w: Dictionary = fs.write_text("notes/hello.txt", "hi")
	if not T.require_true(self, bool(w.get("ok", false)), "write_text should succeed"):
		return
	var r: Dictionary = fs.read_text("notes/hello.txt")
	if not T.require_true(self, bool(r.get("ok", false)), "read_text should succeed"):
		return
	if not T.require_eq(self, String(r.get("text", "")), "hi", "read_text should match"):
		return

	# List directory.
	var l: Dictionary = fs.list_dir("notes")
	if not T.require_true(self, bool(l.get("ok", false)), "list_dir should succeed"):
		return
	var entries: Array = l.get("entries", [])
	if not T.require_true(self, entries.any(func(e): return typeof(e) == TYPE_DICTIONARY and String((e as Dictionary).get("name", "")) == "hello.txt"), "list_dir should include hello.txt"):
		return

	# Path traversal / absolute / scheme escapes must be rejected.
	var bad_paths := [
		"../x",
		"a/../b",
		"/etc/passwd",
		"res://project.godot",
		"user://openagentic/saves/slot1/whatever.txt",
		"C:\\Windows\\system.ini",
		"..",
	]
	for bp0 in bad_paths:
		var bp := String(bp0)
		var rr: Dictionary = fs.read_text(bp)
		if not T.require_true(self, bool(rr.get("ok", false)) == false, "escape path must fail: " + bp):
			return

	T.pass_and_quit(self)
