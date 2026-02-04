extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var MediaRefScript := load("res://addons/openagentic/core/OAMediaRef.gd")
	if MediaRefScript == null:
		T.fail_and_quit(self, "Missing OAMediaRef.gd")
		return
	var MediaRef := MediaRefScript as Script

	var ref := {
		"id": "img_" + "a".repeat(16),
		"kind": "image",
		"mime": "image/png",
		"bytes": 123,
		"sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
		"name": "t.png",
		"caption": "c".repeat(64),
	}
	var line: String = MediaRef.call("encode_v1", ref)
	if not T.require_true(self, line.begins_with("OAMEDIA1 "), "Expected OAMEDIA1 line"):
		return
	if not T.require_true(self, line.length() <= 512, "Expected <=512"):
		return

	# Force fragmentation for the test.
	var max_len := 80
	if not T.require_true(self, line.length() > max_len, "Precondition: line must exceed max_len"):
		return
	if not (MediaRef as Object).has_method("irc_encode_lines"):
		T.fail_and_quit(self, "OAMediaRef missing irc_encode_lines()")
		return
	var lines0: Variant = MediaRef.call("irc_encode_lines", line, max_len)
	if not T.require_true(self, typeof(lines0) == TYPE_ARRAY, "irc_encode_lines must return Array"):
		return
	var lines: Array = lines0 as Array
	if not T.require_true(self, lines.size() >= 2, "Expected fragmented lines"):
		return
	for l0 in lines:
		var l := String(l0)
		if not T.require_true(self, l.length() <= max_len, "Each line must fit max_len"):
			return
		if not T.require_true(self, not l.begins_with("OA1 "), "Must not conflict with OA1"):
			return
		if not T.require_true(self, l.begins_with("OAMEDIA1F "), "Fragments must use OAMEDIA1F"):
			return

	# Reassemble.
	var state := {"mid": "", "total": 0, "parts": {}}
	for l0 in lines:
		if not (MediaRef as Object).has_method("irc_parse_fragment"):
			T.fail_and_quit(self, "OAMediaRef missing irc_parse_fragment()")
			return
		var p0: Variant = MediaRef.call("irc_parse_fragment", String(l0))
		if not T.require_true(self, typeof(p0) == TYPE_DICTIONARY and bool((p0 as Dictionary).get("ok", false)), "parse_fragment ok"):
			return
		var p: Dictionary = p0 as Dictionary
		var mid := String(p.get("message_id", ""))
		var idx := int(p.get("index", 0))
		var total := int(p.get("total", 0))
		var payload := String(p.get("payload_part", ""))
		if state.mid == "":
			state.mid = mid
			state.total = total
		if not T.require_eq(self, mid, state.mid, "mid consistent"):
			return
		if not T.require_eq(self, total, state.total, "total consistent"):
			return
		state.parts[idx] = payload

	if not (MediaRef as Object).has_method("irc_reassemble"):
		T.fail_and_quit(self, "OAMediaRef missing irc_reassemble()")
		return
	var r0: Variant = MediaRef.call("irc_reassemble", String(state.mid), int(state.total), state.parts)
	if not T.require_true(self, typeof(r0) == TYPE_DICTIONARY and bool((r0 as Dictionary).get("ok", false)), "reassemble ok"):
		return
	var rebuilt := String((r0 as Dictionary).get("line", ""))
	if not T.require_eq(self, rebuilt, line, "reassembled line matches"):
		return

	T.pass_and_quit(self)
