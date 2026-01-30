extends RefCounted

static func get_camera(owner: Node, camera_rig: Node) -> Camera3D:
	if owner == null:
		return null
	if camera_rig != null and camera_rig.has_method("get_camera"):
		var cam0: Variant = camera_rig.call("get_camera")
		if cam0 is Camera3D:
			return cam0 as Camera3D
	return owner.get_viewport().get_camera_3d()

static func rect_from_world_points(a: Vector3, b: Vector3) -> Rect2:
	var min_x := minf(float(a.x), float(b.x))
	var max_x := maxf(float(a.x), float(b.x))
	var min_z := minf(float(a.z), float(b.z))
	var max_z := maxf(float(a.z), float(b.z))
	return Rect2(Vector2(min_x, min_z), Vector2(max_x - min_x, max_z - min_z))

static func raycast_floor_point(owner: Node, camera_rig: Node, screen_pos: Vector2, collision_mask: int = 1) -> Dictionary:
	var cam := get_camera(owner, camera_rig)
	if cam == null:
		return {"ok": false}
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var to := from + dir * 200.0
	var world: World3D = (owner as Node3D).get_world_3d() if owner is Node3D else null
	if world == null:
		return {"ok": false}
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = collision_mask
	q.collide_with_areas = false
	var hit: Dictionary = world.direct_space_state.intersect_ray(q)
	if hit.is_empty() or not hit.has("position"):
		return {"ok": false}
	return {"ok": true, "pos": hit.get("position")}

static func raycast_workspace(owner: Node, camera_rig: Node, screen_pos: Vector2, collision_mask: int = 4) -> Dictionary:
	var cam := get_camera(owner, camera_rig)
	if cam == null:
		return {"ok": false}
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var to := from + dir * 200.0
	var world: World3D = (owner as Node3D).get_world_3d() if owner is Node3D else null
	if world == null:
		return {"ok": false}
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = collision_mask
	q.collide_with_areas = false
	var hit: Dictionary = world.direct_space_state.intersect_ray(q)
	if hit.is_empty() or not hit.has("collider"):
		return {"ok": false}
	return {"ok": true, "collider": hit.get("collider")}

static func ray_hits_mask(owner: Node, camera_rig: Node, screen_pos: Vector2, mask: int) -> bool:
	var cam := get_camera(owner, camera_rig)
	if cam == null:
		return false
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var to := from + dir * 200.0
	var world: World3D = (owner as Node3D).get_world_3d() if owner is Node3D else null
	if world == null:
		return false
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = mask
	q.collide_with_areas = false
	return not world.direct_space_state.intersect_ray(q).is_empty()

