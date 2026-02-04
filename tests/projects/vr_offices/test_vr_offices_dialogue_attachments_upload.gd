extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var DialogueScene := load("res://vr_offices/ui/DialogueOverlay.tscn")
	if DialogueScene == null:
		T.fail_and_quit(self, "Missing DialogueOverlay.tscn")
		return
	var dlg: Control = (DialogueScene as PackedScene).instantiate()
	get_root().add_child(dlg)
	await process_frame

	var save_id: String = "slot_test_dialogue_attach_upload_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	dlg.call("open", "npc_1", "NPC", save_id)
	await process_frame

	# Create a small valid png file.
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 0, 1))
	var png_bytes := img.save_png_to_buffer()
	var src_path := "user://oa_test_upload.png"
	var f := FileAccess.open(src_path, FileAccess.WRITE)
	if f == null:
		T.fail_and_quit(self, "Failed to create temp png")
		return
	f.store_buffer(png_bytes)
	f.close()

	var bearer := "test-bearer-token-xyz"
	var captured: Array[String] = []
	if dlg.has_signal("message_submitted"):
		dlg.connect("message_submitted", func(t: String) -> void: captured.append(t))

	var calls := {"n": 0}
	var transport := func(req: Dictionary) -> Dictionary:
		calls["n"] = int(calls.get("n", 0)) + 1
		var method := String(req.get("method", ""))
		var url := String(req.get("url", ""))
		var headers: Dictionary = req.get("headers", {})
		var body: PackedByteArray = req.get("body", PackedByteArray())
		if method != "POST" or url.find("/upload") == -1:
			return {"ok": true, "status": 404, "headers": {}, "body": "{\"ok\":false}".to_utf8_buffer()}
		if String(headers.get("authorization", "")) != "Bearer " + bearer:
			return {"ok": true, "status": 403, "headers": {}, "body": "{\"ok\":false}".to_utf8_buffer()}
		if String(headers.get("x-oa-name", "")) != "oa_test_upload.png":
			return {"ok": true, "status": 400, "headers": {}, "body": "{\"ok\":false}".to_utf8_buffer()}
		if body != png_bytes:
			return {"ok": true, "status": 400, "headers": {}, "body": "{\"ok\":false}".to_utf8_buffer()}
		var sha := _sha256_hex(body)
		var meta := {
			"ok": true,
			"id": "img_123",
			"kind": "image",
			"mime": "image/png",
			"bytes": body.size(),
			"sha256": sha,
			"name": String(headers.get("x-oa-name", "")),
		}
		return {"ok": true, "status": 200, "headers": {"content-type": "application/json"}, "body": JSON.stringify(meta).to_utf8_buffer()}

	if not dlg.has_method("_test_set_media_config"):
		T.fail_and_quit(self, "DialogueOverlay missing _test_set_media_config()")
		return
	dlg.call("_test_set_media_config", "http://media.local", bearer, transport)

	dlg.call("_test_enqueue_attachment_paths", PackedStringArray([src_path]))

	# Wait for the upload worker to emit.
	for _i in range(60):
		if captured.size() >= 1:
			break
		await process_frame

	if not T.require_eq(self, captured.size(), 1, "Expected exactly one emitted message"):
		return
	var line := String(captured[0]).strip_edges()
	if not T.require_true(self, line.begins_with("OAMEDIA1 "), "Expected OAMEDIA1 line"):
		return
	if not T.require_true(self, line.find(bearer) == -1, "Token must not appear in chat line"):
		return
	if not T.require_true(self, line.find("/tmp/") == -1 and line.find("\\") == -1, "Local paths must not appear in chat line"):
		return
	if not T.require_eq(self, int(calls.get("n", 0)), 1, "Expected exactly 1 upload request"):
		return

	var MediaRefScript := load("res://addons/openagentic/core/OAMediaRef.gd")
	if MediaRefScript == null:
		T.fail_and_quit(self, "Missing OAMediaRef.gd")
		return
	var dec: Dictionary = (MediaRefScript as Script).call("decode_v1", line)
	if not T.require_true(self, bool(dec.get("ok", false)), "Expected decode ok"):
		return
	var ref: Dictionary = dec.get("ref", {})
	if not T.require_eq(self, String(ref.get("id", "")), "img_123"):
		return

	var CacheScript := load("res://vr_offices/ui/VrOfficesMediaCache.gd")
	if CacheScript == null:
		T.fail_and_quit(self, "Missing VrOfficesMediaCache.gd")
		return
	var cache_path := String((CacheScript as Script).call("media_cache_path", save_id, ref))
	if not T.require_true(self, cache_path != "" and FileAccess.file_exists(cache_path), "Expected cached file to exist"):
		return
	var f2 := FileAccess.open(cache_path, FileAccess.READ)
	if f2 == null:
		T.fail_and_quit(self, "Failed to read cached file")
		return
	var got := f2.get_buffer(f2.get_length())
	f2.close()
	if not T.require_true(self, got == png_bytes, "Cached bytes must match uploaded bytes"):
		return

	# Unsupported file type is rejected pre-upload.
	var bad_path := "user://oa_test_upload.gif"
	var f3 := FileAccess.open(bad_path, FileAccess.WRITE)
	if f3 == null:
		T.fail_and_quit(self, "Failed to create temp gif")
		return
	f3.store_buffer(PackedByteArray([0x47, 0x49, 0x46, 0x38]))
	f3.close()
	calls["n"] = 0
	captured.clear()

	dlg.call("_test_enqueue_attachment_paths", PackedStringArray([bad_path]))
	await process_frame

	if not T.require_true(self, int(calls.get("n", 0)) == 0, "Unsupported types must not call upload transport"):
		return
	if not dlg.has_method("_test_attachment_items"):
		T.fail_and_quit(self, "DialogueOverlay missing _test_attachment_items()")
		return
	var items: Array = dlg.call("_test_attachment_items")
	var bad_state := ""
	for it0 in items:
		if typeof(it0) != TYPE_DICTIONARY:
			continue
		var it: Dictionary = it0 as Dictionary
		if String(it.get("name", "")) == "oa_test_upload.gif":
			bad_state = String(it.get("state", ""))
	if not T.require_eq(self, bad_state, "failed", "Unsupported type should appear as failed in queue"):
		return

	T.pass_and_quit(self)

func _sha256_hex(b: PackedByteArray) -> String:
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	hc.update(b)
	return hc.finish().hex_encode()
