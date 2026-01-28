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

	var got_text := ""
	var got_tool := false
	var got_done := false

	parser.parse_from_string(sse, func(ev: Dictionary) -> void:
		if ev.type == "text_delta":
			got_text += ev.delta
		elif ev.type == "tool_call":
			got_tool = true
			T.assert_eq(ev.tool_call.name, "echo")
			T.assert_eq(ev.tool_call.tool_use_id, "call_1")
			T.assert_eq(ev.tool_call.input.x, 1)
		elif ev.type == "done":
			got_done = true
	)

	T.assert_eq(got_text, "Hello")
	T.assert_true(got_tool, "expected tool_call")
	T.assert_true(got_done, "expected done")

	T.pass_and_quit(self)
