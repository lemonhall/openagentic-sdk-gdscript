extends RefCounted

static func try_pick_npc(owner: Node, camera_rig: Node, screen_pos: Vector2) -> Node:
	var hit := _raycast(owner, camera_rig, screen_pos, 2)
	if hit.is_empty():
		return null
	return _find_owner_in_group(hit.get("collider") as Object, "vr_offices_npc")

static func try_pick_desk(owner: Node, camera_rig: Node, screen_pos: Vector2) -> Node:
	var hit := _raycast(owner, camera_rig, screen_pos, 8)
	if hit.is_empty():
		return null
	return _find_owner_in_group(hit.get("collider") as Object, "vr_offices_desk")

static func try_pick_vending_machine(owner: Node, camera_rig: Node, screen_pos: Vector2) -> Node:
	var hit := _raycast(owner, camera_rig, screen_pos, 16)
	if hit.is_empty():
		return null
	return _find_owner_in_group(hit.get("collider") as Object, "vr_offices_vending_machine")

static func try_pick_manager_desk(owner: Node, camera_rig: Node, screen_pos: Vector2) -> Node:
	var hit := _raycast(owner, camera_rig, screen_pos, 32)
	if hit.is_empty():
		return null
	return _find_owner_in_group(hit.get("collider") as Object, "vr_offices_manager_desk")

static func try_pick_double_click_prop(owner: Node, camera_rig: Node, screen_pos: Vector2) -> Dictionary:
	var hit_vending := _raycast(owner, camera_rig, screen_pos, 16)
	if not hit_vending.is_empty():
		var vending := _find_owner_in_group(hit_vending.get("collider") as Object, "vr_offices_vending_machine")
		if vending != null:
			return {"type": "vending", "node": vending}

	var hit_manager := _raycast(owner, camera_rig, screen_pos, 32)
	if not hit_manager.is_empty():
		var manager_desk := _find_owner_in_group(hit_manager.get("collider") as Object, "vr_offices_manager_desk")
		if manager_desk != null:
			return {"type": "manager_desk", "node": manager_desk}
	return {}

static func _raycast(owner: Node, camera_rig: Node, screen_pos: Vector2, collision_mask: int) -> Dictionary:
	if owner == null:
		return {}

	var cam: Camera3D = null
	if camera_rig != null and camera_rig.has_method("get_camera"):
		cam = camera_rig.call("get_camera") as Camera3D
	else:
		cam = owner.get_viewport().get_camera_3d()
	if cam == null:
		return {}

	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * 200.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = collision_mask

	var world: World3D = (owner as Node3D).get_world_3d() if owner is Node3D else null
	if world == null:
		return {}
	return world.direct_space_state.intersect_ray(query)

static func _find_owner_in_group(node: Object, group_name: String) -> Node:
	var cur := node
	while cur != null and cur is Node:
		var n := cur as Node
		if n.is_in_group(group_name):
			return n
		cur = n.get_parent()
	return null
