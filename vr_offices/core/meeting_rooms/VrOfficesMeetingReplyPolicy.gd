extends Object

static func pick_responders(meeting_room_id: String, roster: Array, mentioned: Array, text: String) -> Array[String]:
	# Fan out to all participants; the agent decides whether to respond (via prompt framing / <<SILENCE>>).
	# Mentions are still parsed and provided for prompt context, but do not gate delivery.
	return _participant_ids_sorted(roster)

static func _participant_ids_sorted(roster: Array) -> Array[String]:
	var ids: Array[String] = []
	for r0 in roster:
		if typeof(r0) != TYPE_DICTIONARY:
			continue
		var r: Dictionary = r0 as Dictionary
		var nid := String(r.get("npc_id", "")).strip_edges()
		if nid != "":
			ids.append(nid)
	ids.sort()
	return ids
