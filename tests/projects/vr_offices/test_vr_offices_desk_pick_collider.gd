extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var scene := load("res://vr_offices/furniture/StandingDesk.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing res://vr_offices/furniture/StandingDesk.tscn")
		return

	var desk := (scene as PackedScene).instantiate() as Node
	if desk == null:
		T.fail_and_quit(self, "Failed to instantiate StandingDesk.tscn")
		return
	get_root().add_child(desk)
	await process_frame

	var pick := desk.get_node_or_null("PickBody") as StaticBody3D
	if not T.require_true(self, pick != null, "StandingDesk must have PickBody StaticBody3D"):
		return
	if not T.require_eq(self, int(pick.collision_layer), 8, "PickBody collision_layer must be 8"):
		return
	if not T.require_eq(self, int(pick.collision_mask), 0, "PickBody collision_mask must be 0"):
		return
	if not T.require_true(self, pick.get_node_or_null("Collider") != null, "PickBody must have Collider"):
		return

	get_root().remove_child(desk)
	desk.free()
	await process_frame
	T.pass_and_quit(self)

