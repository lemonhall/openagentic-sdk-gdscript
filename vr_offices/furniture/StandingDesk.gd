extends Node3D

@export var desk_id: String = ""
@export var workspace_id: String = ""
@export var kind: String = "standing_desk"

func configure(desk_id_in: String, workspace_id_in: String) -> void:
	desk_id = desk_id_in
	workspace_id = workspace_id_in

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

