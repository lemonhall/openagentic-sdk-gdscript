extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var args := OS.get_cmdline_args()
	var enabled := false
	for a in args:
		if String(a) == "--oa-online-tests":
			enabled = true
			break
	if not enabled:
		print("SKIP: pass --oa-online-tests to run the GitHub ZIP online test.")
		T.pass_and_quit(self)
		return

	var Script0 := load("res://vr_offices/core/skill_library/VrOfficesGitHubZipSource.gd")
	if Script0 == null:
		T.fail_and_quit(self, "Missing VrOfficesGitHubZipSource.gd")
		return
	var ZipSource := Script0 as Script

	var repo_url := _arg_value(args, "--oa-github-test-repo=")
	if repo_url == "":
		repo_url = "https://github.com/vercel-labs/skills"

	var proxy_http := _arg_value(args, "--oa-github-proxy-http=")
	var proxy_https := _arg_value(args, "--oa-github-proxy-https=")

	print("ONLINE TEST: repo=%s proxy_http=%s proxy_https=%s" % [repo_url, proxy_http, proxy_https])

	var has_tree := false
	for _i in range(10):
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			has_tree = true
			break
		await process_frame
	if not has_tree:
		T.fail_and_quit(self, "Engine.get_main_loop() did not return SceneTree")
		return

	var rr: Dictionary = await ZipSource.call("download_repo_zip", repo_url, Callable(), proxy_http, proxy_https)
	if not bool(rr.get("ok", false)):
		var out := rr.duplicate(true)
		out.erase("zip")
		T.fail_and_quit(self, "GitHub ZIP download failed: %s" % JSON.stringify(out, "  "))
		return

	var zip: PackedByteArray = rr.get("zip", PackedByteArray())
	if zip.size() <= 0:
		T.fail_and_quit(self, "GitHub ZIP download returned empty body")
		return

	print("ONLINE TEST: ok zip_size=%d url=%s" % [zip.size(), str(rr.get("url", "")).strip_edges()])
	T.pass_and_quit(self)

static func _arg_value(args: PackedStringArray, prefix: String) -> String:
	for a in args:
		var s := String(a)
		if s.begins_with(prefix):
			return s.substr(prefix.length()).strip_edges()
	return ""
