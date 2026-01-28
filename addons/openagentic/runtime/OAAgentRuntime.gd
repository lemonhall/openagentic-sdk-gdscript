extends RefCounted
class_name OAAgentRuntime

var _store: OAJsonlNpcSessionStore
var _tool_runner: OAToolRunner
var _tools: OAToolRegistry
var _provider
var _model: String
var _system_prompt: String = ""
var _max_steps: int = 50

func _init(store: OAJsonlNpcSessionStore, tool_runner: OAToolRunner, tools: OAToolRegistry, provider, model: String) -> void:
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
		var t := _tools.get(name)
		if t == null:
			continue
		var params := t.input_schema if typeof(t.input_schema) == TYPE_DICTIONARY and t.input_schema.size() > 0 else {"type": "object", "properties": {}}
		var schema := {"type": "function", "name": t.name, "parameters": params}
		if t.description.strip_edges() != "":
			schema["description"] = t.description
		out.append(schema)
	return out

func _provider_stream_maybe(req: Dictionary, on_model_event: Callable):
	# Support either an object with .stream(req, cb) or a Dictionary with key "stream" as Callable.
	if _provider == null:
		return
	if typeof(_provider) == TYPE_DICTIONARY and (_provider as Dictionary).has("stream"):
		var c: Callable = (_provider as Dictionary).stream
		return c.call(req, on_model_event)
	if typeof(_provider) == TYPE_OBJECT and _provider.has_method("stream"):
		return _provider.stream(req, on_model_event)

func _load_optional_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var txt := f.get_as_text()
	f.close()
	return txt.strip_edges()

func _build_system_preamble(save_id: String, npc_id: String) -> String:
	var parts: Array[String] = []
	if _system_prompt.strip_edges() != "":
		parts.append(_system_prompt.strip_edges())
	var world := _load_optional_text(OAPaths.shared_world_summary_path(save_id))
	if world != "":
		parts.append("World summary:\n" + world)
	var npc_sum := _load_optional_text(OAPaths.npc_summary_path(save_id, npc_id))
	if npc_sum != "":
		parts.append("NPC summary:\n" + npc_sum)
	return "\n\n---\n\n".join(parts)

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
		var input_items: Array = OAReplay.rebuild_responses_input(events)

		# Optional system preamble injection (used when save_id is passed in).
		if save_id.strip_edges() != "":
			var pre := _build_system_preamble(save_id, npc_id)
			if pre != "":
				input_items = [{"role": "system", "content": pre}] + input_items

		var tool_calls: Array = []
		var parts: Array[String] = []
		var provider_error: String = ""

		var req := {"model": _model, "input": input_items, "tools": _tool_schemas(), "stream": true}
		var stream_res = _provider_stream_maybe(req, func(mev: Dictionary) -> void:
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
				var tc := mev.get("tool_call", {})
				if typeof(tc) == TYPE_DICTIONARY:
					tool_calls.append(tc)
			elif t == "done" and typeof(mev.get("error", null)) == TYPE_STRING:
				provider_error = String(mev.error)
		)
		if stream_res is GDScriptFunctionState:
			await stream_res

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

		var assistant_text := "".join(parts)
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
