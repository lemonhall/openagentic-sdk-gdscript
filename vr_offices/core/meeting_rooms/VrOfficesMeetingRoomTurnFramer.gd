extends RefCounted

const _IrcNames := preload("res://vr_offices/core/irc/VrOfficesIrcNames.gd")
const _SessionStore := preload("res://addons/openagentic/core/OAJsonlNpcSessionStore.gd")
const _DEFAULT_NICKLEN := 9
const _DEFAULT_CHANNELLEN := 50

static func frame(
	save_id: String,
	meeting_room_id: String,
	meeting_room_name: String,
	meeting_channel: String,
	meeting_npc_id: String,
	target_npc_id: String,
	roster: Array,
	host_text: String,
	is_mentioned: bool
) -> String:
	var sid := save_id.strip_edges()
	var rid := meeting_room_id.strip_edges()
	var room_name := meeting_room_name.strip_edges()
	var ch := meeting_channel.strip_edges()
	var mid := meeting_npc_id.strip_edges()
	var nid := target_npc_id.strip_edges()
	var t := host_text.strip_edges()
	if rid == "" or nid == "" or t == "":
		return host_text
	if room_name == "":
		room_name = rid
	if ch == "" and sid != "":
		ch = String(_IrcNames.derive_channel_for_meeting_room(sid, rid, _DEFAULT_CHANNELLEN)).strip_edges()

	var self_name := nid
	var self_nick := ""
	var parts := PackedStringArray()
	for p0 in roster:
		if typeof(p0) != TYPE_DICTIONARY:
			continue
		var p := p0 as Dictionary
		var pid := String(p.get("npc_id", "")).strip_edges()
		var dn := String(p.get("display_name", pid)).strip_edges()
		var nick := String(p.get("irc_nick", "")).strip_edges()
		var label := dn if dn != "" else pid
		if nick != "":
			label = "%s(@%s)" % [label, nick]
		if label != "":
			parts.append(label)
		if pid == nid:
			self_name = dn if dn != "" else pid
			self_nick = nick

	var transcript := PackedStringArray()
	if sid != "":
		var store := _SessionStore.new(sid)
		var evs0: Variant = store.call("read_events", nid)
		if typeof(evs0) == TYPE_ARRAY:
			var evs := evs0 as Array
			for i in range(evs.size() - 1, -1, -1):
				var e0: Variant = evs[i]
				if typeof(e0) != TYPE_DICTIONARY:
					continue
				var e := e0 as Dictionary
				var typ := String(e.get("type", "")).strip_edges()
				if typ != "user.message" and typ != "assistant.message":
					continue
				var line := String(e.get("text", "")).strip_edges()
				if line != "" and line.begins_with("[MeetingRoom %s] " % rid):
					transcript.append(line)
				if transcript.size() >= 8:
					break
	transcript.reverse()

	var head := PackedStringArray()
	head.append("【会议模式】你正在参会。")
	head.append("你被点名：%s" % ("是" if is_mentioned else "否"))
	if sid != "" and mid != "":
		var host_nick := String(_IrcNames.derive_nick(sid, mid, _DEFAULT_NICKLEN)).strip_edges()
		if host_nick != "":
			head.append("主持人：主持人（你） (@%s)" % host_nick)
	if self_nick != "":
		head.append("你的身份：%s (@%s)" % [self_name, self_nick])
	else:
		head.append("你的身份：%s" % self_name)
	head.append("地点：会议室 %s" % room_name)
	if ch != "":
		head.append("公开频道：%s" % ch)
	if not parts.is_empty():
		head.append("参会者：" + ", ".join(parts))
	if not transcript.is_empty():
		head.append("最近公开发言：")
		for line in transcript:
			head.append("- " + String(line))
	head.append("发言规则：")
	head.append("- 如果你决定不在公开频道发言，请输出严格的 <<SILENCE>>（不带任何其他字符）并结束。")
	head.append("- 如果你被点名（@你），你必须发言，不得输出 <<SILENCE>>。")
	head.append("- 如果要发言，请只输出你要在公开频道说的话（不要解释规则，不要复述上下文）。")
	head.append("主持人对你说：")
	head.append(t)
	return "\n".join(head)
