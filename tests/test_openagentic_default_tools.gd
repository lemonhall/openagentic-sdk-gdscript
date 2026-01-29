extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var oa := get_node_or_null("/root/OpenAgentic")
	if oa == null:
		T.fail_and_quit(self, "Missing autoload: OpenAgentic")
		return

	# Reset tool registry to simulate a host game that forgot to enable tools.
	var RegistryScript := load("res://addons/openagentic/core/OAToolRegistry.gd")
	if RegistryScript == null:
		T.fail_and_quit(self, "Missing OAToolRegistry")
		return
	oa.set("tools", RegistryScript.new())

	var save_id: String = "slot_test_default_tools_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	oa.set("save_id", save_id)

	var captured := {"tool_names": []}
	var fake_provider := {"name": "fake"}
	fake_provider["stream"] = func(req: Dictionary, on_event: Callable) -> void:
		var tools_v: Variant = req.get("tools", null)
		if typeof(tools_v) == TYPE_ARRAY:
			for t0 in tools_v as Array:
				if typeof(t0) != TYPE_DICTIONARY:
					continue
				var t: Dictionary = t0 as Dictionary
				captured["tool_names"].append(String(t.get("name", "")))
		on_event.call({"type": "done"})

	oa.set("provider", fake_provider)
	oa.set("model", "gpt-test")
	oa.set_approver(func(_q: Dictionary, _ctx: Dictionary) -> bool:
		return true
	)

	await oa.run_npc_turn("npc_tools_1", "hello", func(_ev: Dictionary) -> void:
		pass
	)

	var tool_names: Array = captured.get("tool_names", [])
	var have_read := tool_names.has("Read")
	var have_skill := tool_names.has("Skill")
	if not T.require_true(self, have_read and have_skill, "Expected default tools to be enabled automatically. Got: " + str(tool_names)):
		return

	T.pass_and_quit(self)

