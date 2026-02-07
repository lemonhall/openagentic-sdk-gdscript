extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var ManagerScript := load("res://vr_offices/core/meeting_rooms/VrOfficesMeetingRoomManager.gd")
	var AreaScene0 := load("res://vr_offices/meeting_rooms/MeetingRoomArea.tscn")
	if ManagerScript == null or AreaScene0 == null or not (AreaScene0 is PackedScene):
		T.fail_and_quit(self, "Missing meeting room manager / area scene")
		return

	var root := Node3D.new()
	root.name = "MeetingRooms"
	get_root().add_child(root)
	await process_frame

	var bounds := Rect2(Vector2(-10, -10), Vector2(20, 20))
	var mgr := (ManagerScript as Script).new(bounds) as RefCounted
	if mgr == null:
		T.fail_and_quit(self, "Failed to instantiate manager")
		return
	mgr.call("bind_scene", root, AreaScene0, Callable())

	var res: Dictionary = mgr.call("create_meeting_room", Rect2(Vector2(-2, -2), Vector2(3, 4)), "Room A")
	if not T.require_true(self, bool(res.get("ok", false)), "Expected create_meeting_room ok"):
		return
	await process_frame
	if not T.require_eq(self, root.get_child_count(), 1, "Expected one meeting room node spawned"):
		return

	var child := root.get_child(0) as Node
	if not T.require_true(self, child != null and child.is_in_group("vr_offices_meeting_room"), "Expected meeting room node group"):
		return
	if not T.require_eq(self, String(child.get("meeting_room_name")), "Room A", "Expected meeting room name on node"):
		return
	var walls := child.get_node_or_null("Walls") as Node3D
	if not T.require_true(self, walls != null, "Expected meeting room Walls node"):
		return

	var rid := String(child.get("meeting_room_id"))
	var del: Dictionary = mgr.call("delete_meeting_room", rid)
	if not T.require_true(self, bool(del.get("ok", false)), "Expected delete ok"):
		return
	await process_frame
	await process_frame
	if not T.require_eq(self, root.get_child_count(), 0, "Expected no meeting room nodes after delete"):
		return

	get_root().remove_child(root)
	root.free()
	await process_frame
	T.pass_and_quit(self)

