extends RefCounted

const _StandingDeskScene := preload("res://vr_offices/furniture/StandingDesk.tscn")
const _DeskPreview := preload("res://vr_offices/core/workspaces/VrOfficesWorkspaceDeskPreview.gd")
const _Raycast := preload("res://vr_offices/core/workspaces/VrOfficesWorkspaceRaycast.gd")

var owner: Node = null
var camera_rig: Node = null
var workspace_manager: RefCounted = null
var desk_manager: RefCounted = null
var overlay: Control = null
var action_hint: Control = null
var autosave: Callable = Callable()

var _placing_workspace_id: String = ""
var _placing_workspace_rect := Rect2()
var _placing_yaw := 0.0
var _last_screen := Vector2.ZERO

var _preview: RefCounted = null

func _init(
	owner_in: Node,
	camera_rig_in: Node,
	workspace_manager_in: RefCounted,
	desk_manager_in: RefCounted,
	overlay_in: Control,
	action_hint_in: Control,
	autosave_in: Callable
) -> void:
	owner = owner_in
	camera_rig = camera_rig_in
	workspace_manager = workspace_manager_in
	desk_manager = desk_manager_in
	overlay = overlay_in
	action_hint = action_hint_in
	autosave = autosave_in
	_preview = _DeskPreview.new()

func is_placing() -> bool:
	return _placing_workspace_id != ""

func get_placing_workspace_id() -> String:
	return _placing_workspace_id

func begin_placement(workspace_id: String, rect_xz: Rect2) -> void:
	_placing_workspace_id = workspace_id
	_placing_workspace_rect = rect_xz
	_placing_yaw = 0.0
	_preview.call("ensure", owner, _StandingDeskScene)
	if owner != null:
		_last_screen = owner.get_viewport().get_mouse_position()
	var center_xz := rect_xz.position + rect_xz.size * 0.5
	_set_desk_preview_center_xz(center_xz)
	if action_hint != null and action_hint.has_method("show_hint"):
		action_hint.call("show_hint", "Place Standing Desk: LMB confirm · R/RMB rotate · Esc cancel")

func end_placement(toast_msg: String = "") -> void:
	_placing_workspace_id = ""
	_placing_workspace_rect = Rect2()
	_placing_yaw = 0.0
	_preview.call("dispose")
	if action_hint != null and action_hint.has_method("hide_hint"):
		action_hint.call("hide_hint")
	if toast_msg.strip_edges() != "" and overlay != null and overlay.has_method("show_toast"):
		overlay.call("show_toast", toast_msg)

func handle_lmb_event(event: InputEvent) -> bool:
	if owner == null or desk_manager == null or _placing_workspace_id == "":
		return false

	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_last_screen = mm.position
		_update_desk_preview(mm.position)
		return true

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return false
		if mb.pressed:
			_last_screen = mb.position
			_try_place_desk(mb.position)
			return true

	return false

func handle_rmb_release(screen_pos: Vector2) -> bool:
	if _placing_workspace_id == "":
		return false
	_rotate_desk_preview(screen_pos)
	return true

func handle_key_event(event: InputEventKey) -> bool:
	if _placing_workspace_id == "" or event == null:
		return false
	if not event.pressed or event.echo:
		return false

	if event.physical_keycode == KEY_ESCAPE:
		end_placement("Canceled")
		return true
	if event.physical_keycode == KEY_R:
		_rotate_desk_preview(_last_screen)
		return true
	return false

func _ensure_desk_preview() -> void:
	if _preview != null:
		_preview.call("ensure", owner, _StandingDeskScene)

func _free_desk_preview() -> void:
	if _preview != null:
		_preview.call("dispose")

func _rotate_desk_preview(screen_pos: Vector2) -> void:
	_placing_yaw = _next_snap_yaw(_placing_yaw)
	_update_desk_preview(screen_pos)

static func _next_snap_yaw(current_yaw: float, step_rad: float = PI * 0.5) -> float:
	var step := maxf(0.001, absf(step_rad))
	var snaps := roundi(current_yaw / step) + 1
	var yaw := float(snaps) * step
	return wrapf(yaw, 0.0, TAU)

func _update_desk_preview(screen_pos: Vector2) -> void:
	if owner == null or desk_manager == null or _placing_workspace_id == "":
		return
	_preview.call("ensure", owner, _StandingDeskScene)

	var hit := _Raycast.raycast_floor_point(owner, camera_rig, screen_pos, 1)
	if not bool(hit.get("ok", false)):
		return
	var p := hit.get("pos") as Vector3

	var yaw := _placing_yaw
	var size_xz: Vector2 = desk_manager.call("get_standing_desk_footprint_size_xz", yaw)
	var half := size_xz * 0.5

	var rect := _placing_workspace_rect
	var cx := clampf(float(p.x), float(rect.position.x + half.x), float(rect.position.x + rect.size.x - half.x))
	var cz := clampf(float(p.z), float(rect.position.y + half.y), float(rect.position.y + rect.size.y - half.y))
	var center_xz := Vector2(cx, cz)

	var can: Dictionary = desk_manager.call("can_place_standing_desk", _placing_workspace_id, rect, center_xz, yaw)
	var ok := bool(can.get("ok", false))

	_preview.call("set_state", center_xz, yaw, ok)

func _set_desk_preview_center_xz(center_xz: Vector2) -> void:
	if owner == null or desk_manager == null or _placing_workspace_id == "":
		return
	_preview.call("ensure", owner, _StandingDeskScene)

	var yaw := _placing_yaw
	var rect := _placing_workspace_rect

	var can: Dictionary = desk_manager.call("can_place_standing_desk", _placing_workspace_id, rect, center_xz, yaw)
	var ok := bool(can.get("ok", false))

	_preview.call("set_state", center_xz, yaw, ok)

func _try_place_desk(screen_pos: Vector2) -> void:
	if owner == null or desk_manager == null or _placing_workspace_id == "":
		return
	var hit := _Raycast.raycast_floor_point(owner, camera_rig, screen_pos, 1)
	if not bool(hit.get("ok", false)):
		return
	var p := hit.get("pos") as Vector3
	var rect := _placing_workspace_rect

	var size_xz: Vector2 = desk_manager.call("get_standing_desk_footprint_size_xz", _placing_yaw)
	if rect.size.x + 1e-4 < size_xz.x or rect.size.y + 1e-4 < size_xz.y:
		if overlay != null and overlay.has_method("show_toast"):
			overlay.call("show_toast", "Workspace is too small for a standing desk.")
		return
	var half := size_xz * 0.5
	var cx := clampf(float(p.x), float(rect.position.x + half.x), float(rect.position.x + rect.size.x - half.x))
	var cz := clampf(float(p.z), float(rect.position.y + half.y), float(rect.position.y + rect.size.y - half.y))
	var pos := Vector3(cx, 0.0, cz)

	var res: Dictionary = desk_manager.call("add_standing_desk", _placing_workspace_id, rect, pos, _placing_yaw)
	if bool(res.get("ok", false)):
		if autosave.is_valid():
			autosave.call()
		end_placement("Standing Desk placed.")
	else:
		if overlay != null and overlay.has_method("show_toast"):
			var reason := String(res.get("reason", ""))
			if reason == "overlap":
				overlay.call("show_toast", "Can't place: overlaps an existing desk.")
			elif reason == "out_of_bounds":
				overlay.call("show_toast", "Can't place: outside workspace.")
			elif reason == "too_many_desks":
				overlay.call("show_toast", "Can't place: too many desks in this workspace.")
			else:
				overlay.call("show_toast", "Can't place desk (%s)." % reason)
