extends RefCounted

const _WorkspaceAreaScene := preload("res://vr_offices/workspaces/WorkspaceArea.tscn")
const _StandingDeskScene := preload("res://vr_offices/furniture/StandingDesk.tscn")

var owner: Node = null
var camera_rig: Node = null
var workspace_manager: RefCounted = null
var desk_manager: RefCounted = null
var overlay: Control = null
var action_hint: Control = null
var autosave: Callable = Callable()

var _armed := false
var _dragging := false
var _start_screen := Vector2.ZERO
var _last_screen := Vector2.ZERO
var _start_world := Vector3.ZERO
var _last_world := Vector3.ZERO
var _pending_rect: Rect2 = Rect2()

var _preview_node: Node = null

var _placing_workspace_id: String = ""
var _placing_workspace_rect := Rect2()
var _placing_yaw := 0.0
var _desk_preview_root: Node3D = null
var _desk_preview_model: Node3D = null
var _action_hint_generation := 0
var _workspace_create_hint_shown := false

func _init(
	owner_in: Node,
	camera_rig_in: Node,
	manager_in: RefCounted,
	desk_manager_in: RefCounted,
	overlay_in: Control,
	action_hint_in: Control,
	autosave_in: Callable
) -> void:
	owner = owner_in
	camera_rig = camera_rig_in
	workspace_manager = manager_in
	desk_manager = desk_manager_in
	overlay = overlay_in
	action_hint = action_hint_in
	autosave = autosave_in

	if overlay != null:
		if overlay.has_signal("create_confirmed"):
			overlay.connect("create_confirmed", Callable(self, "_on_create_confirmed"))
		if overlay.has_signal("create_canceled"):
			overlay.connect("create_canceled", Callable(self, "_on_create_canceled"))
		if overlay.has_signal("delete_requested"):
			overlay.connect("delete_requested", Callable(self, "_on_delete_requested"))
		if overlay.has_signal("add_standing_desk_requested"):
			overlay.connect("add_standing_desk_requested", Callable(self, "_on_add_standing_desk_requested"))

func handle_lmb_event(event: InputEvent, select_npc: Callable) -> bool:
	if owner == null or camera_rig == null or workspace_manager == null:
		return false

	if _placing_workspace_id != "":
		return _handle_desk_placement_event(event)

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return false
		if mb.pressed:
			# If we clicked an NPC, don't start workspace selection.
			if _ray_hits_mask(mb.position, 2):
				return false
			var hit := _raycast_floor_point(mb.position)
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
			var hit2 := _raycast_floor_point(mb.position)
			if bool(hit2.get("ok", false)):
				_last_world = hit2.get("pos") as Vector3

			if _dragging:
				var rect := _rect_from_world_points(_start_world, _last_world)
				rect = workspace_manager.call("clamp_rect_to_floor", rect)
				if not bool(workspace_manager.call("can_place", rect)):
					_hide_preview()
					_reset_drag()
					return true
				_pending_rect = rect
				_show_preview(rect, true)
				if overlay != null and overlay.has_method("prompt_create"):
					var next_idx := int(workspace_manager.call("get_workspace_counter")) + 1
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
		var hit3 := _raycast_floor_point(mm.position)
		if bool(hit3.get("ok", false)):
			_last_world = hit3.get("pos") as Vector3

		if not _dragging and (_last_screen - _start_screen).length() > 6.0:
			_dragging = true

		if _dragging:
			var rect2 := _rect_from_world_points(_start_world, _last_world)
			rect2 = workspace_manager.call("clamp_rect_to_floor", rect2)
			var ok := bool(workspace_manager.call("can_place", rect2))
			_show_preview(rect2, ok)
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
		_end_desk_placement("Canceled")
		return true
	if event.physical_keycode == KEY_R:
		_rotate_desk_preview(_last_screen)
		return true
	return false

func try_open_context_menu(screen_pos: Vector2) -> bool:
	if owner == null or overlay == null or workspace_manager == null:
		return false
	if _placing_workspace_id != "":
		return false
	var hit := _raycast_workspace(screen_pos)
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

func _on_create_confirmed(name: String) -> void:
	if _pending_rect.size == Vector2.ZERO:
		return
	var res: Dictionary = workspace_manager.call("create_workspace", _pending_rect, name)
	_pending_rect = Rect2()
	if bool(res.get("ok", false)):
		if autosave.is_valid():
			autosave.call()
		_show_post_create_hint()
	_hide_preview()

func _on_create_canceled() -> void:
	_pending_rect = Rect2()
	_hide_preview()

