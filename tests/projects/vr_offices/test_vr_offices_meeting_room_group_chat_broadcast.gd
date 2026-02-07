extends SceneTree

const T := preload("res://tests/_test_util.gd")

class FakeOpenAgentic:
	extends Node

	var save_id: String = ""
	var system_prompt: String = ""
	var calls: Array[Dictionary] = []

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

	func run_npc_turn(npc_id: String, user_text: String, on_event: Callable) -> void:
		calls.append({"npc_id": npc_id, "user_text": user_text})
		on_event.call({"type": "assistant.delta", "text_delta": "ACK:"})
		on_event.call({"type": "assistant.delta", "text_delta": user_text})
		await get_tree().process_frame
		on_event.call({"type": "result"})

func _init() -> void:
	var oa := FakeOpenAgentic.new()
	oa.name = "OpenAgentic"
	oa.set_save_id("slot_test_vr_offices_meeting_broadcast_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())])
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
	var table := room.get_node_or_null("Decor/Table") as Node3D
	if table == null:
		T.fail_and_quit(self, "Missing Decor/Table")
		return

	var npc_scene := load("res://vr_offices/npc/Npc.tscn")
	if npc_scene == null or not (npc_scene is PackedScene):
		T.fail_and_quit(self, "Missing Npc.tscn")
		return
	var npc_root := s.get_node_or_null("NpcRoot") as Node3D
	if npc_root == null:
		T.fail_and_quit(self, "Missing NpcRoot")
		return

	var alice := (npc_scene as PackedScene).instantiate() as Node
	alice.name = "npc_01"
	if alice.has_method("set"):
		alice.set("npc_id", "npc_01")
		alice.set("display_name", "Alice")
	npc_root.add_child(alice)

	var bob := (npc_scene as PackedScene).instantiate() as Node
	bob.name = "npc_02"
	if bob.has_method("set"):
		bob.set("npc_id", "npc_02")
		bob.set("display_name", "Bob")
	npc_root.add_child(bob)
	await process_frame

	# Join both NPCs into the meeting by emitting "move_target_reached" near the table.
	var near := table.global_position + Vector3(1.0, 0.0, 0.0)
	alice.emit_signal("move_target_reached", "npc_01", Vector3(near.x, 0.0, near.z))
	bob.emit_signal("move_target_reached", "npc_02", Vector3(near.x, 0.0, near.z))
	await process_frame

	# Open overlay via mic.
	var mic := room.get_node_or_null("Decor/Table/Mic") as Node
	if mic == null:
		T.fail_and_quit(self, "Missing Decor/Table/Mic")
		return
	s.call("open_meeting_room_chat_for_mic", mic)
	await process_frame

	var overlay := s.get_node_or_null("UI/MeetingRoomChatOverlay") as Control
	if overlay == null or not overlay.visible:
		T.fail_and_quit(self, "Expected meeting room overlay visible")
		return

	# Broadcast without mention: at least one participant should be turned.
	overlay.emit_signal("message_submitted", "hello everyone")
	for _i in range(10):
		await process_frame
	if not T.require_true(self, oa.calls.size() >= 1, "Expected at least one NPC turn call from meeting broadcast"):
		return

	var calls_before := oa.calls.size()
	overlay.emit_signal("message_submitted", "question for @Alice")
	for _j in range(10):
		await process_frame

	var mentioned_ok := false
	for k in range(calls_before, oa.calls.size()):
		if String(oa.calls[k].get("npc_id", "")) == "npc_01":
			mentioned_ok = true
			break
	if not T.require_true(self, mentioned_ok, "Mention must force Alice (npc_01) to reply"):
		return

	T.pass_and_quit(self)

