extends RefCounted
class_name VrOfficesMediaHealth

const _OAMediaHttp := preload("res://addons/openagentic/core/OAMediaHttp.gd")

static func check_health(base_url: String, transport: Callable = Callable()) -> Dictionary:
	var base := base_url.strip_edges()
	if base == "":
		return {"ok": false, "error": "MissingBaseUrl"}
	if base.ends_with("/"):
		base = base.rstrip("/")
	var url := base + "/healthz"
	var t0 := Time.get_ticks_msec()
	var resp: Dictionary = await _OAMediaHttp.request(HTTPClient.METHOD_GET, url, {}, PackedByteArray(), 10.0, transport)
	var dt := int(Time.get_ticks_msec() - t0)
	if not bool(resp.get("ok", false)):
		return {"ok": false, "error": String(resp.get("error", "RequestError")), "status": int(resp.get("status", 0)), "ms": dt}
	var status := int(resp.get("status", 0))
	return {"ok": status == 200, "status": status, "ms": dt}

