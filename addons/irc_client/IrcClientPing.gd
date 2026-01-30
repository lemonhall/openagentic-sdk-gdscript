extends RefCounted

func maybe_reply(msg: RefCounted, send_line: Callable) -> void:
	# Minimal keepalive: reply to server PING.
	if msg == null:
		return
	var cmd := String((msg as Object).get("command"))
	if cmd != "PING":
		return

	var payload := String((msg as Object).get("trailing"))
	if payload.strip_edges() != "":
		send_line.call("PONG :%s" % payload)
		return

	var params = (msg as Object).get("params")
	if params is Array and params.size() > 0:
		send_line.call("PONG %s" % String(params[0]))
		return

	send_line.call("PONG")

