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

