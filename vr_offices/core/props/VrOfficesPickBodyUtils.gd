extends RefCounted

static func ensure_box_pick_body(
	wrapper: Node3D,
	group_name: String,
	collision_layer: int,
	box_size: Vector3,
	collider_pos: Vector3
) -> StaticBody3D:
	if wrapper == null:
		return null
	if group_name.strip_edges() != "":
		wrapper.add_to_group(group_name)

	var pick := wrapper.get_node_or_null("PickBody") as StaticBody3D
	if pick == null:
		pick = StaticBody3D.new()
		pick.name = "PickBody"
		wrapper.add_child(pick)
	pick.collision_layer = collision_layer
	pick.collision_mask = 0

	var cs := pick.get_node_or_null("Collider") as CollisionShape3D
	if cs == null:
		cs = CollisionShape3D.new()
		cs.name = "Collider"
		pick.add_child(cs)
	cs.position = collider_pos

	var shape := cs.shape as BoxShape3D
	if shape == null:
		shape = BoxShape3D.new()
		cs.shape = shape
	shape.size = box_size

	return pick

