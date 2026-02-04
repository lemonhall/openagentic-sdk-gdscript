extends SceneTree

const T := preload("res://tests/_test_util.gd")
const Q := preload("res://vr_offices/ui/VrOfficesAttachmentQueue.gd")

func _init() -> void:
	var q := Q.new()

	var id1 := int(q.call("enqueue", "/home/me/Pictures/a.png", {"bytes": 123, "mime": "image/png"}))
	var id2 := int(q.call("enqueue", "C:\\Users\\me\\Videos\\b.mp4", {"bytes": 456, "mime": "video/mp4"}))
	var id3 := int(q.call("enqueue", "/tmp/c.jpg", {"bytes": 789, "mime": "image/jpeg"}))

	if not T.require_true(self, id1 > 0 and id2 > 0 and id3 > 0, "expected positive ids"):
		return

	var it1: Dictionary = q.call("get_item", id1)
	var it2: Dictionary = q.call("get_item", id2)
	var it3: Dictionary = q.call("get_item", id3)

	if not T.require_eq(self, String(it1.get("name", "")), "a.png", "basename should not leak path"):
		return
	if not T.require_eq(self, String(it2.get("name", "")), "b.mp4", "basename should not leak path"):
		return
	if not T.require_eq(self, String(it3.get("name", "")), "c.jpg", "basename should not leak path"):
		return

	if not T.require_eq(self, String(it1.get("state", "")), "pending"):
		return

	if not T.require_true(self, bool(q.call("mark_uploading", id1)), "should mark uploading"):
		return
	if not T.require_eq(self, String(q.call("get_item", id1).get("state", "")), "uploading"):
		return

	if not T.require_true(self, bool(q.call("mark_sent", id1, "OAMEDIA1 ...")), "should mark sent"):
		return
	if not T.require_eq(self, String(q.call("get_item", id1).get("state", "")), "sent"):
		return

	# Invalid transition: sent -> uploading
	if not T.require_true(self, not bool(q.call("mark_uploading", id1)), "sent items must not transition"):
		return

	# Cancel a pending item
	if not T.require_true(self, bool(q.call("cancel_item", id2)), "should cancel pending"):
		return
	if not T.require_eq(self, String(q.call("get_item", id2).get("state", "")), "cancelled"):
		return

	# cancel_all cancels remaining pending items but not sent ones
	q.call("cancel_all")
	if not T.require_eq(self, String(q.call("get_item", id1).get("state", "")), "sent"):
		return
	if not T.require_eq(self, String(q.call("get_item", id3).get("state", "")), "cancelled"):
		return

	# Basic DialogueOverlay wiring exists (Attach button, queue container, test hooks).
	var DialogueScene := load("res://vr_offices/ui/DialogueOverlay.tscn")
	if DialogueScene == null:
		T.fail_and_quit(self, "Missing DialogueOverlay.tscn")
		return
	var dlg: Control = (DialogueScene as PackedScene).instantiate()
	get_root().add_child(dlg)
	await process_frame

	var attach_btn := dlg.get_node_or_null("Panel/VBox/Footer/AttachButton") as Button
	if not T.require_true(self, attach_btn != null, "Expected DialogueOverlay AttachButton"):
		return
	var attachments_panel := dlg.get_node_or_null("Panel/VBox/AttachmentsPanel") as Control
	if not T.require_true(self, attachments_panel != null, "Expected DialogueOverlay AttachmentsPanel"):
		return
	var file_dialog := dlg.get_node_or_null("FileDialog") as FileDialog
	if not T.require_true(self, file_dialog != null, "Expected DialogueOverlay FileDialog"):
		return

	if not dlg.has_method("_test_enqueue_attachment_paths"):
		T.fail_and_quit(self, "DialogueOverlay missing _test_enqueue_attachment_paths()")
		return
	if not dlg.has_method("_test_attachment_row_count"):
		T.fail_and_quit(self, "DialogueOverlay missing _test_attachment_row_count()")
		return

	dlg.call("_test_enqueue_attachment_paths", PackedStringArray(["/tmp/a.png", "/tmp/b.jpg"]))
	await process_frame

	var n := int(dlg.call("_test_attachment_row_count"))
	if not T.require_eq(self, n, 2, "Expected 2 attachment rows after enqueue"):
		return

	T.pass_and_quit(self)
