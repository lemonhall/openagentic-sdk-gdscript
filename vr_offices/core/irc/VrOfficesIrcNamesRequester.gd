extends RefCounted

static func _strip_mode_prefix(nick: String) -> String:
	var s := nick.strip_edges()
	while s.length() > 0:
		var c := s.substr(0, 1)
		if c == "@" or c == "+" or c == "~" or c == "%" or c == "&":
			s = s.substr(1).strip_edges()
		else:
			break
	return s

static func _parse_names_line(trailing: String) -> Array[String]:
	var out: Array[String] = []
	var t := trailing.strip_edges()
	if t == "":
		return out
	for tok0 in t.split(" ", false):
		var tok := _strip_mode_prefix(String(tok0))
		if tok != "":
			out.append(tok)
	return out

static func _get_cmd(msg: RefCounted) -> String:
	var obj := msg as Object
	if obj == null:
		return ""
	var v: Variant = obj.get("command")
	return "" if v == null else String(v).strip_edges()

static func _get_params(msg: RefCounted) -> Array:
	var obj := msg as Object
	if obj == null:
		return []
	var v: Variant = obj.get("params")
	return v as Array if v is Array else []

static func _get_trailing(msg: RefCounted) -> String:
	var obj := msg as Object
	if obj == null:
		return ""
	var v: Variant = obj.get("trailing")
	return "" if v == null else String(v)

static func request_names(link: Node, client: Node, channel: String, timeout_frames: int = 240) -> Dictionary:
	var names: Dictionary = {}
	var ch := channel.strip_edges()
	if link == null or not is_instance_valid(link) or client == null or not is_instance_valid(client) or ch == "":
		return names

	var inbox: Array[RefCounted] = []
	var cb := func(m: RefCounted) -> void:
		inbox.append(m)

	# Prefer the wrapper signal if present (it ensures messages are parsed already).
	var connected := false
	if link.has_signal("message_received"):
		link.connect("message_received", cb)
		connected = true
	elif client.has_signal("message_received"):
		client.connect("message_received", cb)
		connected = true
	if not connected:
		return names

	client.call("send_message", "NAMES", [ch], "")
	for _i in range(max(1, timeout_frames)):
		client.call("poll", 0.016)
		for m in inbox:
			var cmd := _get_cmd(m)
			if cmd == "353":
				# params: <me> <symbol> <#channel> ; trailing: names
				var params := _get_params(m)
				if params.size() >= 3 and String(params[2]).strip_edges() == ch:
					for n in _parse_names_line(_get_trailing(m)):
						names[n] = true
			elif cmd == "366":
				var params2 := _get_params(m)
				if params2.size() >= 2 and String(params2[1]).strip_edges() == ch:
					if link.has_signal("message_received") and link.is_connected("message_received", cb):
						link.disconnect("message_received", cb)
					elif client.has_signal("message_received") and client.is_connected("message_received", cb):
						client.disconnect("message_received", cb)
					return names
		await Engine.get_main_loop().process_frame

	if link.has_signal("message_received") and link.is_connected("message_received", cb):
		link.disconnect("message_received", cb)
	elif client.has_signal("message_received") and client.is_connected("message_received", cb):
		client.disconnect("message_received", cb)
	return names

