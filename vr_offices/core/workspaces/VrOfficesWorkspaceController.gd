extends RefCounted

const _SelectionCtrl := preload("res://vr_offices/core/workspaces/VrOfficesWorkspaceSelectionController.gd")
const _PlacementCtrl := preload("res://vr_offices/core/workspaces/VrOfficesWorkspaceDeskPlacementController.gd")
const _Raycast := preload("res://vr_offices/core/workspaces/VrOfficesWorkspaceRaycast.gd")

var owner: Node = null
var camera_rig: Node = null
var workspace_manager: RefCounted = null
var meeting_room_manager: RefCounted = null
var desk_manager: RefCounted = null
var overlay: Control = null
var action_hint: Control = null
var autosave: Callable = Callable()

var _selection: RefCounted = null
var _placement: RefCounted = null

func _init(
	owner_in: Node,
	camera_rig_in: Node,
	manager_in: RefCounted,
	desk_manager_in: RefCounted,
	overlay_in: Control,
	action_hint_in: Control,
	autosave_in: Callable,
	meeting_room_manager_in: RefCounted = null
) -> void:
	owner = owner_in
	camera_rig = camera_rig_in
	workspace_manager = manager_in
	meeting_room_manager = meeting_room_manager_in
	desk_manager = desk_manager_in
	overlay = overlay_in
	action_hint = action_hint_in
	autosave = autosave_in

	_selection = _SelectionCtrl.new(owner, camera_rig, workspace_manager, meeting_room_manager, overlay, action_hint)
	_placement = _PlacementCtrl.new(owner, camera_rig, workspace_manager, desk_manager, overlay, action_hint, autosave)

	if overlay != null:
		if overlay.has_signal("create_confirmed"):
			overlay.connect("create_confirmed", Callable(self, "_on_create_confirmed"))
		if overlay.has_signal("create_meeting_room_confirmed"):
			overlay.connect("create_meeting_room_confirmed", Callable(self, "_on_create_meeting_room_confirmed"))
		if overlay.has_signal("create_canceled"):
			overlay.connect("create_canceled", Callable(self, "_on_create_canceled"))
		if overlay.has_signal("delete_requested"):
			overlay.connect("delete_requested", Callable(self, "_on_delete_requested"))
		if overlay.has_signal("add_standing_desk_requested"):
			overlay.connect("add_standing_desk_requested", Callable(self, "_on_add_standing_desk_requested"))

func handle_lmb_event(event: InputEvent, select_npc: Callable) -> bool:
	if owner == null or camera_rig == null or workspace_manager == null:
		return false
	if _placement != null and bool(_placement.call("is_placing")):
		return bool(_placement.call("handle_lmb_event", event))
	return bool(_selection.call("handle_lmb_event", event, select_npc))

func handle_rmb_release(screen_pos: Vector2) -> bool:
	return _placement != null and bool(_placement.call("handle_rmb_release", screen_pos))

func handle_key_event(event: InputEventKey) -> bool:
	return _placement != null and bool(_placement.call("handle_key_event", event))

func try_open_context_menu(screen_pos: Vector2) -> bool:
	if owner == null or overlay == null or workspace_manager == null:
		return false
	if _placement != null and bool(_placement.call("is_placing")):
		return false

	var hit := _Raycast.raycast_workspace(owner, camera_rig, screen_pos, 4)
	if not bool(hit.get("ok", false)):
		return false
	var obj := hit.get("collider") as Object
	var wid := String(workspace_manager.call("workspace_id_from_collider", obj)).strip_edges()
	if wid == "":
		return false
	if overlay.has_method("show_workspace_menu"):
		overlay.call("show_workspace_menu", screen_pos, wid)
		return true
	return false

func debug_set_pending_rect(rect: Rect2) -> void:
	if _selection != null:
		_selection.call("debug_set_pending_rect", rect)

func _on_create_confirmed(name: String) -> void:
	if _selection != null:
		_selection.call("on_create_confirmed", name, autosave)

func _on_create_meeting_room_confirmed(name: String) -> void:
	if _selection != null:
		_selection.call("on_create_meeting_room_confirmed", name, autosave)

func _on_create_canceled() -> void:
	if _selection != null:
		_selection.call("on_create_canceled")

func _on_delete_requested(workspace_id: String) -> void:
	if workspace_manager == null:
		return
	var wid := workspace_id.strip_edges()
	if wid == "":
		return

	if _placement != null and String(_placement.call("get_placing_workspace_id")) == wid:
		_placement.call("end_placement", "Canceled")

	var res: Dictionary = workspace_manager.call("delete_workspace", wid)
	if bool(res.get("ok", false)):
		if desk_manager != null and desk_manager.has_method("delete_desks_for_workspace"):
			desk_manager.call("delete_desks_for_workspace", wid)
		if autosave.is_valid():
			autosave.call()

func _on_add_standing_desk_requested(workspace_id: String) -> void:
	if owner == null or workspace_manager == null or desk_manager == null or overlay == null:
		return
	var wid := workspace_id.strip_edges()
	if wid == "":
		return
	var rect: Rect2 = workspace_manager.call("get_workspace_rect_xz", wid)
	if rect.size == Vector2.ZERO:
		return

	var center_xz := rect.position + rect.size * 0.5
	var can: Dictionary = desk_manager.call("can_place_standing_desk", wid, rect, center_xz, 0.0)
	if not bool(can.get("ok", false)):
		if overlay.has_method("show_toast"):
			var reason := String(can.get("reason", ""))
			if reason == "too_many_desks":
				overlay.call("show_toast", "Workspace already has too many desks.")
			elif reason == "workspace_too_small":
				overlay.call("show_toast", "Workspace is too small for a standing desk.")
			else:
				overlay.call("show_toast", "Can't add desk here (%s)." % reason)
		return

	if _selection != null:
		_selection.call("cancel_interaction")
	_placement.call("begin_placement", wid, rect)
