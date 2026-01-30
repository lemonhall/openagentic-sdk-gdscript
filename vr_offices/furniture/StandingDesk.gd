extends Node3D

@export var desk_id: String = ""
@export var workspace_id: String = ""
@export var kind: String = "standing_desk"

func configure(desk_id_in: String, workspace_id_in: String) -> void:
	desk_id = desk_id_in
	workspace_id = workspace_id_in

func set_preview(enabled: bool) -> void:
	if not enabled:
		return
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.95, 0.95, 1.0, 0.25)
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.75, 1.0, 1.0)
	mat.emission_energy_multiplier = 0.35

	for n0: Node in _iter_descendants(self):
		if n0 is MeshInstance3D:
			var mi: MeshInstance3D = n0 as MeshInstance3D
			if mi != null:
				mi.material_override = mat
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func play_spawn_fx() -> void:
	# Simple "gamey" arrival: pop + drop.
	var final_pos := position
	var final_scale := scale

	position = final_pos + Vector3(0.0, 0.6, 0.0)
	scale = final_scale * 0.15

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "position", final_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", final_scale, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _iter_descendants(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back() as Node
		if n == null:
			continue
		for c0 in n.get_children():
			var c: Node = c0 as Node
			if c == null:
				continue
			out.append(c)
			stack.append(c)
	return out
