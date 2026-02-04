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

	var MediaRefScript := load("res://addons/openagentic/core/OAMediaRef.gd")
	if MediaRefScript == null:
		T.fail_and_quit(self, "Missing OAMediaRef.gd")
		return

	var save_id: String = "slot_test_dialogue_media_dl_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	dlg.call("open", "npc_1", "NPC", save_id)
	await process_frame

	# Prepare image bytes to be "downloaded" by transport.
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 1, 1))
	var png_bytes := img.save_png_to_buffer()
	var sha := _sha256_hex(png_bytes)

	var ref := {
		"id": "img_dl_1",
		"kind": "image",
		"mime": "image/png",
		"bytes": png_bytes.size(),
		"sha256": sha,
		"name": "x.png",
	}
	var line: String = (MediaRefScript as Script).call("encode_v1", ref)
	if not T.require_true(self, line.begins_with("OAMEDIA1 "), "Expected OAMEDIA1"):
		return

	var bearer := "tok123"
	var calls := {"n": 0}
	var transport := func(req: Dictionary) -> Dictionary:
		calls["n"] = int(calls.get("n", 0)) + 1
		var method := String(req.get("method", ""))
		var url := String(req.get("url", ""))
		var headers: Dictionary = req.get("headers", {})
		if method != "GET" or url.find("/media/" + String(ref.id)) == -1:
			return {"ok": true, "status": 404, "headers": {}, "body": PackedByteArray()}
		if String(headers.get("authorization", "")) != "Bearer " + bearer:
			return {"ok": true, "status": 403, "headers": {}, "body": PackedByteArray()}
		return {"ok": true, "status": 200, "headers": {"content-type": "image/png"}, "body": png_bytes}

	if not dlg.has_method("_test_set_media_config"):
		T.fail_and_quit(self, "DialogueOverlay missing _test_set_media_config()")
		return
	dlg.call("_test_set_media_config", "http://media.local", bearer, transport)

	# Ensure cache does not exist yet.
	if not dlg.has_method("_test_get_media_cache_path"):
		T.fail_and_quit(self, "DialogueOverlay missing _test_get_media_cache_path()")
		return
	var cache_path := String(dlg.call("_test_get_media_cache_path", ref))
	if cache_path.strip_edges() == "":
		T.fail_and_quit(self, "Expected cache path")
		return
	if FileAccess.file_exists(cache_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cache_path))

	dlg.call("add_user_message", line)

	# Wait for async download + render.
	for _i in range(120):
		if FileAccess.file_exists(cache_path) and bool(dlg.call("_test_has_any_image_message")):
			break
		await process_frame

	if not T.require_true(self, FileAccess.file_exists(cache_path), "Expected cache file after download"):
		return
	if not T.require_true(self, bool(dlg.call("_test_has_any_image_message")), "Expected image render after download"):
		return
	if not T.require_true(self, int(calls.get("n", 0)) >= 1, "Expected at least one download request"):
		return

	var f := FileAccess.open(cache_path, FileAccess.READ)
	if f == null:
		T.fail_and_quit(self, "Failed to read cache file")
		return
	var got := f.get_buffer(f.get_length())
	f.close()
	if not T.require_true(self, got == png_bytes, "Cached bytes mismatch"):
		return

	T.pass_and_quit(self)

func _sha256_hex(b: PackedByteArray) -> String:
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	hc.update(b)
	return hc.finish().hex_encode()

