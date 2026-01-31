extends SceneTree

const T := preload("res://tests/_test_util.gd")

class HiddenTool:
	extends RefCounted

	var name := "HiddenTool"
	var description := "A tool that should be hidden when is_available(ctx)=false."
	var input_schema := {"type": "object", "properties": {}}

	func is_available(_ctx: Dictionary) -> bool:
		return false

func _init() -> void:
	var root: Node = get_root()

	var OAScript := load("res://addons/openagentic/OpenAgentic.gd")
	if OAScript == null:
		T.fail_and_quit(self, "Missing OpenAgentic.gd")
		return
	var oa: Node = (OAScript as Script).new()
	oa.name = "OpenAgentic"
	root.add_child(oa)

	var RegistryScript := load("res://addons/openagentic/core/OAToolRegistry.gd")
	if RegistryScript == null:
		T.fail_and_quit(self, "Missing OAToolRegistry")
		return
	oa.set("tools", RegistryScript.new())

	oa.call("register_tool", HiddenTool.new())

	var save_id: String = "slot_test_tool_avail_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	oa.set("save_id", save_id)

	var captured: Array[String] = []
	var fake_provider := {"name": "fake"}
	fake_provider["stream"] = func(req: Dictionary, on_event: Callable) -> void:
		var tools_v: Variant = req.get("tools", null)
		if typeof(tools_v) == TYPE_ARRAY:
			for t0 in tools_v as Array:
				if typeof(t0) != TYPE_DICTIONARY:
					continue
				var t: Dictionary = t0 as Dictionary
				captured.append(String(t.get("name", "")))
		on_event.call({"type": "done"})

	oa.set("provider", fake_provider)
	oa.set("model", "gpt-test")
	oa.set_approver(func(_q: Dictionary, _ctx: Dictionary) -> bool:
		return true
	)

	await oa.run_npc_turn("npc_avail_1", "hello", func(_ev: Dictionary) -> void:
		pass
	)

	# Expected after implementation: HiddenTool must be excluded from schema list.
	if not T.require_true(self, not captured.has("HiddenTool"), "HiddenTool must not appear in tool schemas when is_available(ctx)=false. Got: " + str(captured)):
		return

	T.pass_and_quit(self)

