extends RefCounted
const _Props := preload("res://vr_offices/core/props/VrOfficesPropUtils.gd")
const _PickBodies := preload("res://vr_offices/core/props/VrOfficesPickBodyUtils.gd")
const ANALOG_CLOCK_SCENE := "res://assets/office_pack_glb/Analog clock.glb"
const DARTBOARD_SCENE := "res://assets/office_pack_glb/Dartboard.glb"
const FIRE_EXIT_SIGN_SCENE := "res://assets/office_pack_glb/Fire Exit Sign-0ywPpb36cyK.glb"
const FILE_CABINET_SCENE := "res://assets/office_pack_glb/File Cabinet.glb"
const HOUSEPLANT_SCENE := "res://assets/office_pack_glb/Houseplant-bfLOqIV5uP.glb"
const TRASHCAN_SMALL_SCENE := "res://assets/office_pack_glb/Trashcan Small.glb"
const VENDING_MACHINE_SCENE := "res://assets/office_pack_glb/Vending Machine.glb"
const WALL_ART_03_SCENE := "res://assets/office_pack_glb/Wall Art 03.glb"
const WATER_COOLER_SCENE := "res://assets/office_pack_glb/Water Cooler.glb"
const WHITEBOARD_SCENE := "res://assets/office_pack_glb/Whiteboard.glb"
const _WALL_EPS := 0.02
const _VENDING_WALL_INSET := 0.55
const _VENDING_ALONG_MARGIN := 0.9
static func decorate_workspace(workspace_node: Node3D, workspace_id: String, rect_xz: Rect2) -> void:
	if workspace_node == null:
		return
	var decor := workspace_node.get_node_or_null("Decor") as Node3D
	if decor == null:
		decor = Node3D.new()
		decor.name = "Decor"
		workspace_node.add_child(decor)
	var sx := maxf(0.001, float(rect_xz.size.x))
	var sz := maxf(0.001, float(rect_xz.size.y))
	var hx := sx * 0.5
	var hz := sz * 0.5
	var decor_seed := _fnv1a32(workspace_id.strip_edges())
	var corner := int(decor_seed % 4)
	# Floor props (organization: keep under Decor).
	var cabinet := _ensure_prop_wrapper(decor, "FileCabinet")
	_place_on_floor(cabinet, Vector3(-hx + 0.75, 0.0, 0.0), decor_seed)
	_Props.spawn_floor_model(cabinet, FILE_CABINET_SCENE)
	var plant := _ensure_prop_wrapper(decor, "Houseplant")
	var plant_corner := corner ^ 3
	_place_on_floor(plant, _corner_pos(hx, hz, plant_corner, 0.75), decor_seed ^ 0x1234)
	_Props.spawn_floor_model(plant, HOUSEPLANT_SCENE)
	var cooler := _ensure_prop_wrapper(decor, "WaterCooler")
	_place_on_floor(cooler, _corner_pos(hx, hz, corner, 0.85), decor_seed ^ 0xBEEF)
	_Props.spawn_floor_model(cooler, WATER_COOLER_SCENE)
	var vending := _ensure_prop_wrapper(decor, "VendingMachine")
	var along_limit := maxf(0.0, hz - _VENDING_ALONG_MARGIN)
	var along := 0.0
	if along_limit > 0.001:
		along = (_rand01(decor_seed ^ 0xC0FFEE) * 2.0 - 1.0) * minf(0.75, along_limit)
	var wall_x := maxf(0.0, hx - _VENDING_WALL_INSET)
	_place_on_floor(vending, Vector3(wall_x, 0.0, along), decor_seed ^ 0xC0FFEE)
	_Props.spawn_floor_model(vending, VENDING_MACHINE_SCENE)
	_PickBodies.ensure_box_pick_body(vending, "vr_offices_vending_machine", 16, Vector3(1.0, 1.85, 1.1), Vector3(0.0, 0.925, 0.0))
	var trash := _ensure_prop_wrapper(decor, "TrashcanSmall")
	_place_on_floor(trash, _trashcan_pos(hx, hz, decor_seed), decor_seed ^ 0xD00D)
	_Props.spawn_floor_model(trash, TRASHCAN_SMALL_SCENE)
	# Wall props (may be attached to wall mesh nodes for visibility).
	var walls := workspace_node.get_node_or_null("Walls") as Node3D
	if walls == null:
		return
	var wall_pos_x := walls.get_node_or_null("WallPosX") as MeshInstance3D
	var wall_neg_x := walls.get_node_or_null("WallNegX") as MeshInstance3D
	var wall_pos_z := walls.get_node_or_null("WallPosZ") as MeshInstance3D
	var wall_neg_z := walls.get_node_or_null("WallNegZ") as MeshInstance3D
	if wall_pos_x == null or wall_neg_x == null or wall_pos_z == null or wall_neg_z == null:
		return
	_place_wall_prop(wall_neg_z, "AnalogClock", ANALOG_CLOCK_SCENE, Vector3(0.0, 1.62, 0.0), PI, 0.0)
	_place_wall_prop(wall_pos_x, "Dartboard", DARTBOARD_SCENE, Vector3(0.0, 1.52, 0.0), PI * 0.5, -0.85)
	_place_wall_prop(wall_neg_x, "Whiteboard", WHITEBOARD_SCENE, Vector3(0.0, 1.38, 0.0), -PI * 0.5, -0.35)
	_place_wall_prop(wall_neg_x, "WallArt03", WALL_ART_03_SCENE, Vector3(0.0, 1.55, 0.0), -PI * 0.5, 0.85)
	_place_wall_prop(wall_neg_z, "FireExitSign", FIRE_EXIT_SIGN_SCENE, Vector3(0.0, 0.38, 0.0), PI, -0.75)

