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

	var save_id := "slot_test_3_%s" % str(Time.get_ticks_msec())
	var store = StoreScript.new(save_id)
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
	var provider_state := {"call_count": 0}
	var fake_provider := {"name": "fake"}
	fake_provider["stream"] = func(_req: Dictionary, on_event: Callable) -> void:
		var cc := int(provider_state.get("call_count", 0)) + 1
		provider_state["call_count"] = cc
		if cc == 1:
			on_event.call({"type": "tool_call", "tool_call": {"tool_use_id": "call_1", "name": "echo", "input": {"x": 1}}})
			on_event.call({"type": "done"})
			return
		on_event.call({"type": "text_delta", "delta": "Hi"})
		on_event.call({"type": "text_delta", "delta": "!"})
		on_event.call({"type": "done"})

	var rt = RuntimeScript.new(store, runner, tools, fake_provider, "gpt-test")
	var npc_id := "npc_1"

	await rt.run_turn(npc_id, "hello", func(_ev: Dictionary) -> void:
		pass
	)

	var events: Array = store.read_events(npc_id)
	if not T.require_true(self, events.any(func(e): return typeof(e) == TYPE_DICTIONARY and e.get("type", "") == "assistant.delta"), "expected streaming delta events"):
		return
	if not T.require_true(self, events.any(func(e): return typeof(e) == TYPE_DICTIONARY and e.get("type", "") == "tool.use"), "expected tool.use"):
		return
	if not T.require_true(self, events.any(func(e): return typeof(e) == TYPE_DICTIONARY and e.get("type", "") == "assistant.message"), "expected assistant.message"):
		return
	if not T.require_true(self, events.any(func(e): return typeof(e) == TYPE_DICTIONARY and e.get("type", "") == "result"), "expected result event"):
		return

	T.pass_and_quit(self)
