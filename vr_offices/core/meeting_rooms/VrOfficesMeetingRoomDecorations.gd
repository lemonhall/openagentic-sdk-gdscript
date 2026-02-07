extends RefCounted

const _Props := preload("res://vr_offices/core/props/VrOfficesPropUtils.gd")
const _WallUtils := preload("res://vr_offices/core/meeting_rooms/VrOfficesMeetingRoomWallUtils.gd")
const _ModelUtils := preload("res://vr_offices/core/meeting_rooms/VrOfficesMeetingRoomDecorationModelUtils.gd")
const _TableLayout := preload("res://vr_offices/core/meeting_rooms/VrOfficesMeetingRoomTableLayout.gd")

const TABLE_SCENE := "res://assets/meeting_room/Table.glb"
const SCREEN_SCENE := "res://assets/meeting_room/projector screen.glb"
const PROJECTOR_SCENE := "res://assets/meeting_room/projector.glb"

const _MARGIN_XZ := 0.55
const _SCREEN_GAP := 0.75
const _CEILING_INSET := -2
const _SCREEN_YAW_OFFSET := PI * 0.5
const _SCREEN_WIDTH_MULT := 2.0
const _PROJECTOR_TARGET_H := 1
const _PROJECTOR_MODEL_YAW_OFFSET := PI
const _TABLE_STRETCH_RATIO := 1.1

static func decorate_meeting_room(meeting_room_node: Node3D, meeting_room_id: String, rect_xz: Rect2) -> void:
	if meeting_room_node == null:
		return
	var walls := meeting_room_node.get_node_or_null("Walls") as Node3D
	if walls == null:
		return

	var decor := meeting_room_node.get_node_or_null("Decor") as Node3D
	if decor == null:
		decor = Node3D.new()
		decor.name = "Decor"
		meeting_room_node.add_child(decor)

	var sx := maxf(0.001, float(rect_xz.size.x))
	var sz := maxf(0.001, float(rect_xz.size.y))
	var hx := sx * 0.5
	var hz := sz * 0.5

	var screen_wall := _WallUtils.pick_screen_wall(walls, sx, sz, meeting_room_id)
	if screen_wall == null:
		return
	var screen_spec := _WallUtils.wall_spec(screen_wall)
	var screen_axis := String(screen_spec.get("axis", "z"))
	var screen_wall_sign := float(screen_spec.get("sign", -1.0))
	var axis_half := hx if screen_axis == "x" else hz

	# Create stable wrapper nodes.
	var table_wrap := _ensure_wrapper(decor, "Table")
	var proj_wrap := _ensure_wrapper(decor, "CeilingProjector")

	var screen_wrap := screen_wall.get_node_or_null("ProjectorScreen") as Node3D
	if screen_wrap == null:
		screen_wrap = Node3D.new()
		screen_wrap.name = "ProjectorScreen"
		screen_wall.add_child(screen_wrap)

	# Spawn models at origin first so we can probe bounds before final placement.
	table_wrap.position = Vector3.ZERO
	table_wrap.rotation = Vector3.ZERO
	table_wrap.scale = Vector3.ONE
	var table_model := _Props.spawn_floor_model(table_wrap, TABLE_SCENE, true)

	screen_wrap.position = Vector3.ZERO
	screen_wrap.rotation = Vector3.ZERO
	screen_wrap.scale = Vector3.ONE
	var screen_model := _Props.spawn_wall_model(screen_wrap, SCREEN_SCENE, true)

	proj_wrap.position = Vector3.ZERO
	proj_wrap.rotation = Vector3.ZERO
	proj_wrap.scale = Vector3.ONE
	var projector_model := _ModelUtils.spawn_ceiling_model(proj_wrap, PROJECTOR_SCENE, true)
	if projector_model != null:
		projector_model.rotation.y += _PROJECTOR_MODEL_YAW_OFFSET
		_ModelUtils.realign_ceiling_model(proj_wrap, projector_model)

	# Compute bounds in meeting-room local space for placement and fitting.
	var table_bounds := _ModelUtils.bounds_in_space(decor, table_model)
	if table_bounds.size == Vector3.ZERO:
		table_bounds = AABB(Vector3(-1.0, 0.0, -0.5), Vector3(2.0, 0.75, 1.0))

	var screen_bounds := _ModelUtils.bounds_in_space(screen_wrap, screen_model)
	if screen_bounds.size == Vector3.ZERO:
		screen_bounds = AABB(Vector3(-0.75, 0.0, 0.0), Vector3(1.5, 1.0, 0.25))

	# Scale up and stretch table into a long meeting table aligned with the room long axis.
	_TableLayout.scale_table_for_room(table_wrap, decor, table_model, screen_axis, Vector2(sx, sz), _MARGIN_XZ, _TABLE_STRETCH_RATIO)
	table_bounds = _ModelUtils.bounds_in_space(decor, table_model)
	if table_bounds.size == Vector3.ZERO:
		table_bounds = AABB(Vector3(-1.0, 0.0, -0.5), Vector3(2.0, 0.75, 1.0))

	# Ensure table long axis points into the room from the screen (room long axis).
	var want_long_x := (screen_axis == "x")
	var b0 := table_bounds
	var long_is_x := float(b0.size.x) >= float(b0.size.z)
	if want_long_x != long_is_x:
		table_wrap.rotation.y = PI * 0.5
		table_bounds = _ModelUtils.bounds_in_space(decor, table_model)
		if table_bounds.size == Vector3.ZERO:
			table_bounds = b0

	# Fit screen within wall before final placement.
	_WallUtils.fit_screen(screen_wrap, screen_wall, screen_bounds)
	screen_bounds = _ModelUtils.bounds_in_space(screen_wrap, screen_model)
	if screen_bounds.size == Vector3.ZERO:
		screen_bounds = AABB(Vector3(-0.75, 0.0, 0.0), Vector3(1.5, 1.0, 0.25))

	# Place screen on wall, centered along the wall.
	_WallUtils.place_wall_wrapper(screen_wall, screen_wrap, screen_bounds)
	screen_wrap.rotation.y += _SCREEN_YAW_OFFSET
	_WallUtils.stretch_screen_width(screen_wrap, screen_wall, screen_model, _SCREEN_WIDTH_MULT)

	# Place table near center but ensure it stays inside footprint and keeps a gap to the screen wall.
	var table_pos := Vector3.ZERO
	table_pos = _clamp_aabb_center_to_room(table_bounds, hx, hz, _MARGIN_XZ)
	table_pos = _push_away_from_screen_wall(table_pos, table_bounds, screen_axis, screen_wall_sign, axis_half, _SCREEN_GAP)
	table_wrap.position = table_pos

	# Place projector on ceiling above the table, slightly toward the screen wall, facing the screen.
	var ceiling_y := float(screen_spec.get("height", 2.2)) - _CEILING_INSET
	var proj_pos := table_pos
	var toward_wall := Vector3.ZERO
	if screen_axis == "x":
		toward_wall = Vector3(screen_wall_sign, 0.0, 0.0)
	else:
		toward_wall = Vector3(0.0, 0.0, screen_wall_sign)
	var dist_to_wall := axis_half - screen_wall_sign * (proj_pos.x if screen_axis == "x" else proj_pos.z)
	var offset := minf(0.75, maxf(0.0, dist_to_wall) * 0.35)
	proj_pos += toward_wall * offset
	proj_pos.y = ceiling_y
	proj_wrap.position = proj_pos
	var screen_target_local := Vector3.ZERO
	if screen_axis == "x":
		screen_target_local = Vector3(screen_wall_sign * hx, 1.35, 0.0)
	else:
		screen_target_local = Vector3(0.0, 1.35, screen_wall_sign * hz)
	var tgt_global := decor.to_global(Vector3(screen_target_local.x, proj_wrap.position.y, screen_target_local.z))
	proj_wrap.look_at(tgt_global, Vector3.UP)
	# Keep projector level (avoid pitch).
	proj_wrap.rotation.x = 0.0
	proj_wrap.rotation.z = 0.0

	# Ensure projector doesn't hang all the way down to the table.
	_ModelUtils.fit_height(proj_wrap, decor, projector_model, _PROJECTOR_TARGET_H)
	_ModelUtils.realign_ceiling_model(proj_wrap, projector_model)

	# Fit projector footprint gently if it is too large.
	_ModelUtils.fit_xz(proj_wrap, decor, projector_model, Vector2(sx, sz), _MARGIN_XZ)
	_ModelUtils.realign_ceiling_model(proj_wrap, projector_model)

