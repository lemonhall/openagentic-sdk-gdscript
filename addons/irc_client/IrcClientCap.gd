extends RefCounted

const IrcCapNegotiation := preload("res://addons/irc_client/IrcCapNegotiation.gd")

var _enabled: bool = false
var _requested_caps: Array[String] = []
var _neg = null

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not _enabled:
		_neg = null

func set_requested_caps(caps: Array) -> void:
	_requested_caps = []
	for c in caps:
		var s := String(c).strip_edges()
		if s != "":
			_requested_caps.append(s)

func is_in_progress() -> bool:
	if _neg == null:
		return false
	return bool(_neg.call("is_started")) and not bool(_neg.call("is_done"))

func on_connected(send_line: Callable) -> void:
	if not _enabled:
		return
	if _requested_caps.is_empty():
		return
	if _neg != null and bool(_neg.call("is_started")):
		return
	_neg = IrcCapNegotiation.new()
	_neg.call("set_requested_caps", _requested_caps)
	for l in (_neg.call("start") as Array[String]):
		send_line.call(l)

func on_message(msg: RefCounted, send_line: Callable) -> bool:
	if _neg == null or msg == null:
		return false
	if not is_in_progress():
		return bool(_neg.call("is_done"))
	for l in (_neg.call("handle_message", msg) as Array[String]):
		send_line.call(l)
	return bool(_neg.call("is_done"))

