extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	# Isolated save slot so existing state doesn't affect the test.
	var save_id: String = "slot_test_vr_offices_meeting_mic_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	var oa := get_root().get_node_or_null("OpenAgentic") as Node
	if oa == null:
		var OAScript := load("res://addons/openagentic/OpenAgentic.gd")
		if OAScript == null:
			T.fail_and_quit(self, "Missing res://addons/openagentic/OpenAgentic.gd")
			return
		oa = (OAScript as Script).new() as Node
		if oa == null:
			T.fail_and_quit(self, "Failed to instantiate OpenAgentic.gd")
			return
		oa.name = "OpenAgentic"
		get_root().add_child(oa)
		await process_frame
	oa.call("set_save_id", save_id)

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
	var res: Dictionary = mgr.call("create_meeting_room", Rect2(Vector2(-2, -2), Vector2(3, 4)), "Room A")
	if not T.require_true(self, bool(res.get("ok", false)), "Expected create_meeting_room ok"):
		return
	await process_frame
	await process_frame

	var cam_rig: Node = s.get_node_or_null("CameraRig") as Node
	if cam_rig == null or not cam_rig.has_method("get_camera"):
		T.fail_and_quit(self, "CameraRig missing get_camera()")
		return
	var cam0: Variant = cam_rig.call("get_camera")
	if not (cam0 is Camera3D):
		T.fail_and_quit(self, "Expected Camera3D")
		return
	var cam: Camera3D = cam0 as Camera3D

	var rooms := s.get_node_or_null("MeetingRooms") as Node3D
	if rooms == null:
		T.fail_and_quit(self, "Missing MeetingRooms root")
		return
	if not T.require_true(self, rooms.get_child_count() >= 1, "Expected meeting room node spawned"):
		return
	var room := rooms.get_child(0) as Node
	if room == null:
		T.fail_and_quit(self, "Missing meeting room node")
		return
	var mic := room.get_node_or_null("Decor/Table/Mic") as Node3D
	if mic == null:
		T.fail_and_quit(self, "Missing Decor/Table/Mic")
		return
	var pick := mic.get_node_or_null("PickBody") as StaticBody3D
	if pick == null:
		T.fail_and_quit(self, "Missing mic PickBody")
		return
	if not T.require_eq(self, int(pick.collision_layer), 64, "Expected mic PickBody collision_layer=64"):
		return

	# Give transforms a frame to settle.
	await process_frame

	var screen_pos := cam.unproject_position(mic.global_position + Vector3(0.0, 0.12, 0.0))
	var PickerScript := load("res://vr_offices/core/input/VrOfficesClickPicker.gd")
	if PickerScript == null:
		T.fail_and_quit(self, "Missing VrOfficesClickPicker.gd")
		return
	var picked0: Variant = PickerScript.call("try_pick_double_click_prop", s, cam_rig, screen_pos)
	if not T.require_true(self, typeof(picked0) == TYPE_DICTIONARY, "Expected dict pick result"):
		return
	var picked := picked0 as Dictionary
	if not T.require_eq(self, String(picked.get("type", "")), "meeting_mic", "Expected meeting_mic double-click pick"):
		return

	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.double_click = true
	ev.position = screen_pos
	s.call("_unhandled_input", ev)
	await process_frame

	var overlay := s.get_node_or_null("UI/MeetingRoomChatOverlay") as Control
	if overlay == null:
		T.fail_and_quit(self, "Missing UI/MeetingRoomChatOverlay")
		return
	if not T.require_true(self, overlay.visible, "Expected meeting room chat overlay to open on mic double click"):
		return
	var skills := overlay.get_node_or_null("%SkillsButton") as Control
	if not T.require_true(self, skills != null and not skills.visible, "Expected skills button hidden for meeting room chat"):
		return

	T.pass_and_quit(self)

