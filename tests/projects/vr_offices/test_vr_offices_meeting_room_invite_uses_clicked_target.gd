extends SceneTree

const T := preload("res://tests/_test_util.gd")

class FakeOpenAgentic:
	extends Node

	var save_id: String = ""

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
	oa.set_save_id("slot_test_vr_offices_meeting_invite_target_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())])
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

	var npc_scene := load("res://vr_offices/npc/Npc.tscn")
	if npc_scene == null or not (npc_scene is PackedScene):
		T.fail_and_quit(self, "Missing Npc.tscn")
		return
	var npc_root := s.get_node_or_null("NpcRoot") as Node3D
	if npc_root == null:
		T.fail_and_quit(self, "Missing NpcRoot")
		return

	var npc_a := (npc_scene as PackedScene).instantiate() as Node
	if npc_a == null:
		T.fail_and_quit(self, "Failed to instantiate NPC A")
		return
	npc_a.name = "npc_a"
	if npc_a.has_method("set"):
		npc_a.set("npc_id", "npc_a")
		npc_a.set("display_name", "Alice")
	npc_root.add_child(npc_a)

	var npc_b := (npc_scene as PackedScene).instantiate() as Node
	if npc_b == null:
		T.fail_and_quit(self, "Failed to instantiate NPC B")
		return
	npc_b.name = "npc_b"
	if npc_b.has_method("set"):
		npc_b.set("npc_id", "npc_b")
		npc_b.set("display_name", "Bob")
	npc_root.add_child(npc_b)
	await process_frame

	if not T.require_true(self, s.has_method("_transform_move_command_for_meetings"), "VrOffices must have _transform_move_command_for_meetings(npc, clicked_pos)"):
		return

	var click1 := Vector3(-1.8, 0.0, -1.8)
	var tr1_0: Variant = s.call("_transform_move_command_for_meetings", npc_a, click1)
	if not (tr1_0 is Dictionary):
		T.fail_and_quit(self, "Expected transformer result to be a Dictionary")
		return
	var tr1 := tr1_0 as Dictionary
	if not T.require_true(self, bool(tr1.get("skip_default", false)), "Expected invite to set skip_default=true for non-invited NPC"):
		return
	var t1_0: Variant = tr1.get("target", null)
	if not (t1_0 is Vector3):
		T.fail_and_quit(self, "Expected transformer to provide a Vector3 target")
		return
	var t1 := t1_0 as Vector3
	if not T.require_true(self, absf(t1.x - click1.x) < 0.5, "Invite target.x must be close to clicked_pos.x"):
		return
	if not T.require_true(self, absf(t1.z - click1.z) < 0.5, "Invite target.z must be close to clicked_pos.z"):
		return
	if not T.require_true(self, absf(t1.y - click1.y) < 0.5, "Invite target.y must be close to clicked_pos.y (floor)"):
		return

	# Once pending/invited for this room, RMB inside the room should behave like a normal move (no re-invite override).
	var click2 := Vector3(1.8, 0.0, 1.8)
	var tr1b_0: Variant = s.call("_transform_move_command_for_meetings", npc_a, click2)
	if not (tr1b_0 is Dictionary):
		T.fail_and_quit(self, "Expected transformer result to be a Dictionary (second click)")
		return
	var tr1b := tr1b_0 as Dictionary
	if not T.require_true(self, not bool(tr1b.get("skip_default", false)), "Pending/invited NPC RMB inside room must not skip_default"):
		return

	# A fresh NPC invited by RMB should also use the clicked target (not a deterministic table ring point).
	var tr2_0: Variant = s.call("_transform_move_command_for_meetings", npc_b, click2)
	if not (tr2_0 is Dictionary):
		T.fail_and_quit(self, "Expected transformer result to be a Dictionary (NPC B)")
		return
	var tr2 := tr2_0 as Dictionary
	if not T.require_true(self, bool(tr2.get("skip_default", false)), "Expected invite to set skip_default=true for NPC B"):
		return
	var t2_0: Variant = tr2.get("target", null)
	if not (t2_0 is Vector3):
		T.fail_and_quit(self, "Expected transformer to provide a Vector3 target (NPC B)")
		return
	var t2 := t2_0 as Vector3
	if not T.require_true(self, absf(t2.x - click2.x) < 0.5, "Invite target.x must be close to clicked_pos.x (NPC B)"):
		return
	if not T.require_true(self, absf(t2.z - click2.z) < 0.5, "Invite target.z must be close to clicked_pos.z (NPC B)"):
		return

	T.pass_and_quit(self)

