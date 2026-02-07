extends Node
const _IrcNames := preload("res://vr_offices/core/irc/VrOfficesIrcNames.gd")
const _LinkScript := preload("res://vr_offices/core/meeting_rooms/VrOfficesMeetingRoomIrcLink.gd")
const _TextSplit := preload("res://vr_offices/core/meeting_rooms/VrOfficesMeetingRoomTextSplit.gd")
const _Connections := preload("res://vr_offices/core/meeting_rooms/VrOfficesMeetingRoomIrcBridgeConnections.gd")
var _config: Dictionary = {}
var _get_save_id: Callable = Callable()
var _is_headless: Callable = Callable()
# meeting_room_id -> { host: Node, npcs: Dictionary[npc_id -> Node] }
var _rooms: Dictionary = {}
func _online_tests_enabled() -> bool:
	return OS.get_cmdline_args().has("--oa-online-tests")
func bind(get_save_id: Callable, is_headless: Callable) -> void:
	_get_save_id = get_save_id
	_is_headless = is_headless
func set_config(cfg: Dictionary) -> void:
	_config = cfg if cfg != null else {}
	_reconfigure_all()
func join_participant(meeting_room_id: String, npc_id: String, _display_name: String, irc_nick: String, _channel: String) -> void:
	if not _enabled():
		return
	var rid := meeting_room_id.strip_edges()
	var nid := npc_id.strip_edges()
	if rid == "" or nid == "":
		return
	_ensure_host_link(rid)
	_ensure_npc_link(rid, nid, irc_nick.strip_edges())
func ensure_host_for_room(meeting_room_id: String) -> void:
	if not _enabled():
		return
	var rid := meeting_room_id.strip_edges()
	if rid == "":
		return
	_ensure_host_link(rid)
func get_host_link(meeting_room_id: String) -> Node:
	var rid := meeting_room_id.strip_edges()
	return null if rid == "" or not _enabled() else _ensure_host_link(rid)
func get_npc_link(meeting_room_id: String, npc_id: String) -> Node:
	var rid := meeting_room_id.strip_edges()
	var nid := npc_id.strip_edges()
	return null if rid == "" or nid == "" else _npc_link(rid, nid)
func close_room_connections(meeting_room_id: String) -> void:
	if _Connections != null:
		_Connections.close_room_connections(_rooms, meeting_room_id)
func part_participant(meeting_room_id: String, npc_id: String) -> void:
	var rid := meeting_room_id.strip_edges()
	var nid := npc_id.strip_edges()
	if rid == "" or nid == "":
		return
	if not _rooms.has(rid):
		return
	var st0: Variant = _rooms.get(rid, {})
	if typeof(st0) != TYPE_DICTIONARY:
		return
	var st := st0 as Dictionary
	var npcs0: Variant = st.get("npcs", {})
	if typeof(npcs0) != TYPE_DICTIONARY:
		return
	var npcs := npcs0 as Dictionary
	var link0: Variant = npcs.get(nid, null)
	var link := link0 as Node
	if link != null and is_instance_valid(link):
		link.queue_free()
	npcs.erase(nid)
	st["npcs"] = npcs
	_rooms[rid] = st
func send_human_message(meeting_room_id: String, text: String) -> void:
	if not _enabled():
		return
	var rid := meeting_room_id.strip_edges()
	var t := text.strip_edges()
	if rid == "" or t == "":
		return
	var host := _ensure_host_link(rid)
	_send_text(host, t)
func send_npc_message(meeting_room_id: String, npc_id: String, text: String) -> void:
	if not _enabled():
		return
	var rid := meeting_room_id.strip_edges()
	var nid := npc_id.strip_edges()
	var t := text.strip_edges()
	if rid == "" or nid == "" or t == "":
		return
	var link := _npc_link(rid, nid)
	_send_text(link, t)
func _send_text(link: Node, text: String) -> void:
	if link == null or not is_instance_valid(link) or not link.has_method("send_channel_message"):
		return
	var chunks: Array[String] = _TextSplit.split_text(text, 320) if _TextSplit != null else []
	if chunks.is_empty():
		chunks = [text]
	for c in chunks:
		var s := String(c).strip_edges()
		if s != "":
			link.call("send_channel_message", s)
