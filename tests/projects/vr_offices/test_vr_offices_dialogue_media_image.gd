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

	var save_id: String = "slot_test_dialogue_media_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	dlg.call("open", "npc_1", "NPC", save_id)
	await process_frame

	# Write a tiny 1x1 png into the expected cache path.
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var png_bytes := img.save_png_to_buffer()
	var sha := _sha256_hex(png_bytes)
	var ref := {
		"id": "img_abc123",
		"kind": "image",
		"mime": "image/png",
		"bytes": png_bytes.size(),
		"sha256": sha,
		"name": "t.png",
	}

	var line: String = (MediaRefScript as Script).call("encode_v1", ref)
	if not T.require_true(self, line.begins_with("OAMEDIA1 "), "expected OAMEDIA1 line"):
		return

	if not dlg.has_method("_test_get_media_cache_path"):
		T.fail_and_quit(self, "DialogueOverlay missing _test_get_media_cache_path()")
		return
	var cache_path := String(dlg.call("_test_get_media_cache_path", ref))
	if cache_path.strip_edges() == "":
		T.fail_and_quit(self, "DialogueOverlay did not provide cache path")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cache_path.get_base_dir()))
	var f := FileAccess.open(cache_path, FileAccess.WRITE)
	if f == null:
		T.fail_and_quit(self, "Failed to write cache file")
		return
	f.store_buffer(png_bytes)
	f.close()

	dlg.call("add_user_message", line)
	await process_frame

	# Expect that an image node was created in the messages container.
	if not dlg.has_method("_test_has_any_image_message"):
		T.fail_and_quit(self, "DialogueOverlay missing _test_has_any_image_message()")
		return
	var has_image := bool(dlg.call("_test_has_any_image_message"))
	if not T.require_true(self, has_image, "Expected DialogueOverlay to render image message"):
		return

	T.pass_and_quit(self)

func _sha256_hex(b: PackedByteArray) -> String:
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	hc.update(b)
	return hc.finish().hex_encode()
