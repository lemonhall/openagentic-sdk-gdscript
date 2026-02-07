extends RefCounted
const _IrcNames := preload("res://vr_offices/core/irc/VrOfficesIrcNames.gd")
const _RosterPanel := preload("res://vr_offices/core/meeting_rooms/VrOfficesMeetingRoomRosterPanel.gd")
const _DEFAULT_NICKLEN := 9
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
var _save_id := ""
var _roster_connected := false
var _irc_names_cache: Dictionary = {}
var _irc_names_inflight := false
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
	_ensure_roster_connected()

	if owner != null and is_instance_valid(owner):
		var bridge := owner.get_node_or_null("MeetingRoomIrcBridge") as Node
		if bridge != null and bridge.has_method("ensure_host_for_room"):
			bridge.call("ensure_host_for_room", rid)
	if camera_rig != null and camera_rig.has_method("set_controls_enabled"):
		camera_rig.call("set_controls_enabled", false)
	var sid := ""
	if get_save_id.is_valid():
		sid = String(get_save_id.call())
	_save_id = sid.strip_edges()
	var title := meeting_room_name.strip_edges()
	if title == "":
		title = rid
	if channel_hub != null and channel_hub.has_method("get_channel_name"):
		var ch := String(channel_hub.call("get_channel_name", rid)).strip_edges()
		if ch != "":
			title = "%s  %s" % [title, ch]
	overlay.call("open", _chat_npc_id, title, sid)
	_disable_skills_ui()
	_refresh_roster_ui()
	_refresh_irc_names_async()
	if overlay.has_method("set_history") and chat_history != null and sid.strip_edges() != "":
		var hist0: Variant = chat_history.call("read_ui_history", sid, _chat_npc_id)
		var hist: Array = hist0 as Array if typeof(hist0) == TYPE_ARRAY else []
		overlay.call("set_history", hist)
func close() -> void:
	_disconnect_roster()
	_meeting_room_id = ""
	_chat_npc_id = ""
	_save_id = ""
	if camera_rig != null and camera_rig.has_method("set_controls_enabled"):
		camera_rig.call("set_controls_enabled", true)
	if overlay != null and overlay.visible and overlay.has_method("close"):
		overlay.call("close")
func refresh_roster() -> void:
	_refresh_roster_ui()
	_refresh_irc_names_async()
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
func _ensure_roster_connected() -> void:
	if _roster_connected:
		return
	if channel_hub == null or not channel_hub.has_signal("roster_changed"):
		return
	var cb := Callable(self, "_on_roster_changed")
	if channel_hub.is_connected("roster_changed", cb):
		_roster_connected = true
		return
	channel_hub.connect("roster_changed", cb)
	_roster_connected = true
func _disconnect_roster() -> void:
	if not _roster_connected:
		return
	_roster_connected = false
	if channel_hub == null or not channel_hub.has_signal("roster_changed"):
		return
	var cb := Callable(self, "_on_roster_changed")
	if channel_hub.is_connected("roster_changed", cb):
		channel_hub.disconnect("roster_changed", cb)
func _on_roster_changed(meeting_room_id: String) -> void:
	var rid := meeting_room_id.strip_edges()
	if rid == "" or rid != _meeting_room_id:
		return
	_refresh_roster_ui()
	_refresh_irc_names_async()
func _refresh_irc_names_async() -> void:
	if _irc_names_inflight:
		return
	if overlay == null or not is_instance_valid(overlay) or not overlay.visible:
		return
	var rid := _meeting_room_id.strip_edges()
	if rid == "":
		return
	_irc_names_inflight = true
	_irc_names_cache = await _RosterPanel.fetch_irc_names(owner, rid, 240) if _RosterPanel != null else {}
	_irc_names_inflight = false
	_refresh_roster_ui()
func _refresh_roster_ui() -> void:
	if overlay == null or not is_instance_valid(overlay) or not overlay.visible:
		return
	if not overlay.has_method("set_participants_visible") or not overlay.has_method("set_participants"):
		return
	if _meeting_room_id.strip_edges() == "":
		return
	overlay.call("set_participants_visible", true)

	var roster_lines: Array[String] = []
	var host_nick := ""
	if _save_id != "" and _chat_npc_id != "":
		host_nick = String(_IrcNames.derive_nick(_save_id, _chat_npc_id, _DEFAULT_NICKLEN)).strip_edges()
	var host_line := "主持人（你）" if host_nick == "" else ("主持人（你） (@%s)" % host_nick)

	# If we have real IRC NAMES, prefer showing server truth.
	if not _irc_names_cache.is_empty():
		var lines := _RosterPanel.build_lines(host_nick, _meeting_room_id, channel_hub, _irc_names_cache) if _RosterPanel != null else []
		overlay.call("set_participants", lines)
		return
	if channel_hub != null and channel_hub.has_method("roster_for_room"):
		var roster0: Variant = channel_hub.call("roster_for_room", _meeting_room_id)
		if typeof(roster0) == TYPE_ARRAY:
			for p0 in (roster0 as Array):
				if typeof(p0) != TYPE_DICTIONARY:
					continue
				var p := p0 as Dictionary
				var display_name := String(p.get("display_name", "")).strip_edges()
				var npc_id := String(p.get("npc_id", "")).strip_edges()
				var nick := String(p.get("irc_nick", "")).strip_edges()
				var base := display_name if display_name != "" else npc_id
				if base == "":
					continue
				var line := base
				if nick != "":
					line = "%s (@%s)" % [base, nick]
				roster_lines.append(line)
	roster_lines.sort()
	var out: Array[String] = [host_line]
	out.append_array(roster_lines)
	overlay.call("set_participants", out)
func _meeting_npc_id(meeting_room_id: String) -> String:
	var rid := meeting_room_id.strip_edges()
	rid = rid.replace("/", "_").replace("\\", "_").replace(":", "_")
	return "meetingroom_%s" % rid
