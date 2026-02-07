extends RefCounted

static func fetch_irc_names(owner: Node, meeting_room_id: String, timeout_frames: int = 240) -> Dictionary:
	var rid := meeting_room_id.strip_edges()
	if owner == null or not is_instance_valid(owner) or rid == "":
		return {}
	var bridge := owner.get_node_or_null("MeetingRoomIrcBridge") as Node
	if bridge == null or not bridge.has_method("get_host_link"):
		return {}
	var host_link0: Variant = bridge.call("get_host_link", rid)
	var host_link := host_link0 as Node
	if host_link == null or not is_instance_valid(host_link) or not host_link.has_method("request_names_for_desired_channel"):
		return {}
	var res0: Variant = await host_link.call("request_names_for_desired_channel", timeout_frames)
	return res0 as Dictionary if typeof(res0) == TYPE_DICTIONARY else {}

static func build_lines(host_nick: String, meeting_room_id: String, channel_hub: RefCounted, irc_names: Dictionary) -> Array[String]:
	var rid := meeting_room_id.strip_edges()
	if rid == "":
		return []
	var nick_to_label: Dictionary = {}
	var expected: Array[String] = []
	if host_nick.strip_edges() != "":
		nick_to_label[host_nick] = "主持人（你）"
		expected.append(host_nick)

	if channel_hub != null and channel_hub.has_method("roster_for_room"):
		var roster0: Variant = channel_hub.call("roster_for_room", rid)
		if typeof(roster0) == TYPE_ARRAY:
			for p0 in (roster0 as Array):
				if typeof(p0) != TYPE_DICTIONARY:
					continue
				var p := p0 as Dictionary
				var display_name := String(p.get("display_name", "")).strip_edges()
				var npc_id := String(p.get("npc_id", "")).strip_edges()
				var nick := String(p.get("irc_nick", "")).strip_edges()
				if nick == "":
					continue
				expected.append(nick)
				var base := display_name if display_name != "" else npc_id
				if base != "":
					nick_to_label[nick] = base

	var lines: Array[String] = []
	var nicks: Array[String] = []
	if irc_names != null:
		for k0 in irc_names.keys():
			var k := String(k0).strip_edges()
			if k != "":
				nicks.append(k)
	nicks.sort()
	for nick in nicks:
		var who := String(nick_to_label.get(nick, "")).strip_edges()
		lines.append(("%s (@%s)" % [who, nick]) if who != "" else ("@%s" % nick))

	expected.sort()
	for en0 in expected:
		var en := String(en0).strip_edges()
		if en != "" and (irc_names == null or not irc_names.has(en)):
			lines.append("缺失: @%s" % en)
	return lines

