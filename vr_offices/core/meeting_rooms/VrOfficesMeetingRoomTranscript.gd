extends RefCounted

const _SessionStore := preload("res://addons/openagentic/core/OAJsonlNpcSessionStore.gd")

static func append_public_line(save_id: String, meeting_room_id: String, speaker_kind: String, speaker: String, text: String, participants: Array) -> void:
	var sid := save_id.strip_edges()
	var rid := meeting_room_id.strip_edges()
	var sk := speaker_kind.strip_edges()
	var who := speaker.strip_edges()
	var t := text.strip_edges()
	if sid == "" or rid == "" or sk == "" or who == "" or t == "":
		return
	if participants == null or participants.is_empty():
		return

	var store := _SessionStore.new(sid)
	var line := ("[MeetingRoom %s] %s: %s" % [rid, who, t]).strip_edges()
	var ev_type := "user.message" if sk == "host" else "assistant.message"
	for p0 in participants:
		if typeof(p0) != TYPE_DICTIONARY:
			continue
		var p := p0 as Dictionary
		var npc_id := String(p.get("npc_id", "")).strip_edges()
		if npc_id == "":
			continue
		store.call("append_event", npc_id, {
			"type": ev_type,
			"meeting_room_id": rid,
			"speaker": who,
			"text": line,
		})
