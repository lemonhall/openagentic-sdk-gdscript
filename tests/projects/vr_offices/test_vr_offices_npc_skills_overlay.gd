extends SceneTree

const T := preload("res://tests/_test_util.gd")
const _OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")

class FakeProvider:
	extends RefCounted
	var calls: int = 0
	var fail_count: int = 0

	func stream(_req: Dictionary, on_event: Callable) -> void:
		# Make this a coroutine so callers can reliably `await` provider.stream(...).
		await (Engine.get_main_loop() as SceneTree).process_frame
		calls += 1
		if fail_count > 0:
			fail_count -= 1
			on_event.call({"type": "done", "error": "fake_error"})
			return
		on_event.call({"type": "text_delta", "delta": "擅长将多项技能组合为可执行方案，沟通清晰，交付稳定。"})
		on_event.call({"type": "done"})

class FakeOpenAgentic:
	extends Node
	var provider: Variant = null
	var model: String = ""

func _write_skill(save_id: String, npc_id: String, skill_name: String, description: String) -> void:
	var dir := _OAPaths.npc_skill_dir(save_id, npc_id, skill_name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var md := dir.rstrip("/") + "/SKILL.md"
	var f := FileAccess.open(md, FileAccess.WRITE)
	if f == null:
		return
	f.store_string("---\nname: %s\ndescription: %s\n---\n\nBody\n" % [skill_name, description])
	f.close()

func _init() -> void:
	var OverlayScene := load("res://vr_offices/ui/VrOfficesNpcSkillsOverlay.tscn")
	if OverlayScene == null or not (OverlayScene is PackedScene):
		T.fail_and_quit(self, "Missing res://vr_offices/ui/VrOfficesNpcSkillsOverlay.tscn")
		return

	var ServiceScript := load("res://vr_offices/core/skills/VrOfficesNpcSkillsService.gd")
	if ServiceScript == null:
		T.fail_and_quit(self, "Missing res://vr_offices/core/skills/VrOfficesNpcSkillsService.gd")
		return

	var save_id: String = "slot_test_npc_skills_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	var npc_id := "npc_1"

	# Arrange: 2 learned skills in the NPC workspace.
	_write_skill(save_id, npc_id, "skill_alpha", "将复杂问题拆解为可执行步骤。")
	_write_skill(save_id, npc_id, "skill_beta", "擅长跨团队协调与复盘。")

	# Act: open overlay and verify cards/uninstall (no OpenAgentic / summary generation involved).
	var overlay := (OverlayScene as PackedScene).instantiate() as Control
	if overlay == null:
		T.fail_and_quit(self, "Failed to instantiate VrOfficesNpcSkillsOverlay.tscn")
		return
	get_root().add_child(overlay)
	await process_frame

	if not T.require_true(self, overlay.has_method("open_for_npc"), "Overlay must have open_for_npc()"):
		return
	overlay.call("open_for_npc", save_id, npc_id, "林晓", "res://vr_offices/npc/Npc.tscn")
	await process_frame

	if not T.require_true(self, overlay.has_method("_test_skill_names"), "Overlay missing _test_skill_names()"):
		return
	var names0: Variant = overlay.call("_test_skill_names")
	if not T.require_true(self, typeof(names0) == TYPE_ARRAY, "Expected _test_skill_names() -> Array"):
		return
	var names: Array = names0 as Array
	if not T.require_eq(self, names.size(), 2, "Expected 2 skill cards"):
		return
	if not T.require_eq(self, String(names[0]), "skill_alpha", "Expected sorted names"):
		return
	if not T.require_eq(self, String(names[1]), "skill_beta", "Expected sorted names"):
		return

	# Uninstall removes directory and refreshes cards.
	if not T.require_true(self, overlay.has_method("_test_uninstall_skill"), "Overlay missing _test_uninstall_skill()"):
		return
	overlay.call("_test_uninstall_skill", "skill_alpha")
	await process_frame
	var abs_alpha := ProjectSettings.globalize_path(_OAPaths.npc_skill_dir(save_id, npc_id, "skill_alpha"))
	if not T.require_true(self, not DirAccess.dir_exists_absolute(abs_alpha), "Expected skill_alpha directory removed"):
		return
	var names2: Array = overlay.call("_test_skill_names") as Array
	if not T.require_eq(self, names2.size(), 1, "Expected 1 skill after uninstall"):
		return
	if not T.require_eq(self, String(names2[0]), "skill_beta", "Expected remaining skill_beta"):
		return

	# Summary generation writes meta.json and is cached by hash (stubbed provider; no network).
	var service := Node.new()
	service.set_script(ServiceScript)
	get_root().add_child(service)

	var oa := FakeOpenAgentic.new()
	oa.name = "OpenAgentic"
	var fake := FakeProvider.new()
	oa.provider = fake
	oa.model = "test-model"
	get_root().add_child(oa)

	if service.has_method("bind_openagentic"):
		service.call("bind_openagentic", oa)

	await process_frame

	if not T.require_true(self, service.has_method("regenerate_profile"), "Service missing regenerate_profile()"):
		return
	var r1: Dictionary = await service.call("regenerate_profile", save_id, npc_id, false)
	if not T.require_true(self, bool(r1.get("ok", false)), "Expected regenerate_profile ok. Got: %s" % JSON.stringify(r1)):
		return
	if not T.require_eq(self, fake.calls, 1, "Expected provider called once"):
		return

	# Re-run without changes should be skipped.
	var r2: Dictionary = await service.call("regenerate_profile", save_id, npc_id, false)
	if not T.require_true(self, bool(r2.get("ok", false)), "Expected regenerate_profile ok (cached)"):
		return
	if not T.require_eq(self, fake.calls, 1, "Expected provider still called once (cached)"):
		return

	# Change skill description => hash changes => provider called again.
	_write_skill(save_id, npc_id, "skill_beta", "擅长跨团队协调、推动共识与落地。")
	var r3: Dictionary = await service.call("regenerate_profile", save_id, npc_id, false)
	if not T.require_true(self, bool(r3.get("ok", false)), "Expected regenerate_profile ok (changed)"):
		return
	if not T.require_eq(self, fake.calls, 2, "Expected provider called again after change"):
		return

	overlay.free()
	service.free()
	oa.free()
	await process_frame

	T.pass_and_quit(self)
