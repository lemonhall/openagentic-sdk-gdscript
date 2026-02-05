extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _make_zip(save_id: String, skill_name: String, desc: String, zip_name: String) -> String:
	var base_dir := "user://openagentic/saves/%s/shared/test_pack_src_%s" % [save_id, skill_name]
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
	var save_id: String = "slot_test_vend_lib_manage_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
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

	var InstallerScript := load("res://vr_offices/core/skill_library/VrOfficesSkillPackInstaller.gd")
	if InstallerScript == null:
		T.fail_and_quit(self, "Missing VrOfficesSkillPackInstaller.gd")
		return
	var inst := (InstallerScript as Script).new() as RefCounted

	var zip1 := _make_zip(save_id, "alpha-skill", "Alpha", "alpha.zip")
	var zip2 := _make_zip(save_id, "beta-skill", "Beta", "beta.zip")
	var rr1: Dictionary = await inst.call("install_zip_for_save", save_id, zip1, {"source": "local-zip"})
	if not T.require_true(self, bool(rr1.get("ok", false)), "Expected install alpha ok"):
		return
	var rr2: Dictionary = await inst.call("install_zip_for_save", save_id, zip2, {"source": "local-zip"})
	if not T.require_true(self, bool(rr2.get("ok", false)), "Expected install beta ok"):
		return

	var OverlayScene := load("res://vr_offices/ui/VendingMachineOverlay.tscn")
	var overlay := (OverlayScene as PackedScene).instantiate() as Control
	root.add_child(overlay)
	await process_frame

	var open_folder_btn := overlay.get_node_or_null("%LibraryOpenFolderButton") as Button
	if open_folder_btn == null:
		T.fail_and_quit(self, "Missing %LibraryOpenFolderButton")
		return
	open_folder_btn.pressed.emit()
	await process_frame
	if overlay.has_method("open"):
		overlay.call("open")
	await process_frame

	if not overlay.has_method("library_refresh"):
		T.fail_and_quit(self, "Missing library_refresh()")
		return
	overlay.call("library_refresh")
	await process_frame

	var list := overlay.get_node_or_null("%LibraryList") as ItemList
	if list == null:
		T.fail_and_quit(self, "Missing %LibraryList")
		return
	if not T.require_eq(self, int(list.item_count), 2, "Expected 2 library skills listed"):
		return

	var filter := overlay.get_node_or_null("%LibraryFilterEdit") as LineEdit
	if filter == null:
		T.fail_and_quit(self, "Missing %LibraryFilterEdit")
		return
	filter.text = "alpha"
	if filter.has_signal("text_changed"):
		filter.text_changed.emit(filter.text)
	await process_frame
	if not T.require_eq(self, int(list.item_count), 1, "Expected filter reduces list to 1"):
		return

	T.pass_and_quit(self)
