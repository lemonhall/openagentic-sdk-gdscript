extends SceneTree

const T := preload("res://tests/_test_util.gd")
const _Http := preload("res://addons/openagentic/core/OAMediaHttp.gd")

const _DEFAULT_BASE_URL := "http://127.0.0.1:8787/gemini"
const _MODEL := "gemini-3-pro-image-preview"

func _init() -> void:
	var args := OS.get_cmdline_args()
	var enabled := false
	for a in args:
		if String(a) == "--oa-online-tests":
			enabled = true
			break
	if not enabled:
		print("SKIP: pass --oa-online-tests to run the Gemini image thumbnail online test.")
		T.pass_and_quit(self)
		return

	var base_url := _arg_value(args, "--oa-gemini-base-url=")
	if base_url == "":
		var env_base := OS.get_environment("OPENAGENTIC_GEMINI_BASE_URL").strip_edges()
		base_url = env_base if env_base != "" else _DEFAULT_BASE_URL
	var api_key := _arg_value(args, "--oa-gemini-api-key=")
	if api_key == "":
		api_key = OS.get_environment("OPENAGENTIC_GEMINI_API_KEY").strip_edges()

	var proxy_http := _arg_value(args, "--oa-gemini-proxy-http=")
	var proxy_https := _arg_value(args, "--oa-gemini-proxy-https=")

	var out_path := _arg_value(args, "--oa-gemini-out=")
	if out_path == "":
		out_path = _default_out_path()

	print("ONLINE TEST: base_url=%s proxy_http=%s proxy_https=%s out=%s api_key=%s" % [
		base_url,
		proxy_http,
		proxy_https,
		out_path,
		"(set)" if api_key != "" else "(empty)",
	])

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

	var prompt := _thumbnail_prompt()
	var payload := {
		"contents": [{
			"parts": [{"text": prompt}],
		}],
		"generationConfig": {
			"responseModalities": ["IMAGE"],
			"imageConfig": {
				"aspectRatio": "1:1",
				"imageSize": "1K",
			},
		},
	}

	var url := base_url.rstrip("/") + "/v1beta/models/%s:generateContent" % _MODEL
	var headers := {
		"content-type": "application/json",
		"accept": "application/json",
	}
	if api_key != "":
		headers["x-goog-api-key"] = api_key

	var body := JSON.stringify(payload).to_utf8_buffer()
	var opts := {"proxy_http": proxy_http, "proxy_https": proxy_https}
	var resp: Dictionary = await _Http.request(HTTPClient.METHOD_POST, url, headers, body, 30.0, Callable(), opts)
	if not bool(resp.get("ok", false)):
		T.fail_and_quit(self, "Gemini request failed: %s" % JSON.stringify(resp, "  "))
		return

	var status := int(resp.get("status", 0))
	var bytes: PackedByteArray = resp.get("body", PackedByteArray())
	var txt := bytes.get_string_from_utf8()
	if status < 200 or status >= 300:
		var body_preview := txt
		if body_preview.length() > 2000:
			body_preview = body_preview.substr(0, 2000) + "\n...[truncated]..."
		T.fail_and_quit(self, "Gemini HTTP %d\n%s" % [status, body_preview])
		return

	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		T.fail_and_quit(self, "Gemini response was not JSON object")
		return

	var pick: Dictionary = _find_first_inline_data(parsed)
	if not bool(pick.get("ok", false)):
		var preview := txt
		if preview.length() > 2000:
			preview = preview.substr(0, 2000) + "\n...[truncated]..."
		T.fail_and_quit(self, "No inline image data found. Response:\n%s" % preview)
		return

	var b64 := String(pick.get("data", "")).strip_edges()
	var mime := String(pick.get("mime", "")).strip_edges().to_lower()
	var img_bytes := Marshalls.base64_to_raw(b64)
	if img_bytes.size() <= 0:
		T.fail_and_quit(self, "Decoded image bytes were empty (mime=%s)" % mime)
		return

	var expected_ext := ".png"
	if mime.find("jpeg") != -1 or mime.find("jpg") != -1:
		expected_ext = ".jpg"

	# Always write a file whose extension matches the content type (Godot loaders may rely on extension).
	var final_out := out_path
	if final_out.get_extension().strip_edges() != "":
		final_out = final_out.get_basename() + expected_ext
	else:
		final_out = final_out.rstrip("/") + expected_ext

	_ensure_dir(final_out.get_base_dir())
	var f := FileAccess.open(final_out, FileAccess.WRITE)
	if f == null:
		T.fail_and_quit(self, "Failed to open output path for write: %s" % final_out)
		return
	f.store_buffer(img_bytes)
	f.close()

	if expected_ext == ".png" and not _looks_like_png(img_bytes):
		T.fail_and_quit(self, "Output does not look like PNG (bytes=%d, mime=%s)" % [img_bytes.size(), mime])
		return
	if expected_ext == ".jpg" and not _looks_like_jpeg(img_bytes):
		T.fail_and_quit(self, "Output does not look like JPEG (bytes=%d, mime=%s)" % [img_bytes.size(), mime])
		return

	var abs_out := ProjectSettings.globalize_path(final_out)
	print("ONLINE TEST: wrote %d bytes to %s (abs=%s, mime=%s)" % [img_bytes.size(), final_out, abs_out, mime])
	T.pass_and_quit(self)

