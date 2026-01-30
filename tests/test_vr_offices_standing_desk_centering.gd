extends SceneTree

const T := preload("res://tests/_test_util.gd")

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

static func _iter_descendants(root: Node) -> Array[Node]:
	var out: Array[Node] = []
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

static func _compute_visual_bounds_local(desk: Node3D, root: Node) -> AABB:
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
			var p_local := desk.to_local(p_world)
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

func _init() -> void:
	var scene := load("res://vr_offices/furniture/StandingDesk.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing res://vr_offices/furniture/StandingDesk.tscn")
		return

	var desk := (scene as PackedScene).instantiate() as Node3D
	if desk == null:
		T.fail_and_quit(self, "Failed to instantiate StandingDesk.tscn")
		return
	get_root().add_child(desk)
	await process_frame

	var model := desk.get_node_or_null("Model") as Node
	if not T.require_true(self, model != null, "StandingDesk must have Model"):
		return

	var bounds := _compute_visual_bounds_local(desk, model)
	if not T.require_true(self, bounds.size != Vector3.ZERO, "StandingDesk Model must have mesh bounds"):
		return

	var center := bounds.position + bounds.size * 0.5
	# The model should be centered on XZ (so desk click collider & indicator align with the mesh).
	var max_abs := maxf(absf(center.x), absf(center.z))
	if not T.require_true(self, max_abs <= 0.05, "StandingDesk model center (XZ) must be near origin, got %s" % [str(center)]):
		return

	get_root().remove_child(desk)
	desk.free()
	await process_frame
	T.pass_and_quit(self)

