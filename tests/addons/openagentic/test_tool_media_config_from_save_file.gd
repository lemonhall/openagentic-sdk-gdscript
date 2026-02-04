extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var StoreScript := load("res://addons/openagentic/core/OAJsonlNpcSessionStore.gd")
	var RegistryScript := load("res://addons/openagentic/core/OAToolRegistry.gd")
	var GateScript := load("res://addons/openagentic/core/OAAskOncePermissionGate.gd")
	var RunnerScript := load("res://addons/openagentic/core/OAToolRunner.gd")
	var PathsScript := load("res://addons/openagentic/core/OAPaths.gd")
	var StandardToolsScript := load("res://addons/openagentic/tools/OAStandardTools.gd")
	var RefScript := load("res://addons/openagentic/core/OAMediaRef.gd")
	if StoreScript == null or RegistryScript == null or GateScript == null or RunnerScript == null or PathsScript == null or StandardToolsScript == null or RefScript == null:
		T.fail_and_quit(self, "Missing required OpenAgentic scripts")
		return

	var save_id: String = "slot_test_media_cfg_%s_%s" % [str(OS.get_process_id()), str(int(Time.get_unix_time_from_system() * 1000.0))]
	var npc_id := "npc_media_cfg_1"

	var workspace_root: String = String(PathsScript.npc_workspace_dir(save_id, npc_id))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(workspace_root))

	var cfg_path: String = "%s/vr_offices/media_config.json" % String(PathsScript.save_root(save_id))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cfg_path.get_base_dir()))
	var f := FileAccess.open(cfg_path, FileAccess.WRITE)
	if f == null:
		T.fail_and_quit(self, "Failed to write media config file")
		return
	f.store_string(JSON.stringify({"base_url": "http://media.local", "bearer_token": "tok1"}, "  ") + "\n")
	f.close()

	var store = StoreScript.new(save_id)
	var tools = RegistryScript.new()
	var OAStandardTools = StandardToolsScript
	for t in OAStandardTools.tools():
		tools.register(t)
	var gate = GateScript.new(func(_q: Dictionary, _ctx: Dictionary) -> bool:
		return true
	)

	var captured := {"upload": null, "fetch": null}
	var media_transport := func(req: Dictionary) -> Dictionary:
		var method := String(req.get("method", ""))
		var url := String(req.get("url", ""))
		var headers0: Variant = req.get("headers", {})
		var headers: Dictionary = headers0 as Dictionary if typeof(headers0) == TYPE_DICTIONARY else {}
		if method == "POST" and url == "http://media.local/upload":
			captured["upload"] = req.duplicate(true)
			var body: PackedByteArray = req.get("body", PackedByteArray())
			var hc := HashingContext.new()
			hc.start(HashingContext.HASH_SHA256)
			hc.update(body)
			var sha := hc.finish().hex_encode()
			var meta := {"ok": true, "id": "id1", "kind": "image", "mime": "image/png", "bytes": body.size(), "sha256": sha}
			return {"ok": true, "status": 200, "headers": {}, "body": JSON.stringify(meta).to_utf8_buffer()}
		if method == "GET" and url == "http://media.local/media/id1":
			captured["fetch"] = req.duplicate(true)
			var bytes := PackedByteArray([1, 2, 3, 4])
			return {"ok": true, "status": 200, "headers": {"content-type": "image/png"}, "body": bytes}
		return {"ok": false, "error": "UnexpectedRequest", "status": 599}

	var runner = RunnerScript.new(tools, gate, store, func(session_id: String, _tool_call: Dictionary) -> Dictionary:
		return {
			"save_id": save_id,
			"npc_id": session_id,
			"workspace_root": workspace_root,
			"media_transport": media_transport,
		}
	)

	# MediaUpload should pick up base_url/token from the per-save config file.
	var local_path := "in/x.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/%s" % [workspace_root, local_path.get_base_dir()]))
	var f2 := FileAccess.open("%s/%s" % [workspace_root, local_path], FileAccess.WRITE)
	if f2 == null:
		T.fail_and_quit(self, "Failed to write workspace file")
		return
	f2.store_buffer(PackedByteArray([9, 9, 9]))
	f2.close()

	await runner.run(npc_id, {"tool_use_id": "call_up", "name": "MediaUpload", "input": {"file_path": local_path}})
	var events: Array = store.read_events(npc_id)
	var up_res := events.filter(func(e): return typeof(e) == TYPE_DICTIONARY and (e as Dictionary).get("type", "") == "tool.result" and (e as Dictionary).get("tool_use_id", "") == "call_up")
	if not T.require_eq(self, up_res.size(), 1, "Expected 1 MediaUpload tool.result"):
		return
	var up_out: Dictionary = (up_res[0] as Dictionary).get("output", {})
	if not T.require_true(self, bool(up_out.get("ok", false)), "MediaUpload must succeed without env vars when save config exists. Got: " + str(up_out)):
		return

	# MediaFetch should also succeed.
	var OAMediaRef = RefScript
	var fetch_body := PackedByteArray([1, 2, 3, 4])
	var hc2 := HashingContext.new()
	hc2.start(HashingContext.HASH_SHA256)
	hc2.update(fetch_body)
	var sha2 := hc2.finish().hex_encode()
	var line := String(OAMediaRef.encode_v1({"id": "id1", "kind": "image", "mime": "image/png", "bytes": fetch_body.size(), "sha256": sha2}))

	await runner.run(npc_id, {"tool_use_id": "call_fetch", "name": "MediaFetch", "input": {"media_ref": line}})
	var events2: Array = store.read_events(npc_id)
	var fe_res := events2.filter(func(e): return typeof(e) == TYPE_DICTIONARY and (e as Dictionary).get("type", "") == "tool.result" and (e as Dictionary).get("tool_use_id", "") == "call_fetch")
	if not T.require_eq(self, fe_res.size(), 1, "Expected 1 MediaFetch tool.result"):
		return
	var fe_out: Dictionary = (fe_res[0] as Dictionary).get("output", {})
	if not T.require_true(self, bool(fe_out.get("ok", false)), "MediaFetch must succeed without env vars when save config exists. Got: " + str(fe_out)):
		return

	# Sanity: tools must have sent bearer auth header from save config.
	var up_req0: Variant = captured.get("upload", null)
	var fe_req0: Variant = captured.get("fetch", null)
	if not T.require_true(self, typeof(up_req0) == TYPE_DICTIONARY and typeof(fe_req0) == TYPE_DICTIONARY, "Expected transport to capture requests"):
		return
	var up_req: Dictionary = up_req0 as Dictionary
	var fe_req: Dictionary = fe_req0 as Dictionary
	var up_h: Dictionary = up_req.get("headers", {})
	var fe_h: Dictionary = fe_req.get("headers", {})
	if not T.require_eq(self, String(up_h.get("authorization", "")), "Bearer tok1", "Upload must use bearer token from save config"):
		return
	if not T.require_eq(self, String(fe_h.get("authorization", "")), "Bearer tok1", "Fetch must use bearer token from save config"):
		return

	T.pass_and_quit(self)
