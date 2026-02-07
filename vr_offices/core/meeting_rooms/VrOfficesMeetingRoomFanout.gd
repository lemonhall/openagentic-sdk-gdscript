extends RefCounted

const _TurnFramer := preload("res://vr_offices/core/meeting_rooms/VrOfficesMeetingRoomTurnFramer.gd")
const _EventLog := preload("res://vr_offices/core/meeting_rooms/VrOfficesMeetingRoomEventLog.gd")
const _Transcript := preload("res://vr_offices/core/meeting_rooms/VrOfficesMeetingRoomTranscript.gd")
const _SILENCE := "<<SILENCE>>"

static func fanout_to_all(
	oa: Node,
	meeting_room_id: String,
	meeting_npc_id: String,
	host_text: String,
	save_id: String,
	channel: String,
	roster: Array,
	mentioned: Array,
	find_npc: Callable,
	display_name_for_node: Callable,
	overlay: Control,
	irc_bridge: Node,
	chat_store: RefCounted
) -> void:
	if oa == null or not is_instance_valid(oa) or not oa.has_method("run_npc_turn"):
		return
	var rid := meeting_room_id.strip_edges()
	var mid := meeting_npc_id.strip_edges()
	var t := host_text.strip_edges()
	if rid == "" or mid == "" or t == "":
		return

	var sid := save_id.strip_edges()
	var ch := channel.strip_edges()

	var mset: Dictionary = {}
	for m0 in mentioned:
		var m := String(m0).strip_edges()
		if m != "":
			mset[m] = true

	var participants := roster.duplicate()
	participants.sort_custom(func(a: Variant, b: Variant) -> bool:
		if typeof(a) != TYPE_DICTIONARY or typeof(b) != TYPE_DICTIONARY:
			return false
		return String((a as Dictionary).get("npc_id", "")).strip_edges() < String((b as Dictionary).get("npc_id", "")).strip_edges()
	)

	for p0 in participants:
		if typeof(p0) != TYPE_DICTIONARY:
			continue
		var p := p0 as Dictionary
		var npc_id := String(p.get("npc_id", "")).strip_edges()
		if npc_id == "":
			continue
		if not find_npc.is_valid():
			continue
		var n0: Variant = find_npc.call(npc_id)
		var npc := n0 as Node
		if npc == null or not is_instance_valid(npc):
			continue

		var who := ""
		if display_name_for_node.is_valid():
			who = String(display_name_for_node.call(npc)).strip_edges()
		if who == "":
			who = npc_id

		var is_mentioned := mset.has(npc_id)
		var framed := _TurnFramer.frame(sid, rid, rid, ch, mid, npc_id, roster, t, is_mentioned) if sid != "" else t

		var reply_parts := PackedStringArray()
		await oa.run_npc_turn(npc_id, framed, func(ev: Dictionary) -> void:
			if String(ev.get("type", "")) == "assistant.delta":
				var delta := String(ev.get("text_delta", ""))
				if delta != "":
					reply_parts.append(delta)
		)

		var reply := "".join(reply_parts).strip_edges()
		if reply == "" or reply == _SILENCE:
			if sid != "" and _EventLog != null:
				_EventLog.append(sid, rid, {"type": "silence", "npc_id": npc_id, "display_name": who, "mentioned": is_mentioned})
			continue

		if overlay != null and overlay.has_method("begin_assistant") and overlay.has_method("append_assistant_delta") and overlay.has_method("end_assistant"):
			overlay.call("begin_assistant")
			overlay.call("append_assistant_delta", ("%s: %s" % [who, reply]).strip_edges())
			overlay.call("end_assistant")

		if irc_bridge != null and is_instance_valid(irc_bridge) and irc_bridge.has_method("send_npc_message"):
			irc_bridge.call("send_npc_message", rid, npc_id, reply)

		if chat_store != null:
			var line := ("%s: %s" % [who, reply]).strip_edges()
			if line != "":
				chat_store.call("append_event", mid, {"type": "assistant.message", "text": line})

		if sid != "" and _Transcript != null:
			_Transcript.append_public_line(sid, rid, "npc", who, reply, roster)
		if sid != "" and _EventLog != null:
			_EventLog.append(sid, rid, {"type": "msg", "speaker": "npc", "npc_id": npc_id, "display_name": who, "text_len": reply.length()})

