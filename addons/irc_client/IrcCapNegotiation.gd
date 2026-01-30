extends RefCounted

var _requested: Array[String] = []
var _supported: Dictionary = {}
var _acked: Dictionary = {}
var _started: bool = false
var _done: bool = false
var _ls_collecting: bool = false
var _ack_collecting: bool = false

func _cap_name(token: String) -> String:
	var eq: int = token.find("=")
	if eq == -1:
		return token
	return token.substr(0, eq)

func _has_more_marker(params: Variant) -> bool:
	if not (params is Array):
		return false
	var a: Array = params
	# Spec uses trailing '*' param for multiline (e.g. "CAP nick LS * :...").
	for i in range(2, a.size()):
		if String(a[i]) == "*":
			return true
	return false

func _extract_caps_tokens(msg: RefCounted) -> Array[String]:
	# Prefer the standard trailing form (":cap cap2 ..."), but tolerate servers that
	# send the list as regular params (no ':').
	var trailing: String = String((msg as Object).get("trailing"))
	if trailing.strip_edges() != "":
		var parts: PackedStringArray = trailing.split(" ", false)
		var out: Array[String] = []
		for p in parts:
			out.append(String(p))
		return out

	var params = (msg as Object).get("params")
	if not (params is Array):
		return []
	var a: Array = params
	var out2: Array[String] = []
	for i in range(2, a.size()):
		var tok := String(a[i]).strip_edges()
		if tok == "" or tok == "*" or tok == "302":
			continue
		out2.append(tok)
	return out2

func set_requested_caps(caps: Array) -> void:
	_requested = []
	for c in caps:
		var s := String(c).strip_edges()
		if s != "":
			_requested.append(s)

func is_started() -> bool:
	return _started

func is_done() -> bool:
	return _done

func start() -> Array[String]:
	if _started:
		return []
	_started = true
	_done = false
	_supported = {}
	_acked = {}
	_ls_collecting = false
	_ack_collecting = false
	return ["CAP LS 302"]

func get_acked_caps() -> Array[String]:
	var out: Array[String] = []
	for k in _acked.keys():
		out.append(String(k))
	return out

func handle_message(msg: RefCounted) -> Array[String]:
	if _done or msg == null:
		return []
	var cmd := String((msg as Object).get("command"))
	if cmd != "CAP":
		return []

	var params = (msg as Object).get("params")
	var sub := ""
	if params is Array and params.size() >= 2:
		sub = String(params[1])

	if sub == "LS":
		var has_more: bool = _has_more_marker(params)
		if not _ls_collecting:
			_supported = {}
			_ls_collecting = true

		for c in _extract_caps_tokens(msg):
			var tok := String(c).strip_edges()
			if tok == "":
				continue
			var name := _cap_name(tok)
			if name != "":
				_supported[name] = true

		if has_more:
			return []

		_ls_collecting = false

		var req: Array[String] = []
		for want_raw in _requested:
			var want := _cap_name(want_raw)
			if want != "" and _supported.has(want):
				req.append(want)

		if req.is_empty():
			_done = true
			return []
		return ["CAP REQ :%s" % " ".join(req)]

	if sub == "ACK" or sub == "NAK":
		var has_more_ack: bool = _has_more_marker(params)
		if not _ack_collecting:
			_acked = {}
			_ack_collecting = true

		for c2 in _extract_caps_tokens(msg):
			var tok2 := String(c2).strip_edges()
			if tok2 == "":
				continue
			var name2 := _cap_name(tok2)
			if name2 != "":
				_acked[name2] = true

		if has_more_ack:
			return []

		_ack_collecting = false
		_done = true
		return []

	return []
