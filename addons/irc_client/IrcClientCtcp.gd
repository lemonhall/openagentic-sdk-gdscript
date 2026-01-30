extends RefCounted

const SOH := "\u0001"

func send_action(target: String, text: String, send_line: Callable) -> void:
	send_line.call("PRIVMSG %s :%sACTION %s%s" % [target, SOH, text, SOH])

func handle_message(msg: RefCounted, emit_action: Callable) -> void:
	if msg == null:
		return
	var obj := msg as Object
	var cmd := String(obj.get("command"))
	if cmd != "PRIVMSG":
		return
	var params = obj.get("params")
	if not (params is Array) or params.size() < 1:
		return
	var trailing := String(obj.get("trailing"))
	if not (trailing.begins_with(SOH) and trailing.ends_with(SOH) and trailing.length() >= 2):
		return
	var inner := trailing.substr(1, trailing.length() - 2)
	if not inner.begins_with("ACTION "):
		return
	var text := inner.substr(7)
	var prefix := String(obj.get("prefix"))
	var target := String(params[0])
	emit_action.call(prefix, target, text)

