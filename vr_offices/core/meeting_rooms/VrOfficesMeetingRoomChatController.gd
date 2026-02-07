extends RefCounted

var owner: Node = null
var camera_rig: Node = null
var overlay: Control = null
var oa: Node = null
var channel_hub: RefCounted = null
var chat_history: RefCounted = null
var is_headless: Callable
var get_save_id: Callable

var busy := false

var _meeting_room_id := ""
var _chat_npc_id := ""

func _init(
	owner_in: Node,
	camera_rig_in: Node,
	overlay_in: Control,
	oa_in: Node,
	channel_hub_in: RefCounted,
	chat_history_in: RefCounted,
	is_headless_in: Callable,
	get_save_id_in: Callable
) -> void:
	owner = owner_in
	camera_rig = camera_rig_in
	overlay = overlay_in
	oa = oa_in
	channel_hub = channel_hub_in
	chat_history = chat_history_in
	is_headless = is_headless_in
	get_save_id = get_save_id_in

func open_for_meeting_room(meeting_room_id: String, meeting_room_name: String) -> void:
	if overlay == null or not overlay.has_method("open"):
		return
	var rid := meeting_room_id.strip_edges()
	if rid == "":
		return
	_meeting_room_id = rid
	_chat_npc_id = _meeting_npc_id(rid)

	if owner != null and is_instance_valid(owner):
		var bridge := owner.get_node_or_null("MeetingRoomIrcBridge") as Node
		if bridge != null and bridge.has_method("ensure_host_for_room"):
			bridge.call("ensure_host_for_room", rid)

	if camera_rig != null and camera_rig.has_method("set_controls_enabled"):
		camera_rig.call("set_controls_enabled", false)

	var sid := ""
	if get_save_id.is_valid():
		sid = String(get_save_id.call())
	var title := meeting_room_name.strip_edges()
	if title == "":
		title = rid
	if channel_hub != null and channel_hub.has_method("get_channel_name"):
		var ch := String(channel_hub.call("get_channel_name", rid)).strip_edges()
		if ch != "":
			title = "%s  %s" % [title, ch]
	overlay.call("open", _chat_npc_id, title, sid)
	_disable_skills_ui()

	if overlay.has_method("set_history") and chat_history != null and sid.strip_edges() != "":
		var hist0: Variant = chat_history.call("read_ui_history", sid, _chat_npc_id)
		var hist: Array = hist0 as Array if typeof(hist0) == TYPE_ARRAY else []
		overlay.call("set_history", hist)

func close() -> void:
	_meeting_room_id = ""
	_chat_npc_id = ""
	if camera_rig != null and camera_rig.has_method("set_controls_enabled"):
		camera_rig.call("set_controls_enabled", true)
	if overlay != null and overlay.visible and overlay.has_method("close"):
		overlay.call("close")

func on_message_submitted(text: String) -> void:
	if overlay == null or busy:
		return
	if _chat_npc_id.strip_edges() == "":
		return
	_start_broadcast(text)

func _start_broadcast(text: String) -> void:
	busy = true
	if overlay != null and overlay.has_method("set_busy"):
		overlay.call("set_busy", true)

	if channel_hub == null or not channel_hub.has_method("broadcast_human_message"):
		push_warning("Meeting channel hub not configured")
	else:
		await channel_hub.call("broadcast_human_message", _meeting_room_id, _chat_npc_id, text, overlay)

	busy = false
	if overlay != null and overlay.has_method("set_busy"):
		overlay.call("set_busy", false)

func _disable_skills_ui() -> void:
	if overlay == null:
		return
	var skills := overlay.get_node_or_null("%SkillsButton") as Control
	if skills != null:
		skills.visible = false

func _meeting_npc_id(meeting_room_id: String) -> String:
	var rid := meeting_room_id.strip_edges()
	rid = rid.replace("/", "_").replace("\\", "_").replace(":", "_")
	return "meetingroom_%s" % rid
