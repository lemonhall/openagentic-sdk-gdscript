extends RefCounted

static func is_headless() -> bool:
	return DisplayServer.get_name() == "headless" or OS.has_feature("server") or OS.has_feature("headless")

static func spawn_floor_model(wrapper: Node3D, scene_path: String) -> void:
	if wrapper == null:
		return
	_clear_children(wrapper)
	if is_headless():
		return
	var model := _instantiate_scene(wrapper, scene_path)
	if model == null:
		return
	_align_floor_model(wrapper, model)

static func spawn_wall_model(wrapper: Node3D, scene_path: String) -> void:
	if wrapper == null:
		return
	_clear_children(wrapper)
	if is_headless():
		return
	var model := _instantiate_scene(wrapper, scene_path)
	if model == null:
		return
	_align_wall_model(wrapper, model)

static func _clear_children(n: Node) -> void:
	if n == null:
		return
	for c0 in n.get_children():
		var c := c0 as Node
		if c != null:
			c.queue_free()

static func _instantiate_scene(parent: Node, scene_path: String) -> Node3D:
	if parent == null:
		return null
	var ps0 := load(scene_path)
	if ps0 == null or not (ps0 is PackedScene):
		return null
	var inst0 := (ps0 as PackedScene).instantiate()
	var inst := inst0 as Node3D
	if inst == null:
		return null
	inst.name = "Model"
	parent.add_child(inst)
	disable_collisions(inst)
	return inst

static func disable_collisions(root: Node) -> void:
	# Decorations must not interfere with floor raycasts (mask=1).
	if root == null:
		return
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n := stack.pop_back() as Node
		if n == null:
			continue
		if n is CollisionObject3D:
			var co := n as CollisionObject3D
			if co != null:
				co.collision_layer = 0
				co.collision_mask = 0
		for c0 in n.get_children():
			var c := c0 as Node
			if c != null:
				stack.append(c)

static func _align_floor_model(wrapper: Node3D, model_root: Node3D) -> void:
	if wrapper == null or model_root == null:
		return
	if not wrapper.is_inside_tree():
		return
	var bounds := _compute_visual_bounds_local(wrapper, model_root)
	if bounds.size == Vector3.ZERO:
		return
	var center := bounds.position + bounds.size * 0.5
	model_root.position -= Vector3(center.x, bounds.position.y, center.z)

static func _align_wall_model(wrapper: Node3D, model_root: Node3D) -> void:
	if wrapper == null or model_root == null:
		return
	if not wrapper.is_inside_tree():
		return
	var bounds := _compute_visual_bounds_local(wrapper, model_root)
	if bounds.size == Vector3.ZERO:
		return
	var center_x := float(bounds.position.x + bounds.size.x * 0.5)
	var center_y := float(bounds.position.y + bounds.size.y * 0.5)
	var back_z := float(bounds.position.z + bounds.size.z)
	model_root.position -= Vector3(center_x, center_y, back_z)

static func _iter_descendants(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	if root == null:
		return out
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back() as Node
		if n == null:
			continue
		for c0 in n.get_children():
			var c: Node = c0 as Node
			if c == null:
				continue
			out.append(c)
			stack.append(c)
	return out

static func _compute_visual_bounds_local(space: Node3D, root: Node) -> AABB:
	if space == null or root == null:
		return AABB()
	var min_x := INF
	var min_y := INF
	var min_z := INF
	var max_x := -INF
	var max_y := -INF
	var max_z := -INF
	var any := false

	for n0: Node in _iter_descendants(root):
		if not (n0 is MeshInstance3D):
			continue
		var mi := n0 as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var aabb := mi.get_aabb()
		for p0 in _aabb_corners(aabb):
			var p_world := mi.global_transform * p0
			var p_local := space.to_local(p_world)
			min_x = minf(min_x, float(p_local.x))
			min_y = minf(min_y, float(p_local.y))
			min_z = minf(min_z, float(p_local.z))
			max_x = maxf(max_x, float(p_local.x))
			max_y = maxf(max_y, float(p_local.y))
			max_z = maxf(max_z, float(p_local.z))
			any = true

	if not any:
		return AABB()
	return AABB(Vector3(min_x, min_y, min_z), Vector3(max_x - min_x, max_y - min_y, max_z - min_z))

static func _aabb_corners(aabb: AABB) -> Array[Vector3]:
	var p := aabb.position
	var s := aabb.size
	return [
		Vector3(p.x, p.y, p.z),
		Vector3(p.x + s.x, p.y, p.z),
		Vector3(p.x, p.y + s.y, p.z),
		Vector3(p.x, p.y, p.z + s.z),
		Vector3(p.x + s.x, p.y + s.y, p.z),
		Vector3(p.x + s.x, p.y, p.z + s.z),
		Vector3(p.x, p.y + s.y, p.z + s.z),
		Vector3(p.x + s.x, p.y + s.y, p.z + s.z),
	]

