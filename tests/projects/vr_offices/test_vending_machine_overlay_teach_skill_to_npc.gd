extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _wait_for_file(path: String, should_exist: bool, max_frames: int = 120) -> bool:
	for _i in range(max_frames):
		if FileAccess.file_exists(path) == should_exist:
			return true
		await process_frame
	return FileAccess.file_exists(path) == should_exist

func _make_zip(save_id: String, skill_name: String, desc: String, zip_name: String) -> String:
	var base_dir := "user://openagentic/saves/%s/shared/test_pack_src_teach_%s" % [save_id, skill_name]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_dir))
	var skill_dir := base_dir + "/" + skill_name
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(skill_dir))
	var md_path := skill_dir + "/SKILL.md"
	var f := FileAccess.open(md_path, FileAccess.WRITE)
	f.store_string("""---
name: %s
description: %s
---
""" % [skill_name, desc])
	f.close()

	var zip_path := "user://openagentic/saves/%s/shared/%s" % [save_id, zip_name]
	var z := ZIPPacker.new()
	z.open(zip_path)
	z.start_file("%s/SKILL.md" % skill_name)
	z.write_file(FileAccess.get_file_as_bytes(md_path))
	z.close_file()
	z.close()
	return zip_path

func _init() -> void:
	var save_id: String = "slot_test_vend_teach_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	var oa := get_root().get_node_or_null("OpenAgentic") as Node
	if oa == null:
		var OAScript := load("res://addons/openagentic/OpenAgentic.gd")
		if OAScript == null:
			T.fail_and_quit(self, "Missing res://addons/openagentic/OpenAgentic.gd")
			return
		oa = (OAScript as Script).new() as Node
		oa.name = "OpenAgentic"
		get_root().add_child(oa)
		await process_frame
	oa.call("set_save_id", save_id)

	# Install one shared skill into the library.
	var InstallerScript := load("res://vr_offices/core/skill_library/VrOfficesSkillPackInstaller.gd")
	if InstallerScript == null:
		T.fail_and_quit(self, "Missing VrOfficesSkillPackInstaller.gd")
		return
	var inst := (InstallerScript as Script).new() as RefCounted
	var skill_name := "teach-me-skill"
	var zip1 := _make_zip(save_id, skill_name, "Teach Me", "teach.zip")
	var rr1: Dictionary = await inst.call("install_zip_for_save", save_id, zip1, {"source": "local-zip"})
	if not T.require_true(self, bool(rr1.get("ok", false)), "Expected install ok"):
		return

	# Create a fake active NPC in the scene group.
	var npc := Node.new()
	npc.name = "npc_test_1"
	npc.add_to_group("vr_offices_npc")
	npc.set_meta("npc_id", "npc_test_1")
	npc.set_meta("display_name", "NPC Test 1")
	npc.set_meta("model_path", "")
	get_root().add_child(npc)

	var OverlayScene := load("res://vr_offices/ui/VendingMachineOverlay.tscn")
	if OverlayScene == null or not (OverlayScene is PackedScene):
		T.fail_and_quit(self, "Missing VendingMachineOverlay.tscn")
		return
	var overlay := (OverlayScene as PackedScene).instantiate() as Control
	get_root().add_child(overlay)
	await process_frame

	if overlay.has_method("open"):
		overlay.call("open")
	await process_frame
	await process_frame

	var list := overlay.get_node_or_null("%LibraryList") as ItemList
	if list == null:
		T.fail_and_quit(self, "Missing %LibraryList")
		return
	if int(list.item_count) < 1:
		T.fail_and_quit(self, "Expected library has at least 1 skill")
		return
	list.select(0)
	await process_frame

	# Teach button should exist and open a picker popup.
	var teach_btn := overlay.get_node_or_null("%LibraryTeachButton") as Button
	if teach_btn == null:
		T.fail_and_quit(self, "Missing %LibraryTeachButton")
		return
	teach_btn.pressed.emit()
	await process_frame

	var learn_btn := overlay.get_node_or_null("%TeachLearnButton") as Button
	if learn_btn == null:
		T.fail_and_quit(self, "Missing %TeachLearnButton")
		return
	learn_btn.pressed.emit()

	var taught_md := "user://openagentic/saves/%s/npcs/%s/workspace/skills/%s/SKILL.md" % [save_id, "npc_test_1", skill_name]
	if not await _wait_for_file(taught_md, true, 240):
		T.fail_and_quit(self, "Expected taught SKILL.md at npc workspace (timed out)")
		return

	T.pass_and_quit(self)
