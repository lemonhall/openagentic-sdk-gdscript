extends Node3D

@export var color: Color = Color(1.0, 0.92, 0.45, 0.85)
@export_range(0.1, 5.0, 0.05) var base_radius := 0.9
@export_range(0.05, 2.0, 0.01) var pulse_amount := 0.35
@export_range(0.1, 10.0, 0.1) var pulse_speed := 1.6
@export_range(0.001, 0.2, 0.001) var y_offset := 0.02

@onready var mesh: MeshInstance3D = $Mesh

var _t := 0.0

func _ready() -> void:
	position.y = y_offset
	_apply_visual(0.0)

func _process(delta: float) -> void:
	_t += delta
	_apply_visual(_t)

func _apply_visual(t: float) -> void:
	var k := 0.5 + 0.5 * sin(t * pulse_speed * TAU * 0.5)
	var r := base_radius * (1.0 - pulse_amount * k)
	scale = Vector3(r, 1.0, r)

	if mesh != null and mesh.material_override is ShaderMaterial:
		var mat := mesh.material_override as ShaderMaterial
		mat.set_shader_parameter("u_color", color)
		mat.set_shader_parameter("u_pulse", k)

