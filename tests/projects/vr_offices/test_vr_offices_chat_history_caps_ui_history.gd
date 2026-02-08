extends SceneTree

const T := preload("res://tests/_test_util.gd")

const _OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")
const _ChatHistory := preload("res://vr_offices/core/chat/VrOfficesChatHistory.gd")

func _init() -> void:
	var save_id := "slot_test_vr_offices_chat_history_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	var npc_id := "npc_perf"

	# Write a large JSONL log directly (avoid O(n^2) append behavior in the store).
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_OAPaths.npc_session_dir(save_id, npc_id)))
	var events_path := String(_OAPaths.npc_events_path(save_id, npc_id))
	var f := FileAccess.open(events_path, FileAccess.WRITE)
	if f == null:
		T.fail_and_quit(self, "Failed to open events.jsonl for write")
		return
	for i in range(120):
		f.store_line(JSON.stringify({"type": "user.message", "text": "U%d" % i}))
		for _d in range(6):
			f.store_line(JSON.stringify({"type": "assistant.delta", "text_delta": "x"}))
		f.store_line(JSON.stringify({"type": "assistant.message", "text": "A%d" % i}))
	f.close()

	var ch := _ChatHistory.new()
	var hist0: Variant = ch.read_ui_history(save_id, npc_id)
	if typeof(hist0) != TYPE_ARRAY:
		T.fail_and_quit(self, "Expected read_ui_history to return an Array")
		return
	var hist := hist0 as Array

	# The UI should not attempt to render unbounded history; cap to keep overlay opening fast.
	if not T.require_true(self, hist.size() <= 200, "Expected UI history to be capped (<=200 items). Got %d" % hist.size()):
		return

	# Must include the most recent messages.
	var tail_join := ""
	for it0 in hist:
		if typeof(it0) != TYPE_DICTIONARY:
			continue
		var it := it0 as Dictionary
		tail_join += " " + String(it.get("text", ""))
	if not T.require_true(self, tail_join.find("U119") != -1, "Expected UI history to include last user message U119"):
		return
	if not T.require_true(self, tail_join.find("A119") != -1, "Expected UI history to include last assistant message A119"):
		return

	# Must not include very old messages when capped.
	if not T.require_true(self, tail_join.find("U0") == -1, "Expected capped UI history to not include very old message U0"):
		return

	T.pass_and_quit(self)
