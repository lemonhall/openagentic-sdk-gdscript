extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
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

	var dialogue: Control = s.get_node("UI/DialogueOverlay") as Control
	if dialogue == null:
		T.fail_and_quit(self, "Missing DialogueOverlay")
		return
	if not T.require_true(self, dialogue.visible, "Expected dialogue to open on double click"):
		return

	T.pass_and_quit(self)

