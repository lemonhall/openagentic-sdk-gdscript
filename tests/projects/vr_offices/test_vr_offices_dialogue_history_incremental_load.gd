extends SceneTree

const T := preload("res://tests/_test_util.gd")
const _OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")

func _init() -> void:
	# Regression: loading history from events.jsonl must not happen synchronously in the open/talk frame.
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

	var save_id := "slot_test_hist_load_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	var npc_id := "npc_hist_load"

	var events_path := String(_OAPaths.npc_events_path(save_id, npc_id))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_OAPaths.npc_session_dir(save_id, npc_id)))
	var wf := FileAccess.open(events_path, FileAccess.WRITE)
	if wf == null:
		T.fail_and_quit(self, "Failed to write " + events_path)
		return

	# Create a log with lots of non-message noise + a bounded number of messages.
	for i in range(1200):
		wf.store_string("{\"type\":\"tool.use\",\"name\":\"Noop\",\"ts\":%d}\n" % i)
	for j in range(120):
		var typ := "user.message" if (j % 2) == 0 else "assistant.message"
		wf.store_string("{\"type\":\"%s\",\"text\":\"msg_%d\",\"ts\":%d}\n" % [typ, j, 2000 + j])
	wf.close()

	overlay.call("open", npc_id, "History NPC", save_id)
	await process_frame

	var messages := overlay.get_node_or_null("%Messages") as VBoxContainer
	if not T.require_true(self, messages != null, "Missing Messages container"):
		return

	if not T.require_true(self, overlay.has_method("begin_history_load_from_events_jsonl"), "DialogueOverlay must support incremental history load"):
		return

	overlay.call("begin_history_load_from_events_jsonl", save_id, npc_id)

	# Must not synchronously populate history in the same call.
	if not T.require_eq(self, messages.get_child_count(), 0, "Expected history load to be asynchronous (frame-sliced)"):
		return

	# Allow time for: (1) file parse to complete, (2) set_history incremental render to complete.
	var done := false
	for _k in range(60):
		if messages.get_child_count() == 120:
			done = true
			break
		await process_frame

	if not T.require_true(self, done, "History did not finish loading+rendering within frame budget. Got %d/120." % messages.get_child_count()):
		return

	# Sanity: last rendered bubble contains the last message.
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
