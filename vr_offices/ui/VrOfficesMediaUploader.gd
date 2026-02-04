extends RefCounted
class_name VrOfficesMediaUploader

const _OAMediaHttp := preload("res://addons/openagentic/core/OAMediaHttp.gd")
const _OAMediaRef := preload("res://addons/openagentic/core/OAMediaRef.gd")
const _MediaCache := preload("res://vr_offices/ui/VrOfficesMediaCache.gd")

const LIMITS: Dictionary = {
	"image/png": 8 * 1024 * 1024,
	"image/jpeg": 8 * 1024 * 1024,
	"audio/mpeg": 20 * 1024 * 1024,
	"audio/wav": 20 * 1024 * 1024,
	"video/mp4": 64 * 1024 * 1024,
}

static func validate_path_for_upload(path: String) -> Dictionary:
	var p := path.strip_edges()
	if p == "":
		return {"ok": false, "error": "EmptyPath"}
	if not FileAccess.file_exists(p):
		return {"ok": false, "error": "NotFound"}

	var mime := mime_from_path(p)
	if mime == "":
		return {"ok": false, "error": "UnsupportedType"}

	var limit := int(LIMITS.get(mime, 0))
	if limit <= 0:
		return {"ok": false, "error": "UnsupportedType"}

	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {"ok": false, "error": "OpenFailed"}
	var n := int(f.get_length())
	f.close()
	if n <= 0:
		return {"ok": false, "error": "EmptyFile"}
	if n > limit:
		return {"ok": false, "error": "TooLarge", "bytes": n, "limit": limit, "mime": mime}

	return {"ok": true, "mime": mime, "bytes": n, "name": _basename(p)}

static func upload_file(
	path: String,
	save_id: String,
	base_url: String,
	bearer_token: String,
	caption: String = "",
	transport: Callable = Callable()
) -> Dictionary:
	var cfg_base := base_url.strip_edges()
	var cfg_tok := bearer_token.strip_edges()
	if cfg_base == "" or cfg_tok == "":
		return {"ok": false, "error": "MissingMediaConfig"}

	var v: Dictionary = validate_path_for_upload(path)
	if not bool(v.get("ok", false)):
		return v

	var p := path.strip_edges()
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {"ok": false, "error": "OpenFailed"}
	var buf := f.get_buffer(f.get_length())
	f.close()
	if buf.is_empty():
		return {"ok": false, "error": "EmptyFile"}

	var name := String(v.get("name", "")).strip_edges()
	var headers := {
		"authorization": "Bearer " + cfg_tok,
		"x-oa-name": name,
	}
	var cap := caption.strip_edges()
	if cap != "":
		headers["x-oa-caption"] = cap

	var url := cfg_base
	if url.ends_with("/"):
		url = url.substr(0, url.length() - 1)
	url += "/upload"

	var resp: Dictionary = await _OAMediaHttp.request(HTTPClient.METHOD_POST, url, headers, buf, 30.0, transport)
	if not bool(resp.get("ok", false)):
		return {"ok": false, "error": String(resp.get("error", "RequestError")), "status": int(resp.get("status", 0))}

	var status := int(resp.get("status", 0))
	var body: PackedByteArray = resp.get("body", PackedByteArray())
	if status != 200:
		return {"ok": false, "error": "UploadFailed", "status": status, "body": body.get_string_from_utf8()}

	var obj0: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(obj0) != TYPE_DICTIONARY:
		return {"ok": false, "error": "BadJson"}
	var obj: Dictionary = obj0 as Dictionary
	if not bool(obj.get("ok", false)):
		return {"ok": false, "error": String(obj.get("error", "UploadFailed")), "status": status}

	var id := String(obj.get("id", "")).strip_edges()
	var kind := String(obj.get("kind", "")).strip_edges()
	var mime := String(obj.get("mime", "")).strip_edges()
	var bytes := int(obj.get("bytes", -1))
	var sha := String(obj.get("sha256", "")).strip_edges().to_lower()
	if id == "" or kind == "" or mime == "" or bytes <= 0 or sha == "":
		return {"ok": false, "error": "BadMeta"}
	if bytes != buf.size():
		return {"ok": false, "error": "SizeMismatch"}
	if sha256_hex(buf) != sha:
		return {"ok": false, "error": "ShaMismatch"}

	var ref := {
		"id": id,
		"kind": kind,
		"mime": mime,
		"bytes": bytes,
		"sha256": sha,
		"name": name,
	}
	var line: String = _OAMediaRef.encode_v1(ref)
	if not line.begins_with("OAMEDIA1 "):
		return {"ok": false, "error": "EncodeFailed"}

	var cache: Dictionary = _MediaCache.store_cached_bytes(save_id, ref, buf)
	if not bool(cache.get("ok", false)):
		return {"ok": false, "error": String(cache.get("error", "CacheWriteFailed"))}

	return {"ok": true, "media_ref": line, "ref": ref, "cache_path": String(cache.get("path", ""))}

static func mime_from_path(path: String) -> String:
	var ext := String(path.get_extension()).to_lower()
	if ext == "png":
		return "image/png"
	if ext == "jpg" or ext == "jpeg":
		return "image/jpeg"
	if ext == "mp3":
		return "audio/mpeg"
	if ext == "wav":
		return "audio/wav"
	if ext == "mp4":
		return "video/mp4"
	return ""

static func sha256_hex(b: PackedByteArray) -> String:
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	hc.update(b)
	return hc.finish().hex_encode()

static func _basename(path: String) -> String:
	var p := path.replace("\\", "/")
	return p.get_file()

