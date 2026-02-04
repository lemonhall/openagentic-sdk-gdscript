extends RefCounted
class_name OAAgentRuntime

const _OAReplay := preload("res://addons/openagentic/runtime/OAReplay.gd")
const _OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")
const _OASkills := preload("res://addons/openagentic/core/OASkills.gd")
const _OAMediaRef := preload("res://addons/openagentic/core/OAMediaRef.gd")

var _store
var _tool_runner
var _tools
var _provider
var _model: String
var _system_prompt: String = ""
var _max_steps: int = 50
var _hooks = null

func _init(store, tool_runner, tools, provider, model: String, hooks = null) -> void:
	_store = store
	_tool_runner = tool_runner
	_tools = tools
	_provider = provider
	_model = model
	_hooks = hooks

func set_system_prompt(prompt: String) -> void:
	_system_prompt = prompt

func set_max_steps(max_steps: int) -> void:
	_max_steps = max_steps if max_steps > 0 else 50

func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)

func _emit_hook_events(session_id: String, tool_use_id: String, tool_name: String, hook_events0: Variant) -> void:
	if typeof(hook_events0) != TYPE_ARRAY:
		return
	for he0 in hook_events0 as Array:
		if typeof(he0) != TYPE_DICTIONARY:
			continue
		var he: Dictionary = he0 as Dictionary
		he["type"] = "hook.event"
		he["ts"] = _now_ms()
		if tool_use_id != "":
			he["tool_use_id"] = tool_use_id
		if tool_name != "":
			he["tool_name"] = tool_name
		_store.append_event(session_id, he)

func _turn_context(save_id: String, npc_id: String) -> Dictionary:
	var ctx: Dictionary = {}
	ctx["save_id"] = save_id
	ctx["npc_id"] = npc_id
	ctx["workspace_root"] = _OAPaths.npc_workspace_dir(save_id, npc_id)
	return ctx

func _tool_schemas(ctx: Dictionary) -> Array:
	var out: Array = []
	for name in _tools.names():
		var t = _tools.get_tool(name)
		if t == null:
			continue
		if typeof(t) == TYPE_OBJECT and t.has_method("is_available"):
			var av0: Variant = t.call("is_available", ctx)
			if not bool(av0):
				continue
		var params = t.input_schema if typeof(t.input_schema) == TYPE_DICTIONARY and t.input_schema.size() > 0 else {"type": "object", "properties": {}}
		var schema := {"type": "function", "name": t.name, "parameters": params}
		if t.description.strip_edges() != "":
			schema["description"] = t.description
		out.append(schema)
	return out

func _mime_from_path(p: String) -> String:
	var s := p.strip_edges().to_lower()
	if s.ends_with(".png"):
		return "image/png"
	if s.ends_with(".jpg") or s.ends_with(".jpeg"):
		return "image/jpeg"
	if s.ends_with(".webp"):
		return "image/webp"
	if s.ends_with(".gif"):
		return "image/gif"
	return ""

