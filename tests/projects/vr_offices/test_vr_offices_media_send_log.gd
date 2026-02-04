extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var LogScript := load("res://vr_offices/core/media/VrOfficesMediaSendLog.gd")
	if LogScript == null:
		T.fail_and_quit(self, "Missing VrOfficesMediaSendLog.gd")
		return

	var save_id := "slot_test_media_log_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	var entry := {
		"ts": int(Time.get_unix_time_from_system()),
		"npc_id": "npc_1",
		"ref": {
			"id": "img_1",
			"kind": "image",
			"mime": "image/png",
			"bytes": 1,
			"sha256": "a".repeat(64),
			"name": "x.png",
		},
	}

	var wr: Dictionary = (LogScript as Script).call("append", save_id, entry)
	if not T.require_true(self, bool(wr.get("ok", false)), "append should succeed"):
		return

	var rd: Dictionary = (LogScript as Script).call("list_recent", save_id, 10)
	if not T.require_true(self, bool(rd.get("ok", false)), "list_recent should succeed"):
		return
	var items0: Variant = rd.get("items", [])
	if not T.require_true(self, typeof(items0) == TYPE_ARRAY, "items must be Array"):
		return
	var items: Array = items0 as Array
	if not T.require_true(self, items.size() >= 1, "expected >=1 log item"):
		return

	var last: Dictionary = items[items.size() - 1] as Dictionary
	if not T.require_eq(self, String(last.get("npc_id", "")), "npc_1", "npc_id"):
		return
	if typeof(last.get("ref", null)) != TYPE_DICTIONARY:
		T.fail_and_quit(self, "missing ref dict")
		return
	if not T.require_eq(self, String((last.get("ref", {}) as Dictionary).get("id", "")), "img_1", "ref.id"):
		return

	T.pass_and_quit(self)

