extends RefCounted
class_name OATool

var name: String
var description: String
var input_schema: Dictionary
var _run: Callable
var is_async: bool = false

func _init(tool_name: String, tool_description: String, run_callable: Callable, schema: Dictionary = {}, async: bool = false) -> void:
	name = tool_name
	description = tool_description
	_run = run_callable
	input_schema = schema
	is_async = async

func run(input: Dictionary, ctx: Dictionary) -> Variant:
	if is_async:
		push_error("OATool.run(): Trying to call an async tool without await. Use OATool.run_async() via OAToolRunner.")
		return null
	return _run.call(input, ctx)

func run_async(input: Dictionary, ctx: Dictionary) -> Variant:
	if is_async:
		return await _run.call(input, ctx)
	return _run.call(input, ctx)
