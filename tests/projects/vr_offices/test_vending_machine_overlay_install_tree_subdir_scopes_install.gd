extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _make_zip(save_id: String) -> PackedByteArray:
	var zip_path := "user://openagentic/saves/%s/shared/test_pack_tree_subdir.zip" % save_id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(zip_path.get_base_dir()))

	var z := ZIPPacker.new()
	z.open(zip_path)

	# Skill A: under the requested subdir (should be installed).
	z.start_file("ai/skills/skill-writer/SKILL.md")
	z.write_file(PackedByteArray("""---
name: skill-writer
description: Install from tree/master subdir
---
""".to_utf8_buffer()))
	z.close_file()

	# Skill B: elsewhere in the repo (must NOT be installed when subdir is specified).
	z.start_file("skills/other-skill/SKILL.md")
	z.write_file(PackedByteArray("""---
name: other-skill
description: Should not be installed
---
""".to_utf8_buffer()))
	z.close_file()

	z.close()
	return FileAccess.get_file_as_bytes(zip_path)

func _transport_zip(req: Dictionary) -> Dictionary:
	if String(req.get("method", "")).to_upper() != "GET":
		return {"ok": false, "error": "ExpectedGET"}
	var body: PackedByteArray = req.get("body", PackedByteArray())
	if body.size() != 0:
		return {"ok": false, "error": "ExpectedEmptyBody"}
	return {"ok": true, "status": 200, "headers": {"content-type": "application/zip"}, "body": _zip_bytes}

var _zip_bytes: PackedByteArray = PackedByteArray()

func _init() -> void:
	var save_id: String = "slot_test_vend_tree_subdir_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
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

	_zip_bytes = _make_zip(save_id)

	var OverlayScene := load("res://vr_offices/ui/VendingMachineOverlay.tscn")
	if OverlayScene == null or not (OverlayScene is PackedScene):
		T.fail_and_quit(self, "Missing VendingMachineOverlay.tscn")
		return
	var overlay := (OverlayScene as PackedScene).instantiate() as Control
	get_root().add_child(overlay)
	await process_frame

	if overlay.has_method("set_github_zip_transport_override"):
		overlay.call("set_github_zip_transport_override", Callable(self, "_transport_zip"))

	# Use a tree/master URL that points to a subdir.
	if not overlay.has_method("debug_set_selected_skill_for_install"):
		T.fail_and_quit(self, "Missing debug_set_selected_skill_for_install()")
		return
	overlay.call("debug_set_selected_skill_for_install", {
		"name": "Writer Skill",
		"repo_url": "https://github.com/TencentBlueKing/bk-ci/tree/master/ai/skills/skill-writer",
	})
	await process_frame

	var install_btn := overlay.get_node_or_null("%InstallButton") as Button
	if install_btn == null:
		T.fail_and_quit(self, "Missing %InstallButton")
		return
	install_btn.pressed.emit()
	await process_frame
	await process_frame

	var installed_md := "user://openagentic/saves/%s/shared/skill_library/skill-writer/SKILL.md" % save_id
	if not T.require_true(self, FileAccess.file_exists(installed_md), "Expected subdir skill installed"):
		return

	var other_md := "user://openagentic/saves/%s/shared/skill_library/other-skill/SKILL.md" % save_id
	if not T.require_true(self, not FileAccess.file_exists(other_md), "Expected non-subdir skill NOT installed"):
		return

	T.pass_and_quit(self)

