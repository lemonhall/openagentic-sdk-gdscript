extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var StoreScript := load("res://addons/openagentic/core/OAJsonlNpcSessionStore.gd")
	var RegistryScript := load("res://addons/openagentic/core/OAToolRegistry.gd")
	var ToolScript := load("res://addons/openagentic/core/OATool.gd")
	var GateScript := load("res://addons/openagentic/core/OAAskOncePermissionGate.gd")
	var RunnerScript := load("res://addons/openagentic/core/OAToolRunner.gd")
	var HookScript := load("res://addons/openagentic/hooks/OAHookEngine.gd")
	if StoreScript == null or RegistryScript == null or ToolScript == null or GateScript == null or RunnerScript == null or HookScript == null:
		T.fail_and_quit(self, "Missing core tool/hook classes")
		return

	var save_id := "slot_test_hooks_%s" % str(Time.get_ticks_msec())
	var store = StoreScript.new(save_id)
	var tools = RegistryScript.new()

	var echo = ToolScript.new("echo", "echoes input", func(input: Dictionary, _ctx: Dictionary):
		return input
	)
	tools.register(echo)

	var gate = GateScript.new(func(_q: Dictionary, _ctx: Dictionary) -> bool:
		return true
	)

	var hooks = HookScript.new()
	# Rewrite tool input.
	hooks.add_pre_tool_use("rewrite-x", "echo", func(payload: Dictionary) -> Dictionary:
		var ti0: Variant = payload.get("tool_input", {})
		if typeof(ti0) != TYPE_DICTIONARY:
			return {}
		var ti: Dictionary = ti0 as Dictionary
		if int(ti.get("x", 0)) != 1:
			return {}
		var updated := ti.duplicate(true)
		updated["x"] = 2
		return {"override_tool_input": updated, "action": "rewrite_tool_input"}
	)
	# Rewrite tool output.
	hooks.add_post_tool_use("add-y", "echo", func(payload: Dictionary) -> Dictionary:
		var out0: Variant = payload.get("tool_output", null)
		if typeof(out0) != TYPE_DICTIONARY:
			return {}
		var out: Dictionary = out0 as Dictionary
		var updated := out.duplicate(true)
		updated["y"] = 3
		return {"override_tool_output": updated, "action": "rewrite_tool_output"}
	)

	var runner = RunnerScript.new(tools, gate, store, Callable(), hooks)

	var npc_id := "npc_1"
	await runner.run(npc_id, {"tool_use_id": "call_1", "name": "echo", "input": {"x": 1}})

	var events: Array = store.read_events(npc_id)
	var use_events := events.filter(func(e): return typeof(e) == TYPE_DICTIONARY and (e as Dictionary).get("type", "") == "tool.use")
	if not T.require_eq(self, use_events.size(), 1, "Expected exactly 1 tool.use"):
		return
	var used_input: Dictionary = (use_events[0] as Dictionary).get("input", {})
	if not T.require_eq(self, int(used_input.get("x", 0)), 2, "Expected pre-hook to rewrite x=2"):
		return

	var res_events := events.filter(func(e): return typeof(e) == TYPE_DICTIONARY and (e as Dictionary).get("type", "") == "tool.result")
	if not T.require_eq(self, res_events.size(), 1, "Expected exactly 1 tool.result"):
		return
	var out: Dictionary = (res_events[0] as Dictionary).get("output", {})
	if not T.require_eq(self, int(out.get("x", 0)), 2, "Expected tool output to see rewritten input"):
		return
	if not T.require_eq(self, int(out.get("y", 0)), 3, "Expected post-hook to add y=3"):
		return

	var hook_events := events.filter(func(e): return typeof(e) == TYPE_DICTIONARY and (e as Dictionary).get("type", "") == "hook.event")
	if not T.require_true(self, hook_events.size() >= 2, "Expected hook.event entries"):
		return

	# Blocking test.
	var store2 = StoreScript.new(save_id + "_2")
	var hooks2 = HookScript.new()
	hooks2.add_pre_tool_use("block-all", "echo", func(_payload: Dictionary) -> Dictionary:
		return {"block": true, "block_reason": "nope"}
	)
	var runner2 = RunnerScript.new(tools, gate, store2, Callable(), hooks2)
	await runner2.run(npc_id, {"tool_use_id": "call_2", "name": "echo", "input": {"x": 9}})

	var events2: Array = store2.read_events(npc_id)
	var res2 := events2.filter(func(e): return typeof(e) == TYPE_DICTIONARY and (e as Dictionary).get("type", "") == "tool.result")
	if not T.require_eq(self, res2.size(), 1, "Expected 1 blocked tool.result"):
		return
	if not T.require_true(self, bool((res2[0] as Dictionary).get("is_error", false)), "Blocked result should be error"):
		return
	if not T.require_eq(self, String((res2[0] as Dictionary).get("error_type", "")), "HookBlocked", "Expected HookBlocked"):
		return

	T.pass_and_quit(self)

