extends RefCounted
class_name VrOfficesSkillsMpClient

const _OAMediaHttp := preload("res://addons/openagentic/core/OAMediaHttp.gd")

func build_search_url(base_url: String, q: String, page: int, limit: int, sort_by: String) -> String:
	var base := base_url.strip_edges()
	if base.ends_with("/"):
		base = base.rstrip("/")

	var qp := PackedStringArray()
	qp.append("q=%s" % q.uri_encode())
	if page > 0:
		qp.append("page=%d" % page)
	if limit > 0:
		qp.append("limit=%d" % limit)
	var s := sort_by.strip_edges()
	if s != "":
		qp.append("sortBy=%s" % s.uri_encode())
	return base + "/api/v1/skills/search?" + "&".join(qp)

func search(
	base_url: String,
	api_key: String,
	q: String,
	page: int = 1,
	limit: int = 20,
	sort_by: String = "",
	transport: Callable = Callable()
) -> Dictionary:
	var base := base_url.strip_edges()
	if base == "":
		return {"ok": false, "error": "MissingBaseUrl", "url": ""}
	if base.ends_with("/"):
		base = base.rstrip("/")
	var key := api_key.strip_edges()
	if key == "":
		return {"ok": false, "error": "MissingApiKey", "url": ""}
	var query := q.strip_edges()
	if query == "":
		return {"ok": false, "error": "MissingQuery", "url": ""}

	var lim := clampi(limit, 1, 100)
	var pg := maxi(1, page)
	var url := build_search_url(base, query, pg, lim, sort_by)

	var headers := {
		"accept": "application/json",
		"Authorization": "Bearer %s" % key,
	}

	var resp: Dictionary = await _OAMediaHttp.request(HTTPClient.METHOD_GET, url, headers, PackedByteArray(), 15.0, transport)
	if not bool(resp.get("ok", false)):
		return {"ok": false, "error": String(resp.get("error", "RequestError")), "status": int(resp.get("status", 0)), "url": url}

	var status := int(resp.get("status", 0))
	var raw: PackedByteArray = resp.get("body", PackedByteArray())
	var parsed: Variant = null
	if raw.size() > 0:
		parsed = JSON.parse_string(raw.get_string_from_utf8())

	if status != 200:
		var err_code := ""
		var err_msg := ""
		if typeof(parsed) == TYPE_DICTIONARY:
			var pd: Dictionary = parsed as Dictionary
			var err0: Variant = pd.get("error", null)
			if typeof(err0) == TYPE_DICTIONARY:
				var err: Dictionary = err0 as Dictionary
				err_code = String(err.get("code", "")).strip_edges()
				err_msg = String(err.get("message", "")).strip_edges()
		return {"ok": false, "error": "HttpError", "status": status, "error_code": err_code, "message": err_msg, "raw": parsed, "url": url}

	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "BadJson", "status": status, "url": url}
	var obj: Dictionary = parsed as Dictionary
	if not bool(obj.get("success", true)):
		var err2: Dictionary = obj.get("error", {}) if typeof(obj.get("error", null)) == TYPE_DICTIONARY else {}
		return {
			"ok": false,
			"error": "ApiError",
			"status": status,
			"error_code": String(err2.get("code", "")).strip_edges(),
			"message": String(err2.get("message", "")).strip_edges(),
			"raw": obj,
			"url": url,
		}

	var extracted := _extract_items_and_pagination(obj)
	return {
		"ok": true,
		"status": status,
		"items": extracted.get("items", []),
		"pagination": extracted.get("pagination", {}),
		"raw": obj,
		"url": url,
	}

func _extract_items_and_pagination(obj: Dictionary) -> Dictionary:
	var items: Array = []
	var page := 1
	var limit := 0
	var total := 0
	var total_pages := 0

	page = _read_page(obj, page)
	limit = _read_limit(obj, limit)
	total = _read_total(obj, total)
	total_pages = _read_total_pages(obj, total_pages)

	var data0: Variant = obj.get("data", null)
	if typeof(data0) == TYPE_DICTIONARY:
		var data: Dictionary = data0 as Dictionary
		var items0: Variant = data.get("items", data.get("skills", data.get("results", null)))
		if typeof(items0) == TYPE_ARRAY:
			items = items0 as Array
		page = _read_page(data, page)
		limit = _read_limit(data, limit)
		total = _read_total(data, total)
		total_pages = _read_total_pages(data, total_pages)

		var data_meta0: Variant = data.get("meta", null)
		if typeof(data_meta0) == TYPE_DICTIONARY:
			var data_meta: Dictionary = data_meta0 as Dictionary
			page = _read_page(data_meta, page)
			limit = _read_limit(data_meta, limit)
			total = _read_total(data_meta, total)
			total_pages = _read_total_pages(data_meta, total_pages)

		var data_pg0: Variant = data.get("pagination", null)
		if typeof(data_pg0) == TYPE_DICTIONARY:
			var data_pg: Dictionary = data_pg0 as Dictionary
			page = _read_page(data_pg, page)
			limit = _read_limit(data_pg, limit)
			total = _read_total(data_pg, total)
			total_pages = _read_total_pages(data_pg, total_pages)
	elif typeof(data0) == TYPE_ARRAY:
		items = data0 as Array

	if items.is_empty():
		var items2: Variant = obj.get("items", obj.get("skills", obj.get("results", null)))
		if typeof(items2) == TYPE_ARRAY:
			items = items2 as Array

	var meta0: Variant = obj.get("meta", null)
	if typeof(meta0) == TYPE_DICTIONARY:
		var meta: Dictionary = meta0 as Dictionary
		page = _read_page(meta, page)
		limit = _read_limit(meta, limit)
		total = _read_total(meta, total)
		total_pages = _read_total_pages(meta, total_pages)

	var pg0: Variant = obj.get("pagination", null)
	if typeof(pg0) == TYPE_DICTIONARY:
		var pgd: Dictionary = pg0 as Dictionary
		page = _read_page(pgd, page)
		limit = _read_limit(pgd, limit)
		total = _read_total(pgd, total)
		total_pages = _read_total_pages(pgd, total_pages)

	return {
		"items": items,
		"pagination": {
			"page": maxi(1, page),
			"limit": limit,
			"total": total,
			"total_pages": total_pages,
		},
	}

func _read_page(d: Dictionary, fallback: int) -> int:
	return int(d.get("page", d.get("currentPage", d.get("current_page", fallback))))

func _read_limit(d: Dictionary, fallback: int) -> int:
	return int(d.get("limit", d.get("perPage", d.get("per_page", d.get("pageSize", d.get("page_size", fallback))))))

func _read_total(d: Dictionary, fallback: int) -> int:
	return int(d.get("total", fallback))

func _read_total_pages(d: Dictionary, fallback: int) -> int:
	return int(d.get(
		"totalPages",
		d.get(
			"total_pages",
			d.get(
				"pageCount",
				d.get(
					"pages",
					d.get("lastPage", d.get("last_page", fallback))
				)
			)
		)
	))
