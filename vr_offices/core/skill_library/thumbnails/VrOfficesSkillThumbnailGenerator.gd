extends RefCounted
class_name VrOfficesSkillThumbnailGenerator

const _Validator := preload("res://addons/openagentic/core/OASkillMdValidator.gd")
const _Paths := preload("res://vr_offices/core/skill_library/VrOfficesSharedSkillLibraryPaths.gd")
const _ClientScript := preload("res://vr_offices/core/skill_library/thumbnails/VrOfficesGeminiImageClient.gd")

const _DEFAULT_BASE_URL := "http://127.0.0.1:8787/gemini"
const _MAX_RETRIES := 3
const _TARGET_W := 640
const _TARGET_H := 360
const _ASPECT_RATIO := "16:9"

var _client: RefCounted = _ClientScript.new()

func generate_for_skill(
	save_id: String,
	skill_name: String,
	force: bool = false,
	transport: Callable = Callable(),
	options: Dictionary = {}
) -> Dictionary:
	var sid := save_id.strip_edges()
	var name := skill_name.strip_edges()
	if sid == "" or name == "":
		return {"ok": false, "error": "MissingContext"}

	var root := _Paths.library_root(sid)
	if root == "":
		return {"ok": false, "error": "MissingLibraryRoot"}
	var skill_dir := root.rstrip("/") + "/" + name
	var abs_skill_dir := ProjectSettings.globalize_path(skill_dir)
	if not DirAccess.dir_exists_absolute(abs_skill_dir):
		return {"ok": false, "error": "SkillNotFound", "skill": name}

	var thumb_path := skill_dir + "/thumbnail.png"
	if not force and _thumbnail_ok(thumb_path, _TARGET_W, _TARGET_H):
		return {"ok": true, "cached": true, "path": thumb_path}

	var md_path := skill_dir + "/SKILL.md"
	var vr: Dictionary = _Validator.validate_skill_md_path(md_path)
	if not bool(vr.get("ok", false)):
		return {"ok": false, "error": String(vr.get("error", "InvalidSkillMd"))}
	var desc := String(vr.get("description", "")).strip_edges()

	var prompt := _thumbnail_prompt(name, desc)
	var base_url := String(options.get("base_url", "")).strip_edges()
	if base_url == "":
		var env_base := OS.get_environment("OPENAGENTIC_GEMINI_BASE_URL").strip_edges()
		base_url = env_base if env_base != "" else _DEFAULT_BASE_URL
	var api_key := String(options.get("api_key", "")).strip_edges()
	if api_key == "":
		api_key = OS.get_environment("OPENAGENTIC_GEMINI_API_KEY").strip_edges()

	var client_opts := options.duplicate()
	client_opts.erase("base_url")
	client_opts.erase("api_key")
	if not client_opts.has("aspect_ratio"):
		client_opts["aspect_ratio"] = _ASPECT_RATIO
	if not client_opts.has("thumb_width"):
		client_opts["thumb_width"] = _TARGET_W
	if not client_opts.has("thumb_height"):
		client_opts["thumb_height"] = _TARGET_H

	var last_err := ""
	for attempt in range(_MAX_RETRIES):
		var st0: Variant = _client.call("generate_thumbnail_png", prompt, base_url, api_key, transport, client_opts)
		var rr0: Variant = await st0 if _is_function_state(st0) else st0
		if typeof(rr0) == TYPE_DICTIONARY and bool((rr0 as Dictionary).get("ok", false)):
			var png: PackedByteArray = (rr0 as Dictionary).get("png_bytes", PackedByteArray())
			if png.size() <= 0:
				last_err = "EmptyPng"
			else:
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(thumb_path.get_base_dir()))
				var f := FileAccess.open(thumb_path, FileAccess.WRITE)
				if f == null:
					return {"ok": false, "error": "WriteFailed", "path": thumb_path}
				f.store_buffer(png)
				f.close()
				return {"ok": true, "cached": false, "path": thumb_path, "bytes": int(png.size())}
		else:
			var rr: Dictionary = rr0 as Dictionary if typeof(rr0) == TYPE_DICTIONARY else {}
			last_err = String(rr.get("error", "GenerateFailed"))

		if attempt < _MAX_RETRIES - 1 and Engine.get_main_loop() != null:
			var tree := Engine.get_main_loop() as SceneTree
			if tree != null:
				var sec := 0.4 * pow(2.0, float(attempt))
				await tree.create_timer(sec).timeout
	return {"ok": false, "error": last_err if last_err != "" else "GenerateFailed"}

static func _thumbnail_prompt(name: String, description: String) -> String:
	var n := name.strip_edges()
	var d := description.strip_edges()
	return (
		"为一个游戏技能生成缩略图。\n"
		+ "技能名：“%s”。\n" % n
		+ "技能描述：“%s”。\n" % d
		+ "要求：幼儿卡通风、玩具感、色彩明快，和低多边形/卡通角色游戏风格协调。\n"
		+ "构图：16:9 卡牌封面，主体居中，背景干净（纯色或简单渐变）。\n"
		+ "禁止：不要任何文字/字母/符号、不要 logo、不要水印、不要写实、不要血腥暴力。"
	)

static func _file_exists_any(p: String) -> bool:
	return FileAccess.file_exists(p) or FileAccess.file_exists(ProjectSettings.globalize_path(p))

static func _thumbnail_ok(png_path: String, w: int, h: int) -> bool:
	if not _file_exists_any(png_path):
		return false
	var abs_path := ProjectSettings.globalize_path(png_path)
	var img := Image.new()
	var err := img.load(abs_path)
	if err != OK:
		return false
	return img.get_width() == w and img.get_height() == h

static func _is_function_state(v: Variant) -> bool:
	return typeof(v) == TYPE_OBJECT and v != null and (v as Object).get_class() == "GDScriptFunctionState"
