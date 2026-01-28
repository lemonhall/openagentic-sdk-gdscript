extends RefCounted
class_name OAReplay

static func _safe_json(value) -> String:
	var s := JSON.stringify(value)
	return s if typeof(s) == TYPE_STRING else JSON.stringify(str(value))

static func rebuild_responses_input(events: Array) -> Array:
	var out: Array = []
	for e in events:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var typ := String(e.get("type", ""))
		if typ == "user.message" and typeof(e.get("text", null)) == TYPE_STRING:
			out.append({"role": "user", "content": e.text})
		elif typ == "assistant.message" and typeof(e.get("text", null)) == TYPE_STRING:
			out.append({"role": "assistant", "content": e.text})
		elif typ == "tool.use":
			var call_id := String(e.get("tool_use_id", ""))
			var name := String(e.get("name", ""))
			if call_id != "" and name != "":
				out.append({"type": "function_call", "call_id": call_id, "name": name, "arguments": _safe_json(e.get("input", {}))})
		elif typ == "tool.result":
			var call_id := String(e.get("tool_use_id", ""))
			if call_id != "":
				out.append({"type": "function_call_output", "call_id": call_id, "output": _safe_json(e.get("output", null))})
	return out

