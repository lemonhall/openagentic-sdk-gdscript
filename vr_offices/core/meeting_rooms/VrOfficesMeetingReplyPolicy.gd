extends Object

static func pick_responders(meeting_room_id: String, roster: Array, mentioned: Array, text: String) -> Array[String]:
	var rid := meeting_room_id.strip_edges()
	var ids := _participant_ids_sorted(roster)
	var out: Array[String] = []

	if not mentioned.is_empty():
		for m0 in mentioned:
			var mid := String(m0).strip_edges()
			if mid != "" and ids.has(mid):
				out.append(mid)
		return out

	# Deterministic "may reply" policy: per-npc hash threshold, but ensure >= 1 reply.
	for nid in ids:
		var key := "%s:%s:%s" % [rid, nid, text]
		var h := int(key.hash())
		var v: int = int(abs(h)) % 100
		if v < 35:
			out.append(nid)
	if out.is_empty() and not ids.is_empty():
		out.append(ids[0])
	return out

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

