extends RefCounted
class_name VrOfficesMediaCache

const _OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")

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
	return {"ok": true, "path": p}

static func sha256_hex(b: PackedByteArray) -> String:
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	hc.update(b)
	return hc.finish().hex_encode()
