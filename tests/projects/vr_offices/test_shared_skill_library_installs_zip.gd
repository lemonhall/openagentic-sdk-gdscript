extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	# Isolated save slot.
	var save_id: String = "slot_test_skill_lib_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	var oa := get_root().get_node_or_null("OpenAgentic") as Node
	if oa == null:
		var OAScript := load("res://addons/openagentic/OpenAgentic.gd")
		if OAScript == null:
			T.fail_and_quit(self, "Missing res://addons/openagentic/OpenAgentic.gd")
			return
		oa = (OAScript as Script).new() as Node
		if oa == null:
			T.fail_and_quit(self, "Failed to instantiate OpenAgentic.gd")
			return
		oa.name = "OpenAgentic"
		get_root().add_child(oa)
		await process_frame
	oa.call("set_save_id", save_id)

	var InstallerScript := load("res://vr_offices/core/skill_library/VrOfficesSkillPackInstaller.gd")
	if InstallerScript == null:
		T.fail_and_quit(self, "Missing VrOfficesSkillPackInstaller.gd")
		return

	# Build a minimal skill dir in user://, then zip it.
	var base_dir := "user://openagentic/saves/%s/shared/test_pack_src" % save_id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_dir))
	var skill_dir := base_dir + "/skills/hello-skill"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(skill_dir))
	var md_path := skill_dir + "/SKILL.md"
	var f := FileAccess.open(md_path, FileAccess.WRITE)
	if f == null:
		T.fail_and_quit(self, "Failed to write SKILL.md")
		return
	f.store_string("""---
name: hello-skill
description: Hello from zip
---
""")
	f.close()

	var zip_path := "user://openagentic/saves/%s/shared/test_pack.zip" % save_id
	var z := ZIPPacker.new()
	var zerr := z.open(zip_path)
	if not T.require_eq(self, int(zerr), OK, "Expected ZIPPacker.open OK"):
		return
	z.start_file("skills/hello-skill/SKILL.md")
	z.write_file(FileAccess.get_file_as_bytes(md_path))
	z.close_file()
	z.close()

	var inst0: Variant = (InstallerScript as Script).new()
	if not (inst0 is RefCounted):
		T.fail_and_quit(self, "Expected installer RefCounted")
		return
	var inst := inst0 as RefCounted

	var rr0: Variant = inst.call("install_zip_for_save", save_id, zip_path, {"source": "local-zip"})
	var rr: Dictionary = await rr0
	if not T.require_true(self, bool(rr.get("ok", false)), "Expected install ok"):
		return
	var installed: Array = rr.get("installed", [])
	if not T.require_true(self, installed.size() >= 1, "Expected at least 1 installed skill"):
		return

	var dst_md := "user://openagentic/saves/%s/shared/skill_library/hello-skill/SKILL.md" % save_id
	if not T.require_true(self, FileAccess.file_exists(dst_md), "Expected installed SKILL.md exists"):
		return

	var manifest := "user://openagentic/saves/%s/shared/skill_library/index.json" % save_id
	if not T.require_true(self, FileAccess.file_exists(manifest), "Expected manifest exists"):
		return

	T.pass_and_quit(self)

