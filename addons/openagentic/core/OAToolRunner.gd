extends RefCounted
class_name OAToolRunner

var _tools
var _gate
var _store
var _context_factory: Callable
var _hooks = null

func _init(tools, gate, store, context_factory: Callable = Callable(), hooks = null) -> void:
	_tools = tools
	_gate = gate
	_store = store
	_context_factory = context_factory
	_hooks = hooks

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

	# Pre-tool hooks (rewrite/block tool input before approval + execution).
	if _hooks != null and typeof(_hooks) == TYPE_OBJECT and _hooks.has_method("run_pre_tool_use"):
		var pre: Dictionary = await _hooks.run_pre_tool_use(name, input, ctx)
		var hook_events0: Variant = pre.get("hook_events", [])
		if typeof(hook_events0) == TYPE_ARRAY:
			for he0 in hook_events0 as Array:
				if typeof(he0) != TYPE_DICTIONARY:
					continue
				var he: Dictionary = he0 as Dictionary
				he["type"] = "hook.event"
				he["ts"] = _now_ms()
				he["tool_use_id"] = tool_use_id
				he["tool_name"] = name
				_store.append_event(session_id, he)
		if not bool(pre.get("ok", true)):
			var decision0: Variant = pre.get("decision", {})
			var decision: Dictionary = decision0 as Dictionary if typeof(decision0) == TYPE_DICTIONARY else {}
			var reason := String(decision.get("block_reason", decision.get("reason", ""))).strip_edges()
			_store.append_event(session_id, {
				"type": "tool.result",
				"tool_use_id": tool_use_id,
				"output": null,
				"is_error": true,
				"error_type": "HookBlocked",
				"error_message": reason if reason != "" else "tool use blocked by hook",
				"ts": _now_ms(),
			})
			await _maybe_yield()
			return
		var new_input0: Variant = pre.get("tool_input", input)
		if typeof(new_input0) == TYPE_DICTIONARY:
			input = new_input0 as Dictionary

	_store.append_event(session_id, {"type": "tool.use", "tool_use_id": tool_use_id, "name": name, "input": input, "ts": _now_ms()})

	var approval = _gate.approve(session_id, name, input, tool_use_id)
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

	var tool = _tools.get_tool(name)
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
	var output = await tool.run_async(input, ctx)

	# Post-tool hooks (rewrite/block tool output).
	if _hooks != null and typeof(_hooks) == TYPE_OBJECT and _hooks.has_method("run_post_tool_use"):
		var post: Dictionary = await _hooks.run_post_tool_use(name, output, ctx)
		var hook_events1: Variant = post.get("hook_events", [])
		if typeof(hook_events1) == TYPE_ARRAY:
			for he1 in hook_events1 as Array:
				if typeof(he1) != TYPE_DICTIONARY:
					continue
				var he2: Dictionary = he1 as Dictionary
				he2["type"] = "hook.event"
				he2["ts"] = _now_ms()
				he2["tool_use_id"] = tool_use_id
				he2["tool_name"] = name
				_store.append_event(session_id, he2)
		if not bool(post.get("ok", true)):
			ok = false
			var decision1: Variant = post.get("decision", {})
			var decision2: Dictionary = decision1 as Dictionary if typeof(decision1) == TYPE_DICTIONARY else {}
			var reason2 := String(decision2.get("block_reason", decision2.get("reason", ""))).strip_edges()
			_store.append_event(session_id, {
				"type": "tool.result",
				"tool_use_id": tool_use_id,
				"output": null,
				"is_error": true,
				"error_type": "HookBlocked",
				"error_message": reason2 if reason2 != "" else "tool result blocked by hook",
				"ts": _now_ms(),
			})
			await _maybe_yield()
			return
		output = post.get("tool_output", output)
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
