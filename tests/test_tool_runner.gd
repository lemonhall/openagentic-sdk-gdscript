extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var StoreScript := load("res://addons/openagentic/core/OAJsonlNpcSessionStore.gd")
	var RegistryScript := load("res://addons/openagentic/core/OAToolRegistry.gd")
	var ToolScript := load("res://addons/openagentic/core/OATool.gd")
	var GateScript := load("res://addons/openagentic/core/OAAskOncePermissionGate.gd")
	var RunnerScript := load("res://addons/openagentic/core/OAToolRunner.gd")
	if StoreScript == null or RegistryScript == null or ToolScript == null or GateScript == null or RunnerScript == null:
		T.fail_and_quit(self, "Missing core tool classes")
		return

	var store = StoreScript.new("slot_test_2")
	var tools = RegistryScript.new()

	var echo = ToolScript.new("echo", "echoes input", func(input: Dictionary, _ctx: Dictionary):
		return input
	)
	tools.register(echo)

	var gate = GateScript.new(func(_q: Dictionary, _ctx: Dictionary) -> bool:
		return true
	)
	var runner = RunnerScript.new(tools, gate, store)

	var npc_id := "npc_1"
	await runner.run(npc_id, {"tool_use_id": "call_1", "name": "echo", "input": {"x": 1}})

	var events: Array = store.read_events(npc_id)
	T.assert_true(events.any(func(e): return e.type == "tool.use"), "expected tool.use event")
	T.assert_true(events.any(func(e): return e.type == "tool.result" and e.is_error == false), "expected ok tool.result")

	T.pass_and_quit(self)
