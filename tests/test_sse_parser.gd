extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var ParserScript := load("res://addons/openagentic/providers/OASseParser.gd")
	if ParserScript == null:
		T.fail_and_quit(self, "Missing OASseParser.gd")
		return

	var parser = ParserScript.new()

	var sse := ""
	sse += "data: {\"type\":\"response.output_text.delta\",\"delta\":\"He\"}\n\n"
	sse += "data: {\"type\":\"response.output_text.delta\",\"delta\":\"llo\"}\n\n"
	sse += "data: {\"type\":\"response.output_item.added\",\"output_index\":0,\"item\":{\"type\":\"function_call\",\"call_id\":\"call_1\",\"name\":\"echo\"}}\n\n"
	sse += "data: {\"type\":\"response.function_call_arguments.delta\",\"output_index\":0,\"delta\":\"{\\\"x\\\":1\"}\n\n"
	sse += "data: {\"type\":\"response.function_call_arguments.delta\",\"output_index\":0,\"delta\":\"}\"}\n\n"
	sse += "data: {\"type\":\"response.output_item.done\",\"output_index\":0,\"item\":{\"type\":\"function_call\",\"call_id\":\"call_1\",\"name\":\"echo\",\"arguments\":\"{\\\\\\\"x\\\\\\\":1}\"}}\n\n"
	sse += "data: [DONE]\n\n"

	var state := {"text": "", "tool": false, "done": false}

	parser.parse_from_string(sse, func(ev: Dictionary) -> void:
		var t := String(ev.get("type", ""))
		if t == "text_delta":
			state["text"] = String(state.get("text", "")) + String(ev.get("delta", ""))
		elif t == "tool_call":
			state["tool"] = true
			var tc: Dictionary = ev.get("tool_call", {})
			if String(tc.get("name", "")) != "echo" or String(tc.get("tool_use_id", "")) != "call_1":
				T.fail_and_quit(self, "unexpected tool_call: " + JSON.stringify(ev))
				return
			var tc_input: Dictionary = tc.get("input", {})
			if tc_input.get("x", null) != 1:
				T.fail_and_quit(self, "unexpected tool_call input: " + JSON.stringify(ev))
				return
		elif t == "done":
			state["done"] = true
	)

	var got_text := String(state.get("text", ""))
	var got_tool := bool(state.get("tool", false))
	var got_done := bool(state.get("done", false))
	if got_text != "Hello" or not got_tool or not got_done:
		T.fail_and_quit(self, "parse failed: got_text=%s got_tool=%s got_done=%s" % [got_text, str(got_tool), str(got_done)])
		return

	T.pass_and_quit(self)
