extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	# Isolated save slot so existing state doesn't affect the test.
	var save_id: String = "slot_test_vr_offices_vend_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
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

	var mgr0: Variant = s.get("_workspace_manager")
	if not (mgr0 is RefCounted):
		T.fail_and_quit(self, "Missing _workspace_manager")
		return
	var mgr := mgr0 as RefCounted
	var res: Dictionary = mgr.call("create_workspace", Rect2(Vector2(-2, -2), Vector2(3, 4)), "Team A")
	if not T.require_true(self, bool(res.get("ok", false)), "Expected create_workspace ok"):
		return
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

	var workspaces := s.get_node_or_null("Workspaces") as Node3D
	if workspaces == null:
		T.fail_and_quit(self, "Missing Workspaces root")
		return
	if not T.require_true(self, workspaces.get_child_count() >= 1, "Expected workspace node spawned"):
		return
	var ws := workspaces.get_child(0) as Node
	if ws == null:
		T.fail_and_quit(self, "Missing workspace node")
		return
	var vending := ws.get_node_or_null("Decor/VendingMachine") as Node3D
	if vending == null:
		T.fail_and_quit(self, "Missing Decor/VendingMachine")
		return
	var pick := vending.get_node_or_null("PickBody") as StaticBody3D
	if pick == null:
		T.fail_and_quit(self, "Missing Decor/VendingMachine/PickBody")
		return
	if not T.require_eq(self, int(pick.collision_layer), 16, "Expected PickBody collision_layer=16"):
		return

	# Give transforms a frame to settle.
	await process_frame

	var screen_pos := cam.unproject_position(vending.global_position + Vector3(0.0, 1.0, 0.0))
	var PickerScript := load("res://vr_offices/core/input/VrOfficesClickPicker.gd")
	if PickerScript == null:
		T.fail_and_quit(self, "Missing VrOfficesClickPicker.gd")
		return
	var picked := PickerScript.call("try_pick_vending_machine", s, cam_rig, screen_pos) as Node
	if not T.require_true(self, picked != null, "Expected click picker to hit vending machine"):
		return
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.double_click = true
	ev.position = screen_pos
	s.call("_unhandled_input", ev)
	await process_frame

	var overlay := s.get_node_or_null("UI/VendingMachineOverlay") as Control
	if overlay == null:
		T.fail_and_quit(self, "Missing UI/VendingMachineOverlay")
		return
	if not T.require_true(self, overlay.visible, "Expected vending overlay to open on double click"):
		return

	T.pass_and_quit(self)
