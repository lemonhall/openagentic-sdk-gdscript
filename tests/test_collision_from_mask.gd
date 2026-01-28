extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var Script := load("res://demo_rpg/collision/OACollisionFromMask.gd")
	if Script == null:
		T.fail_and_quit(self, "Missing OACollisionFromMask.gd")
		return

	var node: Node2D = Script.new()
	node.mask_path = "res://demo_rpg/collision/sample1_collision_mask.png"
	var polys: Array = node.polygons_from_mask()

	if not T.require_true(self, polys.size() > 0, "expected >= 1 polygon from mask"):
		return
	if not T.require_true(self, polys[0] is PackedVector2Array, "expected polygons to be PackedVector2Array"):
		return

	# A polygon should have at least 3 points.
	if not T.require_true(self, (polys[0] as PackedVector2Array).size() >= 3, "expected polygon >= 3 points"):
		return

	node.free()
	T.pass_and_quit(self)

