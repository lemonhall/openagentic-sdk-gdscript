extends RefCounted
class_name OAAskOncePermissionGate

var _approver: Callable
var _approved_by_session: Dictionary = {}

func _init(approver: Callable = Callable()) -> void:
	_approver = approver

func reset_session(session_id: String) -> void:
	_approved_by_session.erase(session_id)

func approve(session_id: String, tool_name: String, tool_input: Dictionary, tool_use_id: String) -> Dictionary:
	var approved: Dictionary = _approved_by_session.get(session_id, {})
	if approved.get(tool_name, false) == true:
		return {"allowed": true}

	var question := {
		"question_id": tool_use_id,
		"tool_name": tool_name,
		"prompt": "Allow tool %s?" % tool_name,
		"tool_input": tool_input,
	}

	if _approver == null or _approver.is_null():
		return {"allowed": false, "question": question, "deny_message": "no approver configured"}

	var allowed = _approver.call(question, {"session_id": session_id, "tool_use_id": tool_use_id})
	if typeof(allowed) != TYPE_BOOL:
		allowed = false
	if allowed:
		approved[tool_name] = true
		_approved_by_session[session_id] = approved
	return {"allowed": allowed, "question": question}

