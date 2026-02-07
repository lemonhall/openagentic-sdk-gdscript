extends RefCounted

var owner: Node = null
var action_hint: Control = null

var _shown := false
var _generation := 0

func _init(owner_in: Node, action_hint_in: Control) -> void:
	owner = owner_in
	action_hint = action_hint_in

func show_once(text: String, seconds: float = 10.0) -> void:
	if _shown:
		return
	if owner == null or action_hint == null:
		return
	if not owner.is_inside_tree():
		return
	if not action_hint.has_method("show_hint") or not action_hint.has_method("hide_hint"):
		return

	_shown = true
	_generation += 1
	var gen := _generation
	action_hint.call("show_hint", text)

	var tree := owner.get_tree()
	if tree == null:
		return
	tree.create_timer(maxf(0.05, seconds)).timeout.connect(func() -> void:
		if _generation != gen:
			return
		if action_hint != null and action_hint.has_method("hide_hint"):
			action_hint.call("hide_hint")
	)

