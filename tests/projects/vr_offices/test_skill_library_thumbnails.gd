extends SceneTree

const T := preload("res://tests/_test_util.gd")
const _Paths := preload("res://vr_offices/core/skill_library/VrOfficesSharedSkillLibraryPaths.gd")

const _Client := preload("res://vr_offices/core/skill_library/thumbnails/VrOfficesGeminiImageClient.gd")
const _Gen := preload("res://vr_offices/core/skill_library/thumbnails/VrOfficesSkillThumbnailGenerator.gd")

func _init() -> void:
	if not await _test_client_converts_jpeg_inline_data_to_png():
		return
	if not await _test_generator_writes_and_skips():
		return
	T.pass_and_quit(self)

func _test_client_converts_jpeg_inline_data_to_png() -> bool:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.6, 1.0, 1.0))
	var jpg_bytes := img.save_jpg_to_buffer(0.9)
	if not T.require_true(self, jpg_bytes.size() > 0, "Expected Image.save_jpg_to_buffer to return bytes"):
		return false

	var b64 := Marshalls.raw_to_base64(jpg_bytes)
	var body_obj := {
		"candidates": [{
			"content": {
				"parts": [{
					"inlineData": {
						"mimeType": "image/jpeg",
						"data": b64,
					},
				}],
			},
		}],
	}
	var body := JSON.stringify(body_obj).to_utf8_buffer()
	var calls := {"n": 0}
	var transport := func(_req: Dictionary) -> Dictionary:
		calls["n"] = int(calls.get("n", 0)) + 1
		return {"ok": true, "status": 200, "headers": {}, "body": body}

	var c: RefCounted = _Client.new()
	var st: Variant = c.call("generate_thumbnail_png", "unit-test prompt", "http://unit/gemini", "", transport)
	var rr: Variant = await st if T.is_function_state(st) else st
	if not T.require_true(self, typeof(rr) == TYPE_DICTIONARY and bool((rr as Dictionary).get("ok", false)), "Client must return ok"):
		return false
	if not T.require_eq(self, int(calls.get("n", 0)), 1, "Client must call transport exactly once"):
		return false
	var png_bytes: PackedByteArray = (rr as Dictionary).get("png_bytes", PackedByteArray())
	if not T.require_true(self, _looks_like_png(png_bytes), "Expected PNG bytes"):
		return false

	var img2 := Image.new()
	var err := img2.load_png_from_buffer(png_bytes)
	if not T.require_eq(self, err, OK, "PNG must be loadable"):
		return false
	if not T.require_eq(self, img2.get_width(), 640, "PNG must be resized to 640x360"):
		return false
	if not T.require_eq(self, img2.get_height(), 360, "PNG must be resized to 640x360"):
		return false
	return true

func _test_generator_writes_and_skips() -> bool:
	var sid := "test_save_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	var skill := "teamwork"
	var root := _Paths.library_root(sid)
	if not T.require_true(self, root != "", "library_root must be non-empty"):
		return false
	var skill_dir := root.rstrip("/") + "/" + skill
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(skill_dir))

	var md := (
		"---\n"
		+ "name: teamwork\n"
		+ "description: Helps coordinate across teams.\n"
		+ "---\n"
		+ "\n"
		+ "# Teamwork\n"
	)
	var md_path := skill_dir + "/SKILL.md"
	var f := FileAccess.open(md_path, FileAccess.WRITE)
	if not T.require_true(self, f != null, "Failed to write SKILL.md"):
		return false
	f.store_string(md)
	f.close()

	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 0.3, 0.3, 1.0))
	var jpg_bytes := img.save_jpg_to_buffer(0.9)
	var b64 := Marshalls.raw_to_base64(jpg_bytes)
	var body_obj := {"candidates": [{"content": {"parts": [{"inlineData": {"mimeType": "image/jpeg", "data": b64}}]}}]}
	var body := JSON.stringify(body_obj).to_utf8_buffer()

	var calls := {"n": 0}
	var transport := func(_req: Dictionary) -> Dictionary:
		calls["n"] = int(calls.get("n", 0)) + 1
		return {"ok": true, "status": 200, "headers": {}, "body": body}

	var g: RefCounted = _Gen.new()
	var st: Variant = g.call("generate_for_skill", sid, skill, false, transport, {"base_url": "http://unit/gemini"})
	var rr: Variant = await st if T.is_function_state(st) else st
	if not T.require_true(self, typeof(rr) == TYPE_DICTIONARY and bool((rr as Dictionary).get("ok", false)), "Generator must return ok"):
		return false
	if not T.require_eq(self, int(calls.get("n", 0)), 1, "Expected one network call"):
		return false

	var thumb_path := skill_dir + "/thumbnail.png"
	if not T.require_true(self, FileAccess.file_exists(thumb_path) or FileAccess.file_exists(ProjectSettings.globalize_path(thumb_path)), "thumbnail.png must exist"):
		return false
	var f2 := FileAccess.open(thumb_path, FileAccess.READ)
	if f2 == null:
		f2 = FileAccess.open(ProjectSettings.globalize_path(thumb_path), FileAccess.READ)
	if not T.require_true(self, f2 != null, "thumbnail.png must be readable"):
		return false
	var buf := f2.get_buffer(f2.get_length())
	f2.close()
	if not T.require_true(self, _looks_like_png(buf), "thumbnail.png must be PNG"):
		return false
	var img3 := Image.new()
	var err2 := img3.load_png_from_buffer(buf)
	if not T.require_eq(self, err2, OK, "thumbnail.png must be loadable"):
		return false
	if not T.require_eq(self, img3.get_width(), 640, "thumbnail.png must be 640x360"):
		return false
	if not T.require_eq(self, img3.get_height(), 360, "thumbnail.png must be 640x360"):
		return false

	# Second call must skip when thumbnail exists (no transport call).
	var transport_fail := func(_req2: Dictionary) -> Dictionary:
		return {"ok": false, "error": "ShouldNotCall"}
	var st2: Variant = g.call("generate_for_skill", sid, skill, false, transport_fail, {"base_url": "http://unit/gemini"})
	var rr2: Variant = await st2 if T.is_function_state(st2) else st2
	if not T.require_true(self, typeof(rr2) == TYPE_DICTIONARY and bool((rr2 as Dictionary).get("ok", false)), "Second call must still be ok (cached)"):
		return false
	if not T.require_true(self, bool((rr2 as Dictionary).get("cached", false)), "Second call must be cached"):
		return false
	return true

static func _looks_like_png(buf: PackedByteArray) -> bool:
	if buf.size() < 8:
		return false
	return (
		buf[0] == 137 and buf[1] == 80 and buf[2] == 78 and buf[3] == 71 and
		buf[4] == 13 and buf[5] == 10 and buf[6] == 26 and buf[7] == 10
	)
