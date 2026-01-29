extends RefCounted

static func is_function_state(v: Variant) -> bool:
	return typeof(v) == TYPE_OBJECT and v != null and (v as Object).get_class() == "GDScriptFunctionState"

static func require_true(tree: SceneTree, cond: bool, msg: String) -> bool:
	if not cond:
		fail_and_quit(tree, msg)
		return false
	return true

static func require_eq(tree: SceneTree, a, b, msg: String = "") -> bool:
	if a == b:
		return true
	var detail := "expected %s, got %s" % [str(b), str(a)]
	if msg.strip_edges() != "":
		detail = msg + " | " + detail
	fail_and_quit(tree, detail)
	return false

static func pass_and_quit(tree: SceneTree) -> void:
	print("PASS")
	tree.quit(0)

static func fail_and_quit(tree: SceneTree, msg: String) -> void:
	push_error(msg)
	print("FAIL: " + msg)
	tree.quit(1)
