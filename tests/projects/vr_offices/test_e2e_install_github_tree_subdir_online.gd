extends SceneTree

const T := preload("res://tests/_test_util.gd")

static func _arg_value(args: PackedStringArray, prefix: String) -> String:
	for a in args:
		var s := String(a)
		if s.begins_with(prefix):
			return s.substr(prefix.length()).strip_edges()
	return ""

func _init() -> void:
	var args := OS.get_cmdline_args()
	var enabled := false
	for a in args:
		if String(a) == "--oa-online-tests":
			enabled = true
			break
	if not enabled:
		print("SKIP: pass --oa-online-tests to run the GitHub install E2E test.")
		T.pass_and_quit(self)
		return

	var install_url := _arg_value(args, "--oa-install-url=")
	if install_url == "":
		install_url = "https://github.com/openclaw/openclaw/tree/main/skills/himalaya"
	var expect_skill := _arg_value(args, "--oa-expect-skill=")
	if expect_skill == "":
		expect_skill = "himalaya"
	var proxy_http := _arg_value(args, "--oa-github-proxy-http=")
	var proxy_https := _arg_value(args, "--oa-github-proxy-https=")

	print("E2E INSTALL: url=%s proxy_http=%s proxy_https=%s" % [install_url, proxy_http, proxy_https])

	# Ensure OpenAgentic exists so save_id-scoped paths work.
	var save_id: String = "slot_test_e2e_install_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
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

	var ZipScript0 := load("res://vr_offices/core/skill_library/VrOfficesGitHubZipSource.gd")
	if ZipScript0 == null:
		T.fail_and_quit(self, "Missing VrOfficesGitHubZipSource.gd")
		return
	var ZipSource := ZipScript0 as Script

	var dr: Dictionary = await ZipSource.call("download_repo_zip", install_url, Callable(), proxy_http, proxy_https)
	if not bool(dr.get("ok", false)):
		var out := dr.duplicate(true)
		out.erase("zip")
		T.fail_and_quit(self, "Download failed: %s" % JSON.stringify(out, "  "))
		return

	var zip: PackedByteArray = dr.get("zip", PackedByteArray())
	if zip.size() <= 0:
		T.fail_and_quit(self, "Download returned empty zip")
		return

	var LibraryPaths0 := load("res://vr_offices/core/skill_library/VrOfficesSharedSkillLibraryPaths.gd")
	if LibraryPaths0 == null:
		T.fail_and_quit(self, "Missing VrOfficesSharedSkillLibraryPaths.gd")
		return
	var LibraryPaths := LibraryPaths0 as Script
	var stage := String(LibraryPaths.call("staging_root", save_id))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(stage))
	var zip_path := stage.rstrip("/") + "/download.zip"
	var f := FileAccess.open(zip_path, FileAccess.WRITE)
	if f == null:
		T.fail_and_quit(self, "Write zip failed: " + zip_path)
		return
	f.store_buffer(zip)
	f.close()

	var Installer0 := load("res://vr_offices/core/skill_library/VrOfficesSkillPackInstaller.gd")
	if Installer0 == null:
		T.fail_and_quit(self, "Missing VrOfficesSkillPackInstaller.gd")
		return
	var installer: RefCounted = (Installer0 as Script).new()

	var source := {
		"type": "github",
		"requested_url": install_url,
		"repo_url": String(dr.get("repo_url", "")),
		"ref": String(dr.get("ref", "")),
		"subdir": String(dr.get("subdir", "")),
		"url": String(dr.get("url", "")),
	}
	var rr: Dictionary = installer.call("install_zip_for_save", save_id, zip_path, source)
	if not bool(rr.get("ok", false)):
		T.fail_and_quit(self, "Install failed: %s" % JSON.stringify(rr, "  "))
		return

	var installed: Array = rr.get("installed", [])
	var found := false
	for it in installed:
		if typeof(it) == TYPE_DICTIONARY and String((it as Dictionary).get("name", "")).strip_edges() == expect_skill:
			found = true
			break
	if not T.require_true(self, found, "Expected installed skill: " + expect_skill):
		return

	var md := "user://openagentic/saves/%s/shared/skill_library/%s/SKILL.md" % [save_id, expect_skill]
	if not T.require_true(self, FileAccess.file_exists(md), "Expected SKILL.md exists: " + md):
		return

	print("E2E INSTALL: ok installed=%d" % installed.size())
	T.pass_and_quit(self)
