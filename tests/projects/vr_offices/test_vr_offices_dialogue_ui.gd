extends SceneTree

const T := preload("res://tests/_test_util.gd")
const _OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")

var _closed_called := false

func _init() -> void:
	# Unit-test the modern dialogue overlay UI (no network calls).
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

	if not T.require_true(self, overlay.visible == false, "DialogueOverlay should start hidden"):
		return

	if overlay.has_signal("closed"):
		overlay.connect("closed", Callable(self, "_on_overlay_closed"))

	# Provide a save_id context so DialogueOverlay can show the per-NPC session log size.
	var save_id: String = "slot_test_dialogue_ui_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]

	# Create a small per-NPC events.jsonl file (known size) to validate UI size indicator.
	var npc_id := "npc_1"
	var events_path := String(_OAPaths.npc_events_path(save_id, npc_id))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_OAPaths.npc_session_dir(save_id, npc_id)))
	var wf := FileAccess.open(events_path, FileAccess.WRITE)
	if wf == null:
		T.fail_and_quit(self, "Failed to write " + events_path)
		return
	wf.store_string("Hello\n")
	wf.close()
	var rf := FileAccess.open(events_path, FileAccess.READ)
	var expected_bytes := rf.get_length() if rf != null else 0
	if rf != null:
		rf.close()

	if not T.require_true(self, overlay.has_method("open"), "DialogueOverlay must have open()"):
		return
	overlay.call("open", npc_id, "林晓", save_id)
	if not T.require_true(self, overlay.visible == true, "DialogueOverlay.open() should show overlay"):
		return

	var title := overlay.get_node("Panel/VBox/Header/TitleLabel") as Label
	if not T.require_true(self, title != null, "Missing TitleLabel"):
		return
	if not T.require_eq(self, title.text, "林晓", "Title must reflect npc_name"):
		return

	var size_label := overlay.get_node_or_null("Panel/VBox/Header/SessionLogSizeLabel") as Label
	if not T.require_true(self, size_label != null, "Missing SessionLogSizeLabel"):
		return
	if not T.require_true(self, size_label.text.find("events.jsonl=") != -1, "Expected events.jsonl size label"):
		return
	if not T.require_true(self, size_label.text.find("%dB" % expected_bytes) != -1, "Expected label to include file size in bytes. Got: " + size_label.text):
		return

	var clear_btn := overlay.get_node_or_null("Panel/VBox/Header/ClearSessionLogButton") as Button
	if not T.require_true(self, clear_btn != null, "Missing ClearSessionLogButton"):
		return

	# Message append.
	var messages := overlay.get_node("Panel/VBox/Scroll/Messages") as VBoxContainer
	if not T.require_true(self, messages != null, "Missing Messages container"):
		return
	if not T.require_eq(self, messages.get_child_count(), 0, "Messages should start empty"):
		return

	if not T.require_true(self, overlay.has_method("add_user_message"), "DialogueOverlay must have add_user_message()"):
		return
	overlay.call("add_user_message", "Hello")
	if not T.require_eq(self, messages.get_child_count(), 1, "Expected 1 message after add_user_message()"):
		return

	# Assistant streaming.
	if not T.require_true(self, overlay.has_method("begin_assistant") and overlay.has_method("append_assistant_delta"), "Expected assistant streaming methods"):
		return
	overlay.call("begin_assistant")
	overlay.call("append_assistant_delta", "Hi")
	if not T.require_eq(self, messages.get_child_count(), 2, "Expected 2 messages after begin_assistant()"):
		return

	# Verify last message contains "Hi".
	var last_row := messages.get_child(messages.get_child_count() - 1) as Node
	var labels := last_row.find_children("*", "RichTextLabel", true, false)
	if not T.require_true(self, labels.size() >= 1, "Expected RichTextLabel in assistant bubble"):
		return
	var rtl := labels[0] as RichTextLabel
	if not T.require_true(self, rtl.text.find("Hi") != -1, "Expected assistant bubble to contain delta text"):
		return

	# Busy state toggles input.
	if not T.require_true(self, overlay.has_method("set_busy"), "DialogueOverlay must have set_busy()"):
		return
	var input := overlay.get_node("Panel/VBox/Footer/Input") as LineEdit
	var send := overlay.get_node("Panel/VBox/Footer/SendButton") as Button
	if not T.require_true(self, input != null and send != null, "Missing input/send controls"):
		return
	overlay.call("set_busy", true)
	if not T.require_true(self, input.editable == false and send.disabled == true, "Busy should disable input/send"):
		return
	if not T.require_true(self, clear_btn.disabled == true, "Busy should disable ClearSessionLogButton"):
		return
	overlay.call("set_busy", false)
	if not T.require_true(self, input.editable == true and send.disabled == false, "Unbusy should enable input/send"):
		return
	if not T.require_true(self, clear_btn.disabled == false, "Unbusy should enable ClearSessionLogButton"):
		return

	# Clear should truncate persisted events.jsonl and clear UI bubbles.
	clear_btn.emit_signal("pressed")
	await process_frame
	var rf2 := FileAccess.open(events_path, FileAccess.READ)
	var bytes2 := rf2.get_length() if rf2 != null else -1
	if rf2 != null:
		rf2.close()
	if not T.require_eq(self, bytes2, 0, "Expected events.jsonl length 0 after clear"):
		return
	if not T.require_true(self, size_label.text.find("0B") != -1, "Expected size label to update after clear. Got: " + size_label.text):
		return
	if not T.require_eq(self, messages.get_child_count(), 0, "Expected UI bubbles cleared after log clear"):
		return

	# Close by interacting with the backdrop (outside panel):
	# - Right-click single
	# - Left double-click
	_closed_called = false
	var ev_right := InputEventMouseButton.new()
	ev_right.button_index = MOUSE_BUTTON_RIGHT
	ev_right.pressed = true
	overlay.call("_on_backdrop_gui_input", ev_right)
	await process_frame
	if not T.require_true(self, overlay.visible == false, "Backdrop right-click should close overlay"):
		return
	if not T.require_true(self, _closed_called, "Backdrop close should emit closed"):
		return

	_closed_called = false
	overlay.call("open", "npc_1", "林晓")
	await process_frame
	var ev_dbl := InputEventMouseButton.new()
	ev_dbl.button_index = MOUSE_BUTTON_LEFT
	ev_dbl.pressed = true
	ev_dbl.double_click = true
	overlay.call("_on_backdrop_gui_input", ev_dbl)
	await process_frame
	if not T.require_true(self, overlay.visible == false, "Backdrop double-click should close overlay"):
		return
	if not T.require_true(self, _closed_called, "Backdrop double-click should emit closed"):
		return

	# Free explicitly to avoid headless shutdown leak noise.
	overlay.free()
	await process_frame

	# UI regression: Add/Remove buttons should not be activatable via Enter.
	var ui_scene := load("res://vr_offices/ui/VrOfficesUi.tscn")
	if ui_scene == null or not (ui_scene is PackedScene):
		T.fail_and_quit(self, "Missing res://vr_offices/ui/VrOfficesUi.tscn")
		return
	var ui := (ui_scene as PackedScene).instantiate() as Control
	if ui == null:
		T.fail_and_quit(self, "Failed to instantiate VrOfficesUi.tscn")
		return
	get_root().add_child(ui)
	await process_frame

	var add_btn := ui.get_node("Panel/VBox/Buttons/AddNpcButton") as Button
	var rm_btn := ui.get_node("Panel/VBox/Buttons/RemoveSelectedButton") as Button
	if not T.require_true(self, add_btn != null and rm_btn != null, "Missing Add/Remove buttons"):
		return
	if not T.require_eq(self, add_btn.focus_mode, Control.FOCUS_NONE, "Add NPC button should not capture focus (prevents Enter activation)"):
		return
	if not T.require_eq(self, rm_btn.focus_mode, Control.FOCUS_NONE, "Remove button should not capture focus (prevents Enter activation)"):
		return

	ui.free()
	await process_frame

	T.pass_and_quit(self)

func _on_overlay_closed() -> void:
	_closed_called = true
