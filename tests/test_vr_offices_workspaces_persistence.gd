extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var ManagerScript := load("res://vr_offices/core/VrOfficesWorkspaceManager.gd")
	var WorldStateScript := load("res://vr_offices/core/VrOfficesWorldState.gd")
	if ManagerScript == null or WorldStateScript == null:
		T.fail_and_quit(self, "Missing workspace manager / world state scripts")
		return

	var bounds := Rect2(Vector2(-10, -10), Vector2(20, 20))
	var mgr1 := (ManagerScript as Script).new(bounds) as RefCounted
	if mgr1 == null:
		T.fail_and_quit(self, "Failed to instantiate VrOfficesWorkspaceManager")
		return

	var a: Dictionary = mgr1.call("create_workspace", Rect2(Vector2(-6, -2), Vector2(3, 5)), "Design")
	if not T.require_true(self, bool(a.get("ok", false)), "Expected workspace created"):
		return
	var b: Dictionary = mgr1.call("create_workspace", Rect2(Vector2(1, 1), Vector2(3, 3)), "Ops")
	if not T.require_true(self, bool(b.get("ok", false)), "Expected second workspace created"):
		return

	# Build a state dict as VrOffices would do and ensure workspaces round-trip.
	var ws_state: Array = mgr1.call("to_state_array")
	var ws_counter := int(mgr1.call("get_workspace_counter"))

	var world_state := (WorldStateScript as Script).new() as RefCounted
	if world_state == null:
		T.fail_and_quit(self, "Failed to instantiate VrOfficesWorldState")
		return

	var st: Dictionary = world_state.call("build_state", "slot_test", "zh-CN", 0, null, ws_state, ws_counter)
	if not T.require_true(self, st.has("workspaces"), "Expected state.workspaces"):
		return
	if not T.require_eq(self, int((st.get("workspaces") as Array).size()), 2, "Expected 2 workspaces in state"):
		return

	# Load into a fresh manager.
	var mgr2 := (ManagerScript as Script).new(bounds) as RefCounted
	if mgr2 == null:
		T.fail_and_quit(self, "Failed to instantiate second workspace manager")
		return
	mgr2.call("load_from_state_dict", st)
	var ws2: Array = mgr2.call("list_workspaces")
	if not T.require_eq(self, ws2.size(), 2, "Expected 2 workspaces after reload"):
		return

	var names: Dictionary = {}
	for w0 in ws2:
		if typeof(w0) != TYPE_DICTIONARY:
			continue
		var w := w0 as Dictionary
		names[String(w.get("name", ""))] = true
	if not T.require_true(self, names.has("Design") and names.has("Ops"), "Expected workspace names to persist"):
		return

	T.pass_and_quit(self)
