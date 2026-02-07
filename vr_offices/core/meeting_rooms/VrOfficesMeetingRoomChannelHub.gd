extends RefCounted
const _IrcNames := preload("res://vr_offices/core/irc/VrOfficesIrcNames.gd")
const _Mentions := preload("res://vr_offices/core/meeting_rooms/VrOfficesMeetingMentions.gd")
const _ReplyPolicy := preload("res://vr_offices/core/meeting_rooms/VrOfficesMeetingReplyPolicy.gd")
const _SessionStore := preload("res://addons/openagentic/core/OAJsonlNpcSessionStore.gd")
const _DEFAULT_NICKLEN := 9
signal roster_changed(meeting_room_id: String)
var oa: Node = null
var get_save_id: Callable
var find_npc_by_id: Callable
var _irc_bridge: Node = null
var _rooms: Dictionary = {}
func _init(oa_in: Node, get_save_id_in: Callable, find_npc_by_id_in: Callable) -> void:
	oa = oa_in
	get_save_id = get_save_id_in
	find_npc_by_id = find_npc_by_id_in

func set_irc_bridge(bridge: Node) -> void:
	_irc_bridge = bridge

func get_channel_name(meeting_room_id: String, channellen: int = 50) -> String:
	var rid := meeting_room_id.strip_edges()
	if rid == "":
		return ""
	var sid := _effective_save_id()
	return String(_IrcNames.derive_channel_for_meeting_room(sid, rid, channellen))

func join_participant(meeting_room_id: String, npc: Node) -> void:
	var rid := meeting_room_id.strip_edges()
	if rid == "" or npc == null or not is_instance_valid(npc):
		return
	var npc_id := _npc_id_for_node(npc)
	if npc_id == "":
		return
	var display_name := _display_name_for_node(npc)
	var nick := String(_IrcNames.derive_nick(_effective_save_id(), npc_id, _DEFAULT_NICKLEN))

	var st := _ensure_room_state(rid)
	var parts0: Variant = st.get("participants", {})
	var parts: Dictionary = parts0 as Dictionary if typeof(parts0) == TYPE_DICTIONARY else {}
	parts[npc_id] = {"npc_id": npc_id, "display_name": display_name, "irc_nick": nick}
	st["participants"] = parts
	_rooms[rid] = st

	if _irc_bridge != null and is_instance_valid(_irc_bridge) and _irc_bridge.has_method("join_participant"):
		var ch := String(st.get("channel", "")).strip_edges()
		_irc_bridge.call("join_participant", rid, npc_id, display_name, nick, ch)
	roster_changed.emit(rid)

func part_participant(meeting_room_id: String, npc_id: String) -> void:
	var rid := meeting_room_id.strip_edges()
	var nid := npc_id.strip_edges()
	if rid == "" or nid == "":
		return
	if not _rooms.has(rid):
		return
	var st0: Variant = _rooms.get(rid, {})
	var st: Dictionary = st0 as Dictionary if typeof(st0) == TYPE_DICTIONARY else {}
	var parts0: Variant = st.get("participants", {})
	if typeof(parts0) != TYPE_DICTIONARY:
		return
	var parts := parts0 as Dictionary
	if parts.has(nid):
		parts.erase(nid)
	st["participants"] = parts
	_rooms[rid] = st
	if _irc_bridge != null and is_instance_valid(_irc_bridge) and _irc_bridge.has_method("part_participant"):
		_irc_bridge.call("part_participant", rid, nid)
	roster_changed.emit(rid)

func roster_for_room(meeting_room_id: String) -> Array:
	var rid := meeting_room_id.strip_edges()
	if rid == "" or not _rooms.has(rid):
		return []
	var st0: Variant = _rooms.get(rid, {})
	var st: Dictionary = st0 as Dictionary if typeof(st0) == TYPE_DICTIONARY else {}
	var parts0: Variant = st.get("participants", {})
	if typeof(parts0) != TYPE_DICTIONARY:
		return []
	var parts: Dictionary = parts0 as Dictionary
	var out: Array = []
	for k0 in parts.keys():
		var k := String(k0).strip_edges()
		if k == "":
			continue
		var p0: Variant = parts.get(k, {})
		if typeof(p0) != TYPE_DICTIONARY:
			continue
		out.append(p0 as Dictionary)
	return out

