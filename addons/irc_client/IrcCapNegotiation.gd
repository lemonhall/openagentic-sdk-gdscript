extends RefCounted

var _requested: Array[String] = []
var _supported: Dictionary = {}
var _started: bool = false
var _done: bool = false

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
	return ["CAP LS 302"]

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
		var caps := String((msg as Object).get("trailing"))
		_supported = {}
		for c in caps.split(" ", false):
			var cap := String(c).strip_edges()
			if cap != "":
				_supported[cap] = true

		var req: Array[String] = []
		for want in _requested:
			if _supported.has(want):
				req.append(want)

		if req.is_empty():
			_done = true
			return ["CAP END"]
		return ["CAP REQ :%s" % " ".join(req)]

	if sub == "ACK" or sub == "NAK":
		_done = true
		return ["CAP END"]

	return []

