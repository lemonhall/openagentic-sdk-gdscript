extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var Paths := load("res://addons/openagentic/core/OAPaths.gd")
	if Paths == null:
		T.fail_and_quit(self, "Missing OAPaths")
		return

	var save_id: String = "slot_test_tool_fs_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	var npc_id := "npc_1"
	var ctx := {
		"save_id": save_id,
		"npc_id": npc_id,
		"session_id": npc_id,
		"workspace_root": Paths.npc_workspace_dir(save_id, npc_id),
	}

	var tools: Array = OAStandardTools.tools()
	var write = _find_tool(tools, "Write")
	var read = _find_tool(tools, "Read")
	var edit = _find_tool(tools, "Edit")
	if not T.require_true(self, write != null and read != null and edit != null, "Missing Read/Write/Edit tools"):
		return

	var w = write.run({"file_path": "notes/a.txt", "content": "hello\nworld\n"}, ctx)
	if T.is_function_state(w):
		w = await w
	if not T.require_true(self, typeof(w) == TYPE_DICTIONARY and bool((w as Dictionary).get("ok", false)), "Write should succeed"):
		return

	var r = read.run({"file_path": "notes/a.txt"}, ctx)
	if T.is_function_state(r):
		r = await r
	if not T.require_true(self, typeof(r) == TYPE_DICTIONARY, "Read should return a dict"):
		return
	if not T.require_true(self, String((r as Dictionary).get("content", "")).find("world") != -1, "Read content should include 'world'"):
		return

	var e = edit.run({"file_path": "notes/a.txt", "old": "world", "new": "godot"}, ctx)
	if T.is_function_state(e):
		e = await e
	if not T.require_true(self, typeof(e) == TYPE_DICTIONARY and bool((e as Dictionary).get("ok", false)), "Edit should succeed"):
		return

	var r2 = read.run({"file_path": "notes/a.txt"}, ctx)
	if T.is_function_state(r2):
		r2 = await r2
	if not T.require_true(self, String((r2 as Dictionary).get("content", "")).find("godot") != -1, "Edited content should include 'godot'"):
		return

	T.pass_and_quit(self)

func _find_tool(tools: Array, name: String):
	for t in tools:
		if t != null and typeof(t) == TYPE_OBJECT and String(t.name) == name:
			return t
	return null
