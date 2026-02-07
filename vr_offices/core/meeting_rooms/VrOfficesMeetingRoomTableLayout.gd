extends RefCounted

const _ModelUtils := preload("res://vr_offices/core/meeting_rooms/VrOfficesMeetingRoomDecorationModelUtils.gd")

static func scale_table_for_room(
	wrapper: Node3D,
	space: Node3D,
	model_root: Node3D,
	screen_axis: String,
	room_size_xz: Vector2,
	margin: float,
	stretch_ratio: float
) -> void:
	if wrapper == null or space == null or model_root == null:
		return
	var b := _ModelUtils.bounds_in_space(space, model_root)
	if b.size == Vector3.ZERO:
		return

	var sx := float(room_size_xz.x)
	var sz := float(room_size_xz.y)
	var room_long := sx if screen_axis == "x" else sz
	var room_short := sz if screen_axis == "x" else sx
	var desired_long := maxf(1.8, room_long - margin * 2.0)
	var desired_short := maxf(1.1, minf(2.4, room_short - margin * 2.0))

	var long_axis_x := (screen_axis == "x")
	var cur_long := float(b.size.x) if long_axis_x else float(b.size.z)
	var cur_short := float(b.size.z) if long_axis_x else float(b.size.x)
	if cur_long <= 0.001 or cur_short <= 0.001:
		return

	var s_long := clampf(desired_long / cur_long, 0.5, 6.0)
	var s_short := clampf(desired_short / cur_short, 0.5, 6.0)
	s_short = minf(s_short, s_long / maxf(1.01, stretch_ratio))
	var s_y := clampf(minf(s_long, s_short), 0.5, 6.0)

	if long_axis_x:
		wrapper.scale = Vector3(s_long, s_y, s_short)
	else:
		wrapper.scale = Vector3(s_short, s_y, s_long)
