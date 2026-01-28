extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var Script := load("res://demo_rpg/characters/OACharacterSprite.gd")
	if Script == null:
		T.fail_and_quit(self, "Missing OACharacterSprite.gd")
		return

	var tex := load("res://assets/kenney/roguelike-characters/Spritesheet/roguelikeChar_transparent.png")
	if tex == null:
		T.fail_and_quit(self, "Missing roguelikeChar_transparent.png")
		return

	var s: Sprite2D = Script.new()
	s.texture = tex
	s.base_cell = Vector2i(0, 0)
	s.alt_cell = Vector2i(1, 0)
	s.use_alt_for_walk = true
	s.anim_fps = 6.0
	s.init_visual()

	# Initial region is base cell.
	if not T.require_eq(self, int(s.region_rect.position.x), 0, "expected base x=0"):
		return
	if not T.require_eq(self, int(s.region_rect.position.y), 0, "expected base y=0"):
		return

	# Facing left flips horizontally.
	s.set_move_dir(Vector2.LEFT)
	if not T.require_true(self, s.flip_h == true, "expected flip_h when facing left"):
		return

	# Walking advances to alt cell.
	s.set_walking(true)
	s.tick(0.2) # > 1/6 sec
	if not T.require_eq(self, int(s.region_rect.position.x), 17, "expected alt x=17 after tick"):
		return

	# Stop walking returns to base frame.
	s.set_walking(false)
	if not T.require_eq(self, int(s.region_rect.position.x), 0, "expected base x=0 after stop"):
		return

	s.free()
	T.pass_and_quit(self)
