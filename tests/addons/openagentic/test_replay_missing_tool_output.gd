extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var ReplayScript := load("res://addons/openagentic/runtime/OAReplay.gd")
	if ReplayScript == null:
		T.fail_and_quit(self, "Missing OAReplay")
		return

	var events: Array = [
		{"type": "user.message", "text": "hi"},
		{"type": "tool.use", "tool_use_id": "call_123", "name": "WebFetch", "input": {"url": "https://example.com"}},
		# Intentionally missing tool.result.
	]

	var input_items: Array = (ReplayScript as Script).call("rebuild_responses_input", events)
	var has_call := false
	var has_out := false
	var out_text := ""
	for it0 in input_items:
		if typeof(it0) != TYPE_DICTIONARY:
			continue
		var it: Dictionary = it0 as Dictionary
		if String(it.get("type", "")) == "function_call" and String(it.get("call_id", "")) == "call_123":
			has_call = true
		if String(it.get("type", "")) == "function_call_output" and String(it.get("call_id", "")) == "call_123":
			has_out = true
			out_text = String(it.get("output", ""))

	if not T.require_true(self, has_call, "Expected function_call item"):
		return
	if not T.require_true(self, has_out, "Expected synthesized function_call_output item"):
		return
	if not T.require_true(self, out_text.find("ToolMissingOutput") != -1, "Expected ToolMissingOutput in output JSON"):
		return

	T.pass_and_quit(self)