func _on_delete_requested(workspace_id: String) -> void:
	if workspace_manager == null:
		return
	if _placing_workspace_id == workspace_id.strip_edges():
		_end_desk_placement("Canceled")
	var res: Dictionary = workspace_manager.call("delete_workspace", workspace_id)
	if bool(res.get("ok", false)):
		if desk_manager != null and desk_manager.has_method("delete_desks_for_workspace"):
			desk_manager.call("delete_desks_for_workspace", workspace_id)
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

	# Quick pre-check: if the workspace can't ever fit a desk or is already at limit, don't enter placement mode.
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

	_begin_desk_placement(wid, rect)

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

func _handle_desk_placement_event(event: InputEvent) -> bool:
	if owner == null or desk_manager == null:
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

func _begin_desk_placement(workspace_id: String, rect_xz: Rect2) -> void:
	_placing_workspace_id = workspace_id
	_placing_workspace_rect = rect_xz
	_placing_yaw = 0.0
	_hide_preview()
	_reset_drag()
	_ensure_desk_preview()
	_last_screen = owner.get_viewport().get_mouse_position()
	var center_xz := rect_xz.position + rect_xz.size * 0.5
	_set_desk_preview_center_xz(center_xz)
	if action_hint != null and action_hint.has_method("show_hint"):
		_action_hint_generation += 1
		action_hint.call("show_hint", "Place Standing Desk: LMB confirm · R/RMB rotate · Esc cancel")

func _show_post_create_hint() -> void:
	# Help users discover the workspace context menu (needed to add desks / delete workspaces).
	# Show once per session to avoid spamming during rapid workspace creation.
	if owner == null or action_hint == null:
		return
	if not owner.is_inside_tree():
		return
	if _workspace_create_hint_shown:
		return
	if not action_hint.has_method("show_hint") or not action_hint.has_method("hide_hint"):
		return

	_workspace_create_hint_shown = true
	_action_hint_generation += 1
	var gen := _action_hint_generation
	action_hint.call("show_hint", "提示：Shift + 右键 工作区 打开菜单（添加桌子/删除）\nTip: Shift + RMB on a workspace opens the menu (Add desk / Delete).")

	var tree := owner.get_tree()
	if tree == null:
		return
	tree.create_timer(10.0).timeout.connect(func() -> void:
		# Only hide if this hint is still the latest hint shown by the controller.
		if _action_hint_generation != gen:
			return
		if _placing_workspace_id != "":
			return
		if action_hint != null and action_hint.has_method("hide_hint"):
			action_hint.call("hide_hint")
	)

func _end_desk_placement(toast_msg: String = "") -> void:
	_placing_workspace_id = ""
	_placing_workspace_rect = Rect2()
	_placing_yaw = 0.0
	_free_desk_preview()
	if action_hint != null and action_hint.has_method("hide_hint"):
		action_hint.call("hide_hint")
	if toast_msg.strip_edges() != "" and overlay != null and overlay.has_method("show_toast"):
		overlay.call("show_toast", toast_msg)

func _ensure_desk_preview() -> void:
	if owner == null:
		return
	if _desk_preview_root != null and is_instance_valid(_desk_preview_root):
		return
	_desk_preview_root = Node3D.new()
	_desk_preview_root.name = "DeskPreview"
	_desk_preview_root.position = Vector3(0, 0.0, 0)
	owner.add_child(_desk_preview_root)

	var ghost0 := _StandingDeskScene.instantiate()
	var ghost := ghost0 as Node3D
	if ghost != null:
		ghost.name = "GhostStandingDesk"
		ghost.process_mode = Node.PROCESS_MODE_DISABLED
		_desk_preview_root.add_child(ghost)
		if ghost.has_method("ensure_centered"):
			ghost.call("ensure_centered")
		if ghost.has_method("set_preview"):
			ghost.call("set_preview", true)
		_desk_preview_model = ghost

func _rotate_desk_preview(screen_pos: Vector2) -> void:
	if _placing_workspace_id == "":
		return
	_placing_yaw = _next_snap_yaw(_placing_yaw)
	_update_desk_preview(screen_pos)

static func _next_snap_yaw(current_yaw: float, step_rad: float = PI * 0.5) -> float:
	var step := maxf(0.001, absf(step_rad))
	var snaps := roundi(current_yaw / step) + 1
	var yaw := float(snaps) * step
	return wrapf(yaw, 0.0, TAU)

func _free_desk_preview() -> void:
	if _desk_preview_root != null and is_instance_valid(_desk_preview_root):
		_desk_preview_root.queue_free()
	_desk_preview_root = null
	_desk_preview_model = null

