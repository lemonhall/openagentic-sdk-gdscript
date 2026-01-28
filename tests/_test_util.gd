extends RefCounted

static func assert_true(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		assert(false, msg)

static func assert_eq(a, b, msg: String = "") -> void:
	if a != b:
		var detail := "assert_eq failed: %s != %s" % [str(a), str(b)]
		if msg.strip_edges() != "":
			detail = msg + " | " + detail
		push_error(detail)
		assert(false, detail)

static func pass_and_quit(tree: SceneTree) -> void:
	print("PASS")
	tree.quit(0)

static func fail_and_quit(tree: SceneTree, msg: String) -> void:
	push_error(msg)
	print("FAIL: " + msg)
	tree.quit(1)

