extends SceneTree

const T := preload("res://tests/_test_util.gd")

class FakeOpenAgentic:
	extends Node

	var save_id: String = ""
	var system_prompt: String = ""

	func set_save_id(id: String) -> void:
		save_id = id

	func configure_proxy_openai_responses(_base_url: String, _model: String) -> void:
		pass

	func enable_default_tools() -> void:
		pass

	func set_approver(_fn: Callable) -> void:
		pass

	func add_before_turn_hook(_name: String, _npc_id_glob: String, _cb: Callable) -> void:
		pass

	func add_after_turn_hook(_name: String, _npc_id_glob: String, _cb: Callable) -> void:
		pass

func _init() -> void:
	var oa := FakeOpenAgentic.new()
	oa.name = "OpenAgentic"
	oa.set_save_id("slot_test_vr_offices_meeting_state_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())])
	get_root().add_child(oa)

	var VrScene := load("res://vr_offices/VrOffices.tscn")
	if VrScene == null or not (VrScene is PackedScene):
		T.fail_and_quit(self, "Missing VrOffices scene")
		return
	var s := (VrScene as PackedScene).instantiate()
	root.add_child(s)
	await process_frame

	var mgr0: Variant = s.get("_meeting_room_manager")
	if not (mgr0 is RefCounted):
		T.fail_and_quit(self, "Missing _meeting_room_manager")
		return
	var mgr := mgr0 as RefCounted
	var res: Dictionary = mgr.call("create_meeting_room", Rect2(Vector2(-2, -2), Vector2(4, 4)), "Room A")
	if not T.require_true(self, bool(res.get("ok", false)), "Expected create_meeting_room ok"):
		return
	await process_frame
	await process_frame

	var rooms_root := s.get_node_or_null("MeetingRooms") as Node3D
	if rooms_root == null or rooms_root.get_child_count() < 1:
		T.fail_and_quit(self, "Missing MeetingRooms child")
		return
	var room := rooms_root.get_child(0) as Node
	if room == null:
		T.fail_and_quit(self, "Missing meeting room node")
		return
	var rid := String(room.name).strip_edges()
	if rid == "":
		T.fail_and_quit(self, "Meeting room id empty")
		return
	var table := room.get_node_or_null("Decor/Table") as Node3D
	if table == null:
		T.fail_and_quit(self, "Missing Decor/Table")
		return

	var npc_scene := load("res://vr_offices/npc/Npc.tscn")
	if npc_scene == null or not (npc_scene is PackedScene):
		T.fail_and_quit(self, "Missing Npc.tscn")
		return
	var npc := (npc_scene as PackedScene).instantiate() as Node
	if npc == null:
		T.fail_and_quit(self, "Failed to instantiate Npc")
		return
	npc.name = "npc_01"
	if npc.has_method("set"):
		npc.set("npc_id", "npc_01")
		npc.set("display_name", "Alice")
	var npc_root := s.get_node_or_null("NpcRoot") as Node3D
	if npc_root == null:
		T.fail_and_quit(self, "Missing NpcRoot")
		return
	npc_root.add_child(npc)
	await process_frame

	var meeting_ring := npc.get_node_or_null("MeetingRing") as Node
	if not T.require_true(self, meeting_ring != null, "Expected NPC MeetingRing node for meeting-bound state visibility"):
		return
	if meeting_ring is CanvasItem:
		if not T.require_true(self, not bool((meeting_ring as CanvasItem).visible), "MeetingRing must start hidden"):
			return
	elif meeting_ring is Node3D:
		if not T.require_true(self, not bool((meeting_ring as Node3D).visible), "MeetingRing must start hidden"):
			return

	var near := table.global_position + Vector3(1.0, 0.0, 0.0)
	npc.emit_signal("move_target_reached", "npc_01", Vector3(near.x, 0.0, near.z))
	await process_frame

	if not T.require_true(self, npc.has_method("get_bound_meeting_room_id"), "Npc missing get_bound_meeting_room_id()"):
		return
	if not T.require_eq(self, String(npc.call("get_bound_meeting_room_id")), rid, "NPC should enter meeting state near the table"):
		return
	if not T.require_true(self, not bool(npc.get("wander_enabled")), "Meeting NPC should stop wandering"):
		return
	if meeting_ring is CanvasItem:
		if not T.require_true(self, bool((meeting_ring as CanvasItem).visible), "MeetingRing must be visible when meeting-bound"):
			return
	elif meeting_ring is Node3D:
		if not T.require_true(self, bool((meeting_ring as Node3D).visible), "MeetingRing must be visible when meeting-bound"):
			return

	# Repro: command_move_to sets a "waiting-for-work" timer by default; meeting state must suppress that.
	# Use a target near the table end (outside center radius) but within 2m of the table footprint.
	var table_body := table.get_node_or_null("TableCollision") as StaticBody3D
	var shape_node := table_body.get_node_or_null("Shape") as CollisionShape3D if table_body != null else null
	if not T.require_true(self, shape_node != null and shape_node.shape is BoxShape3D, "Expected table collision box"):
		return
	var box := shape_node.shape as BoxShape3D
	var hx := float(box.size.x) * 0.5
	var local_outside := Vector3(shape_node.position.x + hx + 0.5, 0.0, shape_node.position.z)
	var p_global := table_body.to_global(local_outside)
	if npc is Node3D:
		# Start a bit away so the NPC has to process a real move-to completion.
		(npc as Node3D).global_position = Vector3(p_global.x + 3.0, 0.3, p_global.z)
	# Wait until the NPC settles on the floor.
	for _k in range(60):
		await process_frame
		if npc.has_method("is_on_floor") and bool(npc.call("is_on_floor")):
			break
	npc.call("command_move_to", Vector3(p_global.x, 0.0, p_global.z))
	for _m in range(240):
		await process_frame
		if not bool(npc.get("_goto_active")):
			break
	if not T.require_eq(self, String(npc.call("get_bound_meeting_room_id")), rid, "Move-to near table footprint should keep meeting binding"):
		return
	if not T.require_true(self, float(npc.get("_waiting_for_work_left")) <= 0.001, "Meeting-bound NPC must not start waiting-for-work timer"):
		return

	var far := table.global_position + Vector3(5.0, 0.0, 5.0)
	npc.call("command_move_to", Vector3(far.x, 0.0, far.z))
	for _n in range(600):
		await process_frame
		if not bool(npc.get("_goto_active")):
			break
	if not T.require_true(self, not bool(npc.get("_goto_active")), "Expected NPC to reach far target"):
		return

	if not T.require_eq(self, String(npc.call("get_bound_meeting_room_id")), "", "NPC should exit meeting state when moved away"):
		return
	if not T.require_true(self, bool(npc.get("wander_enabled")), "NPC should resume wandering after meeting exit"):
		return
	if meeting_ring is CanvasItem:
		if not T.require_true(self, not bool((meeting_ring as CanvasItem).visible), "MeetingRing must hide after meeting exit"):
			return
	elif meeting_ring is Node3D:
		if not T.require_true(self, not bool((meeting_ring as Node3D).visible), "MeetingRing must hide after meeting exit"):
			return

	T.pass_and_quit(self)
