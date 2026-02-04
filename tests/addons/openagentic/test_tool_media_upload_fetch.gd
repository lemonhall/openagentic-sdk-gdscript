extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var Paths := load("res://addons/openagentic/core/OAPaths.gd")
	var FsScript := load("res://addons/openagentic/core/OAWorkspaceFs.gd")
	if Paths == null or FsScript == null:
		T.fail_and_quit(self, "Missing OAPaths/OAWorkspaceFs")
		return

	var save_id: String = "slot_test_media_tools_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	var npc_id := "npc_media_1"
	var root: String = (Paths as Script).call("npc_workspace_dir", save_id, npc_id)
	var fs = (FsScript as Script).new(root)

	# Create a small binary file to upload.
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 0, 1))
	var png_bytes := img.save_png_to_buffer()
	var src_rel := "in/t.png"
	if fs.has_method("write_bytes"):
		fs.call("write_bytes", src_rel, png_bytes)
	else:
		# Pre-tool red will fail here until write_bytes exists.
		T.fail_and_quit(self, "OAWorkspaceFs missing write_bytes()")
		return

	var bearer := "test-token-xyz"
	var captured_lines: Array[String] = []

	var transport := func(req: Dictionary) -> Dictionary:
		var method := String(req.get("method", ""))
		var url := String(req.get("url", ""))
		var headers: Dictionary = req.get("headers", {})
		var body: PackedByteArray = req.get("body", PackedByteArray())
		# Guardrail: token must never appear in transmitted chat lines (we only send it via header).
		if url.find(bearer) != -1:
			return {"ok": false, "status": 500, "error": "TokenLeak"}
		if method == "POST" and url.ends_with("/upload"):
			if String(headers.get("authorization", "")).find("Bearer ") != 0:
				return {"ok": true, "status": 401, "headers": {}, "body": "{\"ok\":false}".to_utf8_buffer()}
			if String(headers.get("authorization", "")) != "Bearer " + bearer:
				return {"ok": true, "status": 403, "headers": {}, "body": "{\"ok\":false}".to_utf8_buffer()}
			var sha := _sha256_hex(body)
			var meta := {
				"ok": true,
				"id": "img_abc123",
				"kind": "image",
				"mime": "image/png",
				"bytes": body.size(),
				"sha256": sha,
				"name": String(headers.get("x-oa-name", "")),
				"caption": String(headers.get("x-oa-caption", "")),
			}
			return {"ok": true, "status": 200, "headers": {"content-type": "application/json"}, "body": JSON.stringify(meta).to_utf8_buffer()}
		if method == "GET" and url.find("/media/img_abc123") != -1:
			if String(headers.get("authorization", "")) != "Bearer " + bearer:
				return {"ok": true, "status": 403, "headers": {}, "body": PackedByteArray()}
			return {"ok": true, "status": 200, "headers": {"content-type": "image/png"}, "body": png_bytes}
		return {"ok": true, "status": 404, "headers": {}, "body": PackedByteArray()}

	var ctx := {
		"save_id": save_id,
		"npc_id": npc_id,
		"session_id": npc_id,
		"workspace_root": root,
		"media_base_url": "http://media.local",
		"media_bearer_token": bearer,
		"media_transport": transport,
	}

	var tools: Array = OAStandardTools.tools()
	var upload = _find_tool(tools, "MediaUpload")
	var fetch = _find_tool(tools, "MediaFetch")
	if not T.require_true(self, upload != null and fetch != null, "Missing MediaUpload/MediaFetch tools"):
		return

	# Path traversal must be rejected.
	var bad = await upload.run_async({"file_path": "../x.png"}, ctx)
	if not T.require_true(self, typeof(bad) == TYPE_DICTIONARY and String((bad as Dictionary).get("error", "")) != "", "Expected traversal to be rejected"):
		return

	var up = await upload.run_async({"file_path": src_rel, "caption": "hi"}, ctx)
	if not T.require_true(self, typeof(up) == TYPE_DICTIONARY and bool((up as Dictionary).get("ok", false)), "Upload should succeed"):
		return
	var media_ref := String((up as Dictionary).get("media_ref", "")).strip_edges()
	if not T.require_true(self, media_ref.begins_with("OAMEDIA1 "), "Expected OAMEDIA1 media_ref"):
		return
	captured_lines.append(media_ref)
	if not T.require_true(self, media_ref.find(bearer) == -1, "Token must not appear in media_ref"):
		return

	var out = await fetch.run_async({"media_ref": media_ref}, ctx)
	if not T.require_true(self, typeof(out) == TYPE_DICTIONARY and bool((out as Dictionary).get("ok", false)), "Fetch should succeed"):
		return
	var rel := String((out as Dictionary).get("file_path", "")).strip_edges()
	if not T.require_true(self, rel != "" and rel.find(":") == -1 and not rel.begins_with("/") and rel.find("..") == -1, "Expected workspace-relative file_path"):
		return

	var rr: Dictionary = fs.call("read_bytes", rel)
	if not T.require_true(self, bool(rr.get("ok", false)), "Expected downloaded file readable"):
		return
	var got: PackedByteArray = rr.get("bytes", PackedByteArray())
	if not T.require_true(self, got == png_bytes, "Downloaded bytes must match"):
		return

	T.pass_and_quit(self)

func _find_tool(tools: Array, name: String):
	for t in tools:
		if t != null and typeof(t) == TYPE_OBJECT and String(t.name) == name:
			return t
	return null

func _sha256_hex(b: PackedByteArray) -> String:
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	hc.update(b)
	return hc.finish().hex_encode()