func _update_desk_preview(screen_pos: Vector2) -> void:
	if owner == null or desk_manager == null or _placing_workspace_id == "":
		return
	_ensure_desk_preview()
	if _desk_preview_root == null:
		return

	var hit := _raycast_floor_point(screen_pos)
	if not bool(hit.get("ok", false)):
		return
	var p := hit.get("pos") as Vector3

	var yaw := _placing_yaw
	var size_xz: Vector2 = desk_manager.call("get_standing_desk_footprint_size_xz", yaw)
	var half := size_xz * 0.5

	var rect := _placing_workspace_rect
	if rect.size.x + 1e-4 < size_xz.x or rect.size.y + 1e-4 < size_xz.y:
		# Should not normally happen (we pre-check), but keep placement mode robust.
		_set_desk_preview_center_xz(rect.position + rect.size * 0.5)
		return
	var cx := clampf(float(p.x), float(rect.position.x + half.x), float(rect.position.x + rect.size.x - half.x))
	var cz := clampf(float(p.z), float(rect.position.y + half.y), float(rect.position.y + rect.size.y - half.y))
	var center_xz := Vector2(cx, cz)

	var can: Dictionary = desk_manager.call("can_place_standing_desk", _placing_workspace_id, rect, center_xz, yaw)
	var ok := bool(can.get("ok", false))

	_desk_preview_root.position = Vector3(cx, 0.0, cz)
	if _desk_preview_model != null and is_instance_valid(_desk_preview_model):
		_desk_preview_model.rotation = Vector3(0.0, yaw, 0.0)
		if _desk_preview_model.has_method("set_preview_valid"):
			_desk_preview_model.call("set_preview_valid", ok)

func _set_desk_preview_center_xz(center_xz: Vector2) -> void:
	if owner == null or desk_manager == null or _placing_workspace_id == "":
		return
	_ensure_desk_preview()
	if _desk_preview_root == null:
		return

	var yaw := _placing_yaw
	var rect := _placing_workspace_rect

	var can: Dictionary = desk_manager.call("can_place_standing_desk", _placing_workspace_id, rect, center_xz, yaw)
	var ok := bool(can.get("ok", false))

	_desk_preview_root.position = Vector3(center_xz.x, 0.0, center_xz.y)
	if _desk_preview_model != null and is_instance_valid(_desk_preview_model):
		_desk_preview_model.rotation = Vector3(0.0, yaw, 0.0)
		if _desk_preview_model.has_method("set_preview_valid"):
			_desk_preview_model.call("set_preview_valid", ok)

func _try_place_desk(screen_pos: Vector2) -> void:
	if owner == null or desk_manager == null or _placing_workspace_id == "":
		return
	var hit := _raycast_floor_point(screen_pos)
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
		_end_desk_placement("Standing Desk placed.")
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

func _rect_from_world_points(a: Vector3, b: Vector3) -> Rect2:
	var min_x := minf(float(a.x), float(b.x))
	var max_x := maxf(float(a.x), float(b.x))
	var min_z := minf(float(a.z), float(b.z))
	var max_z := maxf(float(a.z), float(b.z))
	return Rect2(Vector2(min_x, min_z), Vector2(max_x - min_x, max_z - min_z))

func _raycast_floor_point(screen_pos: Vector2) -> Dictionary:
	var cam := _get_camera()
	if cam == null:
		return {"ok": false}
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var to := from + dir * 200.0
	var world: World3D = owner.get_world_3d()
	if world == null:
		return {"ok": false}
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	q.collide_with_areas = false
	var hit: Dictionary = world.direct_space_state.intersect_ray(q)
	if hit.is_empty() or not hit.has("position"):
		return {"ok": false}
	return {"ok": true, "pos": hit.get("position")}

func _raycast_workspace(screen_pos: Vector2) -> Dictionary:
	var cam := _get_camera()
	if cam == null:
		return {"ok": false}
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var to := from + dir * 200.0
	var world: World3D = owner.get_world_3d()
	if world == null:
		return {"ok": false}
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 4
	q.collide_with_areas = false
	var hit: Dictionary = world.direct_space_state.intersect_ray(q)
	if hit.is_empty() or not hit.has("collider"):
		return {"ok": false}
	return {"ok": true, "collider": hit.get("collider")}

func _ray_hits_mask(screen_pos: Vector2, mask: int) -> bool:
	var cam := _get_camera()
	if cam == null:
		return false
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var to := from + dir * 200.0
	var world: World3D = owner.get_world_3d()
	if world == null:
		return false
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = mask
	q.collide_with_areas = false
	return not world.direct_space_state.intersect_ray(q).is_empty()

func _get_camera() -> Camera3D:
	if camera_rig != null and camera_rig.has_method("get_camera"):
		var cam0: Variant = camera_rig.call("get_camera")
		if cam0 is Camera3D:
			return cam0 as Camera3D
	var cam1 := owner.get_viewport().get_camera_3d()
	return cam1
