extends RefCounted

const _Raycast := preload("res://vr_offices/core/workspaces/VrOfficesWorkspaceRaycast.gd")

var owner: Node = null
var camera_rig: Node = null
var meeting_room_manager: RefCounted = null
var overlay: Control = null
var autosave: Callable = Callable()

func _init(
	owner_in: Node,
	camera_rig_in: Node,
	meeting_room_manager_in: RefCounted,
	overlay_in: Control,
	autosave_in: Callable
) -> void:
	owner = owner_in
	camera_rig = camera_rig_in
	meeting_room_manager = meeting_room_manager_in
	overlay = overlay_in
	autosave = autosave_in

	if overlay != null and overlay.has_signal("meeting_room_delete_requested"):
		overlay.connect("meeting_room_delete_requested", Callable(self, "_on_delete_requested"))

func try_open_context_menu(screen_pos: Vector2) -> bool:
	if owner == null or overlay == null or meeting_room_manager == null:
		return false
	var hit := _Raycast.raycast_workspace(owner, camera_rig, screen_pos, 4)
	if not bool(hit.get("ok", false)):
		return false
	var obj := hit.get("collider") as Object
	var rid := String(meeting_room_manager.call("meeting_room_id_from_collider", obj)).strip_edges()
	if rid == "":
		return false
	if overlay.has_method("show_meeting_room_menu"):
		overlay.call("show_meeting_room_menu", screen_pos, rid)
		return true
	return false

func _on_delete_requested(meeting_room_id: String) -> void:
	if meeting_room_manager == null:
		return
	var rid := meeting_room_id.strip_edges()
	if rid == "":
		return
	var res: Dictionary = meeting_room_manager.call("delete_meeting_room", rid)
	if bool(res.get("ok", false)) and autosave.is_valid():
		autosave.call()

