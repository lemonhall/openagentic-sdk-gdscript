extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var HookScript := load("res://addons/openagentic/hooks/OAHookEngine.gd")
	var VrScene := load("res://vr_offices/VrOffices.tscn")
	var OAScript := load("res://addons/openagentic/OpenAgentic.gd")
	if HookScript == null or VrScene == null or OAScript == null:
		T.fail_and_quit(self, "Missing HookEngine, OpenAgentic, or VrOffices scene")
		return

	var oa: Node = root.get_node_or_null("OpenAgentic")
	if oa == null:
		oa = (OAScript as Script).new()
		oa.name = "OpenAgentic"
		root.add_child(oa)

	# Reset hooks and meta to ensure isolation within this test process.
	oa.set("hooks", HookScript.new())
	if oa.has_meta("vr_offices_turn_hooks_installed"):
		oa.remove_meta("vr_offices_turn_hooks_installed")

	var s1 := (VrScene as PackedScene).instantiate()
	root.add_child(s1)
	await process_frame

	var hooks0: Variant = oa.get("hooks")
	if hooks0 == null:
		T.fail_and_quit(self, "OpenAgentic.hooks missing after reset")
		return

	var before_turn0: Variant = hooks0.get("before_turn") if typeof(hooks0) == TYPE_OBJECT and hooks0.has_method("get") else null
	# OAHookEngine exposes `before_turn` as a field, so fetch via `get`.
	if typeof(before_turn0) != TYPE_ARRAY:
		before_turn0 = hooks0.get("before_turn")
	if typeof(before_turn0) != TYPE_ARRAY:
		T.fail_and_quit(self, "Expected OpenAgentic.hooks.before_turn to exist")
		return

	var before_turn: Array = before_turn0 as Array
	var has_vr := false
	for m0 in before_turn:
		if typeof(m0) != TYPE_DICTIONARY:
			continue
		var m: Dictionary = m0 as Dictionary
		if String(m.get("name", "")) == "vr_offices.before_turn":
			has_vr = true
			break
	if not T.require_true(self, has_vr, "Expected vr_offices.before_turn hook matcher"):
		return

	# Instantiate again; should not add a duplicate matcher (guarded by autoload meta).
	var s2 := (VrScene as PackedScene).instantiate()
	root.add_child(s2)
	await process_frame

	var hooks1: Variant = oa.get("hooks")
	var before_turn1: Variant = hooks1.get("before_turn")
	if typeof(before_turn1) != TYPE_ARRAY:
		T.fail_and_quit(self, "Expected before_turn array after second scene load")
		return

	var count := 0
	for m1 in before_turn1 as Array:
		if typeof(m1) != TYPE_DICTIONARY:
			continue
		if String((m1 as Dictionary).get("name", "")) == "vr_offices.before_turn":
			count += 1
	if not T.require_eq(self, count, 1, "Expected vr_offices.before_turn hook matcher to be installed once"):
		return

	T.pass_and_quit(self)
