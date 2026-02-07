extends SceneTree

const T := preload("res://tests/_test_util.gd")
const IrcMessage := preload("res://addons/irc_client/IrcMessage.gd")

func _init() -> void:
	var LinkScript := load("res://vr_offices/core/meeting_rooms/VrOfficesMeetingRoomIrcLink.gd")
	if LinkScript == null or not (LinkScript is Script) or not (LinkScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing or invalid res://vr_offices/core/meeting_rooms/VrOfficesMeetingRoomIrcLink.gd")
		return

	var link := (LinkScript as Script).new() as Node
	if not T.require_true(self, link != null, "Failed to instantiate VrOfficesMeetingRoomIrcLink"):
		return
	get_root().add_child(link)
	await process_frame

	if not link.has_method("configure"):
		T.fail_and_quit(self, "VrOfficesMeetingRoomIrcLink must implement configure(config: Dictionary, save_id: String, meeting_room_id: String, nick: String)")
		return

	# Must be safe to configure in headless tests without opening sockets.
	link.call("configure", {}, "slot1", "room_1", "host")

	if not link.has_method("get_desired_channel"):
		T.fail_and_quit(self, "VrOfficesMeetingRoomIrcLink must implement get_desired_channel()")
		return
	var ch := String(link.call("get_desired_channel"))
	if not T.require_true(self, ch.begins_with("#"), "Derived meeting room channel must start with #"):
		return

	# JOIN may arrive as `JOIN :#channel` (channel stored in `trailing` by our parser).
	var join_msg := IrcMessage.new()
	join_msg.command = "JOIN"
	join_msg.trailing = ch
	link.call("_on_message_received", join_msg)
	if not link.has_method("is_ready"):
		T.fail_and_quit(self, "VrOfficesMeetingRoomIrcLink must implement is_ready()")
		return
	if not T.require_true(self, bool(link.call("is_ready")), "MeetingRoomIrcLink must become ready after JOIN trailing matches desired_channel"):
		return

	get_root().remove_child(link)
	link.free()
	await process_frame

	T.pass_and_quit(self)

