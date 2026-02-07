extends RefCounted

const _Props := preload("res://vr_offices/core/props/VrOfficesPropUtils.gd")

static func bounds_in_space(space: Node3D, model_root: Node3D) -> AABB:
	if space == null or model_root == null:
		return AABB()
	return _Props._compute_visual_bounds_local(space, model_root)

static func fit_xz(wrapper: Node3D, space: Node3D, model_root: Node3D, room_size_xz: Vector2, margin: float) -> void:
	if wrapper == null or space == null or model_root == null:
		return
	var b := bounds_in_space(space, model_root)
	if b.size == Vector3.ZERO:
		return
	var max_x := maxf(0.001, float(room_size_xz.x) - margin * 2.0)
	var max_z := maxf(0.001, float(room_size_xz.y) - margin * 2.0)
	var sx := float(b.size.x)
	var sz := float(b.size.z)
	if sx <= 0.001 or sz <= 0.001:
		return
	var scale := minf(1.0, minf(max_x / sx, max_z / sz))
	if absf(scale - 1.0) <= 0.0001:
		return
	wrapper.scale = wrapper.scale * scale

static func spawn_ceiling_model(wrapper: Node3D, scene_path: String) -> Node3D:
	if wrapper == null:
		return null
	# Use PropUtils to ensure consistent GLB instantiation + collision disabling.
	var model := _Props.spawn_floor_model(wrapper, scene_path)
	if model == null:
		return null
	realign_ceiling_model(wrapper, model)
	return model

static func realign_ceiling_model(wrapper: Node3D, model_root: Node3D) -> void:
	if wrapper == null or model_root == null:
		return
	var b := _Props._compute_visual_bounds_local(wrapper, model_root)
	if b.size == Vector3.ZERO:
		return
	var center := b.position + b.size * 0.5
	var top := float(b.position.y + b.size.y)
	model_root.position -= Vector3(center.x, top, center.z)

