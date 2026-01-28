extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var StoreScript := load("res://addons/openagentic/core/OAJsonlNpcSessionStore.gd")
	var RegistryScript := load("res://addons/openagentic/core/OAToolRegistry.gd")
	var ToolScript := load("res://addons/openagentic/core/OATool.gd")
	var GateScript := load("res://addons/openagentic/core/OAAskOncePermissionGate.gd")
	var RunnerScript := load("res://addons/openagentic/core/OAToolRunner.gd")
	var RuntimeScript := load("res://addons/openagentic/runtime/OAAgentRuntime.gd")
	if StoreScript == null or RegistryScript == null or ToolScript == null or GateScript == null or RunnerScript == null or RuntimeScript == null:
		T.fail_and_quit(self, "Missing runtime/core classes")
		return

	var store = StoreScript.new("slot_test_3")
	var tools = RegistryScript.new()
	var echo = ToolScript.new("echo", "echoes input", func(input: Dictionary, _ctx: Dictionary):
		return {"echoed": input}
	)
	tools.register(echo)

	var gate = GateScript.new(func(_q: Dictionary, _ctx: Dictionary) -> bool:
		return true
	)
	var runner = RunnerScript.new(tools, gate, store)

	# Fake provider: 1st call produces a tool call; 2nd call produces assistant text.
	var fake_provider := {
		"name": "fake",
		"call_count": 0,
		"stream": func(req: Dictionary, on_event: Callable) -> void:
			fake_provider.call_count += 1
			if fake_provider.call_count == 1:
				on_event.call({"type": "tool_call", "tool_call": {"tool_use_id": "call_1", "name": "echo", "input": {"x": 1}}})
				on_event.call({"type": "done"})
				return
			on_event.call({"type": "text_delta", "delta": "Hi"})
			on_event.call({"type": "text_delta", "delta": "!"})
			on_event.call({"type": "done"})
	}

	var rt = RuntimeScript.new(store, runner, tools, fake_provider, "gpt-test")
	var npc_id := "npc_1"

	await rt.run_turn(npc_id, "hello", func(_ev: Dictionary) -> void:
		pass
	)

	var events: Array = store.read_events(npc_id)
	T.assert_true(events.any(func(e): return e.type == "assistant.delta"), "expected streaming delta events")
	T.assert_true(events.any(func(e): return e.type == "tool.use"), "expected tool.use")
	T.assert_true(events.any(func(e): return e.type == "assistant.message"), "expected assistant.message")
	T.assert_true(events.any(func(e): return e.type == "result"), "expected result event")

	T.pass_and_quit(self)
