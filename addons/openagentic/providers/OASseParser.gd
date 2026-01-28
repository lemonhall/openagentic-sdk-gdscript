extends RefCounted
class_name OASseParser

var _ongoing: Dictionary = {} # output_index -> {call_id,name,arguments}
var _event_data: Array[String] = []
func _parse_tool_arguments(raw) -> Dictionary:
	if typeof(raw) == TYPE_DICTIONARY:
		return raw
	if typeof(raw) == TYPE_STRING:
		var trimmed := String(raw).strip_edges()
		if trimmed == "":
			return {}
		var parsed = JSON.parse_string(trimmed)
		if typeof(parsed) == TYPE_DICTIONARY:
			return parsed
		return {"_raw": parsed}
	return {"_raw": raw}

func reset() -> void:
	_ongoing = {}
	_event_data = []

func feed_line(raw_line: String, on_event: Callable) -> bool:
	var line := String(raw_line).rstrip("\r\n")
	if line.strip_edges() == "":
		if _event_data.size() == 0:
			return false
		var data := "\n".join(_event_data)
		_event_data.clear()
		return _handle_data(data, on_event)
	if line.begins_with("data:"):
		_event_data.append(line.substr(5).lstrip(" "))
	return false

func parse_from_string(sse: String, on_event: Callable) -> void:
	reset()
	var start := 0
	while true:
		var idx := sse.find("\n", start)
		if idx < 0:
			var tail := sse.substr(start)
			var done_tail := feed_line(tail, on_event)
			if done_tail:
				return
			break
		var line := sse.substr(start, idx - start)
		var done := feed_line(line, on_event)
		if done:
			return
		start = idx + 1
	# Flush.
	if _event_data.size() > 0:
		_handle_data("\n".join(_event_data), on_event)

func _handle_data(data: String, on_event: Callable) -> bool:
	var trimmed := data.strip_edges()
	if trimmed == "[DONE]":
		on_event.call({"type": "done"})
		return true
	var obj = JSON.parse_string(trimmed)
	if typeof(obj) != TYPE_DICTIONARY:
		return false
	var typ := String(obj.get("type", ""))

	if typ == "response.output_text.delta":
		var delta: String = String(obj.get("delta", ""))
		if delta != "":
			on_event.call({"type": "text_delta", "delta": delta})
		return false

	if typ == "response.output_item.added":
		var idx_v = obj.get("output_index", null)
		var item = obj.get("item", null)
		if (typeof(idx_v) == TYPE_INT or typeof(idx_v) == TYPE_FLOAT) and typeof(item) == TYPE_DICTIONARY and String(item.get("type", "")) == "function_call":
			var idx := int(idx_v)
			var call_id := String(item.get("call_id", ""))
			var name := String(item.get("name", ""))
			if call_id != "" and name != "":
				_ongoing[idx] = {"call_id": call_id, "name": name, "arguments": ""}
		return false

	if typ == "response.function_call_arguments.delta":
		var idx_v = obj.get("output_index", null)
		var delta: String = String(obj.get("delta", ""))
		if typeof(idx_v) == TYPE_INT or typeof(idx_v) == TYPE_FLOAT:
			var idx := int(idx_v)
			var st: Dictionary = _ongoing.get(idx, {})
			if st.size() > 0:
				st["arguments"] = String(st.get("arguments", "")) + String(delta)
				_ongoing[idx] = st
		return false

	if typ == "response.output_item.done":
		var idx_v = obj.get("output_index", null)
		var item = obj.get("item", null)
		if (typeof(idx_v) == TYPE_INT or typeof(idx_v) == TYPE_FLOAT) and typeof(item) == TYPE_DICTIONARY and String(item.get("type", "")) == "function_call":
			var idx := int(idx_v)
			var st: Dictionary = _ongoing.get(idx, {})
			var call_id := String(st.get("call_id", item.get("call_id", "")))
			var name := String(st.get("name", item.get("name", "")))
			var args := st.get("arguments", item.get("arguments", ""))
			if call_id != "" and name != "":
				on_event.call({"type": "tool_call", "tool_call": {"tool_use_id": call_id, "name": name, "input": _parse_tool_arguments(args)}})
		return false

	# Ignore other event types for v1 parser.
	return false
