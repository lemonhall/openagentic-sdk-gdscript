extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var ManagerScript := load("res://vr_offices/core/meeting_rooms/VrOfficesMeetingRoomManager.gd")
	var WorldStateScript := load("res://vr_offices/core/state/VrOfficesWorldState.gd")
	if ManagerScript == null or WorldStateScript == null:
		T.fail_and_quit(self, "Missing meeting room manager / world state scripts")
		return

	var bounds := Rect2(Vector2(-10, -10), Vector2(20, 20))
	var mgr1 := (ManagerScript as Script).new(bounds) as RefCounted
	if mgr1 == null:
		T.fail_and_quit(self, "Failed to instantiate VrOfficesMeetingRoomManager")
		return

	var a: Dictionary = mgr1.call("create_meeting_room", Rect2(Vector2(-6, -2), Vector2(3, 5)), "Design Sync")
	if not T.require_true(self, bool(a.get("ok", false)), "Expected meeting room created"):
		return
	var b: Dictionary = mgr1.call("create_meeting_room", Rect2(Vector2(1, 1), Vector2(3, 3)), "1:1")
	if not T.require_true(self, bool(b.get("ok", false)), "Expected second meeting room created"):
		return

	var rooms_state: Array = mgr1.call("to_state_array")
	var room_counter := int(mgr1.call("get_meeting_room_counter"))

	var world_state := (WorldStateScript as Script).new() as RefCounted
	if world_state == null:
		T.fail_and_quit(self, "Failed to instantiate VrOfficesWorldState")
		return

	var st: Dictionary = world_state.call("build_state", "slot_test", "zh-CN", 0, null, [], 0, [], 0, {}, rooms_state, room_counter)
	if not T.require_true(self, st.has("meeting_rooms"), "Expected state.meeting_rooms"):
		return
	if not T.require_eq(self, int((st.get("meeting_rooms") as Array).size()), 2, "Expected 2 meeting rooms in state"):
		return

	var mgr2 := (ManagerScript as Script).new(bounds) as RefCounted
	if mgr2 == null:
		T.fail_and_quit(self, "Failed to instantiate second meeting room manager")
		return
	mgr2.call("load_from_state_dict", st)
	var rooms2: Array = mgr2.call("list_meeting_rooms")
	if not T.require_eq(self, rooms2.size(), 2, "Expected 2 meeting rooms after reload"):
		return

	var names: Dictionary = {}
	for r0 in rooms2:
		if typeof(r0) != TYPE_DICTIONARY:
			continue
		var r := r0 as Dictionary
		names[String(r.get("name", ""))] = true
	if not T.require_true(self, names.has("Design Sync") and names.has("1:1"), "Expected meeting room names to persist"):
		return

	T.pass_and_quit(self)

