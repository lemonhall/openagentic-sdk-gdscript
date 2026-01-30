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
		var parts: Array[String] = []
		for p in params:
			var s := String(p)
			if s != "":
				parts.append(s)
		if parts.is_empty():
			send_line.call("PONG")
		else:
			send_line.call("PONG %s" % " ".join(parts))
		return

	send_line.call("PONG")