static func _ensure_prop_wrapper(parent: Node, name: String) -> Node3D:
	if parent == null:
		return null
	var existing := parent.get_node_or_null(name) as Node3D
	if existing != null:
		return existing
	var n := Node3D.new()
	n.name = name
	parent.add_child(n)
	return n

static func _place_on_floor(n: Node3D, pos: Vector3, rng_seed: int) -> void:
	if n == null:
		return
	n.position = pos
	n.rotation = Vector3.ZERO
	var xz := Vector2(float(pos.x), float(pos.z))
	if xz.length() >= 0.01:
		# Face the workspace center.
		n.rotation = Vector3(0.0, atan2(xz.x, xz.y), 0.0)
	# Add a tiny deterministic yaw variance to avoid looking perfectly repeated.
	var jitter := _rand01(rng_seed) * 0.18 - 0.09
	n.rotation.y += jitter

static func _corner_pos(hx: float, hz: float, corner: int, margin: float) -> Vector3:
	var x_sign := 1.0
	var z_sign := 1.0
	if corner == 1:
		z_sign = -1.0
	elif corner == 2:
		x_sign = -1.0
	elif corner == 3:
		x_sign = -1.0
		z_sign = -1.0
	var x := maxf(0.0, hx - margin) * x_sign
	var z := maxf(0.0, hz - margin) * z_sign
	return Vector3(x, 0.0, z)

static func _trashcan_pos(hx: float, hz: float, rng_seed: int) -> Vector3:
	# Place near the likely desk area (near center), but biased toward one side.
	var side := -1.0 if ((rng_seed >> 5) & 1) == 0 else 1.0
	var max_x := maxf(0.0, hx - 0.9)
	var max_z := maxf(0.0, hz - 0.9)
	var x := clampf(0.75 * side, -max_x, max_x)
	var z := clampf(0.35, -max_z, max_z)
	return Vector3(x, 0.0, z)

static func _place_wall_prop(
	wall: MeshInstance3D,
	name: String,
	scene_path: String,
	center_world_hint: Vector3,
	yaw: float,
	along_offset: float
) -> void:
	if wall == null:
		return
	var wrapper := _ensure_prop_wrapper(wall, name)
	if wrapper == null:
		return

	var thickness := _wall_thickness(wall)
	var height := _wall_height(wall)
	var half_len := _wall_half_length(wall)
	var along := _clamp_along(along_offset, half_len, 0.55)

	# Position in wall-local space (wall origin is at its center, at y = height/2 in workspace space).
	var local_y := float(center_world_hint.y) - height * 0.5
	wrapper.position = Vector3(0.0, local_y, 0.0)
	wrapper.rotation = Vector3(0.0, yaw, 0.0)

	var n := wall.name
	if n == "WallPosX":
		wrapper.position.x = -(thickness * 0.5 + _WALL_EPS)
		wrapper.position.z = along
	elif n == "WallNegX":
		wrapper.position.x = thickness * 0.5 + _WALL_EPS
		wrapper.position.z = along
	elif n == "WallPosZ":
		wrapper.position.z = -(thickness * 0.5 + _WALL_EPS)
		wrapper.position.x = along
	elif n == "WallNegZ":
		wrapper.position.z = thickness * 0.5 + _WALL_EPS
		wrapper.position.x = along

	_Props.spawn_wall_model(wrapper, scene_path)

static func _clamp_along(v: float, half_len: float, margin: float) -> float:
	var h := maxf(0.0, half_len - margin)
	if h <= 0.001:
		return 0.0
	return clampf(v, -h, h)

static func _wall_thickness(wall: MeshInstance3D) -> float:
	if wall == null:
		return 0.06
	var bm := wall.mesh as BoxMesh
	if bm == null:
		return 0.06
	return maxf(0.001, minf(float(bm.size.x), float(bm.size.z)))

static func _wall_height(wall: MeshInstance3D) -> float:
	if wall == null:
		return 2.2
	var bm := wall.mesh as BoxMesh
	if bm == null:
		return 2.2
	return maxf(0.001, float(bm.size.y))

static func _wall_half_length(wall: MeshInstance3D) -> float:
	if wall == null:
		return 1.0
	var bm := wall.mesh as BoxMesh
	if bm == null:
		return 1.0
	var wall_len := maxf(float(bm.size.x), float(bm.size.z))
	return wall_len * 0.5

static func _fnv1a32(s: String) -> int:
	var h: int = 0x811C9DC5
	var n := s.length()
	for i in range(n):
		h = h ^ s.unicode_at(i)
		h = int((h * 0x01000193) & 0xFFFFFFFF)
	return h

static func _rand01(rng_seed: int) -> float:
	var v := int(((rng_seed >> 8) ^ rng_seed) & 0xFFFF)
	return float(v) / 65535.0
