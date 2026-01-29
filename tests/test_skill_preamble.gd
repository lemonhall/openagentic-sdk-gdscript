extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var PathsScript := load("res://addons/openagentic/core/OAPaths.gd")
	var StoreScript := load("res://addons/openagentic/core/OAJsonlNpcSessionStore.gd")
	var RegistryScript := load("res://addons/openagentic/core/OAToolRegistry.gd")
	var GateScript := load("res://addons/openagentic/core/OAAskOncePermissionGate.gd")
	var RunnerScript := load("res://addons/openagentic/core/OAToolRunner.gd")
	var RuntimeScript := load("res://addons/openagentic/runtime/OAAgentRuntime.gd")
	var FsScript := load("res://addons/openagentic/core/OAWorkspaceFs.gd")
	if PathsScript == null or StoreScript == null or RegistryScript == null or GateScript == null or RunnerScript == null or RuntimeScript == null or FsScript == null:
		T.fail_and_quit(self, "Missing OpenAgentic classes")
		return

	var save_id: String = "slot_test_skill_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	var npc_id := "npc_skill_1"
	var SkillsScript := load("res://addons/openagentic/core/OASkills.gd")
	if SkillsScript == null:
		T.fail_and_quit(self, "Missing OASkills")
		return

	# Write SKILL.md into the per-NPC workspace skills directory.
	var root: String = PathsScript.npc_workspace_dir(save_id, npc_id)
	var fs = (FsScript as Script).new(root)
	if fs == null:
		T.fail_and_quit(self, "Failed to instantiate OAWorkspaceFs")
		return
	var skill_text := "# Skill\n\nYou are good at spreadsheets."
	var wr: Dictionary = fs.write_text("skills/spreadsheets/SKILL.md", skill_text)
	if not T.require_true(self, bool(wr.get("ok", false)), "Failed to write SKILL.md"):
		return
	var names: Array[String] = SkillsScript.list_skill_names(save_id, npc_id)
	var found := names.has("spreadsheets")
	if not T.require_true(self, found, "OASkills.list_skill_names didn't find 'spreadsheets': " + str(names)):
		return

	var store = StoreScript.new(save_id)
	var tools = RegistryScript.new()
	var gate = GateScript.new(func(_q: Dictionary, _ctx: Dictionary) -> bool:
		return true
	)
	var runner = RunnerScript.new(tools, gate, store)

	# NOTE: Anonymous functions can't reliably assign to outer-scope variables in all Godot versions,
	# so capture mutable state via a Dictionary.
	var cap := {"saw_skill": false, "last_system": "", "first_item": ""}
	var provider_state := {"called": 0}
	var fake_provider := {"name": "fake"}
	fake_provider["stream"] = func(req: Dictionary, on_event: Callable) -> void:
		provider_state["called"] = int(provider_state.get("called", 0)) + 1
		var instr_v: Variant = req.get("instructions", null)
		cap["first_item"] = "keys=%s typeof(instructions)=%s\n" % [str(req.keys()), str(typeof(instr_v))]
		if typeof(instr_v) == TYPE_STRING:
			var content := String(instr_v)
			cap["last_system"] = content if content.length() <= 800 else (content.substr(0, 800) + "\n...[truncated]...")
			if content.find("NPC skills") != -1 and content.find("spreadsheets") != -1:
				cap["saw_skill"] = true
		else:
			cap["first_item"] += "instructions_value=%s\n" % str(instr_v)
		on_event.call({"type": "done"})

	var rt = RuntimeScript.new(store, runner, tools, fake_provider, "gpt-test")
	var pre0: String = rt._build_system_preamble(save_id, npc_id)
	if not T.require_true(self, typeof(pre0) == TYPE_STRING and String(pre0).find("NPC skills") != -1 and String(pre0).find("spreadsheets") != -1, "System preamble builder didn't include skill. Preamble was:\n" + String(pre0)):
		return
	await rt.run_turn(npc_id, "hello", func(_ev: Dictionary) -> void:
		pass
	, save_id)

	if not T.require_true(self, int(provider_state.get("called", 0)) >= 1, "Provider wasn't called"):
		return
	if not T.require_true(self, String(cap.get("last_system", "")) != "", "No system message found. First input item was:\n" + String(cap.get("first_item", ""))):
		return
	if not T.require_true(self, bool(cap.get("saw_skill", false)), "Expected SKILL.md to be injected into system preamble. System was:\n" + String(cap.get("last_system", ""))):
		return

	T.pass_and_quit(self)
