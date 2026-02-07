extends RefCounted

const _WorkspaceAreaScene := preload("res://vr_offices/workspaces/WorkspaceArea.tscn")
const _Raycast := preload("res://vr_offices/core/workspaces/VrOfficesWorkspaceRaycast.gd")
const _RoomMenuHint := preload("res://vr_offices/core/rooms/VrOfficesRoomMenuHint.gd")

var owner: Node = null
var camera_rig: Node = null
var workspace_manager: RefCounted = null
var meeting_room_manager: RefCounted = null
var overlay: Control = null
var action_hint: Control = null

var _armed := false
var _dragging := false
var _start_screen := Vector2.ZERO
var _last_screen := Vector2.ZERO
var _start_world := Vector3.ZERO
var _last_world := Vector3.ZERO

var _pending_rect: Rect2 = Rect2()
var _preview_node: Node = null
var _room_menu_hint: RefCounted = null

func _init(owner_in: Node, camera_rig_in: Node, manager_in: RefCounted, meeting_room_manager_in: RefCounted, overlay_in: Control, action_hint_in: Control) -> void:
	owner = owner_in
	camera_rig = camera_rig_in
	workspace_manager = manager_in
	meeting_room_manager = meeting_room_manager_in
	overlay = overlay_in
	action_hint = action_hint_in
	if action_hint != null:
		_room_menu_hint = _RoomMenuHint.new(owner, action_hint)

func handle_lmb_event(event: InputEvent, select_npc: Callable) -> bool:
	if owner == null or camera_rig == null or workspace_manager == null:
		return false

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return false
		if mb.pressed:
			# If we clicked an NPC, don't start workspace selection.
			if _Raycast.ray_hits_mask(owner, camera_rig, mb.position, 2):
				return false
			# If we clicked a desk, don't start workspace selection (desk double-click is used for IRC verification).
			if _Raycast.ray_hits_mask(owner, camera_rig, mb.position, 8):
				return false
			var hit := _Raycast.raycast_floor_point(owner, camera_rig, mb.position, 1)
			if not bool(hit.get("ok", false)):
				return false
			if select_npc.is_valid():
				select_npc.call(null)
			_armed = true
			_dragging = false
			_start_screen = mb.position
			_last_screen = mb.position
			_start_world = hit.get("pos") as Vector3
			_last_world = _start_world
			_hide_preview()
			return true
		else:
			if not _armed:
				return false
			_last_screen = mb.position
			var hit2 := _Raycast.raycast_floor_point(owner, camera_rig, mb.position, 1)
			if bool(hit2.get("ok", false)):
				_last_world = hit2.get("pos") as Vector3

			if _dragging:
				var rect := _Raycast.rect_from_world_points(_start_world, _last_world)
				rect = workspace_manager.call("clamp_rect_to_floor", rect)
				if not _can_place_any(rect):
					_hide_preview()
					_reset_drag()
					return true
				_pending_rect = rect
				_show_preview(rect, true)
				if overlay != null and overlay.has_method("prompt_create"):
					var next_idx := int(workspace_manager.call("get_workspace_counter")) + 1
					var next_mr_idx := 1
					if meeting_room_manager != null and meeting_room_manager.has_method("get_meeting_room_counter"):
						next_mr_idx = int(meeting_room_manager.call("get_meeting_room_counter")) + 1
					if overlay.has_method("prompt_create_room"):
						overlay.call("prompt_create_room", "Workspace %d" % next_idx, "Meeting Room %d" % next_mr_idx)
					else:
						overlay.call("prompt_create", "Workspace %d" % next_idx)
				# Keep preview visible until confirm/cancel.
			else:
				_hide_preview()
			_reset_drag()
			return true

	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if not _armed:
			return false
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT == 0:
			return false
		_last_screen = mm.position
		var hit3 := _Raycast.raycast_floor_point(owner, camera_rig, mm.position, 1)
		if bool(hit3.get("ok", false)):
			_last_world = hit3.get("pos") as Vector3

		if not _dragging and (_last_screen - _start_screen).length() > 6.0:
			_dragging = true

		if _dragging:
			var rect2 := _Raycast.rect_from_world_points(_start_world, _last_world)
			rect2 = workspace_manager.call("clamp_rect_to_floor", rect2)
			var ok := _can_place_any(rect2)
			_show_preview(rect2, ok)
			return true

	return false

func debug_set_pending_rect(rect: Rect2) -> void:
	_pending_rect = rect

func on_create_confirmed(name: String, autosave: Callable) -> void:
	if _pending_rect.size == Vector2.ZERO:
		return
	var res: Dictionary = workspace_manager.call("create_workspace", _pending_rect, name)
	_pending_rect = Rect2()
	if bool(res.get("ok", false)):
		if autosave.is_valid():
			autosave.call()
		_show_room_menu_hint()
	_hide_preview()

func on_create_meeting_room_confirmed(name: String, autosave: Callable) -> void:
	if meeting_room_manager == null:
		return
	if _pending_rect.size == Vector2.ZERO:
		return
	var res: Dictionary = meeting_room_manager.call("create_meeting_room", _pending_rect, name)
	_pending_rect = Rect2()
	if bool(res.get("ok", false)):
		if autosave.is_valid():
			autosave.call()
		_show_room_menu_hint()
	_hide_preview()

func on_create_canceled() -> void:
	_pending_rect = Rect2()
	_hide_preview()

func cancel_interaction() -> void:
	_pending_rect = Rect2()
	_hide_preview()
	_reset_drag()

func _reset_drag() -> void:
	_armed = false
	_dragging = false
	_start_screen = Vector2.ZERO
	_last_screen = Vector2.ZERO
	_start_world = Vector3.ZERO
	_last_world = Vector3.ZERO

func _show_preview(rect_xz: Rect2, ok: bool) -> void:
	if owner == null:
		return
	if _preview_node == null or not is_instance_valid(_preview_node):
		_preview_node = _WorkspaceAreaScene.instantiate()
		var n := _preview_node as Node
		if n == null:
			_preview_node = null
			return
		owner.add_child(n)
	var color := Color(0.25, 0.75, 1.0, 0.18)
	if not ok:
		color = Color(1.0, 0.25, 0.35, 0.18)
	if _preview_node.has_method("configure"):
		_preview_node.call("configure", rect_xz, color, true)

func _hide_preview() -> void:
	if _preview_node != null and is_instance_valid(_preview_node):
		_preview_node.queue_free()
	_preview_node = null

func _show_room_menu_hint() -> void:
	if _room_menu_hint == null:
		return
	_room_menu_hint.call("show_once", "提示：Shift + 右键 房间 打开菜单（工作区/会议室）\nTip: Shift + RMB on a room opens the menu (Workspace / Meeting room).", 10.0)

func _can_place_any(rect_xz: Rect2) -> bool:
	if workspace_manager == null:
		return false
	if not bool(workspace_manager.call("can_place", rect_xz)):
		return false
	if meeting_room_manager == null:
		return true
	if meeting_room_manager.has_method("can_place"):
		return bool(meeting_room_manager.call("can_place", rect_xz))
	return true
