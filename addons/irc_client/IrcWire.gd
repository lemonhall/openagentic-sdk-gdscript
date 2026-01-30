extends RefCounted

func format(command: String, params: Array = [], trailing: String = "") -> String:
	var cmd := _sanitize_token(command)
	if cmd == "":
		return ""

	var parts: Array[String] = [cmd]
	for p in params:
		var tok := _sanitize_token(String(p))
		if tok == "":
			continue
		parts.append(tok)

	var out := " ".join(parts)
	var tr := _sanitize_trailing(trailing)
	if tr != "":
		out += " :" + tr

	# Defense-in-depth: never allow line breaks in wire output.
	out = out.replace("\r", "").replace("\n", "")
	return out

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
	# Middle tokens must not contain spaces.
	t = t.replace(" ", "")
	return t

func _sanitize_trailing(s: String) -> String:
	# Trailing may contain spaces, but must not contain line breaks.
	return s.replace("\r", "").replace("\n", "")