static func _thumbnail_prompt() -> String:
	return (
		"为一个游戏技能生成缩略图：技能名“跨团队协调”，技能描述“擅长跨团队协调与复盘”。\n"
		+ "要求：幼儿卡通风、玩具感、色彩明快，和低多边形/卡通角色游戏风格协调。\n"
		+ "构图：1:1 图标，主体居中，背景干净（纯色或简单渐变）。\n"
		+ "禁止：不要文字、不要 logo、不要水印、不要写实、不要血腥暴力。"
	)

static func _default_out_path() -> String:
	var tmp := OS.get_environment("TMPDIR").strip_edges()
	if tmp == "":
		tmp = OS.get_environment("TEMP").strip_edges()
	if tmp != "":
		return tmp.rstrip("/\\") + "/oa_gemini_skill_thumb.png"
	return "user://openagentic/tmp/oa_gemini_skill_thumb.png"

static func _ensure_dir(path: String) -> void:
	var p := path.strip_edges()
	if p == "":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(p))

static func _looks_like_png(buf: PackedByteArray) -> bool:
	if buf.size() < 8:
		return false
	return (
		buf[0] == 137 and buf[1] == 80 and buf[2] == 78 and buf[3] == 71 and
		buf[4] == 13 and buf[5] == 10 and buf[6] == 26 and buf[7] == 10
	)

static func _looks_like_jpeg(buf: PackedByteArray) -> bool:
	if buf.size() < 4:
		return false
	# JPEG SOI marker: FF D8
	return buf[0] == 255 and buf[1] == 216

static func _find_first_inline_data(v: Variant) -> Dictionary:
	if typeof(v) == TYPE_DICTIONARY:
		var d: Dictionary = v as Dictionary
		var id0: Variant = null
		if d.has("inlineData"):
			id0 = d.get("inlineData")
		elif d.has("inline_data"):
			id0 = d.get("inline_data")
		if typeof(id0) == TYPE_DICTIONARY:
			var id: Dictionary = id0 as Dictionary
			var data := String(id.get("data", "")).strip_edges()
			var mime := String(id.get("mimeType", id.get("mime_type", ""))).strip_edges()
			if data != "":
				return {"ok": true, "data": data, "mime": mime}
		for k in d.keys():
			var r := _find_first_inline_data(d.get(k))
			if bool(r.get("ok", false)):
				return r
		return {"ok": false}

	if typeof(v) == TYPE_ARRAY:
		var arr: Array = v as Array
		for it in arr:
			var r2 := _find_first_inline_data(it)
			if bool(r2.get("ok", false)):
				return r2
		return {"ok": false}

	return {"ok": false}

static func _arg_value(args: PackedStringArray, prefix: String) -> String:
	for a in args:
		var s := String(a)
		if s.begins_with(prefix):
			return s.substr(prefix.length()).strip_edges()
	return ""
