extends RefCounted

static func _extract_error_reason(msg: Object) -> String:
	var reason := String(msg.get("trailing"))
	if reason.strip_edges() == "":
		var params = msg.get("params")
		if params is Array and params.size() > 0:
			reason = String(params[0])
	if reason.strip_edges() == "":
		reason = "server ERROR"
	return reason

func handle_line(
	line: String,
	parser: Object,
	cap: Object,
	ctcp: Object,
	ping: Object,
	send_raw_line: Callable,
	emit_raw_line: Callable,
	emit_message: Callable,
	emit_error: Callable,
	close_connection: Callable,
	on_welcome: Callable,
	on_cap_complete: Callable,
	emit_ctcp_action: Callable,
) -> bool:
	emit_raw_line.call(line)
	var msg = parser.call("parse_line", line)
	emit_message.call(msg)
	if msg == null:
		return false

	var obj := msg as Object
	var cmd := String(obj.get("command"))

	if cmd == "ERROR":
		emit_error.call(_extract_error_reason(obj))
		close_connection.call()
		return true

	if cmd == "001":
		on_welcome.call()

	if bool(cap.call("on_message", msg, func(out: String) -> void: send_raw_line.call(out))):
		on_cap_complete.call()

	ctcp.call("handle_message", msg, func(prefix: String, target: String, text: String) -> void:
		emit_ctcp_action.call(prefix, target, text)
	)
	ping.call("maybe_reply", msg, func(out: String) -> void: send_raw_line.call(out))
	return false