func _find_recent_mediafetch_between_last_two_user_messages(events: Array) -> Dictionary:
	# Option A: after a successful MediaFetch, inject that image into the *next* user message.
	# We detect the most recent successful MediaFetch that happened between the previous
	# and current user.message events.
	var last_user_idx := -1
	for i in range(events.size() - 1, -1, -1):
		if typeof(events[i]) == TYPE_DICTIONARY and String((events[i] as Dictionary).get("type", "")) == "user.message":
			last_user_idx = i
			break
	if last_user_idx < 0:
		return {"ok": false, "error": "NoUserMessage"}
	var prev_user_idx := -1
	for j in range(last_user_idx - 1, -1, -1):
		if typeof(events[j]) == TYPE_DICTIONARY and String((events[j] as Dictionary).get("type", "")) == "user.message":
			prev_user_idx = j
			break
	if prev_user_idx < 0:
		return {"ok": false, "error": "NoPrevUserMessage"}

	var start := prev_user_idx + 1
	var end := last_user_idx
	var uses: Dictionary = {}
	for k in range(start, end):
		var e0: Variant = events[k]
		if typeof(e0) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = e0 as Dictionary
		if String(e.get("type", "")) != "tool.use":
			continue
		var name := String(e.get("name", "")).strip_edges()
		if name != "MediaFetch":
			continue
		var call_id := String(e.get("tool_use_id", "")).strip_edges()
		if call_id == "":
			continue
		uses[call_id] = e

	var best: Dictionary = {}
	for k2 in range(start, end):
		var e1: Variant = events[k2]
		if typeof(e1) != TYPE_DICTIONARY:
			continue
		var e2: Dictionary = e1 as Dictionary
		if String(e2.get("type", "")) != "tool.result":
			continue
		var call_id2 := String(e2.get("tool_use_id", "")).strip_edges()
		if call_id2 == "" or not uses.has(call_id2):
			continue
		var out0: Variant = e2.get("output", null)
		if typeof(out0) != TYPE_DICTIONARY:
			continue
		var out: Dictionary = out0 as Dictionary
		if not bool(out.get("ok", false)):
			continue
		var file_path := String(out.get("file_path", out.get("filePath", ""))).strip_edges()
		if file_path == "":
			continue

		var mime := ""
		var use: Dictionary = uses.get(call_id2, {})
		var inp0: Variant = use.get("input", {})
		var inp: Dictionary = inp0 as Dictionary if typeof(inp0) == TYPE_DICTIONARY else {}
		var media_ref := String(inp.get("media_ref", inp.get("mediaRef", ""))).strip_edges()
		if media_ref != "":
			var dec: Dictionary = _OAMediaRef.decode_v1(media_ref)
			if bool(dec.get("ok", false)) and typeof(dec.get("ref", null)) == TYPE_DICTIONARY:
				var ref: Dictionary = dec.get("ref", {})
				mime = String(ref.get("mime", "")).strip_edges().to_lower()
		if mime == "":
			mime = _mime_from_path(file_path)
		if mime == "":
			continue

		best = {"ok": true, "file_path": file_path, "mime": mime, "call_id": call_id2}
	return best if bool(best.get("ok", false)) else {"ok": false, "error": "NoSuccessfulMediaFetch"}

func _inject_recent_media_image_into_last_user_message(input_items: Array, events: Array, ctx: Dictionary) -> Array:
	var pick: Dictionary = _find_recent_mediafetch_between_last_two_user_messages(events)
	if not bool(pick.get("ok", false)):
		return input_items
	var workspace_root := String(ctx.get("workspace_root", "")).rstrip("/")
	if workspace_root.strip_edges() == "":
		return input_items

	var rel := String(pick.get("file_path", "")).strip_edges()
	if rel == "" or rel.begins_with("/") or rel.find("..") != -1 or rel.find(":") != -1:
		return input_items
	var p := "%s/%s" % [workspace_root, rel]
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return input_items
	var n := f.get_length()
	if n <= 0:
		f.close()
		return input_items
	# Keep a conservative upper bound to avoid blowing up request size.
	if n > 12 * 1024 * 1024:
		f.close()
		return input_items
	var bytes := f.get_buffer(n)
	f.close()
	if bytes.is_empty():
		return input_items

	var mime := String(pick.get("mime", "")).strip_edges().to_lower()
	if mime == "":
		return input_items
	var b64 := String(Marshalls.raw_to_base64(bytes))
	if b64.strip_edges() == "":
		return input_items
	var data_url := "data:%s;base64,%s" % [mime, b64]

	for i3 in range(input_items.size() - 1, -1, -1):
		if typeof(input_items[i3]) != TYPE_DICTIONARY:
			continue
		var it3: Dictionary = input_items[i3] as Dictionary
		if String(it3.get("role", "")) != "user":
			continue
		var c0: Variant = it3.get("content", "")
		var parts: Array = []
		if typeof(c0) == TYPE_STRING:
			var txt := String(c0)
			parts.append({"type": "input_text", "text": txt})
		elif typeof(c0) == TYPE_ARRAY:
			parts = (c0 as Array).duplicate(true)
		else:
			parts.append({"type": "input_text", "text": ""})
		parts.append({"type": "input_image", "image_url": data_url})
		it3["content"] = parts
		input_items[i3] = it3
		break
	return input_items

func _provider_stream(req: Dictionary, on_model_event: Callable) -> void:
	# Support either an object with .stream(req, cb) or a Dictionary with key "stream" as Callable.
	if _provider == null:
		return
	if typeof(_provider) == TYPE_DICTIONARY:
		var d: Dictionary = _provider as Dictionary
		var c0: Variant = d.get("stream", null)
		if typeof(c0) == TYPE_CALLABLE and not (c0 as Callable).is_null():
			(c0 as Callable).call(req, on_model_event)
			return
	if typeof(_provider) == TYPE_OBJECT and _provider.has_method("stream"):
		await _provider.stream(req, on_model_event)
		return

