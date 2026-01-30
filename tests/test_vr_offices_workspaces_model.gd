extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var Script0 := load("res://vr_offices/core/workspaces/VrOfficesWorkspaceManager.gd")
	if Script0 == null:
		T.fail_and_quit(self, "Missing res://vr_offices/core/workspaces/VrOfficesWorkspaceManager.gd")
		return

	var bounds := Rect2(Vector2(-10, -10), Vector2(20, 20))
	var mgr := (Script0 as Script).new(bounds) as RefCounted
	if mgr == null:
		T.fail_and_quit(self, "Failed to instantiate VrOfficesWorkspaceManager")
		return

	# Clamp must keep rect within floor.
	var r0 := Rect2(Vector2(9, 9), Vector2(5, 5))
	var clamped: Rect2 = mgr.call("clamp_rect_to_floor", r0)
	if not T.require_true(self, clamped.position.x >= -10 and clamped.position.y >= -10, "clamped rect should be within min bounds"):
		return
	if not T.require_true(self, clamped.position.x + clamped.size.x <= 10.0 + 1e-4, "clamped rect should be within max X"):
		return
	if not T.require_true(self, clamped.position.y + clamped.size.y <= 10.0 + 1e-4, "clamped rect should be within max Z"):
		return

	# Create a first workspace.
	var a: Dictionary = mgr.call("create_workspace", Rect2(Vector2(-5, -5), Vector2(4, 4)), "A")
	if not T.require_true(self, bool(a.get("ok", false)), "first workspace should be created"):
		return

	# Overlap should be rejected.
	var b: Dictionary = mgr.call("create_workspace", Rect2(Vector2(-4, -4), Vector2(4, 4)), "B")
	if not T.require_true(self, bool(b.get("ok", false)) == false, "overlapping workspace should be rejected"):
		return

	# Border-touch should be allowed.
	var c: Dictionary = mgr.call("create_workspace", Rect2(Vector2(-1, -5), Vector2(4, 4)), "C")
	if not T.require_true(self, bool(c.get("ok", false)), "border-touch workspace should be allowed"):
		return

	# Color index should cycle and be stable per created workspace.
	var ws_a: Dictionary = a.get("workspace", {})
	var ws_c: Dictionary = c.get("workspace", {})
	if not T.require_true(self, ws_a.has("color_index") and ws_c.has("color_index"), "workspace should include color_index"):
		return
	if not T.require_true(self, int(ws_c.get("color_index")) == (int(ws_a.get("color_index")) + 1), "color_index should increment with creations"):
		return

	T.pass_and_quit(self)
