extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var Std := load("res://addons/openagentic/tools/OAStandardTools.gd")
	var Web := load("res://addons/openagentic/tools/OAWebTools.gd")
	if Std == null or Web == null:
		T.fail_and_quit(self, "Missing tool scripts")
		return

	var tools: Array = []
	for t in (Std as Script).call("tools"):
		tools.append(t)
	for t2 in (Web as Script).call("tools"):
		tools.append(t2)

		for tool0 in tools:
			if tool0 == null:
				continue
			var name := str(tool0.name)
		var schema0: Variant = tool0.input_schema
		if typeof(schema0) != TYPE_DICTIONARY:
			T.fail_and_quit(self, "Tool '%s' missing input_schema dictionary" % name)
			return
		var schema: Dictionary = schema0 as Dictionary
		var ok := _validate_schema(schema)
		if not ok:
			T.fail_and_quit(self, "Invalid JSON schema for tool '%s': %s" % [name, str(schema)])
			return

	T.pass_and_quit(self)

func _validate_schema(s: Dictionary) -> bool:
	# Minimal JSON Schema sanity checks compatible with OpenAI function parameters.
	var types: Array[String] = _schema_types(s)
	if types.has("array"):
		if not s.has("items"):
			return false
		var items0: Variant = s.get("items", null)
		if typeof(items0) != TYPE_DICTIONARY:
			return false
		return _validate_schema(items0 as Dictionary)

	if types.has("object"):
		var props0: Variant = s.get("properties", {})
		if props0 == null:
			return true
		if typeof(props0) != TYPE_DICTIONARY:
			return false
		var props: Dictionary = props0 as Dictionary
		for k in props.keys():
			var v0: Variant = props.get(k, null)
			if typeof(v0) != TYPE_DICTIONARY:
				return false
			if not _validate_schema(v0 as Dictionary):
				return false
		return true

	# Primitive types are fine.
	for t in types:
		if t in ["string", "integer", "number", "boolean", "null"]:
			continue
	return true

func _schema_types(s: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var t0: Variant = s.get("type", null)
	if typeof(t0) == TYPE_STRING:
		out.append(String(t0))
	elif typeof(t0) == TYPE_ARRAY:
		for x0 in t0 as Array:
			if typeof(x0) == TYPE_STRING:
				out.append(String(x0))
	# If "type" is missing, treat as "any" (valid for our minimal checks).
	return out
