extends SceneTree

const T := preload("res://tests/_test_util.gd")
const _OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")

func _init() -> void:
	var save_id: String = "slot_test_vr_offices_manager_desk_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
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

	var wsm0: Variant = world.get("_workspace_manager") if world.has_method("get") else null
	if not (wsm0 is RefCounted):
		T.fail_and_quit(self, "Missing _workspace_manager")
		return
	var wsm := wsm0 as RefCounted
	var ws_res: Dictionary = wsm.call("create_workspace", Rect2(Vector2(-2, -2), Vector2(3, 4)), "Team A")
	if not T.require_true(self, bool(ws_res.get("ok", false)), "Expected create_workspace ok"):
		return
	await process_frame

	var workspaces := world.get_node_or_null("Workspaces") as Node3D
	if workspaces == null or workspaces.get_child_count() < 1:
		T.fail_and_quit(self, "Expected workspace node")
		return
	var ws_node := workspaces.get_child(0) as Node
	if ws_node == null:
		T.fail_and_quit(self, "Missing workspace node")
		return
	var workspace_id := String(ws_node.get("workspace_id"))
	if not T.require_true(self, workspace_id.strip_edges() != "", "Expected workspace_id on workspace node"):
		return

	var manager_desk := ws_node.get_node_or_null("Decor/ManagerDesk") as Node3D
	if manager_desk == null:
		T.fail_and_quit(self, "Missing Decor/ManagerDesk")
		return
	var pick := manager_desk.get_node_or_null("PickBody") as StaticBody3D
	if not T.require_true(self, pick != null, "ManagerDesk should have PickBody"):
		return
	if not T.require_eq(self, int(pick.collision_layer), 32, "ManagerDesk PickBody collision_layer should be 32"):
		return

	var cam_rig: Node = world.get_node_or_null("CameraRig") as Node
	if cam_rig == null or not cam_rig.has_method("get_camera"):
		T.fail_and_quit(self, "CameraRig missing get_camera()")
		return
	var cam0: Variant = cam_rig.call("get_camera")
	if not (cam0 is Camera3D):
		T.fail_and_quit(self, "Expected Camera3D")
		return
	var cam := cam0 as Camera3D

	await process_frame
	var screen_pos := cam.unproject_position(manager_desk.global_position + Vector3(0.0, 1.0, 0.0))
	var PickerScript := load("res://vr_offices/core/input/VrOfficesClickPicker.gd")
	if PickerScript == null:
		T.fail_and_quit(self, "Missing VrOfficesClickPicker.gd")
		return
	var picked_mgr := PickerScript.call("try_pick_manager_desk", world, cam_rig, screen_pos) as Node
	if not T.require_true(self, picked_mgr != null, "Expected click picker to hit manager desk"):
		return
	var manager_pick := manager_desk.get_node_or_null("PickBody") as StaticBody3D
	if not T.require_true(self, manager_pick != null, "Missing ManagerDesk/PickBody"):
		return
	var ray_origin := cam.project_ray_origin(screen_pos)
	var ray_dir := cam.project_ray_normal(screen_pos)
	var near_hit := ray_origin + ray_dir * 0.1
	manager_pick.global_position = near_hit

	world.call("open_manager_dialogue_for_workspace", workspace_id)
	await process_frame

	var manager_overlay := world.get_node_or_null("UI/VrOfficesManagerDialogueOverlay") as Control
	if not T.require_true(self, manager_overlay != null, "Missing UI/VrOfficesManagerDialogueOverlay"):
		return
	if not T.require_true(self, manager_overlay.visible, "Expected manager dialogue overlay to open on manager desk double click"):
		return

	var npc_id := "workspace_manager__%s" % workspace_id
	var manager_events := String(_OAPaths.workspace_manager_events_path(save_id, workspace_id))
	if not T.require_eq(self, manager_events, "user://openagentic/saves/%s/workspaces/%s/manager/session/events.jsonl" % [save_id, workspace_id], "Expected manager fixed events path"):
		return
	if not T.require_true(self, String(_OAPaths.npc_events_path(save_id, npc_id)).find("/workspaces/%s/manager/" % workspace_id) != -1, "Manager npc path should resolve to workspace manager root"):
		return
	if not T.require_true(self, String(_OAPaths.npc_events_path(save_id, "npc_1")).find("/npcs/") != -1, "Regular npc path should still be in /npcs/"):
		return

	T.pass_and_quit(self)
