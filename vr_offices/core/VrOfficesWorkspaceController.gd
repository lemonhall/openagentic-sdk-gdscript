extends RefCounted

const _WorkspaceAreaScene := preload("res://vr_offices/workspaces/WorkspaceArea.tscn")

var owner: Node = null
var camera_rig: Node = null
var workspace_manager: RefCounted = null
var overlay: Control = null
var autosave: Callable = Callable()

var _armed := false
var _dragging := false
var _start_screen := Vector2.ZERO
var _last_screen := Vector2.ZERO
var _start_world := Vector3.ZERO
var _last_world := Vector3.ZERO
var _pending_rect: Rect2 = Rect2()

var _preview_node: Node = null

func _init(
	owner_in: Node,
	camera_rig_in: Node,
	manager_in: RefCounted,
	overlay_in: Control,
	autosave_in: Callable
) -> void:
	owner = owner_in
	camera_rig = camera_rig_in
	workspace_manager = manager_in
	overlay = overlay_in
	autosave = autosave_in

	if overlay != null:
		if overlay.has_signal("create_confirmed"):
			overlay.connect("create_confirmed", Callable(self, "_on_create_confirmed"))
		if overlay.has_signal("create_canceled"):
			overlay.connect("create_canceled", Callable(self, "_on_create_canceled"))
		if overlay.has_signal("delete_requested"):
			overlay.connect("delete_requested", Callable(self, "_on_delete_requested"))

func handle_lmb_event(event: InputEvent, select_npc: Callable) -> bool:
	if owner == null or camera_rig == null or workspace_manager == null:
		return false

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

func try_open_context_menu(screen_pos: Vector2) -> bool:
	if owner == null or overlay == null or workspace_manager == null:
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
	_hide_preview()

func _on_create_canceled() -> void:
	_pending_rect = Rect2()
	_hide_preview()

func _on_delete_requested(workspace_id: String) -> void:
	if workspace_manager == null:
		return
	var res: Dictionary = workspace_manager.call("delete_workspace", workspace_id)
	if bool(res.get("ok", false)) and autosave.is_valid():
		autosave.call()

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

