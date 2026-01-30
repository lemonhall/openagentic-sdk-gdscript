extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var Paths := load("res://addons/openagentic/core/OAPaths.gd")
	var StoreScript := load("res://addons/openagentic/core/OAJsonlNpcSessionStore.gd")
	var FsScript := load("res://addons/openagentic/core/OAWorkspaceFs.gd")
	if Paths == null or StoreScript == null or FsScript == null:
		T.fail_and_quit(self, "Missing OpenAgentic classes")
		return

	var save_id: String = "slot_test_todos_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	var npc_id := "npc_1"
	var root: String = Paths.npc_workspace_dir(save_id, npc_id)
	var ctx := {"save_id": save_id, "npc_id": npc_id, "session_id": npc_id, "workspace_root": root}

	var tools: Array = OAStandardTools.tools()
	var todo = _find_tool(tools, "TodoWrite")
	if not T.require_true(self, todo != null, "Missing TodoWrite tool"):
		return

	var todos := [
		{"content": "A", "status": "pending", "id": "1"},
		{"content": "B", "status": "in_progress", "id": "2"},
		{"content": "C", "status": "completed", "id": "3"},
	]
	var out = await todo.run_async({"todos": todos}, ctx)
	if not T.require_true(self, typeof(out) == TYPE_DICTIONARY, "TodoWrite should return dict"):
		return
	var stats: Dictionary = (out as Dictionary).get("stats", {})
	if not T.require_eq(self, int(stats.get("total", 0)), 3, "Expected total=3"):
		return
	if not T.require_eq(self, int(stats.get("pending", 0)), 1, "Expected pending=1"):
		return
	if not T.require_eq(self, int(stats.get("in_progress", 0)), 1, "Expected in_progress=1"):
		return
	if not T.require_eq(self, int(stats.get("completed", 0)), 1, "Expected completed=1"):
		return

	# Workspace persistence.
	var fs = (FsScript as Script).new(root)
	var rr: Dictionary = fs.read_text("todos.json")
	if not T.require_true(self, bool(rr.get("ok", false)), "Expected todos.json written"):
		return

	# Session log append.
	var store = StoreScript.new(save_id)
	var events: Array = store.read_events(npc_id)
	if not T.require_true(self, events.any(func(e): return typeof(e) == TYPE_DICTIONARY and String((e as Dictionary).get("type", "")) == "todo.write"), "Expected todo.write event"):
		return

	T.pass_and_quit(self)

func _find_tool(tools: Array, name: String):
	for t in tools:
		if t != null and typeof(t) == TYPE_OBJECT and String(t.name) == name:
			return t
	return null
