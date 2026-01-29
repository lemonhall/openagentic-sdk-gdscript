extends SceneTree

const T := preload("res://tests/_test_util.gd")

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

	if not T.require_true(self, overlay.has_method("open"), "DialogueOverlay must have open()"):
		return
	overlay.call("open", "npc_1", "林晓")
	if not T.require_true(self, overlay.visible == true, "DialogueOverlay.open() should show overlay"):
		return

	var title := overlay.get_node("Panel/VBox/Header/TitleLabel") as Label
	if not T.require_true(self, title != null, "Missing TitleLabel"):
		return
	if not T.require_eq(self, title.text, "林晓", "Title must reflect npc_name"):
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
	overlay.call("set_busy", false)
	if not T.require_true(self, input.editable == true and send.disabled == false, "Unbusy should enable input/send"):
		return

	# Close.
	if not T.require_true(self, overlay.has_method("close"), "DialogueOverlay must have close()"):
		return
	overlay.call("close")
	if not T.require_true(self, overlay.visible == false, "DialogueOverlay.close() should hide overlay"):
		return
	if not T.require_true(self, _closed_called, "DialogueOverlay should emit closed"):
		return

	overlay.queue_free()
	await process_frame
	await process_frame
	RenderingServer.sync()

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

	ui.queue_free()
	await process_frame
	await process_frame
	RenderingServer.sync()

	T.pass_and_quit(self)

func _on_overlay_closed() -> void:
	_closed_called = true
