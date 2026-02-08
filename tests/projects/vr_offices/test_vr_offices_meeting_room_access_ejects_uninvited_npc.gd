extends SceneTree

const T := preload("res://tests/_test_util.gd")

class FakeOpenAgentic:
	extends Node
	var save_id: String = ""
	func set_save_id(id: String) -> void: save_id = id
	func configure_proxy_openai_responses(_base_url: String, _model: String) -> void: pass
	func enable_default_tools() -> void: pass
	func set_approver(_fn: Callable) -> void: pass
	func add_before_turn_hook(_name: String, _npc_id_glob: String, _cb: Callable) -> void: pass
	func add_after_turn_hook(_name: String, _npc_id_glob: String, _cb: Callable) -> void: pass

func _init() -> void:
	var oa := FakeOpenAgentic.new()
	oa.name = "OpenAgentic"
	oa.set_save_id("slot_test_vr_offices_meeting_access_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())])
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

	var room0: Variant = res.get("meeting_room", {})
	var rid := String((room0 as Dictionary).get("id", "")).strip_edges() if typeof(room0) == TYPE_DICTIONARY else ""
	if rid == "":
		T.fail_and_quit(self, "Meeting room id empty")
		return

	var rect0: Variant = mgr.call("get_meeting_room_rect_xz", rid)
	var rect: Rect2 = rect0 as Rect2 if rect0 is Rect2 else Rect2()
	if rect.size == Vector2.ZERO:
		T.fail_and_quit(self, "Meeting room rect missing")
		return

	var npc_scene := load("res://vr_offices/npc/Npc.tscn")
	if npc_scene == null or not (npc_scene is PackedScene):
		T.fail_and_quit(self, "Missing Npc.tscn")
		return
	var npc := (npc_scene as PackedScene).instantiate() as Node
	if npc == null or not (npc is Node3D):
		T.fail_and_quit(self, "Failed to instantiate Npc Node3D")
		return
	npc.name = "npc_intruder"
	if npc.has_method("set"):
		npc.set("npc_id", "npc_intruder")
		npc.set("display_name", "Intruder")
	var npc_root := s.get_node_or_null("NpcRoot") as Node3D
	if npc_root == null:
		T.fail_and_quit(self, "Missing NpcRoot")
		return
	npc_root.add_child(npc)
	await process_frame

	# Teleport the NPC inside the meeting room (simulates "wandering in").
	var center := rect.position + rect.size * 0.5
	(npc as Node3D).global_position = Vector3(center.x, 0.3, center.y)
	await process_frame

	var escaped := false
	for _i in range(360):
		await process_frame
		var p := (npc as Node3D).global_position
		var inside := rect.has_point(Vector2(p.x, p.z))
		if not inside:
			escaped = true
			break

	if not T.require_true(self, escaped, "Expected uninvited NPC to be ejected from meeting room bounds"):
		return
	if npc.has_method("get_bound_meeting_room_id"):
		if not T.require_eq(self, String(npc.call("get_bound_meeting_room_id")).strip_edges(), "", "Uninvited NPC must not become meeting-bound"):
			return

	T.pass_and_quit(self)
