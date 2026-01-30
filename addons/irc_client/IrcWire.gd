extends RefCounted

func format(command: String, params: Array = [], trailing: String = "") -> String:
	# Unlimited formatting helper; v16 typically uses format_with_max_bytes(…, 510).
	return format_with_max_bytes(command, params, trailing, 1024 * 1024)

func format_with_max_bytes(command: String, params: Array = [], trailing: String = "", max_bytes: int = 510, force_trailing: bool = false) -> String:
	var cmd := _sanitize_token(command)
	if cmd == "":
		return ""

	var parts: Array[String] = [cmd]
	for p in params:
		var tok := _sanitize_token(String(p))
		if tok == "":
			# Reject invalid middle parameters rather than silently mutating/dropping them.
			return ""
		parts.append(tok)

	var fixed := " ".join(parts)
	# Defense-in-depth: never allow line breaks in wire output.
	fixed = fixed.replace("\r", "").replace("\n", "")
	if fixed.to_utf8_buffer().size() > max_bytes:
		return ""

	var tr := _sanitize_trailing(trailing)
	if tr == "" and not force_trailing:
		return fixed

	var prefix := fixed + " :"
	var prefix_bytes: int = prefix.to_utf8_buffer().size()
	if prefix_bytes > max_bytes:
		return ""

	var allowed_trailing_bytes: int = max_bytes - prefix_bytes
	var kept := _truncate_utf8_by_bytes(tr, allowed_trailing_bytes)
	return prefix + kept

func format_message(msg: RefCounted) -> String:
	if msg == null:
		return ""
	var command := String((msg as Object).get("command"))
	var params_var = (msg as Object).get("params")
	var trailing := String((msg as Object).get("trailing"))
	var params: Array[String] = []
	if params_var is Array:
		for p in params_var:
			params.append(String(p))
	return format(command, params, trailing)

func _sanitize_token(s: String) -> String:
	var t := s.strip_edges()
	t = t.replace("\r", "").replace("\n", "")
	if t == "":
		return ""
	# Middle tokens must not contain whitespace or start with ':' (that would change meaning).
	if t.begins_with(":"):
		return ""
	if t.find(" ") != -1 or t.find("\t") != -1:
		return ""
	return t

func _sanitize_trailing(s: String) -> String:
	# Trailing may contain spaces, but must not contain line breaks.
	return s.replace("\r", "").replace("\n", "")

func _truncate_utf8_by_bytes(s: String, max_bytes: int) -> String:
	if max_bytes <= 0:
		return ""
	var out := ""
	var used: int = 0
	var i: int = 0
	while i < s.length():
		var ch: String = s.substr(i, 1)
		var ch_bytes: int = ch.to_utf8_buffer().size()
		if used + ch_bytes > max_bytes:
			break
		out += ch
		used += ch_bytes
		i += 1
	return out
