extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var PopupScript := load("res://vr_offices/ui/VrOfficesTeachSkillPopup.gd")
	if PopupScript == null:
		T.fail_and_quit(self, "Missing VrOfficesTeachSkillPopup.gd")
		return

	var root := Node3D.new()
	var ap := AnimationPlayer.new()
	root.add_child(ap)

	# Minimal animation clip (no tracks required for is_playing()).
	var anim := Animation.new()
	anim.length = 1.0
	anim.loop_mode = Animation.LOOP_LINEAR
	var lib := AnimationLibrary.new()
	lib.add_animation("idle", anim)
	ap.add_animation_library(&"default", lib)

	# Expect helper to start playing "idle" (or any clip) and keep it looping.
	if not (PopupScript as Script).has_method("autoplay_idle_animation_for_preview"):
		T.fail_and_quit(self, "Missing autoplay_idle_animation_for_preview()")
		return
	var ok: bool = bool(PopupScript.call("autoplay_idle_animation_for_preview", root))
	if not T.require_true(self, ok, "Expected helper returns true"):
		return
	if not T.require_true(self, ap.is_playing(), "Expected AnimationPlayer.is_playing() == true"):
		return

	# Avoid ObjectDB leak warnings in headless tests.
	root.free()

	T.pass_and_quit(self)
