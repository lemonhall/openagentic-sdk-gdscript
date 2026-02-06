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

	if not T.require_true(self, overlay.has_method("_test_autoplay_idle_prefers_idle"), "Expected manager overlay idle autoplay test helper"):
		return

	var ok := bool(overlay.call("_test_autoplay_idle_prefers_idle"))
	if not T.require_true(self, ok, "Expected manager preview to autoplay looping idle animation"):
		return

	overlay.free()
	await process_frame
	T.pass_and_quit(self)