func _load_optional_text(path: String) -> String:
	var abs := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(abs):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		f = FileAccess.open(abs, FileAccess.READ)
	if f == null:
		return ""
	var txt := f.get_as_text()
	f.close()
	return txt.strip_edges()

func _join_strings(sep: String, items: Array[String]) -> String:
	var psa := PackedStringArray()
	for s in items:
		psa.append(s)
	return sep.join(psa)

func _build_system_preamble(save_id: String, npc_id: String) -> String:
	var parts: Array[String] = []
	if _system_prompt.strip_edges() != "":
		parts.append(_system_prompt.strip_edges())
	var world := _load_optional_text(_OAPaths.shared_world_summary_path(save_id))
	if world != "":
		parts.append("World summary:\n" + world)
	var npc_sum := _load_optional_text(_OAPaths.npc_summary_path(save_id, npc_id))
	if npc_sum != "":
		parts.append("NPC summary:\n" + npc_sum)
	var skill_names: Array[String] = _OASkills.list_skill_names(save_id, npc_id)
	if skill_names.size() > 0:
		var blocks: Array[String] = []
		for name in skill_names:
			var body := _OASkills.read_skill_md(save_id, npc_id, name, 128 * 1024)
			if body == "":
				continue
			blocks.append("## Skill: %s\n\n%s" % [name, body])
		if blocks.size() > 0:
			parts.append("NPC skills (workspace/skills/*/SKILL.md):\n\n" + _join_strings("\n\n---\n\n", blocks))
	return _join_strings("\n\n---\n\n", parts)

