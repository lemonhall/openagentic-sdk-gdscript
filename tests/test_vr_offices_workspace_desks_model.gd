extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var DeskScript := load("res://vr_offices/core/VrOfficesDeskManager.gd")
	if DeskScript == null:
		T.fail_and_quit(self, "Missing res://vr_offices/core/VrOfficesDeskManager.gd")
		return

	var mgr := (DeskScript as Script).new() as RefCounted
	if mgr == null:
		T.fail_and_quit(self, "Failed to instantiate VrOfficesDeskManager")
		return

	var ws_rect_small := Rect2(Vector2(0, 0), Vector2(0.6, 0.6))
	var r0: Dictionary = mgr.call("can_place_standing_desk", "ws_1", ws_rect_small, Vector2(0.3, 0.3), 0.0)
	if not T.require_true(self, bool(r0.get("ok", false)) == false, "Expected desk placement to fail in a tiny workspace"):
		return

	var ws_rect := Rect2(Vector2(-3, -3), Vector2(6, 6))
	var add1: Dictionary = mgr.call("add_standing_desk", "ws_1", ws_rect, Vector3(0, 0, 0), 0.0)
	if not T.require_true(self, bool(add1.get("ok", false)), "Expected first desk placement ok"):
		return

	# Overlap should be rejected.
	var add2: Dictionary = mgr.call("add_standing_desk", "ws_1", ws_rect, Vector3(0.2, 0, 0.2), 0.0)
	if not T.require_true(self, bool(add2.get("ok", false)) == false, "Expected overlapping desk placement rejected"):
		return

	# Too many desks should be rejected.
	var max_per_ws := int(mgr.call("get_max_desks_per_workspace"))
	var size0: Vector2 = mgr.call("get_standing_desk_footprint_size_xz", 0.0)
	var start_x := float(ws_rect.position.x + size0.x * 0.5)
	var end_x := float(ws_rect.position.x + ws_rect.size.x - size0.x * 0.5)
	var start_z := float(ws_rect.position.y + size0.y * 0.5)
	var end_z := float(ws_rect.position.y + ws_rect.size.y - size0.y * 0.5)
	var step_x := float(size0.x + 0.25)
	var step_z := float(size0.y + 0.25)

	var target_count := max_per_ws
	var added := 1
	for zi in range(50):
		var cz := start_z + float(zi) * step_z
		if cz > end_z:
			break
		for xi in range(50):
			var cx := start_x + float(xi) * step_x
			if cx > end_x:
				break
			if absf(cx) < 0.2 and absf(cz) < 0.2:
				continue
			var ok_add: Dictionary = mgr.call("add_standing_desk", "ws_1", ws_rect, Vector3(cx, 0, cz), 0.0)
			if bool(ok_add.get("ok", false)):
				added += 1
				if added >= target_count:
					break
		if added >= target_count:
			break
	if not T.require_eq(self, added, target_count, "Expected to place desks up to the per-workspace limit"):
		return

	var too_many: Dictionary = mgr.call("add_standing_desk", "ws_1", ws_rect, Vector3(0, 0, 0), 0.0)
	if not T.require_true(self, bool(too_many.get("ok", false)) == false, "Expected desk placement rejected when exceeding limit"):
		return

	T.pass_and_quit(self)
