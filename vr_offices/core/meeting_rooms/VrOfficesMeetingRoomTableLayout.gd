extends RefCounted

const _Props := preload("res://vr_offices/core/props/VrOfficesPropUtils.gd")
const _ModelUtils := preload("res://vr_offices/core/meeting_rooms/VrOfficesMeetingRoomDecorationModelUtils.gd")

const MIC_SCENE := "res://assets/meeting_room/mic.glb"
const _MIC_TARGET_H := 0.085
const _MIC_END_INSET := 0.12
const _MIC_Y_EPS := 0.01
const _MIC_YAW_OFFSET :=  PI * 1.5

const _TABLE_COLLISION_LAYER := 1 # Layer 1 (floor/props): NPCs collide with this.
const _NPC_COLLISION_LAYER := 2 # vr_offices/npc/Npc.tscn: collision_layer = 2

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

	_ensure_table_collision(wrapper, model_root)
	_place_mic_on_table(wrapper, model_root)

static func _ensure_table_collision(table_wrap: Node3D, table_model: Node3D) -> void:
	if table_wrap == null or table_model == null:
		return
	var body := table_wrap.get_node_or_null("TableCollision") as StaticBody3D
	if body == null:
		body = StaticBody3D.new()
		body.name = "TableCollision"
		table_wrap.add_child(body)

	body.position = Vector3.ZERO
	body.rotation = Vector3.ZERO
	body.scale = Vector3.ONE
	body.collision_layer = _TABLE_COLLISION_LAYER
	body.collision_mask = _NPC_COLLISION_LAYER

	var shape_node := body.get_node_or_null("Shape") as CollisionShape3D
	if shape_node == null:
		shape_node = CollisionShape3D.new()
		shape_node.name = "Shape"
		body.add_child(shape_node)

	var b := _ModelUtils.bounds_in_space(table_wrap, table_model)
	if b.size == Vector3.ZERO:
		return
	var shape := shape_node.shape as BoxShape3D
	if shape == null:
		shape = BoxShape3D.new()
		shape_node.shape = shape
	shape.size = Vector3(maxf(0.05, float(b.size.x)), maxf(0.05, float(b.size.y)), maxf(0.05, float(b.size.z)))
	shape_node.position = b.position + b.size * 0.5

static func _place_mic_on_table(table_wrap: Node3D, table_model: Node3D) -> void:
	if table_wrap == null or table_model == null:
		return
	var mic_wrap := table_wrap.get_node_or_null("Mic") as Node3D
	if mic_wrap == null:
		mic_wrap = Node3D.new()
		mic_wrap.name = "Mic"
		table_wrap.add_child(mic_wrap)

	mic_wrap.position = Vector3.ZERO
	mic_wrap.rotation = Vector3.ZERO
	mic_wrap.scale = Vector3.ONE
	var mic_model := _Props.spawn_floor_model(mic_wrap, MIC_SCENE, true)
	if mic_model == null:
		return
	mic_wrap.rotation.y = _MIC_YAW_OFFSET

	# Fit mic to a reasonable height relative to the table.
	var target_h := clampf(_MIC_TARGET_H, 0.05, 0.14)
	_ModelUtils.fit_height(mic_wrap, table_wrap, mic_model, target_h)

	var table_bounds := _ModelUtils.bounds_in_space(table_wrap, table_model)
	if table_bounds.size == Vector3.ZERO:
		return
	var mic_bounds := _ModelUtils.bounds_in_space(table_wrap, mic_model)
	if mic_bounds.size == Vector3.ZERO:
		mic_bounds = AABB(Vector3(-0.05, 0.0, -0.05), Vector3(0.1, target_h, 0.1))

	var top_y := float(table_bounds.position.y + table_bounds.size.y)
	var long_is_x := float(table_bounds.size.x) >= float(table_bounds.size.z)
	var inset := _MIC_END_INSET
	if long_is_x:
		var max_x := float(table_bounds.position.x + table_bounds.size.x)
		var half_mic := float(mic_bounds.size.x) * 0.5
		mic_wrap.position = Vector3(max_x - inset - half_mic, top_y + _MIC_Y_EPS, 0.0)
	else:
		var max_z := float(table_bounds.position.z + table_bounds.size.z)
		var half_micz := float(mic_bounds.size.z) * 0.5
		mic_wrap.position = Vector3(0.0, top_y + _MIC_Y_EPS, max_z - inset - half_micz)
