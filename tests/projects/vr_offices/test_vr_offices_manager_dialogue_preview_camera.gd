extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var scene0 := load("res://vr_offices/ui/VrOfficesManagerDialogueOverlay.tscn")
	if scene0 == null or not (scene0 is PackedScene):
		T.fail_and_quit(self, "Missing VrOfficesManagerDialogueOverlay.tscn")
		return

	var overlay := (scene0 as PackedScene).instantiate() as Control
	if overlay == null:
		T.fail_and_quit(self, "Failed to instantiate VrOfficesManagerDialogueOverlay")
		return

	get_root().add_child(overlay)
	await process_frame

	if not T.require_true(self, overlay.has_method("_test_frame_with_capsule_height"), "Expected manager overlay test framing helper"):
		return

	var z_small := float(overlay.call("_test_frame_with_capsule_height", 1.2))
	var z_tall := float(overlay.call("_test_frame_with_capsule_height", 5.5))
	if not T.require_true(self, z_tall > z_small + 0.8, "Expected preview camera to move farther for taller model"):
		return

	overlay.free()
	await process_frame
	T.pass_and_quit(self)
