extends RefCounted
class_name OAHookEngine

# Minimal hook engine (inspired by the Python SDK hooks).
# Hooks can rewrite/block tool input/output, or be used as an integration point for gameplay (animations, VFX, etc.).
#
# Each matcher is a Dictionary:
# - name: String
# - tool_name_pattern: String (wildcards; segments separated by '|')
# - hook: Callable
# - is_async: bool (true if the hook callable is a coroutine and must be awaited)

var pre_tool_use: Array[Dictionary] = []
var post_tool_use: Array[Dictionary] = []
var before_turn: Array[Dictionary] = []
var after_turn: Array[Dictionary] = []

static func _match_name(pattern: String, name: String) -> bool:
	var p := pattern.strip_edges()
	if p == "":
		p = "*"
	for seg in p.split("|"):
		var s := String(seg).strip_edges()
		if s == "":
			continue
		if name.match(s):
			return true
	return false

static func _decision_block(reason: String = "") -> Dictionary:
	return {"block": true, "block_reason": reason}

func add_before_turn(name: String, npc_id_pattern: String, hook: Callable, is_async: bool = false) -> void:
	before_turn.append({
		"name": name,
		"npc_id_pattern": npc_id_pattern,
		"hook": hook,
		"is_async": is_async,
	})

func add_after_turn(name: String, npc_id_pattern: String, hook: Callable, is_async: bool = false) -> void:
	after_turn.append({
		"name": name,
		"npc_id_pattern": npc_id_pattern,
		"hook": hook,
		"is_async": is_async,
	})

func add_pre_tool_use(name: String, tool_name_pattern: String, hook: Callable, is_async: bool = false) -> void:
	pre_tool_use.append({
		"name": name,
		"tool_name_pattern": tool_name_pattern,
		"hook": hook,
		"is_async": is_async,
	})

func add_post_tool_use(name: String, tool_name_pattern: String, hook: Callable, is_async: bool = false) -> void:
	post_tool_use.append({
		"name": name,
		"tool_name_pattern": tool_name_pattern,
		"hook": hook,
		"is_async": is_async,
	})

func run_before_turn(npc_id: String, user_text: String, context: Dictionary) -> Dictionary:
	var hook_events: Array[Dictionary] = []
	var override_text: String = ""
	for m0 in before_turn:
		if typeof(m0) != TYPE_DICTIONARY:
			continue
		var m: Dictionary = m0 as Dictionary
		var matcher_name := String(m.get("name", "")).strip_edges()
		var pat := String(m.get("npc_id_pattern", "*"))
		var matched := _match_name(pat, npc_id)
		var action := ""
		var hook0: Variant = m.get("hook", null)
		var is_async := bool(m.get("is_async", false))
		var decision: Dictionary = {}
		if matched and typeof(hook0) == TYPE_CALLABLE and not (hook0 as Callable).is_null():
			var payload := {
				"hook_point": "BeforeTurn",
				"npc_id": npc_id,
				"user_text": user_text,
				"context": context.duplicate(true),
			}
			var res: Variant = null
			if is_async:
				res = await (hook0 as Callable).call(payload)
			else:
				res = (hook0 as Callable).call(payload)
			if typeof(res) == TYPE_DICTIONARY:
				decision = res as Dictionary
			action = String(decision.get("action", "")).strip_edges()
			if bool(decision.get("block", false)):
				hook_events.append({
					"hook_point": "BeforeTurn",
					"name": matcher_name,
					"matched": true,
					"action": action if action != "" else "block",
				})
				return {"ok": false, "hook_events": hook_events, "decision": decision, "override_user_text": override_text}
			var o0: Variant = decision.get("override_user_text", null)
			if typeof(o0) == TYPE_STRING:
				override_text = String(o0)
				if action == "":
					action = "rewrite_user_text"
		hook_events.append({
			"hook_point": "BeforeTurn",
			"name": matcher_name,
			"matched": matched,
			"action": action,
		})
	return {"ok": true, "hook_events": hook_events, "decision": null, "override_user_text": override_text}

