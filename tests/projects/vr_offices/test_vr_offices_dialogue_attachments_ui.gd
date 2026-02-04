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

	T.pass_and_quit(self)

