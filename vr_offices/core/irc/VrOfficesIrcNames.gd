extends Object

static func _sha256_hex(s: String) -> String:
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	hc.update(s.to_utf8_buffer())
	return hc.finish().hex_encode()

static func derive_nick(save_id: String, desk_id: String, nicklen: int) -> String:
	var nlen := nicklen
	if nlen < 1:
		nlen = 1
	var prefix := "oa"
	var digest := _sha256_hex("%s:%s" % [save_id, desk_id])
	var need := nlen - prefix.length()
	if need <= 0:
		return prefix.substr(0, nlen)
	return (prefix + digest.substr(0, need)).substr(0, nlen)

static func derive_channel(save_id: String, desk_id: String, channellen: int) -> String:
	return derive_channel_for_workspace(save_id, "", desk_id, channellen)

static func _sanitize_token(s: String) -> String:
	var out := ""
	var last_us := false
	for i in range(s.length()):
		var c := s.unicode_at(i)
		var is_alnum := (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122)
		if is_alnum:
			out += String.chr(c).to_lower()
			last_us = false
		else:
			if not last_us:
				out += "_"
				last_us = true
	# Trim underscores.
	out = out.strip_edges()
	while out.begins_with("_"):
		out = out.substr(1)
	while out.ends_with("_"):
		out = out.substr(0, out.length() - 1)
	if out == "":
		return "x"
	return out

static func derive_channel_for_workspace(save_id: String, workspace_id: String, desk_id: String, channellen: int) -> String:
	var clen := channellen
	if clen < 1:
		clen = 1
	var prefix := "#oa_"
	if clen <= prefix.length():
		return prefix.substr(0, clen)

	var ws := _sanitize_token(workspace_id)
	var desk := _sanitize_token(desk_id)
	var digest := _sha256_hex("%s:%s:%s" % [save_id, workspace_id, desk_id]).substr(0, 8)

	# Prefer a meaningful channel name, with a short digest suffix for uniqueness.
	var body := "ws_%s_%s_%s" % [ws, desk, digest]
	body = _sanitize_token(body)
	var ch := (prefix + body)
	if ch.length() <= clen:
		return ch

	# If too long, shrink the meaningful parts but keep ws + desk hint if possible.
	var ws_short := ws.substr(0, 10)
	var desk_short := desk.substr(0, 12)
	body = _sanitize_token("ws_%s_%s_%s" % [ws_short, desk_short, digest])
	ch = prefix + body
	if ch.length() <= clen:
		return ch

	# Last resort: just hash (still deterministic).
	var need := clen - prefix.length()
	return (prefix + _sha256_hex("%s:%s:%s" % [save_id, workspace_id, desk_id]).substr(0, max(0, need))).substr(0, clen)
