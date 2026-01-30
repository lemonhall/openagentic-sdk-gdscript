extends StaticBody3D

@export var workspace_id: String = ""
@export var workspace_name: String = ""

const WALL_HEIGHT := 2.2
const WALL_THICKNESS := 0.06
const WALL_ALPHA := 0.92
const WALL_FADE_SEC := 0.12

# Wall visibility bitmask (2 walls visible at a time).
const MASK_POS_X := 1 << 0
const MASK_NEG_X := 1 << 1
const MASK_POS_Z := 1 << 2
const MASK_NEG_Z := 1 << 3

@onready var mesh_node: MeshInstance3D = $Mesh
@onready var collider_node: CollisionShape3D = $Collider
@onready var walls_root: Node3D = $Walls
@onready var wall_pos_x: MeshInstance3D = $Walls/WallPosX
@onready var wall_neg_x: MeshInstance3D = $Walls/WallNegX
@onready var wall_pos_z: MeshInstance3D = $Walls/WallPosZ
@onready var wall_neg_z: MeshInstance3D = $Walls/WallNegZ

var _is_preview := false
var _rect_xz := Rect2()
var _walls_mask := 0
var _walls_tween: Tween = null
var _spawned_once := false

func configure(rect_xz: Rect2, color: Color, is_preview: bool) -> void:
	add_to_group("vr_offices_workspace")
	_is_preview = is_preview
	_rect_xz = rect_xz

	# Position the body at the rect center (XZ). Keep it slightly above the floor for visuals.
	var cx := float(rect_xz.position.x + rect_xz.size.x * 0.5)
	var cz := float(rect_xz.position.y + rect_xz.size.y * 0.5)
	position = Vector3(cx, 0.0, cz)

	var sx := maxf(0.001, float(rect_xz.size.x))
	var sz := maxf(0.001, float(rect_xz.size.y))

	if mesh_node != null:
		var pm := PlaneMesh.new()
		pm.size = Vector2(sx, sz)
		mesh_node.mesh = pm

		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = color
		if is_preview:
			mat.emission_enabled = true
			mat.emission = Color(0.25, 0.75, 1.0, 1.0)
			mat.emission_energy_multiplier = 1.2
		mesh_node.material_override = mat

	if collider_node != null:
		var shape := BoxShape3D.new()
		shape.size = Vector3(sx, 0.1, sz)
		collider_node.shape = shape

	_configure_walls(sx, sz, color, is_preview)

	# Preview should not be pickable.
	if is_preview:
		collision_layer = 0
	else:
		collision_layer = 4

func _process(_delta: float) -> void:
	if _is_preview:
		return
	if not is_inside_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var delta_xz := Vector2(cam.global_position.x - global_position.x, cam.global_position.z - global_position.z)
	var next := pick_wall_mask_for_camera_delta_xz(delta_xz)
	_set_walls_mask(next)

func _configure_walls(sx: float, sz: float, floor_color: Color, is_preview: bool) -> void:
	if walls_root == null:
		return
	walls_root.visible = not is_preview
	if is_preview:
		return

	# Neutral wall color derived from the workspace tint.
	var wall_color := floor_color
	wall_color.a = WALL_ALPHA
	wall_color.r = clampf(wall_color.r * 0.55 + 0.25, 0.0, 1.0)
	wall_color.g = clampf(wall_color.g * 0.55 + 0.25, 0.0, 1.0)
	wall_color.b = clampf(wall_color.b * 0.55 + 0.25, 0.0, 1.0)

	_setup_wall(wall_pos_x, Vector3(WALL_THICKNESS, WALL_HEIGHT, sz), Vector3(sx * 0.5, WALL_HEIGHT * 0.5, 0.0), wall_color)
	_setup_wall(wall_neg_x, Vector3(WALL_THICKNESS, WALL_HEIGHT, sz), Vector3(-sx * 0.5, WALL_HEIGHT * 0.5, 0.0), wall_color)
	_setup_wall(wall_pos_z, Vector3(sx, WALL_HEIGHT, WALL_THICKNESS), Vector3(0.0, WALL_HEIGHT * 0.5, sz * 0.5), wall_color)
	_setup_wall(wall_neg_z, Vector3(sx, WALL_HEIGHT, WALL_THICKNESS), Vector3(0.0, WALL_HEIGHT * 0.5, -sz * 0.5), wall_color)

	# Start with a deterministic default (camera may not be available on the first frame).
	_set_walls_mask(MASK_NEG_X | MASK_NEG_Z, true)

