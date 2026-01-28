extends RefCounted
class_name OAToolRegistry

var _tools: Dictionary = {}

func register(tool) -> void:
	if tool == null or tool.name.strip_edges() == "":
		push_error("OAToolRegistry.register: tool.name required")
		return
	_tools[tool.name] = tool

func get_tool(tool_name: String):
	if not _tools.has(tool_name):
		push_error("unknown tool: " + tool_name)
		return null
	return _tools[tool_name]

func names() -> Array:
	var out := _tools.keys()
	out.sort()
	return out
