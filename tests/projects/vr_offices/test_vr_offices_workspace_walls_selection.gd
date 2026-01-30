extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var AreaScript0 := load("res://vr_offices/workspaces/WorkspaceArea.gd")
	if AreaScript0 == null or not (AreaScript0 is Script):
		T.fail_and_quit(self, "Missing WorkspaceArea.gd")
		return
	var AreaScript := AreaScript0 as Script

	# Quadrant (+x, +z) => show -x and -z
	var m0: int = int(AreaScript.call("pick_wall_mask_for_camera_delta_xz", Vector2(1, 1)))
	if not T.require_eq(self, m0, 0b1010, "Expected (-x,-z) mask for (+x,+z) camera"):
		return

	# Quadrant (-x, +z) => show +x and -z
	var m1: int = int(AreaScript.call("pick_wall_mask_for_camera_delta_xz", Vector2(-1, 1)))
	if not T.require_eq(self, m1, 0b1001, "Expected (+x,-z) mask for (-x,+z) camera"):
		return

	# Quadrant (+x, -z) => show -x and +z
	var m2: int = int(AreaScript.call("pick_wall_mask_for_camera_delta_xz", Vector2(1, -1)))
	if not T.require_eq(self, m2, 0b0110, "Expected (-x,+z) mask for (+x,-z) camera"):
		return

	# Quadrant (-x, -z) => show +x and +z
	var m3: int = int(AreaScript.call("pick_wall_mask_for_camera_delta_xz", Vector2(-1, -1)))
	if not T.require_eq(self, m3, 0b0101, "Expected (+x,+z) mask for (-x,-z) camera"):
		return

	T.pass_and_quit(self)
