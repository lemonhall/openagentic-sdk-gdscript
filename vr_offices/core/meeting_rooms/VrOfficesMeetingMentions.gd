extends Object

static func parse_mentioned_npc_ids(text: String, roster: Array) -> Array:
	var out: Array[String] = []
	var t := text.strip_edges()
	if t == "" or roster.is_empty():
		return out

	# Fast path: "Name:" or "npc_id:" at the start of the line (supports spaces in display name).
	for r0 in roster:
		if typeof(r0) != TYPE_DICTIONARY:
			continue
		var r: Dictionary = r0 as Dictionary
		var npc_id := String(r.get("npc_id", "")).strip_edges()
		var display_name := String(r.get("display_name", "")).strip_edges()
		if npc_id != "" and t.begins_with(npc_id + ":"):
			_append_unique(out, npc_id)
		if display_name != "" and t.begins_with(display_name + ":"):
			_append_unique(out, npc_id if npc_id != "" else display_name)

	var by_token: Dictionary = _build_token_to_npc_id(roster)
	# Scan @mentions (token-based).
	var i := 0
	while i < t.length():
		if t.substr(i, 1) != "@":
			i += 1
			continue
		var j := i + 1
		var token := ""
		while j < t.length():
			var ch := t.substr(j, 1)
			if _is_token_delim(ch):
				break
			token += ch
			j += 1
		var key := _norm_token(token)
		if key != "" and by_token.has(key):
			var npc_id2 := String(by_token.get(key, "")).strip_edges()
			if npc_id2 != "":
				_append_unique(out, npc_id2)
		i = j

	return out

static func _build_token_to_npc_id(roster: Array) -> Dictionary:
	var out: Dictionary = {}
	for r0 in roster:
		if typeof(r0) != TYPE_DICTIONARY:
			continue
		var r: Dictionary = r0 as Dictionary
		var npc_id := String(r.get("npc_id", "")).strip_edges()
		var display_name := String(r.get("display_name", "")).strip_edges()
		if npc_id != "":
			out[_norm_token(npc_id)] = npc_id
		if display_name == "":
			continue

		# If the name has no whitespace, allow @FullName.
		if display_name.find(" ") == -1 and display_name.find("\t") == -1:
			out[_norm_token(display_name)] = npc_id

		# Also allow @FirstToken for convenience (e.g. "Bob Lee" -> @Bob).
		var first := display_name.split(" ", false, 1)[0].strip_edges()
		if first != "" and first.length() >= 2:
			out[_norm_token(first)] = npc_id
	return out

static func _norm_token(s: String) -> String:
	# Lowercase ASCII; keep other unicode chars as-is.
	var t := s.strip_edges()
	if t == "":
		return ""
	var out := ""
	for i in range(t.length()):
		var c := t.unicode_at(i)
		if c >= 65 and c <= 90:
			out += String.chr(c + 32)
		else:
			out += String.chr(c)
	return out

static func _is_token_delim(ch: String) -> bool:
	if ch == "" or ch == " " or ch == "\t" or ch == "\n" or ch == "\r":
		return true
	# Common punctuation (ASCII + CJK).
	if ch == "," or ch == "." or ch == ";" or ch == ":" or ch == "!" or ch == "?" or ch == "(" or ch == ")" or ch == "[" or ch == "]":
		return true
	if ch == "，" or ch == "。" or ch == "；" or ch == "：" or ch == "！" or ch == "？" or ch == "（" or ch == "）" or ch == "、":
		return true
	return false

static func _append_unique(arr: Array[String], npc_id: String) -> void:
	var id := npc_id.strip_edges()
	if id == "":
		return
	if not arr.has(id):
		arr.append(id)

