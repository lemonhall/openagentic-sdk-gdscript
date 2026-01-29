extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var StoreScript := load("res://addons/openagentic/core/OAJsonlNpcSessionStore.gd")
	var RegistryScript := load("res://addons/openagentic/core/OAToolRegistry.gd")
	var GateScript := load("res://addons/openagentic/core/OAAskOncePermissionGate.gd")
	var RunnerScript := load("res://addons/openagentic/core/OAToolRunner.gd")
	var RuntimeScript := load("res://addons/openagentic/runtime/OAAgentRuntime.gd")
	var HookScript := load("res://addons/openagentic/hooks/OAHookEngine.gd")
	if StoreScript == null or RegistryScript == null or GateScript == null or RunnerScript == null or RuntimeScript == null or HookScript == null:
		T.fail_and_quit(self, "Missing runtime/core/hook classes")
		return

	var save_id := "slot_test_turn_hooks_%s" % str(Time.get_ticks_msec())
	var store = StoreScript.new(save_id)
	var tools = RegistryScript.new()

	var gate = GateScript.new(func(_q: Dictionary, _ctx: Dictionary) -> bool:
		return true
	)

	# Fake provider that streams a short message.
	var provider_state := {"call_count": 0}
	var fake_provider := {"name": "fake"}
	fake_provider["stream"] = func(_req: Dictionary, on_event: Callable) -> void:
		provider_state["call_count"] = int(provider_state.get("call_count", 0)) + 1
		on_event.call({"type": "text_delta", "delta": "Hi"})
		on_event.call({"type": "done"})

	# Turn hooks should emit hook.event entries.
	var hooks = HookScript.new()
	if not hooks.has_method("add_before_turn"):
		T.fail_and_quit(self, "Hook engine missing add_before_turn()")
		return
	if not hooks.has_method("add_after_turn"):
		T.fail_and_quit(self, "Hook engine missing add_after_turn()")
		return

	hooks.add_before_turn("before-any", "*", func(_payload: Dictionary) -> Dictionary:
		return {"action": "before_called"}
	)
	hooks.add_after_turn("after-any", "*", func(_payload: Dictionary) -> Dictionary:
		return {"action": "after_called"}
	)

	var runner = RunnerScript.new(tools, gate, store, Callable(), hooks)
	var rt = RuntimeScript.new(store, runner, tools, fake_provider, "gpt-test", hooks)
	var npc_id := "npc_1"

	await rt.run_turn(npc_id, "hello", func(_ev: Dictionary) -> void:
		pass
	, save_id)

	var events: Array = store.read_events(npc_id)
	var hook_events := events.filter(func(e): return typeof(e) == TYPE_DICTIONARY and (e as Dictionary).get("type", "") == "hook.event")
	if not T.require_true(self, hook_events.any(func(e): return String((e as Dictionary).get("hook_point", "")) == "BeforeTurn"), "Expected BeforeTurn hook.event"):
		return
	if not T.require_true(self, hook_events.any(func(e): return String((e as Dictionary).get("hook_point", "")) == "AfterTurn"), "Expected AfterTurn hook.event"):
		return

	# Block behavior: before_turn can stop the turn before provider is called.
	var store2 = StoreScript.new(save_id + "_2")
	var provider_state2 := {"call_count": 0}
	var fake_provider2 := {"name": "fake2"}
	fake_provider2["stream"] = func(_req: Dictionary, _on_event: Callable) -> void:
		provider_state2["call_count"] = int(provider_state2.get("call_count", 0)) + 1

	var hooks2 = HookScript.new()
	hooks2.add_before_turn("block", "*", func(_payload: Dictionary) -> Dictionary:
		return {"block": true, "block_reason": "nope", "action": "block_turn"}
	)

	var runner2 = RunnerScript.new(tools, gate, store2, Callable(), hooks2)
	var rt2 = RuntimeScript.new(store2, runner2, tools, fake_provider2, "gpt-test", hooks2)
	await rt2.run_turn(npc_id, "hello", func(_ev: Dictionary) -> void:
		pass
	, save_id)

	if not T.require_eq(self, int(provider_state2.get("call_count", 0)), 0, "Provider should not be called when BeforeTurn blocks"):
		return
	var events2: Array = store2.read_events(npc_id)
	var results := events2.filter(func(e): return typeof(e) == TYPE_DICTIONARY and (e as Dictionary).get("type", "") == "result")
	if not T.require_true(self, results.size() >= 1, "Expected a result event for blocked turn"):
		return
	var last_result: Dictionary = results[results.size() - 1] as Dictionary
	if not T.require_eq(self, String(last_result.get("stop_reason", "")), "hook_blocked", "Expected stop_reason=hook_blocked"):
		return

	T.pass_and_quit(self)

