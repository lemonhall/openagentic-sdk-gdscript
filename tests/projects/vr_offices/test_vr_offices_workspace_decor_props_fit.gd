extends SceneTree

const T := preload("res://tests/_test_util.gd")
const Props := preload("res://vr_offices/core/props/VrOfficesPropUtils.gd")

func _init() -> void:
	await _assert_wall_prop_fit(
		"Analog clock",
		"res://assets/office_pack_glb/Analog clock.glb",
		0.75,
		0.18,
		PI * 0.5
	)
	await _assert_wall_prop_fit(
		"Dartboard",
		"res://assets/office_pack_glb/Dartboard.glb",
		0.85,
		0.18,
		PI * 0.5
	)
	await _assert_wall_prop_fit(
		"Whiteboard",
		"res://assets/office_pack_glb/Whiteboard.glb",
		2.6,
		0.12,
		PI
	)
	await _assert_wall_prop_fit(
		"Fire Exit Sign-0ywPpb36cyK",
		"res://assets/office_pack_glb/Fire Exit Sign-0ywPpb36cyK.glb",
		0.9,
		0.12,
		PI
	)
	await _assert_floor_prop_fit("Water Cooler", "res://assets/office_pack_glb/Water Cooler.glb", 1.9)

	# File cabinet orientation: requires a fixed 90° yaw offset at the model level.
	await _assert_model_yaw("File Cabinet", "res://assets/office_pack_glb/File Cabinet.glb", PI * 0.5)

	T.pass_and_quit(self)

func _assert_wall_prop_fit(label: String, scene_path: String, max_dim_limit: float, max_depth_z: float, want_rot_y: float) -> void:
	var wrapper := Node3D.new()
	get_root().add_child(wrapper)
	await process_frame

	var model := Props.spawn_wall_model(wrapper, scene_path, true) as Node3D
	if not T.require_true(self, model != null, "Expected wall prop spawned: %s" % label):
		return

	await process_frame
	var aabb := _compute_visual_bounds_local(wrapper, model)
	var max_dim := maxf(maxf(float(aabb.size.x), float(aabb.size.y)), float(aabb.size.z))
	if not T.require_true(self, max_dim <= max_dim_limit, "%s too large after fit (max_dim=%s limit=%s)" % [label, str(max_dim), str(max_dim_limit)]):
		return
	if not T.require_true(self, float(aabb.size.z) <= max_depth_z, "%s should be wall-thin (depth_z=%s limit=%s)" % [label, str(aabb.size.z), str(max_depth_z)]):
		return

	if not _require_angle_near(label, float(model.rotation.y), want_rot_y, 0.02):
		return

	get_root().remove_child(wrapper)
	wrapper.free()
	await process_frame

func _assert_floor_prop_fit(label: String, scene_path: String, max_height: float) -> void:
	var wrapper := Node3D.new()
	get_root().add_child(wrapper)
	await process_frame

	var model := Props.spawn_floor_model(wrapper, scene_path, true) as Node3D
	if not T.require_true(self, model != null, "Expected floor prop spawned: %s" % label):
		return

	await process_frame
	var aabb := _compute_visual_bounds_local(wrapper, model)
	if not T.require_true(self, float(aabb.size.y) <= max_height, "%s too tall after fit (height=%s limit=%s)" % [label, str(aabb.size.y), str(max_height)]):
		return

	get_root().remove_child(wrapper)
	wrapper.free()
	await process_frame

func _assert_model_yaw(label: String, scene_path: String, want_rot_y: float) -> void:
	var wrapper := Node3D.new()
	get_root().add_child(wrapper)
	await process_frame

	var model := Props.spawn_floor_model(wrapper, scene_path, true) as Node3D
	if not T.require_true(self, model != null, "Expected prop spawned: %s" % label):
		return
	if not _require_angle_near(label, float(model.rotation.y), want_rot_y, 0.02):
		return

	get_root().remove_child(wrapper)
	wrapper.free()
	await process_frame

func _require_angle_near(label: String, got: float, want: float, eps: float) -> bool:
	var d := absf(_wrap_angle_pi(got - want))
	return T.require_true(self, d <= eps, "%s rot_y mismatch (got=%s want=%s d=%s)" % [label, str(got), str(want), str(d)])

func _wrap_angle_pi(x: float) -> float:
	var a := fmod(x + PI, PI * 2.0)
	if a < 0.0:
		a += PI * 2.0
	return a - PI

func _compute_visual_bounds_local(space: Node3D, root: Node) -> AABB:
	if space == null or root == null:
		return AABB()
	var min_x := INF
	var min_y := INF
	var min_z := INF
	var max_x := -INF
	var max_y := -INF
	var max_z := -INF
	var any := false

	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n := stack.pop_back() as Node
		if n == null:
			continue
		for c0 in n.get_children():
			var c := c0 as Node
			if c != null:
				stack.append(c)
		if not (n is MeshInstance3D):
			continue
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var local_aabb := mi.get_aabb()
		for p0 in _aabb_corners(local_aabb):
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

func _aabb_corners(aabb: AABB) -> Array[Vector3]:
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