func run_after_turn(npc_id: String, assistant_text: String, stop_reason: String, context: Dictionary) -> Dictionary:
	var hook_events: Array[Dictionary] = []
	for m0 in after_turn:
		if typeof(m0) != TYPE_DICTIONARY:
			continue
		var m: Dictionary = m0 as Dictionary
		var matcher_name := String(m.get("name", "")).strip_edges()
		var pat := String(m.get("npc_id_pattern", "*"))
		var matched := _match_name(pat, npc_id)
		var action := ""
		var hook0: Variant = m.get("hook", null)
		var is_async := bool(m.get("is_async", false))
		var decision: Dictionary = {}
		if matched and typeof(hook0) == TYPE_CALLABLE and not (hook0 as Callable).is_null():
			var payload := {
				"hook_point": "AfterTurn",
				"npc_id": npc_id,
				"assistant_text": assistant_text,
				"stop_reason": stop_reason,
				"context": context.duplicate(true),
			}
			var res: Variant = null
			if is_async:
				res = await (hook0 as Callable).call(payload)
			else:
				res = (hook0 as Callable).call(payload)
			if typeof(res) == TYPE_DICTIONARY:
				decision = res as Dictionary
			action = String(decision.get("action", "")).strip_edges()
			if bool(decision.get("block", false)):
				hook_events.append({
					"hook_point": "AfterTurn",
					"name": matcher_name,
					"matched": true,
					"action": action if action != "" else "block",
				})
				return {"ok": false, "hook_events": hook_events, "decision": decision}
		hook_events.append({
			"hook_point": "AfterTurn",
			"name": matcher_name,
			"matched": matched,
			"action": action,
		})
	return {"ok": true, "hook_events": hook_events, "decision": null}

func run_pre_tool_use(tool_name: String, tool_input: Dictionary, context: Dictionary) -> Dictionary:
	var current_input: Dictionary = tool_input.duplicate(true)
	var hook_events: Array[Dictionary] = []
	for m0 in pre_tool_use:
		if typeof(m0) != TYPE_DICTIONARY:
			continue
		var m: Dictionary = m0 as Dictionary
		var matcher_name := String(m.get("name", "")).strip_edges()
		var pat := String(m.get("tool_name_pattern", "*"))
		var matched := _match_name(pat, tool_name)
		var action := ""
		var hook0: Variant = m.get("hook", null)
		var is_async := bool(m.get("is_async", false))
		var decision: Dictionary = {}
		if matched and typeof(hook0) == TYPE_CALLABLE and not (hook0 as Callable).is_null():
			var payload := {
				"hook_point": "PreToolUse",
				"tool_name": tool_name,
				"tool_input": current_input.duplicate(true),
				"context": context.duplicate(true),
			}
			var res: Variant = null
			if is_async:
				res = await (hook0 as Callable).call(payload)
			else:
				res = (hook0 as Callable).call(payload)
			if typeof(res) == TYPE_DICTIONARY:
				decision = res as Dictionary
			action = String(decision.get("action", "")).strip_edges()
			if bool(decision.get("block", false)):
				hook_events.append({
					"hook_point": "PreToolUse",
					"name": matcher_name,
					"matched": true,
					"action": action if action != "" else "block",
				})
				return {"ok": false, "tool_input": current_input, "hook_events": hook_events, "decision": decision}
			var o0: Variant = decision.get("override_tool_input", null)
			if typeof(o0) == TYPE_DICTIONARY:
				current_input = (o0 as Dictionary).duplicate(true)
				if action == "":
					action = "rewrite_tool_input"
		hook_events.append({
			"hook_point": "PreToolUse",
			"name": matcher_name,
			"matched": matched,
			"action": action,
		})
	return {"ok": true, "tool_input": current_input, "hook_events": hook_events, "decision": null}

func run_post_tool_use(tool_name: String, tool_output: Variant, context: Dictionary) -> Dictionary:
	var current_output: Variant = tool_output
	var hook_events: Array[Dictionary] = []
	for m0 in post_tool_use:
		if typeof(m0) != TYPE_DICTIONARY:
			continue
		var m: Dictionary = m0 as Dictionary
		var matcher_name := String(m.get("name", "")).strip_edges()
		var pat := String(m.get("tool_name_pattern", "*"))
		var matched := _match_name(pat, tool_name)
		var action := ""
		var hook0: Variant = m.get("hook", null)
		var is_async := bool(m.get("is_async", false))
		var decision: Dictionary = {}
		if matched and typeof(hook0) == TYPE_CALLABLE and not (hook0 as Callable).is_null():
			var payload := {
				"hook_point": "PostToolUse",
				"tool_name": tool_name,
				"tool_output": current_output,
				"context": context.duplicate(true),
			}
			var res: Variant = null
			if is_async:
				res = await (hook0 as Callable).call(payload)
			else:
				res = (hook0 as Callable).call(payload)
			if typeof(res) == TYPE_DICTIONARY:
				decision = res as Dictionary
			action = String(decision.get("action", "")).strip_edges()
			if bool(decision.get("block", false)):
				hook_events.append({
					"hook_point": "PostToolUse",
					"name": matcher_name,
					"matched": true,
					"action": action if action != "" else "block",
				})
				return {"ok": false, "tool_output": current_output, "hook_events": hook_events, "decision": decision}
			if decision.has("override_tool_output"):
				current_output = decision.get("override_tool_output", null)
				if action == "":
					action = "rewrite_tool_output"
		hook_events.append({
			"hook_point": "PostToolUse",
			"name": matcher_name,
			"matched": matched,
			"action": action,
		})
	return {"ok": true, "tool_output": current_output, "hook_events": hook_events, "decision": null}
