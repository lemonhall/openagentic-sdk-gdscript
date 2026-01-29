extends RefCounted
class_name OAAgentRuntime

const _OAReplay := preload("res://addons/openagentic/runtime/OAReplay.gd")
const _OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")
const _OASkills := preload("res://addons/openagentic/core/OASkills.gd")

var _store
var _tool_runner
var _tools
var _provider
var _model: String
var _system_prompt: String = ""
var _max_steps: int = 50

func _init(store, tool_runner, tools, provider, model: String) -> void:
	_store = store
	_tool_runner = tool_runner
	_tools = tools
	_provider = provider
	_model = model

func set_system_prompt(prompt: String) -> void:
	_system_prompt = prompt

func set_max_steps(max_steps: int) -> void:
	_max_steps = max_steps if max_steps > 0 else 50

func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)

func _tool_schemas() -> Array:
	var out: Array = []
	for name in _tools.names():
		var t = _tools.get_tool(name)
		if t == null:
			continue
		var params = t.input_schema if typeof(t.input_schema) == TYPE_DICTIONARY and t.input_schema.size() > 0 else {"type": "object", "properties": {}}
		var schema := {"type": "function", "name": t.name, "parameters": params}
		if t.description.strip_edges() != "":
			schema["description"] = t.description
		out.append(schema)
	return out

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

	var steps := 0
	while steps < _max_steps:
		steps += 1
		var events: Array = _store.read_events(npc_id)
		var input_items: Array = _OAReplay.rebuild_responses_input(events)

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

		var req := {"model": _model, "input": input_items, "tools": _tool_schemas(), "stream": true}
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
		return

	var final2 := {"type": "result", "final_text": "", "stop_reason": "max_steps", "ts": _now_ms()}
	_store.append_event(npc_id, final2)
	if on_event != null and not on_event.is_null():
		on_event.call(final2)
