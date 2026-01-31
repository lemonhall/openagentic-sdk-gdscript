extends RefCounted
class_name OA1IrcRpcCodec

static func escape_payload(text: String) -> String:
	# Readable escaping (v40):
	# - "\\" -> "\\\\"
	# - "\r" -> "\\r"
	# - "\n" -> "\\n"
	# - "\t" -> "\\t"
	var out := text
	out = out.replace("\\", "\\\\")
	out = out.replace("\r", "\\r")
	out = out.replace("\n", "\\n")
	out = out.replace("\t", "\\t")
	return out

static func unescape_payload(text: String) -> String:
	# Decode the readable escapes without double-expanding.
	var out := ""
	var i := 0
	while i < text.length():
		var ch := text.substr(i, 1)
		if ch == "\\" and i + 1 < text.length():
			var nxt := text.substr(i + 1, 1)
			if nxt == "n":
				out += "\n"
				i += 2
				continue
			if nxt == "r":
				out += "\r"
				i += 2
				continue
			if nxt == "t":
				out += "\t"
				i += 2
				continue
			if nxt == "\\":
				out += "\\"
				i += 2
				continue
		out += ch
		i += 1
	return out

static func chunk_utf8_by_bytes(text: String, max_bytes: int) -> Array[String]:
	# Byte-safe chunking without splitting UTF-8 codepoints.
	# Implementation: iterate over unicode characters and pack into chunks based on
	# each char's UTF-8 byte size.
	var out: Array[String] = []
	if max_bytes <= 0:
		out.append(text)
		return out
	if text == "":
		out.append("")
		return out

	var parts := PackedStringArray()
	var used := 0
	for i in range(text.length()):
		var ch := text.substr(i, 1)
		var cb := ch.to_utf8_buffer().size()
		if used > 0 and used + cb > max_bytes:
			out.append("".join(parts))
			parts = PackedStringArray()
			used = 0
		parts.append(ch)
		used += cb

	if not parts.is_empty():
		out.append("".join(parts))
	return out

static func make_frame(typ: String, req_id: String, seq: int, more: int, payload_escaped: String) -> String:
	var t := typ.strip_edges().to_upper()
	var id := req_id.strip_edges()
	var s: int = max(1, seq)
	var m: int = 1 if more != 0 else 0
	if payload_escaped == "":
		return "OA1 %s %s %d %d" % [t, id, s, m]
	return "OA1 %s %s %d %d %s" % [t, id, s, m, payload_escaped]

static func parse_frame(line: String) -> Dictionary:
	# Splits into at most 6 parts:
	# OA1 <TYPE> <REQ_ID> <SEQ> <MORE> <PAYLOAD...>
	# Payload is kept as the raw remainder (can include spaces; can be empty).
	var s := line
	if not s.begins_with("OA1 "):
		return {"ok": false}

	var pos := 4
	var a := _read_token(s, pos)
	if not bool(a.ok):
		return {"ok": false}
	var typ: String = String(a.token)
	pos = int(a.next_pos)

	var b := _read_token(s, pos)
	if not bool(b.ok):
		return {"ok": false}
	var req_id: String = String(b.token)
	pos = int(b.next_pos)

	var c := _read_token(s, pos)
	if not bool(c.ok):
		return {"ok": false}
	var seq_s: String = String(c.token)
	pos = int(c.next_pos)

	var d := _read_token(s, pos)
	if not bool(d.ok):
		return {"ok": false}
	var more_s: String = String(d.token)
	pos = int(d.next_pos)

	var payload := ""
	if pos < s.length():
		payload = s.substr(pos)

	var seq := int(seq_s) if seq_s.is_valid_int() else -1
	var more := int(more_s) if more_s.is_valid_int() else -1
	if typ.strip_edges() == "" or req_id.strip_edges() == "" or seq <= 0 or (more != 0 and more != 1):
		return {"ok": false}

	return {
		"ok": true,
		"type": typ.strip_edges().to_upper(),
		"req_id": req_id.strip_edges(),
		"seq": seq,
		"more": more,
		"payload": payload,
	}

static func _read_token(s: String, pos: int) -> Dictionary:
	var i := pos
	# Skip spaces.
	while i < s.length() and s.substr(i, 1) == " ":
		i += 1
	if i >= s.length():
		return {"ok": false}
	var j := s.find(" ", i)
	if j == -1:
		# Token reaches end of string.
		return {"ok": true, "token": s.substr(i), "next_pos": s.length()}
	return {"ok": true, "token": s.substr(i, j - i), "next_pos": j + 1}
