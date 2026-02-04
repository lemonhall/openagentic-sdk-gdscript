extends RefCounted
class_name VrOfficesMediaCache

const _OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")

const DEFAULT_CACHE_MAX_BYTES := 256 * 1024 * 1024

static func media_cache_dir(save_id: String) -> String:
	var sid := save_id.strip_edges()
	if sid == "":
		return ""
	return "%s/cache/media" % _OAPaths.save_root(sid)

static func media_cache_path(save_id: String, ref: Dictionary) -> String:
	var dir := media_cache_dir(save_id)
	if dir == "":
		return ""
	var id := String(ref.get("id", "")).strip_edges()
	var sha := String(ref.get("sha256", "")).strip_edges().to_lower()
	var mime := String(ref.get("mime", "")).strip_edges().to_lower()
	if id == "" or sha == "" or mime == "":
		return ""
	var ext := ".bin"
	if mime == "image/png":
		ext = ".png"
	elif mime == "image/jpeg":
		ext = ".jpg"
	elif mime == "audio/mpeg":
		ext = ".mp3"
	elif mime == "audio/wav":
		ext = ".wav"
	elif mime == "video/mp4":
		ext = ".mp4"
	return "%s/%s_%s%s" % [dir, id, sha, ext]

static func load_cached_image_texture(save_id: String, ref: Dictionary) -> Texture2D:
	var p := media_cache_path(save_id, ref)
	if p == "" or not FileAccess.file_exists(p):
		return null
	var expected_bytes := int(ref.get("bytes", -1))
	var expected_sha := String(ref.get("sha256", "")).strip_edges().to_lower()
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return null
	var buf := f.get_buffer(f.get_length())
	f.close()
	if expected_bytes > 0 and buf.size() != expected_bytes:
		return null
	if expected_sha != "" and sha256_hex(buf) != expected_sha:
		return null
	var img := Image.new()
	var err := img.load(p)
	if err != OK:
		return null
	return ImageTexture.create_from_image(img)

static func store_cached_bytes(save_id: String, ref: Dictionary, bytes: PackedByteArray) -> Dictionary:
	var p := media_cache_path(save_id, ref)
	if p == "":
		return {"ok": false, "error": "BadCachePath"}
	var abs_dir := ProjectSettings.globalize_path(p.get_base_dir())
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": "WriteFailed"}
	f.store_buffer(bytes)
	f.close()

	# Best-effort cache cleanup (REQ-006): TTL and max-bytes pruning.
	var max_bytes := _cache_max_bytes_from_env()
	var ttl_sec := _cache_ttl_sec_from_env()
	prune_cache(save_id, max_bytes, ttl_sec)

	return {"ok": true, "path": p}

static func sha256_hex(b: PackedByteArray) -> String:
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	hc.update(b)
	return hc.finish().hex_encode()

static func prune_cache(save_id: String, max_bytes: int, ttl_sec: int) -> Dictionary:
	var dir := media_cache_dir(save_id)
	if dir == "":
		return {"ok": false, "error": "BadCacheDir"}
	var abs_dir := ProjectSettings.globalize_path(dir)
	if not DirAccess.dir_exists_absolute(abs_dir):
		return {"ok": true, "removed": 0, "total_bytes": 0}

	var now := int(Time.get_unix_time_from_system())
	var removed := 0

	# Pass 1: TTL cleanup.
	if ttl_sec > 0:
		var da0 := DirAccess.open(abs_dir)
		if da0 != null:
			for name0 in da0.get_files():
				var name := String(name0)
				if name == "":
					continue
				var abs_path := "%s/%s" % [abs_dir, name]
				var mt := int(FileAccess.get_modified_time(abs_path))
				if mt > 0 and (now - mt) > ttl_sec:
					var err := DirAccess.remove_absolute(abs_path)
					if err == OK:
						removed += 1

	# Pass 2: max-bytes eviction (oldest-first).
	if max_bytes > 0:
		var items: Array[Dictionary] = []
		var total := 0
		var da := DirAccess.open(abs_dir)
		if da != null:
			for name0 in da.get_files():
				var name := String(name0)
				if name == "":
					continue
				var abs_path := "%s/%s" % [abs_dir, name]
				var f := FileAccess.open(abs_path, FileAccess.READ)
				if f == null:
					continue
				var n := int(f.get_length())
				f.close()
				var mt2 := int(FileAccess.get_modified_time(abs_path))
				items.append({"path": abs_path, "bytes": n, "mtime": mt2})
				total += n

		items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var ta := int(a.get("mtime", 0))
			var tb := int(b.get("mtime", 0))
			if ta != tb:
				return ta < tb
			return String(a.get("path", "")) < String(b.get("path", ""))
		)

		for it in items:
			if total <= max_bytes:
				break
			var p := String(it.get("path", ""))
			var n2 := int(it.get("bytes", 0))
			var err2 := DirAccess.remove_absolute(p)
			if err2 == OK:
				removed += 1
				total -= n2

		return {"ok": total <= max_bytes, "removed": removed, "total_bytes": total, "max_bytes": max_bytes}

	return {"ok": true, "removed": removed, "total_bytes": -1}

static func _cache_max_bytes_from_env() -> int:
	var raw := String(OS.get_environment("OPENAGENTIC_MEDIA_CACHE_MAX_BYTES")).strip_edges()
	var n := int(raw.to_int()) if raw != "" else 0
	if n <= 0:
		return DEFAULT_CACHE_MAX_BYTES
	return n

static func _cache_ttl_sec_from_env() -> int:
	var raw := String(OS.get_environment("OPENAGENTIC_MEDIA_CACHE_TTL_SEC")).strip_edges()
	var n := int(raw.to_int()) if raw != "" else 0
	if n < 0:
		return 0
	return n
