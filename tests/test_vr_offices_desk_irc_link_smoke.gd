extends SceneTree

const T := preload("res://tests/_test_util.gd")
const IrcMessage := preload("res://addons/irc_client/IrcMessage.gd")

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
		T.fail_and_quit(self, "VrOfficesDeskIrcLink must implement configure(config: Dictionary, save_id: String, workspace_id: String, desk_id: String)")
		return

	# Must be safe to configure in headless tests without opening sockets.
	link.call("configure", {}, "slot1", "ws_1", "desk_1")

	if not link.has_method("get_desired_channel"):
		T.fail_and_quit(self, "VrOfficesDeskIrcLink must implement get_desired_channel()")
		return
	var ch := String(link.call("get_desired_channel"))
	if not T.require_true(self, ch.begins_with("#"), "Derived channel must start with #"):
		return
	# JOIN may arrive as `JOIN :#channel` (channel stored in `trailing` by our parser).
	var join_msg := IrcMessage.new()
	join_msg.command = "JOIN"
	join_msg.trailing = ch
	link.call("_on_message_received", join_msg)
	if not T.require_true(self, bool(link.call("is_ready")), "DeskIrcLink must become ready after JOIN trailing matches desired_channel"):
		return

	if not link.has_method("reconnect_now"):
		T.fail_and_quit(self, "VrOfficesDeskIrcLink must implement reconnect_now()")
		return
	# Must be safe to call when disabled (no sockets opened).
	link.call("reconnect_now")

	get_root().remove_child(link)
	link.free()
	await process_frame

	T.pass_and_quit(self)
