extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _find_descendant_named(root: Node, want: String) -> Node:
	if root == null:
		return null
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var cur := stack.pop_back() as Node
		if cur == null:
			continue
		if cur.name == want:
			return cur
		for c0 in cur.get_children():
			var c := c0 as Node
			if c != null:
				stack.append(c)
	return null

func _iter_descendants(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	if root == null:
		return out
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var cur := stack.pop_back() as Node
		if cur == null:
			continue
		for c0 in cur.get_children():
			var c := c0 as Node
			if c == null:
				continue
			out.append(c)
			stack.append(c)
	return out

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
	for n0: Node in _iter_descendants(root):
		if not (n0 is MeshInstance3D):
			continue
		var mi := n0 as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for p0 in _aabb_corners(mi.get_aabb()):
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

func _init() -> void:
	var ManagerScript := load("res://vr_offices/core/meeting_rooms/VrOfficesMeetingRoomManager.gd")
	var AreaScene0 := load("res://vr_offices/meeting_rooms/MeetingRoomArea.tscn")
	if ManagerScript == null or AreaScene0 == null or not (AreaScene0 is PackedScene):
		T.fail_and_quit(self, "Missing meeting room manager / area scene")
		return

	var root := Node3D.new()
	root.name = "MeetingRooms"
	get_root().add_child(root)
	await process_frame

	var bounds := Rect2(Vector2(-10, -10), Vector2(20, 20))
	var mgr := (ManagerScript as Script).new(bounds) as RefCounted
	if mgr == null:
		T.fail_and_quit(self, "Failed to instantiate manager")
		return
	mgr.call("bind_scene", root, AreaScene0, Callable())

	var res: Dictionary = mgr.call("create_meeting_room", Rect2(Vector2(-2, -2), Vector2(3, 4)), "Room A")
	if not T.require_true(self, bool(res.get("ok", false)), "Expected create_meeting_room ok"):
		return
	await process_frame
	if not T.require_eq(self, root.get_child_count(), 1, "Expected one meeting room node spawned"):
		return

	var child := root.get_child(0) as Node
	if not T.require_true(self, child != null and child.is_in_group("vr_offices_meeting_room"), "Expected meeting room node group"):
		return
	if not T.require_eq(self, String(child.get("meeting_room_name")), "Room A", "Expected meeting room name on node"):
		return
	var walls := child.get_node_or_null("Walls") as Node3D
	if not T.require_true(self, walls != null, "Expected meeting room Walls node"):
		return

	# Decorations should include stable wrapper nodes even in headless mode.
	var decor := child.get_node_or_null("Decor") as Node3D
	if not T.require_true(self, decor != null, "Expected meeting room Decor node"):
		return
	var table_wrap := decor.get_node_or_null("Table") as Node3D
	if not T.require_true(self, table_wrap != null, "Expected Decor/Table wrapper"):
		return
	var proj_wrap := decor.get_node_or_null("CeilingProjector") as Node3D
	if not T.require_true(self, proj_wrap != null, "Expected Decor/CeilingProjector wrapper"):
		return
	var table_collision := table_wrap.get_node_or_null("TableCollision") as StaticBody3D
	if not T.require_true(self, table_collision != null, "Expected Decor/Table/TableCollision StaticBody3D"):
		return
	var table_collision_shape := table_collision.get_node_or_null("Shape") as CollisionShape3D
	if not T.require_true(self, table_collision_shape != null, "Expected table collision Shape"):
		return
	var mic_wrap := table_wrap.get_node_or_null("Mic") as Node3D
	if not T.require_true(self, mic_wrap != null, "Expected Decor/Table/Mic wrapper"):
		return
	var mic_indicator := mic_wrap.get_node_or_null("InteractIndicator") as Node3D
	if not T.require_true(self, mic_indicator != null, "Expected Mic/InteractIndicator wrapper"):
		return
	var zone := decor.get_node_or_null("MeetingZoneIndicator") as Node3D
	if not T.require_true(self, zone != null, "Expected Decor/MeetingZoneIndicator"):
		return
	var zone_mesh := zone.get_node_or_null("Mesh") as MeshInstance3D
	if not T.require_true(self, zone_mesh != null, "Expected MeetingZoneIndicator/Mesh MeshInstance3D"):
		return
	var zone_mat := zone_mesh.material_override as ShaderMaterial
	if not T.require_true(self, zone_mat != null, "Expected MeetingZoneIndicator mesh ShaderMaterial override"):
		return

	var ring_a0: Variant = zone_mat.get_shader_parameter("ring_alpha")
	var fill_a0: Variant = zone_mat.get_shader_parameter("fill_alpha")
	var pulse_max0: Variant = zone_mat.get_shader_parameter("pulse_max")
	if not T.require_true(self, (ring_a0 is float) or (ring_a0 is int), "Expected ring_alpha shader parameter"):
		return
	if not T.require_true(self, (fill_a0 is float) or (fill_a0 is int), "Expected fill_alpha shader parameter"):
		return
	if not T.require_true(self, (pulse_max0 is float) or (pulse_max0 is int), "Expected pulse_max shader parameter"):
		return
	var ring_a := float(ring_a0)
	var fill_a := float(fill_a0)
	var pulse_max := float(pulse_max0)
	if not T.require_true(self, ring_a >= 0.55, "Meeting zone ring_alpha must be >= 0.55 for visibility"):
		return
	if not T.require_true(self, fill_a >= 0.08, "Meeting zone fill_alpha must be >= 0.08 for visibility"):
		return
	if not T.require_true(self, pulse_max >= 0.95, "Meeting zone pulse_max must be >= 0.95"):
		return
	# Screen should be attached under a wall so it hides with wall visibility.
	var screen := _find_descendant_named(walls, "ProjectorScreen") as Node3D
	if not T.require_true(self, screen != null, "Expected Walls/**/ProjectorScreen wrapper"):
		return

	# Table should be scaled up and stretched into a long meeting table.
	var sx := float(table_wrap.scale.x)
	var sz := float(table_wrap.scale.z)
	var smax := maxf(sx, sz)
	var smin := maxf(0.0001, minf(sx, sz))
	if not T.require_true(self, smax > 1.05, "Expected Table wrapper scaled up"):
		return
	if not T.require_true(self, (smax / smin) >= 1.2, "Expected Table wrapper stretched (long/short ratio >= 1.2)"):
		return

	# Screen should be rotated by +90deg relative to the wall-facing default.
	var wall := screen.get_parent() as Node
	if not T.require_true(self, wall != null, "Expected ProjectorScreen parent wall"):
		return
	var wall_yaw := 0.0
	if wall.name == "WallPosX":
		wall_yaw = PI * 0.5
	elif wall.name == "WallNegX":
		wall_yaw = -PI * 0.5
	elif wall.name == "WallPosZ":
		wall_yaw = 0.0
	elif wall.name == "WallNegZ":
		wall_yaw = PI
	var want := wall_yaw + PI * 0.5
	var dy := _angle_diff(float(screen.rotation.y), want)
	if not T.require_true(self, absf(dy) <= 0.15, "Expected screen yaw ~ wall_yaw + 90deg"):
		return
	# Screen should be stretched wider (roughly 2x).
	if not T.require_true(self, float(screen.scale.x) >= 1.6, "Expected screen scale.x stretched wider"):
		return

	# Projector should hang above the table and face the screen.
	if not T.require_true(self, float(proj_wrap.position.y) >= 1.6, "Expected projector raised near ceiling"):
		return
	var room := child as Node3D
	if room == null:
		T.fail_and_quit(self, "Expected meeting room node to be Node3D")
		return
	var tgt_local := Vector3.ZERO
	if wall.name == "WallPosX":
		tgt_local = Vector3(1.5, float(proj_wrap.position.y), 0.0)
	elif wall.name == "WallNegX":
		tgt_local = Vector3(-1.5, float(proj_wrap.position.y), 0.0)
	elif wall.name == "WallPosZ":
		tgt_local = Vector3(0.0, float(proj_wrap.position.y), 2.0)
	else:
		tgt_local = Vector3(0.0, float(proj_wrap.position.y), -2.0)
	var tgt_global := room.to_global(tgt_local)
	var to_tgt := (tgt_global - proj_wrap.global_position).normalized()
	var forward := -proj_wrap.global_transform.basis.z
	if not T.require_true(self, forward.dot(to_tgt) >= 0.6, "Expected projector facing screen (forward dot >= 0.6)"):
		return

	# Mic should sit on the table top near one end.
	var table_model := table_wrap.get_node_or_null("Model") as Node3D
	var mic_model := mic_wrap.get_node_or_null("Model") as Node3D
	if not T.require_true(self, table_model != null, "Expected Table wrapper to contain Model"):
		return
	if not T.require_true(self, mic_model != null, "Expected Mic wrapper to contain Model"):
		return
	var tb := _compute_visual_bounds_local(table_wrap, table_model)
	if not T.require_true(self, tb.size != Vector3.ZERO, "Expected table bounds non-zero"):
		return
	var top_y := float(tb.position.y + tb.size.y)
	if not T.require_true(self, float(mic_wrap.position.y) >= top_y - 0.05, "Expected mic on/above table top"):
		return
	if not T.require_true(self, float(mic_wrap.position.y) <= top_y + 0.35, "Expected mic not floating too high"):
		return
	var long_is_x := float(tb.size.x) >= float(tb.size.z)
	if long_is_x:
		var minx := float(tb.position.x)
		var maxx := float(tb.position.x + tb.size.x)
		var cx := (minx + maxx) * 0.5
		var hx := (maxx - minx) * 0.5
		if not T.require_true(self, absf(float(mic_wrap.position.x) - cx) >= hx * 0.55, "Expected mic near a table end (x)"):
			return
	else:
		var minz := float(tb.position.z)
		var maxz := float(tb.position.z + tb.size.z)
		var cz := (minz + maxz) * 0.5
		var hz := (maxz - minz) * 0.5
		if not T.require_true(self, absf(float(mic_wrap.position.z) - cz) >= hz * 0.55, "Expected mic near a table end (z)"):
			return

	var rid := String(child.get("meeting_room_id"))
	var del: Dictionary = mgr.call("delete_meeting_room", rid)
	if not T.require_true(self, bool(del.get("ok", false)), "Expected delete ok"):
		return
	await process_frame
	await process_frame
	if not T.require_eq(self, root.get_child_count(), 0, "Expected no meeting room nodes after delete"):
		return

	get_root().remove_child(root)
	root.free()
	await process_frame
	T.pass_and_quit(self)

func _angle_diff(a: float, b: float) -> float:
	var d := fmod(a - b + PI, TAU) - PI
	return d