static func _ensure_wrapper(parent: Node, name: String) -> Node3D:
	if parent == null:
		return null
	var existing := parent.get_node_or_null(name) as Node3D
	if existing != null:
		return existing
	var n := Node3D.new()
	n.name = name
	parent.add_child(n)
	return n

static func _clamp_aabb_center_to_room(bounds_in_decor: AABB, hx: float, hz: float, margin: float) -> Vector3:
	var half_x := float(bounds_in_decor.size.x) * 0.5
	var half_z := float(bounds_in_decor.size.z) * 0.5
	var x := clampf(0.0, -hx + margin + half_x, hx - margin - half_x)
	var z := clampf(0.0, -hz + margin + half_z, hz - margin - half_z)
	return Vector3(x, 0.0, z)

static func _push_away_from_screen_wall(
	center: Vector3,
	bounds_in_decor: AABB,
	screen_axis: String,
	screen_wall_sign: float,
	axis_half: float,
	gap: float
) -> Vector3:
	var out := center
	if screen_axis == "x":
		var half := float(bounds_in_decor.size.x) * 0.5
		var max_allowed := axis_half - gap - half
		var min_allowed := -axis_half + gap + half
		var coord := float(out.x)
		if screen_wall_sign > 0.0:
			coord = minf(coord, max_allowed)
		else:
			coord = maxf(coord, min_allowed)
		out.x = coord
	else:
		var halfz := float(bounds_in_decor.size.z) * 0.5
		var max_allowed_z := axis_half - gap - halfz
		var min_allowed_z := -axis_half + gap + halfz
		var coordz := float(out.z)
		if screen_wall_sign > 0.0:
			coordz = minf(coordz, max_allowed_z)
		else:
			coordz = maxf(coordz, min_allowed_z)
		out.z = coordz
	return out
