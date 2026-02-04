extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var CacheScript := load("res://vr_offices/ui/VrOfficesMediaCache.gd")
	if CacheScript == null:
		T.fail_and_quit(self, "Missing VrOfficesMediaCache.gd")
		return

	# Must expose a pruning API for PRD REQ-006 (TTL/LRU/size cap).
	if not (CacheScript as Object).has_method("prune_cache"):
		T.fail_and_quit(self, "VrOfficesMediaCache missing prune_cache()")
		return

	var save_id := "slot_test_cache_prune_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]

	var ref1 := {"id": "a", "sha256": _dummy_sha256("a"), "mime": "image/png"}
	var ref2 := {"id": "b", "sha256": _dummy_sha256("b"), "mime": "image/png"}
	var ref3 := {"id": "c", "sha256": _dummy_sha256("c"), "mime": "image/png"}

	var p1 := String((CacheScript as Script).call("media_cache_path", save_id, ref1))
	var p2 := String((CacheScript as Script).call("media_cache_path", save_id, ref2))
	var p3 := String((CacheScript as Script).call("media_cache_path", save_id, ref3))
	if p1 == "" or p2 == "" or p3 == "":
		T.fail_and_quit(self, "Expected cache paths")
		return

	var b1 := PackedByteArray([1, 1, 1, 1])
	var b2 := PackedByteArray([2, 2, 2, 2])
	var b3 := PackedByteArray([3, 3, 3, 3])

	(CacheScript as Script).call("store_cached_bytes", save_id, ref1, b1)
	OS.delay_msec(1100) # ensure mtime differs across files on coarse filesystems
	(CacheScript as Script).call("store_cached_bytes", save_id, ref2, b2)
	OS.delay_msec(1100)
	(CacheScript as Script).call("store_cached_bytes", save_id, ref3, b3)

	if not T.require_true(self, FileAccess.file_exists(p1) and FileAccess.file_exists(p2) and FileAccess.file_exists(p3), "Precondition: all cache files exist"):
		return

	# Prune down to 8 bytes: keep two newest (b,c), evict oldest (a).
	var rr: Dictionary = (CacheScript as Script).call("prune_cache", save_id, 8, 0)
	if not T.require_true(self, bool(rr.get("ok", false)), "Expected prune_cache ok"):
		return

	if not T.require_true(self, not FileAccess.file_exists(p1), "Expected oldest entry evicted"):
		return
	if not T.require_true(self, FileAccess.file_exists(p2) and FileAccess.file_exists(p3), "Expected newest entries kept"):
		return

	T.pass_and_quit(self)

func _dummy_sha256(seed: String) -> String:
	var out := ""
	var ch := seed.left(1)
	if ch == "":
		ch = "a"
	for _i in range(64):
		out += ch
	return out

