extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var Paths := load("res://addons/openagentic/core/OAPaths.gd")
	var FsScript := load("res://addons/openagentic/core/OAWorkspaceFs.gd")
	if Paths == null or FsScript == null:
		T.fail_and_quit(self, "Missing OAPaths/OAWorkspaceFs")
		return

	var save_id: String = "slot_test_tool_grep_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	var npc_id := "npc_1"
	var root: String = Paths.npc_workspace_dir(save_id, npc_id)
	var fs = (FsScript as Script).new(root)
	fs.write_text("notes/a.md", "Hello\n")
	fs.write_text("notes/b.txt", "TODO: fix\n")
	fs.write_text("src/main.gd", "extends Node\n# TODO: something\n")

	var ctx := {"save_id": save_id, "npc_id": npc_id, "session_id": npc_id, "workspace_root": root}
	var tools: Array = OAStandardTools.tools()
	var glob = _find_tool(tools, "Glob")
	var grep = _find_tool(tools, "Grep")
	if not T.require_true(self, glob != null and grep != null, "Missing Glob/Grep tools"):
		return

	var g1 = await glob.run_async({"pattern": "notes/*.txt"}, ctx)
	if not T.require_true(self, typeof(g1) == TYPE_DICTIONARY and bool((g1 as Dictionary).get("ok", false)), "Glob should succeed"):
		return
	var matches: Array = (g1 as Dictionary).get("matches", [])
	if not T.require_true(self, matches.size() == 1 and String(matches[0]) == "notes/b.txt", "Glob should match notes/b.txt only"):
		return

	var gr = await grep.run_async({"query": "TODO", "file_glob": "**/*.gd"}, ctx)
	if not T.require_true(self, typeof(gr) == TYPE_DICTIONARY and bool((gr as Dictionary).get("ok", false)), "Grep should succeed"):
		return
	var mm: Array = (gr as Dictionary).get("matches", [])
	if not T.require_true(self, mm.size() >= 1, "Grep should find at least one match"):
		return
	if not T.require_true(self, String((mm[0] as Dictionary).get("file_path", "")) == "src/main.gd", "Grep match should be in src/main.gd"):
		return

	T.pass_and_quit(self)

func _find_tool(tools: Array, name: String):
	for t in tools:
		if t != null and typeof(t) == TYPE_OBJECT and String(t.name) == name:
			return t
	return null
