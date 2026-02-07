extends RefCounted

const _WALL_EPS := 0.02

static func pick_screen_wall(walls: Node3D, sx: float, sz: float, meeting_room_id: String) -> MeshInstance3D:
	if walls == null:
		return null
	var seed := _fnv1a32(meeting_room_id.strip_edges())
	var choose_pos := ((seed >> 3) & 1) == 1
	# Put the screen on the short wall so the table can extend along the long axis.
	if sx >= sz:
		return walls.get_node_or_null("WallPosX" if choose_pos else "WallNegX") as MeshInstance3D
	return walls.get_node_or_null("WallPosZ" if choose_pos else "WallNegZ") as MeshInstance3D

static func wall_spec(wall: MeshInstance3D) -> Dictionary:
	if wall == null:
		return {}
	var n := String(wall.name)
	if n == "WallPosX":
		return {"axis": "x", "sign": 1.0, "yaw": PI * 0.5, "height": wall_height(wall)}
	if n == "WallNegX":
		return {"axis": "x", "sign": -1.0, "yaw": -PI * 0.5, "height": wall_height(wall)}
	if n == "WallPosZ":
		return {"axis": "z", "sign": 1.0, "yaw": 0.0, "height": wall_height(wall)}
	# WallNegZ
	return {"axis": "z", "sign": -1.0, "yaw": PI, "height": wall_height(wall)}

static func place_wall_wrapper(wall: MeshInstance3D, wrapper: Node3D, screen_bounds: AABB) -> void:
	if wall == null or wrapper == null:
		return
	var spec := wall_spec(wall)
	var yaw := float(spec.get("yaw", 0.0))
	var height := float(spec.get("height", 2.2))
	var half_len := wall_half_length(wall)
	var thickness := wall_thickness(wall)

	# Choose a reasonable center height, clamped by screen height.
	var sh := float(screen_bounds.size.y)
	var center_y := 1.35
	if sh > 0.001:
		var min_center := 0.4 + sh * 0.5
		var max_center := height - 0.15 - sh * 0.5
		center_y = clampf(center_y, min_center, max_center)

	# Keep centered along the wall length.
	var along := _clamp_along(0.0, half_len, 0.35)

	# Wall origin is at its center, at y = height/2 in meeting-room local space.
	var local_y := center_y - height * 0.5
	wrapper.position = Vector3(0.0, local_y, 0.0)
	wrapper.rotation = Vector3(0.0, yaw, 0.0)

	var wn := String(wall.name)
	if wn == "WallPosX":
		wrapper.position.x = -(thickness * 0.5 + _WALL_EPS)
		wrapper.position.z = along
	elif wn == "WallNegX":
		wrapper.position.x = thickness * 0.5 + _WALL_EPS
		wrapper.position.z = along
	elif wn == "WallPosZ":
		wrapper.position.z = -(thickness * 0.5 + _WALL_EPS)
		wrapper.position.x = along
	else: # WallNegZ
		wrapper.position.z = thickness * 0.5 + _WALL_EPS
		wrapper.position.x = along

static func fit_screen(wrapper: Node3D, wall: MeshInstance3D, screen_bounds: AABB) -> void:
	if wrapper == null or wall == null:
		return
	var sh := float(screen_bounds.size.y)
	var sw := float(screen_bounds.size.x)
	if sh <= 0.001 or sw <= 0.001:
		return
	var height := wall_height(wall)
	var wall_len := wall_half_length(wall) * 2.0
	var max_h := maxf(0.25, height - 0.45)
	var max_w := maxf(0.25, wall_len - 0.7)
	var scale := minf(1.0, minf(max_h / sh, max_w / sw))
	if absf(scale - 1.0) <= 0.0001:
		return
	wrapper.scale = wrapper.scale * scale

static func wall_thickness(wall: MeshInstance3D) -> float:
	if wall == null:
		return 0.06
	var bm := wall.mesh as BoxMesh
	if bm == null:
		return 0.06
	return maxf(0.001, minf(float(bm.size.x), float(bm.size.z)))

static func wall_height(wall: MeshInstance3D) -> float:
	if wall == null:
		return 2.2
	var bm := wall.mesh as BoxMesh
	if bm == null:
		return 2.2
	return maxf(0.001, float(bm.size.y))

static func wall_half_length(wall: MeshInstance3D) -> float:
	if wall == null:
		return 1.0
	var bm := wall.mesh as BoxMesh
	if bm == null:
		return 1.0
	var wall_len := maxf(float(bm.size.x), float(bm.size.z))
	return wall_len * 0.5

static func _clamp_along(v: float, half_len: float, margin: float) -> float:
	var h := maxf(0.0, half_len - margin)
	if h <= 0.001:
		return 0.0
	return clampf(v, -h, h)

static func _fnv1a32(s: String) -> int:
	var h: int = 0x811C9DC5
	var n := s.length()
	for i in range(n):
		h = h ^ s.unicode_at(i)
		h = int((h * 0x01000193) & 0xFFFFFFFF)
	return h

