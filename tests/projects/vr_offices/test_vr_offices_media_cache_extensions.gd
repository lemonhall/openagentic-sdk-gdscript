extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var CacheScript := load("res://vr_offices/ui/VrOfficesMediaCache.gd")
	if CacheScript == null:
		T.fail_and_quit(self, "Missing VrOfficesMediaCache.gd")
		return

	var save_id := "slot_test_cache_ext_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	var base := {
		"id": "x",
		"sha256": _dummy_sha256(),
		"bytes": 1,
	}

	var mp3 := base.duplicate(true)
	mp3["mime"] = "audio/mpeg"
	var p1 := String((CacheScript as Script).call("media_cache_path", save_id, mp3))
	if not T.require_true(self, p1.ends_with(".mp3"), "Expected .mp3 cache extension"):
		return

	var wav := base.duplicate(true)
	wav["mime"] = "audio/wav"
	var p2 := String((CacheScript as Script).call("media_cache_path", save_id, wav))
	if not T.require_true(self, p2.ends_with(".wav"), "Expected .wav cache extension"):
		return

	var mp4 := base.duplicate(true)
	mp4["mime"] = "video/mp4"
	var p3 := String((CacheScript as Script).call("media_cache_path", save_id, mp4))
	if not T.require_true(self, p3.ends_with(".mp4"), "Expected .mp4 cache extension"):
		return

	T.pass_and_quit(self)

func _dummy_sha256() -> String:
	var s := ""
	for _i in range(64):
		s += "b"
	return s

