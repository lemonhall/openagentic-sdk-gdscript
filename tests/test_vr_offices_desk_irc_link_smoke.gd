extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var LinkScript := load("res://vr_offices/core/VrOfficesDeskIrcLink.gd")
	if LinkScript == null or not (LinkScript is Script) or not (LinkScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing or invalid res://vr_offices/core/VrOfficesDeskIrcLink.gd")
		return

	var link := (LinkScript as Script).new() as Node
	if not T.require_true(self, link != null, "Failed to instantiate VrOfficesDeskIrcLink"):
		return
	get_root().add_child(link)
	await process_frame

	if not link.has_method("configure"):
		T.fail_and_quit(self, "VrOfficesDeskIrcLink must implement configure(config: Dictionary, save_id: String, desk_id: String)")
		return

	# Must be safe to configure in headless tests without opening sockets.
	link.call("configure", {"enabled": false}, "slot1", "desk_1")

	if not link.has_method("get_desired_channel"):
		T.fail_and_quit(self, "VrOfficesDeskIrcLink must implement get_desired_channel()")
		return
	var ch := String(link.call("get_desired_channel"))
	if not T.require_true(self, ch.begins_with("#"), "Derived channel must start with #"):
		return

	link.queue_free()
	await process_frame

	T.pass_and_quit(self)
