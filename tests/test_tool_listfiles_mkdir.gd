extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var Paths := load("res://addons/openagentic/core/OAPaths.gd")
	if Paths == null:
		T.fail_and_quit(self, "Missing OAPaths")
		return

	var save_id: String = "slot_test_tool_listfiles_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	var npc_id := "npc_1"
	var root: String = Paths.npc_workspace_dir(save_id, npc_id)
	var ctx := {
		"save_id": save_id,
		"npc_id": npc_id,
		"session_id": npc_id,
		"workspace_root": root,
	}

	var tools: Array = OAStandardTools.tools()
	var mkdir = _find_tool(tools, "Mkdir")
	var listfiles = _find_tool(tools, "ListFiles")
	var write = _find_tool(tools, "Write")
	if not T.require_true(self, mkdir != null and listfiles != null and write != null, "Missing Mkdir/ListFiles/Write tools"):
		return

	var m1 = await mkdir.run_async({"path": "a/b"}, ctx)
	if not T.require_true(self, typeof(m1) == TYPE_DICTIONARY and bool((m1 as Dictionary).get("ok", false)), "Mkdir should succeed"):
		return

	var w1 = await write.run_async({"file_path": "a/b/hello.txt", "content": "hi\n"}, ctx)
	if not T.require_true(self, typeof(w1) == TYPE_DICTIONARY and bool((w1 as Dictionary).get("ok", false)), "Write should succeed"):
		return

	var lf = await listfiles.run_async({"path": "a", "recursive": true, "include_dirs": true, "include_files": true}, ctx)
	if not T.require_true(self, typeof(lf) == TYPE_DICTIONARY and bool((lf as Dictionary).get("ok", false)), "ListFiles should succeed"):
		return
	var entries: Array = (lf as Dictionary).get("entries", [])
	var paths: Array[String] = []
	for e0 in entries:
		if typeof(e0) == TYPE_DICTIONARY:
			paths.append(String((e0 as Dictionary).get("path", "")))
	if not T.require_true(self, paths.has("a/b") and paths.has("a/b/hello.txt"), "ListFiles should include created dir+file. Got: " + str(paths)):
		return

	var bad1 = await mkdir.run_async({"path": "../escape"}, ctx)
	if not T.require_true(self, typeof(bad1) == TYPE_DICTIONARY and not bool((bad1 as Dictionary).get("ok", true)), "Mkdir should reject path traversal"):
		return

	var bad2 = await listfiles.run_async({"path": "../"}, ctx)
	if not T.require_true(self, typeof(bad2) == TYPE_DICTIONARY and not bool((bad2 as Dictionary).get("ok", true)), "ListFiles should reject path traversal"):
		return

	T.pass_and_quit(self)

func _find_tool(tools: Array, name: String):
	for t in tools:
		if t != null and typeof(t) == TYPE_OBJECT and String(t.name) == name:
			return t
	return null
