extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	# Regression: building long chat history must not block one frame.
	var overlay_scene := load("res://vr_offices/ui/DialogueOverlay.tscn")
	if overlay_scene == null or not (overlay_scene is PackedScene):
		T.fail_and_quit(self, "Missing res://vr_offices/ui/DialogueOverlay.tscn")
		return

	var overlay := (overlay_scene as PackedScene).instantiate() as Control
	if overlay == null:
		T.fail_and_quit(self, "Failed to instantiate DialogueOverlay.tscn")
		return

	get_root().add_child(overlay)
	await process_frame

	overlay.call("open", "npc_hist", "History NPC", "slot_test_hist_%s" % str(OS.get_process_id()))
	await process_frame

	var messages := overlay.get_node_or_null("%Messages") as VBoxContainer
	if not T.require_true(self, messages != null, "Missing Messages container"):
		return

	var items: Array = []
	for i in range(120):
		var role := "user" if (i % 2) == 0 else "assistant"
		items.append({"role": role, "text": "msg_%d" % i})

	overlay.call("set_history", items)

	# This MUST NOT synchronously render the full history in the same frame.
	# (Otherwise opening the overlay blocks on UI instantiation/layout.)
	var rendered_now := messages.get_child_count()
	if not T.require_true(self, rendered_now < items.size(), "Expected incremental history render. Got %d/%d immediately." % [rendered_now, items.size()]):
		return

	# Allow a short window for the incremental renderer to finish.
	var done := false
	for _k in range(120):
		if messages.get_child_count() == items.size():
			done = true
			break
		await process_frame

	if not T.require_true(self, done, "History did not finish rendering within frame budget. Got %d/%d." % [messages.get_child_count(), items.size()]):
		return

	# Sanity: ensure the last bubble contains the last message text.
	var last_row := messages.get_child(messages.get_child_count() - 1) as Node
	var labels := last_row.find_children("*", "RichTextLabel", true, false)
	if not T.require_true(self, labels.size() >= 1, "Expected RichTextLabel in last bubble"):
		return
	var rtl := labels[0] as RichTextLabel
	if not T.require_true(self, rtl.text.find("msg_119") != -1, "Expected last bubble to contain msg_119"):
		return

	overlay.free()
	await process_frame
	T.pass_and_quit(self)

