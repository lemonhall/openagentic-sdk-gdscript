extends RefCounted

static func close_room_connections(rooms: Dictionary, meeting_room_id: String) -> void:
	var rid := meeting_room_id.strip_edges()
	if rid == "" or rooms == null or not rooms.has(rid):
		return
	var st0: Variant = rooms.get(rid, {})
	if typeof(st0) != TYPE_DICTIONARY:
		return
	var st := st0 as Dictionary

	var host0: Variant = st.get("host", null)
	var host := host0 as Node
	if host != null and is_instance_valid(host) and host.has_method("close_connection"):
		host.call("close_connection")

	var npcs0: Variant = st.get("npcs", {})
	if typeof(npcs0) != TYPE_DICTIONARY:
		return
	var npcs := npcs0 as Dictionary
	for nid0 in npcs.keys():
		var nid := String(nid0).strip_edges()
		if nid == "":
			continue
		var link0: Variant = npcs.get(nid, null)
		var link := link0 as Node
		if link != null and is_instance_valid(link) and link.has_method("close_connection"):
			link.call("close_connection")

