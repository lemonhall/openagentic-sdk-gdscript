extends RefCounted
class_name VrOfficesTavilyHealth

const _OAMediaHttp := preload("res://addons/openagentic/core/OAMediaHttp.gd")

static func check_health(base_url: String, api_key: String, transport: Callable = Callable()) -> Dictionary:
	var base := base_url.strip_edges()
	if base == "":
		return {"ok": false, "error": "MissingBaseUrl"}
	if base.ends_with("/"):
		base = base.rstrip("/")
	var key := api_key.strip_edges()
	if key == "":
		return {"ok": false, "error": "MissingApiKey"}

	var url := base + "/search"
	var payload := {"api_key": key, "query": "health check", "max_results": 1}
	var body_txt := JSON.stringify(payload)
	var body := body_txt.to_utf8_buffer()

	var headers := {"content-type": "application/json", "accept": "application/json"}
	var resp: Dictionary = await _OAMediaHttp.request(HTTPClient.METHOD_POST, url, headers, body, 10.0, transport)
	if not bool(resp.get("ok", false)):
		return {"ok": false, "error": String(resp.get("error", "RequestError")), "status": int(resp.get("status", 0))}

	var status := int(resp.get("status", 0))
	if status != 200:
		return {"ok": false, "error": "HttpError", "status": status}

	var raw: PackedByteArray = resp.get("body", PackedByteArray())
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "BadJson"}
	return {"ok": true}

