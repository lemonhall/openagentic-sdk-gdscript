extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var DeskScript := load("res://vr_offices/core/desks/VrOfficesDeskManager.gd")
	var WorldStateScript := load("res://vr_offices/core/state/VrOfficesWorldState.gd")
	if DeskScript == null or WorldStateScript == null:
		T.fail_and_quit(self, "Missing desk manager / world state scripts")
		return

	var desk_mgr1 := (DeskScript as Script).new() as RefCounted
	if desk_mgr1 == null:
		T.fail_and_quit(self, "Failed to instantiate VrOfficesDeskManager")
		return

	var ws_rect := Rect2(Vector2(-3, -3), Vector2(6, 6))
	var add1: Dictionary = desk_mgr1.call("add_standing_desk", "ws_7", ws_rect, Vector3(1, 0, 2), 0.0)
	if not T.require_true(self, bool(add1.get("ok", false)), "Expected first desk placement ok"):
		return
	var desks_state: Array = desk_mgr1.call("to_state_array")
	var desk_counter := int(desk_mgr1.call("get_desk_counter"))

	var world_state := (WorldStateScript as Script).new() as RefCounted
	if world_state == null:
		T.fail_and_quit(self, "Failed to instantiate VrOfficesWorldState")
		return

	var st: Dictionary = world_state.call("build_state", "slot_test", "zh-CN", 0, null, [], 0, desks_state, desk_counter)
	if not T.require_true(self, st.has("desks"), "Expected state.desks"):
		return
	if not T.require_eq(self, int((st.get("desks") as Array).size()), 1, "Expected 1 desk in state"):
		return

	var desk_mgr2 := (DeskScript as Script).new() as RefCounted
	if desk_mgr2 == null:
		T.fail_and_quit(self, "Failed to instantiate second desk manager")
		return
	desk_mgr2.call("load_from_state_dict", st)
	var desks2: Array = desk_mgr2.call("list_desks")
	if not T.require_eq(self, desks2.size(), 1, "Expected 1 desk after reload"):
		return
	var d0 := desks2[0] as Dictionary
	if not T.require_eq(self, String(d0.get("workspace_id", "")), "ws_7", "Expected workspace_id to persist"):
		return

	T.pass_and_quit(self)
