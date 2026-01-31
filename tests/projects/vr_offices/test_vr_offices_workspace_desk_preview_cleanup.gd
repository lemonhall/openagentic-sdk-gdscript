extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	# Run against an isolated save slot so auto-loaded NPCs/history don't affect this test.
	var save_id: String = "slot_test_vr_offices_desk_preview_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
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
	await physics_frame

	var cam_rig: Node = world.get_node_or_null("CameraRig") as Node
	if cam_rig == null or not cam_rig.has_method("get_camera"):
		T.fail_and_quit(self, "CameraRig missing get_camera()")
		return
	var cam0: Variant = cam_rig.call("get_camera")
	if not (cam0 is Camera3D):
		T.fail_and_quit(self, "Expected Camera3D from CameraRig")
		return
	var cam := cam0 as Camera3D

	var wsm0: Variant = world.get("_workspace_manager") if world.has_method("get") else null
	var wsm := wsm0 as RefCounted
	if wsm == null:
		T.fail_and_quit(self, "Missing _workspace_manager on VrOffices")
		return

	var ws_rect := Rect2(Vector2(-1.5, -1.5), Vector2(3.0, 3.0))
	var created: Dictionary = wsm.call("create_workspace", ws_rect, "Test Workspace")
	if not T.require_true(self, bool(created.get("ok", false)), "Expected to create workspace for desk preview cleanup test"):
		return
	var ws0: Variant = created.get("workspace")
	if not (ws0 is Dictionary):
		T.fail_and_quit(self, "Expected workspace dict in create_workspace result")
		return
	var wid := String((ws0 as Dictionary).get("id", "")).strip_edges()
	if wid == "":
		T.fail_and_quit(self, "Expected non-empty workspace id")
		return

	var ws_overlay := world.get_node_or_null("UI/WorkspaceOverlay") as Control
	if ws_overlay == null:
		T.fail_and_quit(self, "Missing UI/WorkspaceOverlay")
		return
	if not ws_overlay.has_signal("add_standing_desk_requested"):
		T.fail_and_quit(self, "WorkspaceOverlay missing add_standing_desk_requested signal")
		return

	# Begin placement via the same signal the context menu uses.
	ws_overlay.emit_signal("add_standing_desk_requested", wid)
	await process_frame

	# Regression: placement creates a temporary "DeskPreview" node which must be cleaned up when placement ends.
	var preview0 := world.get_node_or_null("DeskPreview") as Node
	if not T.require_true(self, preview0 != null, "Expected DeskPreview node after begin placement"):
		return

	# Place the desk: click near the workspace center.
	var center_xz := ws_rect.position + ws_rect.size * 0.5
	var screen_pos := cam.unproject_position(Vector3(center_xz.x, 0.0, center_xz.y))

	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = screen_pos
	world.call("_unhandled_input", down)

	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = screen_pos
	world.call("_unhandled_input", up)

	# queue_free is deferred; allow a few frames for cleanup.
	for _i in range(10):
		await process_frame
		if world.get_node_or_null("DeskPreview") == null:
			break
	if not T.require_true(self, world.get_node_or_null("DeskPreview") == null, "Expected DeskPreview node to be freed after placement ends"):
		return

	var dm0: Variant = world.get("_desk_manager") if world.has_method("get") else null
	var dm := dm0 as RefCounted
	if dm == null:
		T.fail_and_quit(self, "Missing _desk_manager on VrOffices")
		return
	var desks0: Variant = dm.call("list_desks")
	if not (desks0 is Array):
		T.fail_and_quit(self, "Expected desk manager list_desks() returns Array")
		return
	var desks := desks0 as Array
	var found := false
	for d0 in desks:
		if not (d0 is Dictionary):
			continue
		if String((d0 as Dictionary).get("workspace_id", "")).strip_edges() == wid:
			found = true
			break
	if not T.require_true(self, found, "Expected a standing desk to be created for the workspace"):
		return

	T.pass_and_quit(self)

