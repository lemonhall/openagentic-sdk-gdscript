extends RefCounted
class_name OATool

var name: String
var description: String
var input_schema: Dictionary
var _run: Callable

func _init(tool_name: String, tool_description: String, run_callable: Callable, schema: Dictionary = {}) -> void:
	name = tool_name
	description = tool_description
	_run = run_callable
	input_schema = schema

func run(input: Dictionary, ctx: Dictionary) -> Variant:
	return _run.call(input, ctx)

