extends Node3D

@export_range(0.01, 2.0, 0.01) var base_scale := 0.55
@export_range(0.0, 2.0, 0.01) var y_offset := 0.24
@export_range(0.0, 1.0, 0.01) var bob_amount := 0.08
@export_range(0.1, 10.0, 0.1) var bob_speed := 1.8
@export_range(0.0, 10.0, 0.1) var spin_speed := 1.2

var _target: Node3D = null
var _anchor_local := Vector3.ZERO
var _t := 0.0

func bind_to(target: Node3D, anchor_local: Vector3) -> void:
	_target = target
	_anchor_local = anchor_local
	top_level = true
	scale = Vector3.ONE * base_scale

func _ready() -> void:
	if _target == null:
		var p := get_parent() as Node3D
		if p != null:
			bind_to(p, Vector3.ZERO)

func _process(delta: float) -> void:
	_t += delta
	if _target == null or not is_instance_valid(_target):
		return
	var base := _target.to_global(_anchor_local)
	var k := sin(_t * bob_speed * TAU * 0.5)
	global_position = base + Vector3(0.0, y_offset + bob_amount * k, 0.0)
	rotation.y += spin_speed * delta
