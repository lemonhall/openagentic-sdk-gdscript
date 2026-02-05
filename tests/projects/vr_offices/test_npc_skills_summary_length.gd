extends SceneTree

const T := preload("res://tests/_test_util.gd")

class FakeProvider:
	extends RefCounted

	func stream(_req: Dictionary, on_event: Callable) -> void:
		await (Engine.get_main_loop() as SceneTree).process_frame
		var s := ""
		for _i in range(600):
			s += "长"
		on_event.call({"type": "text_delta", "delta": s})
		on_event.call({"type": "done"})

class FakeOpenAgentic:
	extends Node
	var provider: Variant = null
	var model: String = ""

func _init() -> void:
	var ServiceScript := load("res://vr_offices/core/skills/VrOfficesNpcSkillsService.gd")
	if ServiceScript == null:
		T.fail_and_quit(self, "Missing VrOfficesNpcSkillsService.gd")
		return

	var oa := FakeOpenAgentic.new()
	oa.name = "OpenAgentic"
	oa.provider = FakeProvider.new()
	oa.model = "test-model"
	get_root().add_child(oa)

	var svc := Node.new()
	svc.set_script(ServiceScript)
	get_root().add_child(svc)
	if svc.has_method("bind_openagentic"):
		svc.call("bind_openagentic", oa)

	await process_frame

	# Exercise regenerate_profile by writing a minimal skill into the NPC workspace.
	var save_id := "slot_test_summary_len_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	var npc_id := "npc_len"
	var OAPaths := load("res://addons/openagentic/core/OAPaths.gd")
	var root: String = String((OAPaths as Script).call("npc_skill_dir", save_id, npc_id, "alpha"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	var md: String = root.rstrip("/") + "/SKILL.md"
	var f := FileAccess.open(md, FileAccess.WRITE)
	if f == null:
		T.fail_and_quit(self, "Failed to write SKILL.md")
		return
	f.store_string("---\nname: alpha\ndescription: x\n---\n\nBody\n")
	f.close()

	var rr: Dictionary = await svc.call("regenerate_profile", save_id, npc_id, true)
	if not T.require_true(self, bool(rr.get("ok", false)), "Expected regenerate_profile ok"):
		return
	var summary := String(rr.get("summary", "")).strip_edges()
	if not T.require_true(self, summary.length() > 150, "Summary length should exceed old 150-char limit"):
		return
	if not T.require_true(self, summary.length() <= 260, "Summary should be clamped to a reasonable 2-line limit"):
		return

	svc.free()
	oa.free()
	await process_frame
	T.pass_and_quit(self)
