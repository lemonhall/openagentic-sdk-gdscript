extends RefCounted
class_name VrOfficesMediaDownloader

const _OAMediaHttp := preload("res://addons/openagentic/core/OAMediaHttp.gd")
const _MediaCache := preload("res://vr_offices/ui/VrOfficesMediaCache.gd")

static func download_to_cache(
	save_id: String,
	ref: Dictionary,
	base_url: String,
	bearer_token: String,
	transport: Callable = Callable()
) -> Dictionary:
	var sid := save_id.strip_edges()
	if sid == "":
		return {"ok": false, "error": "MissingSaveId"}

	var id := String(ref.get("id", "")).strip_edges()
	var expected_sha := String(ref.get("sha256", "")).strip_edges().to_lower()
	var expected_bytes := int(ref.get("bytes", -1))
	if id == "" or expected_sha == "" or expected_bytes <= 0:
		return {"ok": false, "error": "BadRef"}

	var cfg_base := base_url.strip_edges()
	var cfg_tok := bearer_token.strip_edges()
	if cfg_base == "" or cfg_tok == "":
		return {"ok": false, "error": "MissingMediaConfig"}

	var url := cfg_base
	if url.ends_with("/"):
		url = url.substr(0, url.length() - 1)
	url += "/media/" + id

	var headers := {"authorization": "Bearer " + cfg_tok}
	var resp: Dictionary = await _OAMediaHttp.request(HTTPClient.METHOD_GET, url, headers, PackedByteArray(), 30.0, transport)
	if not bool(resp.get("ok", false)):
		return {"ok": false, "error": String(resp.get("error", "RequestError")), "status": int(resp.get("status", 0))}

	var status := int(resp.get("status", 0))
	if status != 200:
		return {"ok": false, "error": "DownloadFailed", "status": status}

	var body: PackedByteArray = resp.get("body", PackedByteArray())
	if body.size() != expected_bytes:
		return {"ok": false, "error": "SizeMismatch", "bytes": body.size(), "expected": expected_bytes}

	var sha := _MediaCache.sha256_hex(body)
	if sha != expected_sha:
		return {"ok": false, "error": "ShaMismatch"}

	var wr: Dictionary = _MediaCache.store_cached_bytes(sid, ref, body)
	if not bool(wr.get("ok", false)):
		return {"ok": false, "error": String(wr.get("error", "CacheWriteFailed"))}

	return {"ok": true, "path": String(wr.get("path", ""))}

