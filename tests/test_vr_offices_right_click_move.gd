extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	# Run against an isolated save slot so auto-loaded NPCs/history don't affect this test.
	var save_id: String = "slot_test_vr_offices_rmb_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
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

	var world := (VrScene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var npc: Node = world.call("add_npc")
	if npc == null:
		T.fail_and_quit(self, "Failed to add npc")
		return

	# Speed up the "waiting for work" timer to keep this test fast.
	if npc.has_method("set") and npc.has_method("get"):
		npc.set("waiting_for_work_seconds", 0.2)

	var cam_rig: Node = world.get_node_or_null("CameraRig") as Node
	if cam_rig == null or not cam_rig.has_method("get_camera"):
		T.fail_and_quit(self, "CameraRig missing get_camera()")
		return
	var cam0: Variant = cam_rig.call("get_camera")
	if not (cam0 is Camera3D) or not (npc is Node3D):
		T.fail_and_quit(self, "Expected Camera3D and Node3D npc")
		return
	var cam := cam0 as Camera3D
	var npc3d := npc as Node3D

	# Wait until the NPC has landed; move commands only execute while on the floor.
	var npc_body := npc as CharacterBody3D
	if npc_body != null:
		for _i in range(180):
			await physics_frame
			if npc_body.is_on_floor():
				break

	# Right-click the floor under the NPC (should trigger command_move_to, reach immediately,
	# then resume wandering after the countdown).
	var floor_point := Vector3(npc3d.global_position.x, 0.0, npc3d.global_position.z)
	var screen_pos := cam.unproject_position(floor_point)

	var indicators := world.get_node_or_null("MoveIndicators") as Node
	if not T.require_true(self, indicators != null, "Missing MoveIndicators root"):
		return
	if not T.require_eq(self, indicators.get_child_count(), 0, "Expected no move indicators initially"):
		return

	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_RIGHT
	down.pressed = true
	down.position = screen_pos
	world.call("_unhandled_input", down)

	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_RIGHT
	up.pressed = false
	up.position = screen_pos
	world.call("_unhandled_input", up)

	if not T.require_eq(self, indicators.get_child_count(), 1, "Expected 1 move indicator after right-click"):
		return

	await physics_frame

	var wander0: Variant = npc.get("wander_enabled") if npc.has_method("get") else null
	if not T.require_eq(self, bool(wander0), false, "Expected wander_enabled=false after right-click move command"):
		return

	# Should disappear once the NPC reaches the target.
	for _i in range(30):
		await physics_frame
		if indicators.get_child_count() == 0:
			break
	if not T.require_eq(self, indicators.get_child_count(), 0, "Expected move indicator to clear after arrival"):
		return

	# Wait long enough for the shortened countdown to complete.
	for _i in range(30):
		await physics_frame

	var wander1: Variant = npc.get("wander_enabled") if npc.has_method("get") else null
	if not T.require_eq(self, bool(wander1), true, "Expected wander_enabled=true after waiting-for-work countdown"):
		return

	T.pass_and_quit(self)
