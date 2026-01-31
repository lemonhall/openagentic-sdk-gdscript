extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var LinkScript := load("res://vr_offices/core/desks/VrOfficesDeskIrcLink.gd")
	if LinkScript == null or not (LinkScript is Script) or not (LinkScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing or invalid res://vr_offices/core/desks/VrOfficesDeskIrcLink.gd")
		return

	var link := (LinkScript as Script).new() as Node
	if not T.require_true(self, link != null, "Failed to instantiate VrOfficesDeskIrcLink"):
		return
	get_root().add_child(link)
	await process_frame

	if not link.has_method("configure"):
		T.fail_and_quit(self, "VrOfficesDeskIrcLink must implement configure(...)")
		return
	if not link.has_method("get_desired_channel"):
		T.fail_and_quit(self, "VrOfficesDeskIrcLink must implement get_desired_channel()")
		return

	# No device code: should stay on the workspace-derived naming scheme.
	link.call("configure", {"channellen_default": 50}, "slot1", "ws_1", "desk_1")
	var ch0 := String(link.call("get_desired_channel"))
	if not T.require_true(self, ch0.begins_with("#"), "Derived channel must start with #"):
		return
	if not T.require_true(self, ch0.find("_dev_") == -1, "Unpaired desk channel must not include _dev_"):
		return

	# With device code: channel must include both desk_id and the device code (sanitized to lowercase).
	link.call("configure", {"channellen_default": 50}, "slot1", "ws_1", "desk_1", "ABCD-1234")
	var ch1 := String(link.call("get_desired_channel"))
	if not T.require_true(self, ch1.begins_with("#"), "Derived channel must start with #"):
		return
	if not T.require_true(self, ch1.find("desk_1") != -1, "Paired channel must include desk_id hint"):
		return
	if not T.require_true(self, ch1.find("dev_abcd1234") != -1, "Paired channel must include device code hint"):
		return

	# Switching code changes channel.
	link.call("configure", {"channellen_default": 50}, "slot1", "ws_1", "desk_1", "WXYZ-9999")
	var ch2 := String(link.call("get_desired_channel"))
	if not T.require_true(self, ch2 != ch1, "Changing device code must change desired channel"):
		return

	get_root().remove_child(link)
	link.free()
	await process_frame

	T.pass_and_quit(self)

