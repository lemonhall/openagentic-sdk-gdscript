extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	# Run against an isolated save slot so auto-loaded NPCs/history don't affect this test.
	var save_id: String = "slot_test_vr_offices_focus_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
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

	# Spawn one NPC and open the dialogue.
	var npc: Node = s.call("add_npc")
	if npc == null:
		T.fail_and_quit(self, "Failed to add npc")
		return

	var cam_rig: Node = s.get_node("CameraRig") as Node
	if cam_rig == null or not cam_rig.has_method("get_state"):
		T.fail_and_quit(self, "CameraRig missing get_state()")
		return

	var st0: Dictionary = cam_rig.call("get_state")
	var dist0 := float(st0.get("distance", 0.0))

	s.call("_enter_talk", npc)
	await process_frame

	# NPC should stop wandering while dialogue is open.
	var wander0: Variant = npc.get("wander_enabled") if npc.has_method("get") else null
	if not T.require_eq(self, bool(wander0), false, "Expected wander_enabled=false in dialogue"):
		return

	# NPC should face the camera while in dialogue.
	if cam_rig.has_method("get_camera"):
		var cam0: Variant = cam_rig.call("get_camera")
		if cam0 is Camera3D and npc is Node3D:
			var cam: Camera3D = cam0 as Camera3D
			var npc3d: Node3D = npc as Node3D
			# Kenney Mini Characters face +Z in this demo (we compensate with model_yaw_offset),
			# so use +basis.z as an approximation of the visible forward direction.
			var npc_forward := npc3d.global_transform.basis.z
			npc_forward.y = 0.0
			if npc_forward.length() > 0.001:
				npc_forward = npc_forward.normalized()
			var to_cam := cam.global_position - npc3d.global_position
			to_cam.y = 0.0
			if to_cam.length() > 0.001:
				to_cam = to_cam.normalized()
			var facing := npc_forward.dot(to_cam)
			if not T.require_true(self, facing > 0.3, "Expected NPC to face camera (dot > 0.3)"):
				return

	# Camera controls disabled and distance should zoom in (smaller).
	var controls0: Variant = cam_rig.get("controls_enabled") if cam_rig.has_method("get") else null
	if not T.require_eq(self, bool(controls0), false, "Expected camera controls disabled in dialogue"):
		return
	var st1: Dictionary = cam_rig.call("get_state")
	var dist1 := float(st1.get("distance", dist0))
	if not T.require_true(self, dist1 < dist0, "Expected camera distance to zoom in during dialogue"):
		return

	# Closing should restore.
	s.call("_exit_talk")
	await process_frame

	var wander1: Variant = npc.get("wander_enabled") if npc.has_method("get") else null
	if not T.require_eq(self, bool(wander1), true, "Expected wander_enabled=true after closing dialogue"):
		return
	var controls1: Variant = cam_rig.get("controls_enabled") if cam_rig.has_method("get") else null
	if not T.require_eq(self, bool(controls1), true, "Expected camera controls enabled after closing dialogue"):
		return

	T.pass_and_quit(self)
