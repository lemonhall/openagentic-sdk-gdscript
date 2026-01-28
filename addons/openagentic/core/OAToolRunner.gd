extends RefCounted
class_name OAToolRunner

var _tools: OAToolRegistry
var _gate: OAAskOncePermissionGate
var _store: OAJsonlNpcSessionStore
var _context_factory: Callable

func _init(tools: OAToolRegistry, gate: OAAskOncePermissionGate, store: OAJsonlNpcSessionStore, context_factory: Callable = Callable()) -> void:
	_tools = tools
	_gate = gate
	_store = store
	_context_factory = context_factory

func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)

func _maybe_yield() -> void:
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		await (ml as SceneTree).process_frame

func run(session_id: String, tool_call: Dictionary) -> void:
	var tool_use_id := String(tool_call.get("tool_use_id", ""))
	var name := String(tool_call.get("name", ""))
	var input := tool_call.get("input", {})
	if typeof(input) != TYPE_DICTIONARY:
		input = {}

	var extra: Dictionary = {}
	if _context_factory != null and not _context_factory.is_null():
		var res = _context_factory.call(session_id, tool_call)
		if typeof(res) == TYPE_DICTIONARY:
			extra = res
	var ctx := extra.duplicate(true)
	ctx["session_id"] = session_id
	ctx["tool_use_id"] = tool_use_id

	_store.append_event(session_id, {"type": "tool.use", "tool_use_id": tool_use_id, "name": name, "input": input, "ts": _now_ms()})

	var approval := _gate.approve(session_id, name, input, tool_use_id)
	if approval.has("question"):
		var q: Dictionary = approval.question
		_store.append_event(session_id, {
			"type": "permission.question",
			"question_id": q.question_id,
			"tool_name": q.tool_name,
			"prompt": q.prompt,
			"ts": _now_ms(),
		})
	_store.append_event(session_id, {
		"type": "permission.decision",
		"question_id": approval.get("question", {}).get("question_id", tool_use_id),
		"allowed": approval.allowed,
		"ts": _now_ms(),
	})

	if not approval.allowed:
		_store.append_event(session_id, {
			"type": "tool.result",
			"tool_use_id": tool_use_id,
			"output": null,
			"is_error": true,
			"error_type": "PermissionDenied",
			"error_message": approval.get("deny_message", "tool use not approved"),
			"ts": _now_ms(),
		})
		await _maybe_yield()
		return

	var tool := _tools.get(name)
	if tool == null:
		_store.append_event(session_id, {
			"type": "tool.result",
			"tool_use_id": tool_use_id,
			"output": null,
			"is_error": true,
			"error_type": "UnknownTool",
			"error_message": "unknown tool: " + name,
			"ts": _now_ms(),
		})
		await _maybe_yield()
		return

	var ok := true
	var output = tool.run(input, ctx)
	if output is GDScriptFunctionState:
		output = await output
	_store.append_event(session_id, {
		"type": "tool.result",
		"tool_use_id": tool_use_id,
		"output": output,
		"is_error": not ok,
		"error_type": null,
		"error_message": null,
		"ts": _now_ms(),
	})
	await _maybe_yield()
