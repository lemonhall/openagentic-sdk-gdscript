extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var DeskManagerScript := load("res://vr_offices/core/desks/VrOfficesDeskManager.gd")
	if DeskManagerScript == null or not (DeskManagerScript is Script) or not (DeskManagerScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing or invalid res://vr_offices/core/desks/VrOfficesDeskManager.gd")
		return

	var dm = (DeskManagerScript as Script).new()
	if not T.require_true(self, dm != null, "Failed to instantiate VrOfficesDeskManager"):
		return

	if not dm.has_method("add_standing_desk"):
		T.fail_and_quit(self, "VrOfficesDeskManager must implement add_standing_desk")
		return

	var rect := Rect2(Vector2(-5.0, -5.0), Vector2(10.0, 10.0))
	var res0: Variant = dm.call("add_standing_desk", "ws_1", rect, Vector3(0.0, 0.0, 0.0), 0.0)
	if typeof(res0) != TYPE_DICTIONARY:
		T.fail_and_quit(self, "add_standing_desk must return Dictionary")
		return
	var res := res0 as Dictionary
	if not T.require_true(self, bool(res.get("ok", false)), "Expected ok=true from add_standing_desk"):
		return
	var d0: Variant = res.get("desk")
	if typeof(d0) != TYPE_DICTIONARY:
		T.fail_and_quit(self, "Expected desk Dictionary from add_standing_desk")
		return
	var desk := d0 as Dictionary
	var did := String(desk.get("id", "")).strip_edges()
	if not T.require_true(self, did != "", "Expected non-empty desk id"):
		return

	if not dm.has_method("set_desk_device_code"):
		T.fail_and_quit(self, "VrOfficesDeskManager must implement set_desk_device_code(desk_id, code)")
		return
	dm.call("set_desk_device_code", did, "abCD-1234")

	var st := {
		"desk_counter": int(dm.call("get_desk_counter")),
		"desks": dm.call("to_state_array"),
	}

	var dm2 = (DeskManagerScript as Script).new()
	if not T.require_true(self, dm2 != null, "Failed to instantiate VrOfficesDeskManager (2)"):
		return
	if not dm2.has_method("load_from_state_dict"):
		T.fail_and_quit(self, "VrOfficesDeskManager must implement load_from_state_dict(state)")
		return
	dm2.call("load_from_state_dict", st)

	var desks0: Variant = dm2.call("list_desks")
	if not (desks0 is Array):
		T.fail_and_quit(self, "list_desks must return Array")
		return
	var desks := desks0 as Array
	if not T.require_true(self, desks.size() == 1, "Expected 1 desk after load"):
		return
	if typeof(desks[0]) != TYPE_DICTIONARY:
		T.fail_and_quit(self, "Expected desk Dictionary after load")
		return
	var loaded := desks[0] as Dictionary
	var dc := String(loaded.get("device_code", "")).strip_edges()
	if not T.require_eq(self, dc, "ABCD1234", "device_code must persist as canonical form"):
		return

	T.pass_and_quit(self)
