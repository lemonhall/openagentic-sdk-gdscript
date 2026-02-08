extends RefCounted

static func pick_target(
	meeting_room_manager: RefCounted,
	meeting_room_id: String,
	npc_id: String,
	npc: Node,
	clicked_world_pos: Vector3
) -> Vector3:
	var rid := meeting_room_id.strip_edges()
	if meeting_room_manager == null or not meeting_room_manager.has_method("get_meeting_room_node") or rid == "":
		return Vector3.ZERO
	var room := meeting_room_manager.call("get_meeting_room_node", rid) as Node
	if room == null or not is_instance_valid(room):
		return Vector3.ZERO

	var table := room.get_node_or_null("Decor/Table") as Node3D
	var table_pos := Vector3.ZERO
	if table != null:
		table_pos = table.global_position
	elif room is Node3D:
		table_pos = (room as Node3D).global_position

	var y := 0.0
	if clicked_world_pos != Vector3.ZERO:
		y = float(clicked_world_pos.y)
	elif npc is Node3D:
		y = float((npc as Node3D).global_position.y)
	else:
		y = float(table_pos.y)

	var h: int = int(abs(int(npc_id.hash())))
	var angle_steps := 8
	var ang := float(h % angle_steps) * (TAU / float(angle_steps))
	var radius_bucket := int(float(h) / 13.0)
	var radius := 1.25 + float(radius_bucket % 3) * 0.15

	var p := Vector3.ZERO
	if clicked_world_pos != Vector3.ZERO:
		p = Vector3(clicked_world_pos.x, y, clicked_world_pos.z)
	else:
		p = Vector3(table_pos.x + cos(ang) * radius, y, table_pos.z + sin(ang) * radius)

	p = _clamp_to_room_rect_xz(meeting_room_manager, rid, p, 0.35)

	# Avoid targets too close to the table center (commonly non-navigable).
	var min_table_radius := 0.9
	if table != null:
		var v := Vector2(p.x - table_pos.x, p.z - table_pos.z)
		if v.length() < min_table_radius:
			var dir := v.normalized()
			if dir == Vector2.ZERO:
				dir = Vector2(cos(ang), sin(ang))
			p.x = table_pos.x + dir.x * min_table_radius
			p.z = table_pos.z + dir.y * min_table_radius
			p = _clamp_to_room_rect_xz(meeting_room_manager, rid, p, 0.35)

	return p

static func _clamp_to_room_rect_xz(meeting_room_manager: RefCounted, meeting_room_id: String, p: Vector3, pad: float) -> Vector3:
	if meeting_room_manager == null or not meeting_room_manager.has_method("get_meeting_room_rect_xz"):
		return p
	var rect0: Variant = meeting_room_manager.call("get_meeting_room_rect_xz", meeting_room_id)
	var rect: Rect2 = rect0 as Rect2 if rect0 is Rect2 else Rect2()
	if rect.size == Vector2.ZERO:
		return p
	var min_x := float(rect.position.x + pad)
	var max_x := float(rect.position.x + rect.size.x - pad)
	var min_z := float(rect.position.y + pad)
	var max_z := float(rect.position.y + rect.size.y - pad)
	p.x = clampf(p.x, min_x, max_x)
	p.z = clampf(p.z, min_z, max_z)
	return p
