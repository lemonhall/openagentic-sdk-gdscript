extends RefCounted

var owner: Node = null
var floor_body: StaticBody3D = null
var move_indicators: Node3D = null
var camera_rig: Node = null
var indicator_scene: PackedScene = null

var floor_bounds_xz := Rect2(Vector2(-10.0, -10.0), Vector2(20.0, 20.0))
var _move_indicator_by_npc_id: Dictionary = {}
var _transform_move_command: Callable = Callable()

func _init(
	owner_in: Node,
	floor_in: StaticBody3D,
	move_indicators_in: Node3D,
	camera_rig_in: Node,
	indicator_scene_in: PackedScene
) -> void:
	owner = owner_in
	floor_body = floor_in
	move_indicators = move_indicators_in
	camera_rig = camera_rig_in
	indicator_scene = indicator_scene_in
	floor_bounds_xz = _compute_floor_bounds_xz()

func connect_npc_signals(npc: Node) -> void:
	if npc == null:
		return
	if npc.has_signal("move_target_reached"):
		var cb := Callable(self, "_on_npc_move_target_reached")
		if not npc.is_connected("move_target_reached", cb):
			npc.connect("move_target_reached", cb)

func set_move_command_transformer(cb: Callable) -> void:
	_transform_move_command = cb

func clear_move_indicator_for_node(npc: Node) -> void:
	if npc == null:
		return
	var npc_id := ""
	if npc.has_method("get"):
		var v: Variant = npc.get("npc_id")
		if v != null:
			npc_id = String(v)
	if npc_id.strip_edges() == "":
		npc_id = npc.name
	clear_move_indicator_for_id(npc_id)

func clear_move_indicator_for_id(npc_id: String) -> void:
	var key := npc_id.strip_edges()
	if key == "":
		return
	if not _move_indicator_by_npc_id.has(key):
		return
	var n0: Variant = _move_indicator_by_npc_id.get(key)
	_move_indicator_by_npc_id.erase(key)
	if typeof(n0) != TYPE_OBJECT:
		return
	var n := n0 as Node
	if n != null and is_instance_valid(n):
		n.queue_free()

func command_selected_move_to_click(selected_npc: Node, screen_pos: Vector2) -> void:
	if selected_npc == null or not is_instance_valid(selected_npc):
		return
	if not selected_npc.has_method("command_move_to"):
		return

	var hit := _raycast_floor_point(screen_pos)
	if not bool(hit.get("ok", false)):
		return
	var p0: Variant = hit.get("pos")
	if not (p0 is Vector3):
		return
	var p := p0 as Vector3

	var min_x := floor_bounds_xz.position.x
	var max_x := floor_bounds_xz.position.x + floor_bounds_xz.size.x
	var min_z := floor_bounds_xz.position.y
	var max_z := floor_bounds_xz.position.y + floor_bounds_xz.size.y
	p.x = clampf(p.x, min_x, max_x)
	p.z = clampf(p.z, min_z, max_z)

	var skip_default := false
	if _transform_move_command.is_valid():
		var t0: Variant = _transform_move_command.call(selected_npc, p)
		if typeof(t0) == TYPE_DICTIONARY:
			var tr := t0 as Dictionary
			skip_default = bool(tr.get("skip_default", false))
			var tp0: Variant = tr.get("target", null)
			if tp0 is Vector3:
				p = tp0 as Vector3
	if skip_default:
		_show_move_indicator_for_node(selected_npc, p)
		return

	selected_npc.call("command_move_to", p)
	_show_move_indicator_for_node(selected_npc, p)

func _on_npc_move_target_reached(npc_id: String, _target: Vector3) -> void:
	clear_move_indicator_for_id(npc_id)

func _show_move_indicator_for_node(npc: Node, target: Vector3) -> void:
	if npc == null or not is_instance_valid(npc):
		return
	var npc_id := ""
	if npc.has_method("get"):
		var v: Variant = npc.get("npc_id")
		if v != null:
			npc_id = String(v)
	if npc_id.strip_edges() == "":
		npc_id = npc.name
	clear_move_indicator_for_id(npc_id)

	if move_indicators == null or indicator_scene == null:
		return
	var node0 := indicator_scene.instantiate()
	var ind := node0 as Node3D
	if ind == null:
		return
	move_indicators.add_child(ind)
	ind.position = Vector3(target.x, 0.02, target.z)
	_move_indicator_by_npc_id[npc_id] = ind

func _compute_floor_bounds_xz() -> Rect2:
	# Prefer collider dimensions to avoid depending on mesh settings.
	if floor_body != null:
		var cs := floor_body.get_node_or_null("FloorCollider") as CollisionShape3D
		if cs != null and cs.shape is BoxShape3D:
			var box := cs.shape as BoxShape3D
			var sx := float(box.size.x)
			var sz := float(box.size.z)
			var hx := sx * 0.5
			var hz := sz * 0.5
			return Rect2(Vector2(-hx, -hz), Vector2(sx, sz))
	# Fallback: match the default scene values.
	return Rect2(Vector2(-10.0, -10.0), Vector2(20.0, 20.0))

func _raycast_floor_point(screen_pos: Vector2) -> Dictionary:
	if owner == null:
		return {"ok": false}
	if camera_rig == null or not camera_rig.has_method("get_camera"):
		return {"ok": false}
	var cam0: Variant = camera_rig.call("get_camera")
	if not (cam0 is Camera3D):
		return {"ok": false}
	var cam := cam0 as Camera3D
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var to := from + dir * 200.0
	var world: World3D = owner.get_world_3d()
	if world == null:
		return {"ok": false}
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1 # floor default layer
	q.collide_with_areas = false
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty() or not hit.has("position"):
		return {"ok": false}
	return {"ok": true, "pos": hit.get("position")}
