extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var Paths := load("res://addons/openagentic/core/OAPaths.gd")
	var FsScript := load("res://addons/openagentic/core/OAWorkspaceFs.gd")
	if Paths == null or FsScript == null:
		T.fail_and_quit(self, "Missing OAPaths/OAWorkspaceFs")
		return

	var save_id: String = "slot_test_skill_tool_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	var npc_id := "npc_1"
	var root: String = Paths.npc_workspace_dir(save_id, npc_id)
	var fs = (FsScript as Script).new(root)
	fs.write_text("skills/main-process/SKILL.md", "# Main Process\n\nDo the thing.")
	fs.write_text("skills/spreadsheets/SKILL.md", "# Spreadsheets\n\nYou love sheets.")

	var ctx := {"save_id": save_id, "npc_id": npc_id, "session_id": npc_id, "workspace_root": root}
	var tools: Array = OAStandardTools.tools()
	var skill = _find_tool(tools, "Skill")
	if not T.require_true(self, skill != null, "Missing Skill tool"):
		return

	# Listing (name omitted).
	var list_out = await skill.run_async({}, ctx)
	if not T.require_true(self, typeof(list_out) == TYPE_DICTIONARY, "Skill list must be dict"):
		return
	var names: Array = (list_out as Dictionary).get("skills", [])
	if not T.require_true(self, names.has("main-process") and names.has("spreadsheets"), "Skill list should include both skills"):
		return

	# Load specific skill.
	var load_out = await skill.run_async({"name": "main-process"}, ctx)
	if not T.require_true(self, typeof(load_out) == TYPE_DICTIONARY, "Skill load must be dict"):
		return
	if not T.require_true(self, String((load_out as Dictionary).get("output", "")).find("Main Process") != -1, "Skill output should include body"):
		return

	T.pass_and_quit(self)

func _find_tool(tools: Array, name: String):
	for t in tools:
		if t != null and typeof(t) == TYPE_OBJECT and String(t.name) == name:
			return t
	return null
