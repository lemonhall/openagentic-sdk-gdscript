extends RefCounted
class_name OAReplay

static func _safe_json(value) -> String:
	var s := JSON.stringify(value)
	return s if typeof(s) == TYPE_STRING else JSON.stringify(str(value))

static func rebuild_responses_input(events: Array) -> Array:
	# OpenAI Responses requires that every `function_call` item in `input` has a matching
	# `function_call_output` item with the same `call_id`, otherwise the request fails
	# with HTTP 400 ("No tool output found for function call ...").
	#
	# If a previous run crashed after writing `tool.use` but before writing `tool.result`,
	# we synthesize a minimal `function_call_output` so the session remains usable.
	var has_result: Dictionary = {}
	for e0 in events:
		if typeof(e0) != TYPE_DICTIONARY:
			continue
		var t0 := String((e0 as Dictionary).get("type", ""))
		if t0 == "tool.result":
			var cid0 := String((e0 as Dictionary).get("tool_use_id", ""))
			if cid0 != "":
				has_result[cid0] = true

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
				if not has_result.has(call_id):
					out.append({
						"type": "function_call_output",
						"call_id": call_id,
						"output": _safe_json({
							"ok": false,
							"error": "ToolMissingOutput",
							"message": "synthetic tool output (previous run likely crashed before writing tool.result)",
							"call_id": call_id,
						}),
					})
		elif typ == "tool.result":
			var call_id := String(e.get("tool_use_id", ""))
			if call_id != "":
				out.append({"type": "function_call_output", "call_id": call_id, "output": _safe_json(e.get("output", null))})
	return out
