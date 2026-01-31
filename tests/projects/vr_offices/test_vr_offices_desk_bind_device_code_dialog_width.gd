extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var overlay_script := load("res://vr_offices/ui/DeskOverlay.gd") as Script
	if overlay_script == null:
		T.fail_and_quit(self, "Missing res://vr_offices/ui/DeskOverlay.gd")
		return

	var min_width := 640
	var constants := overlay_script.get_script_constant_map()
	if not T.require_true(self, constants.has("DEVICE_POPUP_SIZE"), "DeskOverlay must define DEVICE_POPUP_SIZE"):
		return
	var popup_size: Vector2i = constants["DEVICE_POPUP_SIZE"]
	if not T.require_true(self, popup_size.x >= min_width, "Expected DEVICE_POPUP_SIZE.x >= %s, got %s" % [str(min_width), str(popup_size.x)]):
		return

	T.pass_and_quit(self)
