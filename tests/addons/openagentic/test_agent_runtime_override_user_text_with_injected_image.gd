extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var StoreScript := load("res://addons/openagentic/core/OAJsonlNpcSessionStore.gd")
	var RegistryScript := load("res://addons/openagentic/core/OAToolRegistry.gd")
	var GateScript := load("res://addons/openagentic/core/OAAskOncePermissionGate.gd")
	var RunnerScript := load("res://addons/openagentic/core/OAToolRunner.gd")
	var RuntimeScript := load("res://addons/openagentic/runtime/OAAgentRuntime.gd")
	var PathsScript := load("res://addons/openagentic/core/OAPaths.gd")
	var HookScript := load("res://addons/openagentic/hooks/OAHookEngine.gd")
	if StoreScript == null or RegistryScript == null or GateScript == null or RunnerScript == null or RuntimeScript == null or PathsScript == null or HookScript == null:
		T.fail_and_quit(self, "Missing required OpenAgentic scripts")
		return

	var save_id: String = "slot_test_img_override_%s_%s" % [str(OS.get_process_id()), str(int(Time.get_unix_time_from_system() * 1000.0))]
	var npc_id := "npc_img_override_1"

	var store = StoreScript.new(save_id)
	var tools = RegistryScript.new()
	var gate = GateScript.new(func(_q: Dictionary, _ctx: Dictionary) -> bool:
		return true
	)
	var runner = RunnerScript.new(tools, gate, store)

	# Pre-seed: prior MediaFetch success between last two user messages.
	var media_ref := "OAMEDIA1 eyJpZCI6ImlkMSIsImtpbmQiOiJpbWFnZSIsIm1pbWUiOiJpbWFnZS9wbmciLCJieXRlcyI6NjgsInNoYTI1NiI6Ijg3OGYwNTVlMTk0YjdhYTkzZDEzZmJmOWYxYzkyNTk4N2U3OGQ3MDdjYTYxNmVjNGZkODFlZDg0ZGI2MmYyZDkifQ"
	store.append_event(npc_id, {"type": "user.message", "text": media_ref})
	store.append_event(npc_id, {"type": "tool.use", "tool_use_id": "call_fetch_1", "name": "MediaFetch", "input": {"media_ref": media_ref, "dest_path": "in/screenshot.png"}})
	store.append_event(npc_id, {"type": "tool.result", "tool_use_id": "call_fetch_1", "output": {"ok": true, "file_path": "in/screenshot.png", "bytes": 68, "sha256": "878f055e194b7aa93d13fbf9f1c925987e78d707ca616ec4fd81ed84db62f2d9"}})
	store.append_event(npc_id, {"type": "assistant.message", "text": "fetched"})

	# Ensure the file exists.
	var OAPaths = PathsScript
	var workspace_root: String = String(OAPaths.npc_workspace_dir(save_id, npc_id))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/%s" % [workspace_root, "in"]))
	var png_bytes: PackedByteArray = Marshalls.base64_to_raw("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMB/6XKQnQAAAAASUVORK5CYII=")
	var f := FileAccess.open("%s/%s" % [workspace_root, "in/screenshot.png"], FileAccess.WRITE)
	if f == null:
		T.fail_and_quit(self, "Failed to write workspace screenshot.png")
		return
	f.store_buffer(png_bytes)
	f.close()

	# Install a before-turn hook that overrides user text.
	var hooks = HookScript.new()
	hooks.add_before_turn("rewrite-user", npc_id, func(_payload: Dictionary) -> Dictionary:
		return {"override_user_text": "OVERRIDDEN", "action": "rewrite_user_text"}
	)

	var captured := {"req": null}
	var fake_provider := {"name": "fake"}
	fake_provider["stream"] = func(req: Dictionary, on_event: Callable) -> void:
		captured["req"] = req.duplicate(true)
		on_event.call({"type": "text_delta", "delta": "ok"})
		on_event.call({"type": "done"})

	var rt = RuntimeScript.new(store, runner, tools, fake_provider, "gpt-test", hooks)
	await rt.run_turn(npc_id, "原始问题", func(_ev: Dictionary) -> void:
		pass
	, save_id)

	var req0: Variant = captured.get("req", null)
	if not T.require_true(self, typeof(req0) == TYPE_DICTIONARY, "Expected provider to be called"):
		return
	var req: Dictionary = req0 as Dictionary
	var input0: Variant = req.get("input", null)
	if not T.require_true(self, typeof(input0) == TYPE_ARRAY, "Expected provider req.input array"):
		return
	var input_items: Array = input0 as Array

	var last_user: Dictionary = {}
	for i in range(input_items.size() - 1, -1, -1):
		if typeof(input_items[i]) != TYPE_DICTIONARY:
			continue
		var it: Dictionary = input_items[i] as Dictionary
		if String(it.get("role", "")) == "user":
			last_user = it
			break
	if not T.require_true(self, last_user.size() > 0, "Expected a user message in provider input"):
		return
	var content0: Variant = last_user.get("content", null)
	if not T.require_true(self, typeof(content0) == TYPE_ARRAY, "Expected content parts array"):
		return
	var parts: Array = content0 as Array
	if not T.require_true(self, parts.size() >= 1 and typeof(parts[0]) == TYPE_DICTIONARY, "Expected first part dict"):
		return
	var p0: Dictionary = parts[0] as Dictionary
	if not T.require_eq(self, String(p0.get("type", "")), "input_text", "Expected first part input_text"):
		return
	if not T.require_eq(self, String(p0.get("text", "")), "OVERRIDDEN", "Expected override_user_text to update input_text even with injected image parts"):
		return

	T.pass_and_quit(self)