func _enabled() -> bool:
	if _is_headless.is_valid() and bool(_is_headless.call()) and not _online_tests_enabled():
		return false
	var host := String(_config.get("host", "")).strip_edges()
	var port := int(_config.get("port", 0))
	return host != "" and port > 0
func _effective_save_id() -> String:
	if _get_save_id.is_valid():
		return String(_get_save_id.call()).strip_edges()
	return ""
func _ensure_host_link(meeting_room_id: String) -> Node:
	var rid := meeting_room_id.strip_edges()
	if rid == "":
		return null
	var st := _room_state(rid)
	var host0: Variant = st.get("host", null)
	var host := host0 as Node
	if host == null or not is_instance_valid(host):
		var nicklen := int(_config.get("nicklen_default", 9))
		var sid := _effective_save_id()
		var host_nick := String(_IrcNames.derive_nick(sid, "meetingroom_%s" % rid, nicklen))
		host = _new_link(sid, rid, host_nick)
		st["host"] = host
		_rooms[rid] = st
	return host
func _ensure_npc_link(meeting_room_id: String, npc_id: String, nick: String) -> Node:
	var rid := meeting_room_id.strip_edges()
	var nid := npc_id.strip_edges()
	if rid == "" or nid == "":
		return null
	var st := _room_state(rid)
	var npcs0: Variant = st.get("npcs", {})
	var npcs: Dictionary = npcs0 as Dictionary if typeof(npcs0) == TYPE_DICTIONARY else {}
	var link0: Variant = npcs.get(nid, null)
	var link := link0 as Node
	if link != null and is_instance_valid(link):
		return link
	var sid := _effective_save_id()
	var want_nick := nick if nick != "" else nid
	link = _new_link(sid, rid, want_nick)
	npcs[nid] = link
	st["npcs"] = npcs
	_rooms[rid] = st
	return link
func _npc_link(meeting_room_id: String, npc_id: String) -> Node:
	var rid := meeting_room_id.strip_edges()
	var nid := npc_id.strip_edges()
	if rid == "" or nid == "":
		return null
	if not _rooms.has(rid):
		return null
	var st0: Variant = _rooms.get(rid, {})
	if typeof(st0) != TYPE_DICTIONARY:
		return null
	var st := st0 as Dictionary
	var npcs0: Variant = st.get("npcs", {})
	if typeof(npcs0) != TYPE_DICTIONARY:
		return null
	var npcs := npcs0 as Dictionary
	var link0: Variant = npcs.get(nid, null)
	var link := link0 as Node
	return link if link != null and is_instance_valid(link) else null
func _room_state(meeting_room_id: String) -> Dictionary:
	var rid := meeting_room_id.strip_edges()
	if rid == "":
		return {"host": null, "npcs": {}}
	if _rooms.has(rid):
		var st0: Variant = _rooms.get(rid, {})
		if typeof(st0) == TYPE_DICTIONARY:
			return st0 as Dictionary
	return {"host": null, "npcs": {}}
func _new_link(save_id: String, meeting_room_id: String, nick: String) -> Node:
	if _LinkScript == null:
		return null
	var link := _LinkScript.new() as Node
	if link == null:
		return null
	add_child(link)
	if link.has_method("configure"):
		link.call("configure", _config, save_id, meeting_room_id, nick)
	return link
func _reconfigure_all() -> void:
	var sid := _effective_save_id()
	for rid0 in _rooms.keys():
		var rid := String(rid0).strip_edges()
		if rid == "":
			continue
		var st0: Variant = _rooms.get(rid, {})
		if typeof(st0) != TYPE_DICTIONARY:
			continue
		var st := st0 as Dictionary
		var host0: Variant = st.get("host", null)
		var host := host0 as Node
		if host != null and is_instance_valid(host) and host.has_method("configure"):
			host.call("configure", _config, sid, rid, String(host.call("get_nick")))
		var npcs0: Variant = st.get("npcs", {})
		if typeof(npcs0) != TYPE_DICTIONARY:
			continue
		var npcs := npcs0 as Dictionary
		for nid0 in npcs.keys():
			var nid := String(nid0).strip_edges()
			var link0: Variant = npcs.get(nid, null)
			var link := link0 as Node
			if link != null and is_instance_valid(link) and link.has_method("configure"):
				link.call("configure", _config, sid, rid, String(link.call("get_nick")))