func _setup_wall(mi: MeshInstance3D, size: Vector3, pos: Vector3, color: Color) -> void:
	if mi == null:
		return
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.roughness = 0.95
	mat.metallic = 0.0
	mi.material_override = mat
	mi.visible = true

func _set_walls_mask(mask: int, immediate: bool = false) -> void:
	if walls_root == null or _is_preview:
		return
	if mask == _walls_mask and not immediate:
		return
	_walls_mask = mask

	if immediate:
		_apply_wall_visibility_immediate()
		return
	_apply_wall_visibility_fade()

func _apply_wall_visibility_immediate() -> void:
	_set_wall_target(wall_pos_x, (_walls_mask & MASK_POS_X) != 0)
	_set_wall_target(wall_neg_x, (_walls_mask & MASK_NEG_X) != 0)
	_set_wall_target(wall_pos_z, (_walls_mask & MASK_POS_Z) != 0)
	_set_wall_target(wall_neg_z, (_walls_mask & MASK_NEG_Z) != 0)

func _apply_wall_visibility_fade() -> void:
	if _walls_tween != null and is_instance_valid(_walls_tween):
		_walls_tween.kill()
	_walls_tween = create_tween()
	_walls_tween.set_parallel(true)
	_fade_wall_to(wall_pos_x, (_walls_mask & MASK_POS_X) != 0)
	_fade_wall_to(wall_neg_x, (_walls_mask & MASK_NEG_X) != 0)
	_fade_wall_to(wall_pos_z, (_walls_mask & MASK_POS_Z) != 0)
	_fade_wall_to(wall_neg_z, (_walls_mask & MASK_NEG_Z) != 0)

func _fade_wall_to(mi: MeshInstance3D, want_visible: bool) -> void:
	if mi == null:
		return
	var mat := mi.material_override as StandardMaterial3D
	if mat == null:
		mi.visible = want_visible
		return
	mi.visible = true

	var a0 := float(mat.albedo_color.a)
	var a1 := WALL_ALPHA if want_visible else 0.0
	_walls_tween.tween_method(func(v: float) -> void:
		var c := mat.albedo_color
		c.a = v
		mat.albedo_color = c
	, a0, a1, WALL_FADE_SEC)
	_walls_tween.tween_callback(func() -> void:
		if mi == null or not is_instance_valid(mi):
			return
		mi.visible = want_visible
	)

func _set_wall_target(mi: MeshInstance3D, want_visible: bool) -> void:
	if mi == null:
		return
	var mat := mi.material_override as StandardMaterial3D
	if mat != null:
		var c := mat.albedo_color
		c.a = WALL_ALPHA if want_visible else 0.0
		mat.albedo_color = c
	mi.visible = want_visible

func play_spawn_fx() -> void:
	if _spawned_once:
		return
	_spawned_once = true
	if _is_preview:
		return
	if not is_inside_tree():
		return

	# "Duang" build: walls grow up with a little overshoot; floor pops slightly.
	if walls_root != null:
		var final_scale := walls_root.scale
		walls_root.scale = Vector3(final_scale.x, 0.05, final_scale.z)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(walls_root, "scale", final_scale, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if mesh_node != null:
		var final_s := mesh_node.scale
		mesh_node.scale = final_s * 0.6
		var t2 := create_tween()
		t2.tween_property(mesh_node, "scale", final_s, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

static func pick_wall_mask_for_camera_delta_xz(delta_xz: Vector2) -> int:
	# Always show the two "far" walls (hide the wall on the camera side for each axis).
	# Bitmask uses: +X, -X, +Z, -Z.
	var mask := 0
	if float(delta_xz.x) >= 0.0:
		mask |= MASK_NEG_X
	else:
		mask |= MASK_POS_X
	if float(delta_xz.y) >= 0.0:
		mask |= MASK_NEG_Z
	else:
		mask |= MASK_POS_Z
	return mask
