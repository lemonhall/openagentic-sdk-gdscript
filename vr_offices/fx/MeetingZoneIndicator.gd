extends Node3D

const _SHADER := preload("res://vr_offices/fx/meeting_zone_indicator.gdshader")

@onready var _mesh: MeshInstance3D = $Mesh

var _mat: ShaderMaterial = null

func _ready() -> void:
	if _mesh == null:
		return
	if not (_mesh.mesh is PlaneMesh):
		_mesh.mesh = PlaneMesh.new()
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = _SHADER
	_mesh.material_override = _mat

func configure(half_extents_m: Vector2, radius_m: float) -> void:
	if _mesh == null:
		return
	_ready()

	var hx := maxf(0.05, float(half_extents_m.x))
	var hz := maxf(0.05, float(half_extents_m.y))
	var r := clampf(radius_m, 0.5, 6.0)

	var pad := 0.55
	var sx := (hx + r + pad) * 2.0
	var sz := (hz + r + pad) * 2.0
	var plane := _mesh.mesh as PlaneMesh
	plane.size = Vector2(sx, sz)

	if _mat != null:
		_mat.set_shader_parameter("half_extents", Vector2(hx, hz))
		_mat.set_shader_parameter("radius", r)

