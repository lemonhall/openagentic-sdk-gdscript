extends StaticBody3D

@export var workspace_id: String = ""
@export var workspace_name: String = ""

@onready var mesh_node: MeshInstance3D = $Mesh
@onready var collider_node: CollisionShape3D = $Collider

func configure(rect_xz: Rect2, color: Color, is_preview: bool) -> void:
	add_to_group("vr_offices_workspace")

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

	# Preview should not be pickable.
	if is_preview:
		collision_layer = 0
	else:
		collision_layer = 4