func run_turn(npc_id: String, user_text: String, on_event: Callable, save_id: String = "") -> void:
	if user_text == null or typeof(user_text) != TYPE_STRING:
		return
	var ctx := _turn_context(save_id, npc_id)
	var existing: Array = _store.read_events(npc_id)
	if not existing.any(func(e): return typeof(e) == TYPE_DICTIONARY and e.get("type", "") == "system.init"):
		var init := {"type": "system.init", "npc_id": npc_id, "ts": _now_ms()}
		_store.append_event(npc_id, init)
		if on_event != null and not on_event.is_null():
			on_event.call(init)

	var user_ev := {"type": "user.message", "text": user_text, "ts": _now_ms()}
	_store.append_event(npc_id, user_ev)
	if on_event != null and not on_event.is_null():
		on_event.call(user_ev)

	# Turn hooks: BeforeTurn (after user message is recorded, before provider request).
	var override_user_text := ""
	if _hooks != null and typeof(_hooks) == TYPE_OBJECT and _hooks.has_method("run_before_turn"):
		var before0: Dictionary = await _hooks.run_before_turn(npc_id, user_text, ctx)
		_emit_hook_events(npc_id, "", "", before0.get("hook_events", []))
		var ot0: Variant = before0.get("override_user_text", "")
		if typeof(ot0) == TYPE_STRING:
			override_user_text = String(ot0)
		if not bool(before0.get("ok", true)):
			var decision0: Variant = before0.get("decision", {})
			var decision: Dictionary = decision0 as Dictionary if typeof(decision0) == TYPE_DICTIONARY else {}
			var reason := String(decision.get("block_reason", decision.get("reason", ""))).strip_edges()
			var final_block := {"type": "result", "final_text": "", "stop_reason": "hook_blocked", "ts": _now_ms()}
			if reason != "":
				final_block["error"] = reason
			_store.append_event(npc_id, final_block)
			if on_event != null and not on_event.is_null():
				on_event.call(final_block)
			# AfterTurn hook still runs on blocked turns.
			if _hooks != null and typeof(_hooks) == TYPE_OBJECT and _hooks.has_method("run_after_turn"):
				var after_block: Dictionary = await _hooks.run_after_turn(npc_id, "", "hook_blocked", ctx)
				_emit_hook_events(npc_id, "", "", after_block.get("hook_events", []))
			return

	var steps := 0
	while steps < _max_steps:
		steps += 1
		var events: Array = _store.read_events(npc_id)
		var input_items: Array = _OAReplay.rebuild_responses_input(events)
		input_items = _inject_recent_media_image_into_last_user_message(input_items, events, ctx)
		if override_user_text.strip_edges() != "":
			for i in range(input_items.size() - 1, -1, -1):
				if typeof(input_items[i]) != TYPE_DICTIONARY:
					continue
				var it: Dictionary = input_items[i] as Dictionary
				if String(it.get("role", "")) != "user":
					continue
				var c0: Variant = it.get("content", null)
				if typeof(c0) == TYPE_STRING:
					it["content"] = override_user_text
					input_items[i] = it
					break
				if typeof(c0) == TYPE_ARRAY:
					var parts: Array = (c0 as Array).duplicate(true)
					for j in range(parts.size()):
						if typeof(parts[j]) != TYPE_DICTIONARY:
							continue
						var p: Dictionary = parts[j] as Dictionary
						if String(p.get("type", "")) == "input_text":
							p["text"] = override_user_text
							parts[j] = p
							it["content"] = parts
							input_items[i] = it
							break
					break

		# Optional system preamble (used when save_id is passed in).
		# For OpenAI Responses API, system guidance should be passed via `instructions`,
		# not as a `role=system` input item (which can trigger HTTP 400).
		var instructions := ""
		if save_id.strip_edges() != "":
			var pre := _build_system_preamble(save_id, npc_id)
			if pre != "":
				instructions = pre

		var tool_calls: Array = []
		var parts: Array[String] = []
		var provider_error: String = ""

		var req := {"model": _model, "input": input_items, "tools": _tool_schemas(ctx), "stream": true}
		if instructions != "":
			req["instructions"] = instructions
		await _provider_stream(req, func(mev: Dictionary) -> void:
			if typeof(mev) != TYPE_DICTIONARY:
				return
			var t := String(mev.get("type", ""))
			if t == "text_delta":
				var delta := String(mev.get("delta", ""))
				if delta != "":
					parts.append(delta)
					var de := {"type": "assistant.delta", "text_delta": delta, "ts": _now_ms()}
					_store.append_event(npc_id, de)
					if on_event != null and not on_event.is_null():
						on_event.call(de)
			elif t == "tool_call":
				var tc0: Variant = mev.get("tool_call", {})
				if typeof(tc0) == TYPE_DICTIONARY:
					tool_calls.append(tc0)
			elif t == "done" and typeof(mev.get("error", null)) == TYPE_STRING:
				provider_error = String(mev.error)
		)

		if tool_calls.size() > 0:
			for tc in tool_calls:
				await _tool_runner.run(npc_id, tc)
			continue

		if parts.size() == 0:
			var stop := "no_output" if provider_error == "" else "provider_error"
			var final0 := {"type": "result", "final_text": "", "stop_reason": stop, "ts": _now_ms()}
			if provider_error != "":
				final0["error"] = provider_error
			_store.append_event(npc_id, final0)
			if on_event != null and not on_event.is_null():
				on_event.call(final0)
			if _hooks != null and typeof(_hooks) == TYPE_OBJECT and _hooks.has_method("run_after_turn"):
				var after0: Dictionary = await _hooks.run_after_turn(npc_id, "", stop, ctx)
				_emit_hook_events(npc_id, "", "", after0.get("hook_events", []))
			return

		var assistant_text := _join_strings("", parts)
		var msg := {"type": "assistant.message", "text": assistant_text, "ts": _now_ms()}
		_store.append_event(npc_id, msg)
		if on_event != null and not on_event.is_null():
			on_event.call(msg)

		var final := {"type": "result", "final_text": assistant_text, "stop_reason": "end", "ts": _now_ms()}
		_store.append_event(npc_id, final)
		if on_event != null and not on_event.is_null():
			on_event.call(final)
		if _hooks != null and typeof(_hooks) == TYPE_OBJECT and _hooks.has_method("run_after_turn"):
			var after1: Dictionary = await _hooks.run_after_turn(npc_id, assistant_text, "end", ctx)
			_emit_hook_events(npc_id, "", "", after1.get("hook_events", []))
		return

	var final2 := {"type": "result", "final_text": "", "stop_reason": "max_steps", "ts": _now_ms()}
	_store.append_event(npc_id, final2)
	if on_event != null and not on_event.is_null():
		on_event.call(final2)
	if _hooks != null and typeof(_hooks) == TYPE_OBJECT and _hooks.has_method("run_after_turn"):
		var after2: Dictionary = await _hooks.run_after_turn(npc_id, "", "max_steps", ctx)
		_emit_hook_events(npc_id, "", "", after2.get("hook_events", []))
