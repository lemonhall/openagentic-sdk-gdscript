extends RefCounted
class_name OATool

var name: String
var description: String
var input_schema: Dictionary
var _run: Callable
var is_async: bool = false
var _availability: Callable = Callable()

func _init(tool_name: String, tool_description: String, run_callable: Callable, schema: Dictionary = {}, async: bool = false, availability_callable: Callable = Callable()) -> void:
	name = tool_name
	description = tool_description
	_run = run_callable
	input_schema = schema
	is_async = async
	_availability = availability_callable

func is_available(ctx: Dictionary) -> bool:
	# Tools are available by default. Hosts may provide an availability callable to
	# hide tools dynamically (e.g. desk-bound tools in VR Offices).
	if _availability == null or _availability.is_null():
		return true
	return bool(_availability.call(ctx))

func run(input: Dictionary, ctx: Dictionary) -> Variant:
	if is_async:
		push_error("OATool.run(): Trying to call an async tool without await. Use OATool.run_async() via OAToolRunner.")
		return null
	return _run.call(input, ctx)

func run_async(input: Dictionary, ctx: Dictionary) -> Variant:
	if is_async:
		return await _run.call(input, ctx)
	return _run.call(input, ctx)
