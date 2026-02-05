extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _zip_bytes_for_save(save_id: String) -> PackedByteArray:
	var base_dir := "user://openagentic/saves/%s/shared/test_pack_src2" % save_id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_dir))
	var skill_dir := base_dir + "/skills/repo-skill"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(skill_dir))
	var md_path := skill_dir + "/SKILL.md"
	var f := FileAccess.open(md_path, FileAccess.WRITE)
	f.store_string("""---
name: repo-skill
description: Installed via repo URL
---
""")
	f.close()

	var zip_path := "user://openagentic/saves/%s/shared/test_pack2.zip" % save_id
	var z := ZIPPacker.new()
	z.open(zip_path)
	z.start_file("skills/repo-skill/SKILL.md")
	z.write_file(FileAccess.get_file_as_bytes(md_path))
	z.close_file()
	z.close()
	return FileAccess.get_file_as_bytes(zip_path)

func _transport_zip(req: Dictionary) -> Dictionary:
	# We ignore URL matching for now; this transport always returns the prepared zip bytes.
	var body: PackedByteArray = req.get("body", PackedByteArray())
	# Sanity: downloads should be GET with empty body.
	if String(req.get("method", "")).to_upper() != "GET":
		return {"ok": false, "error": "ExpectedGET"}
	if body.size() != 0:
		return {"ok": false, "error": "ExpectedEmptyBody"}
	return {"ok": true, "status": 200, "headers": {"content-type": "application/zip"}, "body": _zip_bytes}

var _zip_bytes: PackedByteArray = PackedByteArray()

func _init() -> void:
	var save_id: String = "slot_test_vend_search_install_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
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

	_zip_bytes = _zip_bytes_for_save(save_id)

	var OverlayScene := load("res://vr_offices/ui/VendingMachineOverlay.tscn")
	if OverlayScene == null or not (OverlayScene is PackedScene):
		T.fail_and_quit(self, "Missing VendingMachineOverlay.tscn")
		return
	var overlay := (OverlayScene as PackedScene).instantiate() as Control
	root.add_child(overlay)
	await process_frame

	if overlay.has_method("set_github_zip_transport_override"):
		overlay.call("set_github_zip_transport_override", Callable(self, "_transport_zip"))

	# Inject a "selected skill" that contains a repo URL and render its details.
	if not overlay.has_method("debug_set_selected_skill_for_install"):
		T.fail_and_quit(self, "Missing debug_set_selected_skill_for_install()")
		return
	overlay.call("debug_set_selected_skill_for_install", {"name": "Repo Skill", "repo_url": "https://github.com/acme/repo"})
	await process_frame

	var repo_label := overlay.get_node_or_null("%RepoUrlLabel") as Label
	if repo_label == null:
		T.fail_and_quit(self, "Missing %RepoUrlLabel")
		return
	if not T.require_true(self, repo_label.text.find("github.com/acme/repo") != -1, "Expected repo URL visible"):
		return

	var install_btn := overlay.get_node_or_null("%InstallButton") as Button
	if install_btn == null:
		T.fail_and_quit(self, "Missing %InstallButton")
		return
	install_btn.pressed.emit()
	await process_frame
	await process_frame

	var lib_md := "user://openagentic/saves/%s/shared/skill_library/repo-skill/SKILL.md" % save_id
	if not T.require_true(self, FileAccess.file_exists(lib_md), "Expected installed SKILL.md via install button"):
		return

	T.pass_and_quit(self)

