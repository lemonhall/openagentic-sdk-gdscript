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
	for i in range(max_per_ws - 1):
		var x := -2.0 + float(i) * 2.0
		var ok_add: Dictionary = mgr.call("add_standing_desk", "ws_1", ws_rect, Vector3(x, 0, -2), 0.0)
		if not T.require_true(self, bool(ok_add.get("ok", false)), "Expected desk placement ok until reaching limit"):
			return
	var too_many: Dictionary = mgr.call("add_standing_desk", "ws_1", ws_rect, Vector3(2, 0, 2), 0.0)
	if not T.require_true(self, bool(too_many.get("ok", false)) == false, "Expected desk placement rejected when exceeding limit"):
		return

	T.pass_and_quit(self)

