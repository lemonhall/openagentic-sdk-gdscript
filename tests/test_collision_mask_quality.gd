extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var bytes := FileAccess.get_file_as_bytes("res://demo_rpg/collision/sample1_collision_mask.png")
	if bytes.is_empty():
		T.fail_and_quit(self, "Missing sample1_collision_mask.png")
		return
	var img := Image.new()
	var err := img.load_png_from_buffer(bytes)
	if err != OK:
		T.fail_and_quit(self, "Failed to read sample1_collision_mask.png image")
		return

	# Opaque = obstacle, Transparent = walkable.
	if not _expect_alpha(img, Vector2i(614, 25), 0, "road should be walkable (transparent)"):
		return
	if not _expect_alpha(img, Vector2i(0, 0), 0, "grass should be walkable (transparent)"):
		return
	if not _expect_alpha(img, Vector2i(516, 128), 255, "water should be obstacle (opaque)"):
		return
	if not _expect_alpha(img, Vector2i(210, 310), 255, "house should be obstacle (opaque)"):
		return

	T.pass_and_quit(self)

func _expect_alpha(img: Image, pos: Vector2i, expected_a: int, msg: String) -> bool:
	if pos.x < 0 or pos.y < 0 or pos.x >= img.get_width() or pos.y >= img.get_height():
		T.fail_and_quit(self, "point out of bounds: %s" % str(pos))
		return false
	var a := int(img.get_pixelv(pos).a * 255.0 + 0.5)
	if a != expected_a:
		T.fail_and_quit(self, "%s (got alpha=%d at %s)" % [msg, a, str(pos)])
		return false
	return true
