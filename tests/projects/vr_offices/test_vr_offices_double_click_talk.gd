extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	# Run against an isolated save slot so auto-loaded NPCs/history don't affect this test.
	var save_id: String = "slot_test_vr_offices_dbl_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
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
	if VrScene == null:
		T.fail_and_quit(self, "Missing VrOffices scene")
		return

	var s := (VrScene as PackedScene).instantiate()
	root.add_child(s)
	await process_frame

	var npc: Node = s.call("add_npc")
	if npc == null:
		T.fail_and_quit(self, "Failed to add npc")
		return

	var cam_rig: Node = s.get_node("CameraRig") as Node
	if cam_rig == null or not cam_rig.has_method("get_camera"):
		T.fail_and_quit(self, "CameraRig missing get_camera()")
		return
	var cam0: Variant = cam_rig.call("get_camera")
	if not (cam0 is Camera3D) or not (npc is Node3D):
		T.fail_and_quit(self, "Expected Camera3D and Node3D npc")
		return
	var cam: Camera3D = cam0 as Camera3D
	var npc3d: Node3D = npc as Node3D

	# Give transforms a frame to settle.
	await process_frame

	var screen_pos := cam.unproject_position(npc3d.global_position + Vector3(0.0, 1.2, 0.0))
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.double_click = true
	ev.position = screen_pos
	s.call("_unhandled_input", ev)
	await process_frame

	var shell := s.get_node_or_null("UI/VrOfficesManagerDialogueOverlay") as Control
	if shell == null:
		T.fail_and_quit(self, "Missing VrOfficesManagerDialogueOverlay")
		return
	if not T.require_true(self, shell.visible, "Expected manager-style dialogue shell to open on double click"):
		return
	var embedded: Control = null
	if shell.has_method("get_embedded_dialogue"):
		embedded = shell.call("get_embedded_dialogue") as Control
	if not T.require_true(self, embedded != null and embedded.visible, "Expected embedded dialogue to be visible"):
		return

	T.pass_and_quit(self)
