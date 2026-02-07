extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var Script0 := load("res://vr_offices/core/meeting_rooms/VrOfficesMeetingRoomManager.gd")
	if Script0 == null:
		T.fail_and_quit(self, "Missing res://vr_offices/core/meeting_rooms/VrOfficesMeetingRoomManager.gd")
		return

	var bounds := Rect2(Vector2(-10, -10), Vector2(20, 20))
	var mgr := (Script0 as Script).new(bounds) as RefCounted
	if mgr == null:
		T.fail_and_quit(self, "Failed to instantiate VrOfficesMeetingRoomManager")
		return

	var r0 := Rect2(Vector2(9, 9), Vector2(5, 5))
	var clamped: Rect2 = mgr.call("clamp_rect_to_floor", r0)
	if not T.require_true(self, clamped.position.x >= -10 and clamped.position.y >= -10, "clamped rect within min bounds"):
		return
	if not T.require_true(self, clamped.position.x + clamped.size.x <= 10.0 + 1e-4, "clamped rect within max X"):
		return
	if not T.require_true(self, clamped.position.y + clamped.size.y <= 10.0 + 1e-4, "clamped rect within max Z"):
		return

	var a: Dictionary = mgr.call("create_meeting_room", Rect2(Vector2(-5, -5), Vector2(4, 4)), "A")
	if not T.require_true(self, bool(a.get("ok", false)), "first meeting room should be created"):
		return

	var b: Dictionary = mgr.call("create_meeting_room", Rect2(Vector2(-4, -4), Vector2(4, 4)), "B")
	if not T.require_true(self, bool(b.get("ok", false)) == false, "overlapping meeting room should be rejected"):
		return

	var c: Dictionary = mgr.call("create_meeting_room", Rect2(Vector2(-1, -5), Vector2(4, 4)), "C")
	if not T.require_true(self, bool(c.get("ok", false)), "border-touch meeting room should be allowed"):
		return

	T.pass_and_quit(self)