func broadcast_human_message(meeting_room_id: String, meeting_npc_id: String, text: String, overlay: Control) -> void:
	var rid := meeting_room_id.strip_edges()
	var mid := meeting_npc_id.strip_edges()
	var t := text.strip_edges()
	if rid == "" or mid == "" or t == "":
		return
	if oa == null or not is_instance_valid(oa) or not oa.has_method("run_npc_turn"):
		return

	var roster := roster_for_room(rid)
	if roster.is_empty():
		return

	if _irc_bridge != null and is_instance_valid(_irc_bridge) and _irc_bridge.has_method("send_human_message"):
		_irc_bridge.call("send_human_message", rid, t)

	var sid := _effective_save_id()
	var store: RefCounted = null
	if sid != "":
		store = _SessionStore.new(sid)
		store.call("append_event", mid, {"type": "user.message", "text": t})

	var mentioned0: Variant = _Mentions.parse_mentioned_npc_ids(t, roster)
	var mentioned: Array = mentioned0 as Array if typeof(mentioned0) == TYPE_ARRAY else []
	var responders0: Variant = _ReplyPolicy.pick_responders(rid, roster, mentioned, t)
	var responders: Array = responders0 as Array if typeof(responders0) == TYPE_ARRAY else []
	for npc_id in responders:
		var npc := _find_npc(npc_id)
		if npc == null:
			continue
		var name := _display_name_for_node(npc)

		var reply_parts := PackedStringArray()
		if overlay != null and overlay.has_method("begin_assistant"):
			overlay.call("begin_assistant")
			if overlay.has_method("append_assistant_delta"):
				overlay.call("append_assistant_delta", "%s: " % name)

		await oa.run_npc_turn(npc_id, t, func(ev: Dictionary) -> void:
			var typ := String(ev.get("type", ""))
			if typ == "assistant.delta":
				var delta := String(ev.get("text_delta", ""))
				if delta != "":
					reply_parts.append(delta)
				if overlay != null and overlay.has_method("append_assistant_delta"):
					overlay.call("append_assistant_delta", delta)
			elif typ == "result":
				if overlay != null and overlay.has_method("end_assistant"):
					overlay.call("end_assistant")
		)

		var reply_buf := "".join(reply_parts)
		if _irc_bridge != null and is_instance_valid(_irc_bridge) and _irc_bridge.has_method("send_npc_message"):
			var line2 := reply_buf.strip_edges()
			if line2 != "":
				_irc_bridge.call("send_npc_message", rid, npc_id, line2)

		if store != null:
			var line := ("%s: %s" % [name, reply_buf.strip_edges()]).strip_edges()
			if line != "":
				store.call("append_event", mid, {"type": "assistant.message", "text": line})


func _ensure_room_state(meeting_room_id: String) -> Dictionary:
	var rid := meeting_room_id.strip_edges()
	if rid == "":
		return {"channel": "", "participants": {}}
	if _rooms.has(rid):
		var st0: Variant = _rooms.get(rid, {})
		if typeof(st0) == TYPE_DICTIONARY:
			return st0 as Dictionary
	var st: Dictionary = {"channel": get_channel_name(rid), "participants": {}}
	return st

func _effective_save_id() -> String:
	if get_save_id.is_valid():
		return String(get_save_id.call()).strip_edges()
	return ""

func _npc_id_for_node(npc: Node) -> String:
	if npc == null:
		return ""
	if npc.has_method("get"):
		var v: Variant = npc.get("npc_id")
		if v != null:
			return String(v).strip_edges()
	return npc.name

func _display_name_for_node(npc: Node) -> String:
	if npc == null:
		return ""
	if npc.has_method("get_display_name"):
		return String(npc.call("get_display_name")).strip_edges()
	if npc.has_method("get"):
		var v: Variant = npc.get("display_name")
		if v != null:
			var s := String(v).strip_edges()
			if s != "":
				return s
	return npc.name

func _find_npc(npc_id: String) -> Node:
	var nid := npc_id.strip_edges()
	if nid == "":
		return null
	if find_npc_by_id.is_valid():
		var n0: Variant = find_npc_by_id.call(nid)
		var n := n0 as Node
		if n != null and is_instance_valid(n):
			return n
	return null
