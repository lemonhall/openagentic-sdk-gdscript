extends RefCounted
class_name OAWebTools

const _OATool := preload("res://addons/openagentic/core/OATool.gd")

static func tools() -> Array:
	var out: Array = []

	# NOTE: Web tools are async (coroutines). They must be executed via the tool runner, which will `await`.
	var webfetch_fn: Callable = Callable(OAWebTools, "_web_fetch")
	var webfetch_schema: Dictionary = {
		"type": "object",
		"properties": {
			"url": {"type": "string"},
			"headers": {"type": "object"},
			"max_redirects": {"type": "integer"},
			"max_bytes": {"type": "integer"},
			"allow_private_networks": {"type": "boolean"},
		},
		"required": ["url"],
	}
	out.append(_OATool.new("WebFetch", "Fetch a URL over HTTP(S). Blocks localhost/private networks by default.", webfetch_fn, webfetch_schema, true))

	var websearch_fn: Callable = Callable(OAWebTools, "_web_search")
	var websearch_schema: Dictionary = {
		"type": "object",
		"properties": {
			"query": {"type": "string"},
			"max_results": {"type": "integer"},
			"allowed_domains": {"type": "array", "items": {"type": "string"}},
			"blocked_domains": {"type": "array", "items": {"type": "string"}},
		},
		"required": ["query"],
	}
	out.append(_OATool.new("WebSearch", "Search the web (Tavily). Requires TAVILY_API_KEY (host-provided).", websearch_fn, websearch_schema, true))

	return out

static func _web_fetch(input: Dictionary, ctx: Dictionary) -> Variant:
	var url := String(input.get("url", "")).strip_edges()
	if url == "":
		return {"ok": false, "error": "InvalidInput", "message": "WebFetch: 'url' must be a non-empty string"}

	var max_redirects := int(input.get("max_redirects", 5))
	max_redirects = clampi(max_redirects, 0, 10)
	var max_bytes := int(input.get("max_bytes", 1024 * 1024))
	max_bytes = clampi(max_bytes, 1, 5 * 1024 * 1024)

	var allow_private := bool(input.get("allow_private_networks", false)) or bool(ctx.get("allow_private_networks", false))

	var headers_in: Variant = input.get("headers", {})
	var headers: Dictionary = headers_in if typeof(headers_in) == TYPE_DICTIONARY else {}

	# Allow tests to inject a deterministic transport.
	var transport0: Variant = ctx.get("web_fetch_transport", null)
	if typeof(transport0) == TYPE_CALLABLE and not (transport0 as Callable).is_null():
		return _web_fetch_with_transport(url, headers, max_redirects, max_bytes, allow_private, transport0 as Callable)

	return await _web_fetch_httpclient(url, headers, max_redirects, max_bytes, allow_private)

static func _web_fetch_with_transport(url: String, headers: Dictionary, max_redirects: int, max_bytes: int, allow_private: bool, transport: Callable) -> Dictionary:
	var chain: Array[String] = [url]
	var cur := url
	for _i in range(max_redirects + 1):
		var chk := _validate_url(cur, allow_private)
		if not bool(chk.get("ok", false)):
			return chk
		var res: Variant = transport.call(cur, headers)
		if typeof(res) != TYPE_DICTIONARY:
			return {"ok": false, "error": "TransportError"}
		var r: Dictionary = res as Dictionary
		var status := int(r.get("status", 0))
		var resp_headers: Dictionary = r.get("headers", {}) if typeof(r.get("headers", null)) == TYPE_DICTIONARY else {}
		var body: PackedByteArray = r.get("body", PackedByteArray())
		if body.size() > max_bytes:
			body = body.slice(0, max_bytes)
		if status in [301, 302, 303, 307, 308]:
			var loc := String(resp_headers.get("location", "")).strip_edges()
			if loc == "":
				return _web_fetch_result(url, cur, chain, status, resp_headers, body)
			cur = _join_url(cur, loc)
			chain.append(cur)
			continue
		return _web_fetch_result(url, cur, chain, status, resp_headers, body)
	return {"ok": false, "error": "TooManyRedirects"}

static func _web_fetch_httpclient(url: String, headers: Dictionary, max_redirects: int, max_bytes: int, allow_private: bool) -> Variant:
	var chain: Array[String] = [url]
	var cur := url
	for _i in range(max_redirects + 1):
		var chk := _validate_url(cur, allow_private)
		if not bool(chk.get("ok", false)):
			return chk
		var info := _parse_url(cur)
		if not bool(info.get("ok", false)):
			return info
		var scheme := String(info.scheme)
		var host := String(info.host)
		var port := int(info.port)
		var path := String(info.path)
		var tls := TLSOptions.client() if scheme == "https" else null

		var client := HTTPClient.new()
		var err := client.connect_to_host(host, port, tls)
		if err != OK:
			return {"ok": false, "error": "ConnectFailed"}
		while true:
			client.poll()
			var st := client.get_status()
			if st == HTTPClient.STATUS_CONNECTED:
				break
			if st == HTTPClient.STATUS_CANT_CONNECT or st == HTTPClient.STATUS_CONNECTION_ERROR:
				return {"ok": false, "error": "ConnectionError"}
			await (Engine.get_main_loop() as SceneTree).process_frame

		var hdrs := PackedStringArray()
		for k in headers.keys():
			hdrs.append("%s: %s" % [String(k).to_lower(), String(headers[k])])
		hdrs.append("accept: */*")

		var req_err := client.request(HTTPClient.METHOD_GET, path, hdrs)
		if req_err != OK:
			return {"ok": false, "error": "RequestFailed"}

		while client.get_status() == HTTPClient.STATUS_REQUESTING:
			client.poll()
			await (Engine.get_main_loop() as SceneTree).process_frame

		if not client.has_response():
			return {"ok": false, "error": "NoResponse"}
		var status := client.get_response_code()
		var resp_headers := client.get_response_headers_as_dictionary()

		var body := PackedByteArray()
		while client.get_status() == HTTPClient.STATUS_BODY:
			client.poll()
			var chunk := client.read_response_body_chunk()
			if chunk.size() == 0:
				await (Engine.get_main_loop() as SceneTree).process_frame
				continue
			body.append_array(chunk)
			if body.size() >= max_bytes:
				body = body.slice(0, max_bytes)
				break

		if status in [301, 302, 303, 307, 308]:
			var loc := String(resp_headers.get("location", "")).strip_edges()
			if loc == "":
				return _web_fetch_result(url, cur, chain, status, resp_headers, body)
			cur = _join_url(cur, loc)
			chain.append(cur)
			continue

		return _web_fetch_result(url, cur, chain, status, resp_headers, body)
	return {"ok": false, "error": "TooManyRedirects"}

static func _web_fetch_result(requested_url: String, final_url: String, chain: Array[String], status: int, headers: Dictionary, body: PackedByteArray) -> Dictionary:
	var ct := ""
	if headers.has("content-type"):
		ct = String(headers["content-type"])
	var text := body.get_string_from_utf8()
	return {
		"requested_url": requested_url,
		"url": final_url,
		"final_url": final_url,
		"redirect_chain": chain,
		"status": status,
		"content_type": ct,
		"text": text,
	}

static func _web_search(input: Dictionary, ctx: Dictionary) -> Variant:
	var query := String(input.get("query", "")).strip_edges()
	if query == "":
		return {"ok": false, "error": "InvalidInput", "message": "WebSearch: 'query' must be a non-empty string"}
	var max_results := int(input.get("max_results", 5))
	max_results = clampi(max_results, 1, 20)
	var allowed0: Variant = input.get("allowed_domains", null)
	var blocked0: Variant = input.get("blocked_domains", null)
	var allowed: Array[String] = []
	var blocked: Array[String] = []
	if typeof(allowed0) == TYPE_ARRAY:
		for d0 in allowed0 as Array:
			allowed.append(String(d0).to_lower())
	if typeof(blocked0) == TYPE_ARRAY:
		for d1 in blocked0 as Array:
			blocked.append(String(d1).to_lower())

	var api_key := String(ctx.get("tavily_api_key", "")).strip_edges()
	if api_key == "":
		return {"ok": false, "error": "MissingApiKey", "message": "WebSearch: missing TAVILY_API_KEY"}
	var base_url := String(ctx.get("tavily_base_url", "")).strip_edges()
	if base_url == "":
		base_url = OS.get_environment("TAVILY_BASE_URL").strip_edges()
	if base_url == "":
		base_url = "https://api.tavily.com"
	if base_url.ends_with("/"):
		base_url = base_url.rstrip("/")

	# Allow tests to inject transport.
	var transport0: Variant = ctx.get("web_search_transport", null)
	if typeof(transport0) == TYPE_CALLABLE and not (transport0 as Callable).is_null():
		return _web_search_with_transport(query, max_results, allowed, blocked, api_key, transport0 as Callable)

	return await _web_search_httpclient(query, max_results, allowed, blocked, api_key, base_url)

static func _web_search_with_transport(query: String, max_results: int, allowed: Array[String], blocked: Array[String], api_key: String, transport: Callable) -> Dictionary:
	var payload := {"api_key": api_key, "query": query, "max_results": max_results}
	var res0: Variant = transport.call(payload)
	if typeof(res0) != TYPE_DICTIONARY:
		return {"ok": false, "error": "TransportError"}
	return _filter_search_results(query, res0 as Dictionary, allowed, blocked)

static func _web_search_httpclient(query: String, max_results: int, allowed: Array[String], blocked: Array[String], api_key: String, base_url: String) -> Variant:
	var base := base_url.strip_edges()
	if base == "":
		base = "https://api.tavily.com"
	if base.ends_with("/"):
		base = base.rstrip("/")
	var url := base + "/search"
	var payload := {"api_key": api_key, "query": query, "max_results": max_results}
	var body := JSON.stringify(payload)

	var info := _parse_url(url)
	if not bool(info.get("ok", false)):
		return info
	var scheme := String(info.scheme)
	var host := String(info.host)
	var port := int(info.port)
	var path := String(info.path)
	var tls := TLSOptions.client() if scheme == "https" else null

	var client := HTTPClient.new()
	var err := client.connect_to_host(host, port, tls)
	if err != OK:
		return {"ok": false, "error": "ConnectFailed"}
	while true:
		client.poll()
		var st := client.get_status()
		if st == HTTPClient.STATUS_CONNECTED:
			break
		if st == HTTPClient.STATUS_CANT_CONNECT or st == HTTPClient.STATUS_CONNECTION_ERROR:
			return {"ok": false, "error": "ConnectionError"}
		await (Engine.get_main_loop() as SceneTree).process_frame

	var hdrs := PackedStringArray()
	hdrs.append("content-type: application/json")
	hdrs.append("accept: application/json")
	var req_err := client.request(HTTPClient.METHOD_POST, path, hdrs, body)
	if req_err != OK:
		return {"ok": false, "error": "RequestFailed"}
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		await (Engine.get_main_loop() as SceneTree).process_frame

	if not client.has_response():
		return {"ok": false, "error": "NoResponse"}
	var status := client.get_response_code()
	if status >= 400:
		return {"ok": false, "error": "HttpError", "status": status}
	var raw := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.size() == 0:
			await (Engine.get_main_loop() as SceneTree).process_frame
			continue
		raw.append_array(chunk)
		if raw.size() > 1024 * 1024:
			break
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "ParseError"}
	return _filter_search_results(query, parsed as Dictionary, allowed, blocked)

static func _filter_search_results(query: String, obj: Dictionary, allowed: Array[String], blocked: Array[String]) -> Dictionary:
	var results0: Variant = obj.get("results", [])
	var results_out: Array = []
	if typeof(results0) == TYPE_ARRAY:
		for r0 in results0 as Array:
			if typeof(r0) != TYPE_DICTIONARY:
				continue
			var r: Dictionary = r0 as Dictionary
			var url := String(r.get("url", "")).strip_edges()
			if url == "":
				continue
			if not _domain_allowed(url, allowed, blocked):
				continue
			results_out.append({
				"title": r.get("title", null),
				"url": url,
				"content": r.get("content", r.get("snippet", null)),
				"source": "tavily",
			})
	return {"query": query, "results": results_out, "total_results": results_out.size()}

static func _domain_allowed(url: String, allowed: Array[String], blocked: Array[String]) -> bool:
	var host := String(_parse_url(url).get("host", "")).to_lower()
	if host == "":
		return allowed.is_empty()
	for b in blocked:
		if host == b or host.ends_with("." + b):
			return false
	if allowed.is_empty():
		return true
	for a in allowed:
		if host == a or host.ends_with("." + a):
			return true
	return false

static func _join_url(current_url: String, location: String) -> String:
	# Minimal join: if location is absolute, use it; else reuse scheme+host(+port) and replace path.
	var loc := String(location).strip_edges()
	if loc.begins_with("http://") or loc.begins_with("https://"):
		return loc
	var cur := _parse_url(current_url)
	if not bool(cur.get("ok", false)):
		return loc
	var base := "%s://%s" % [String(cur.scheme), String(cur.host)]
	var port := int(cur.port)
	if (String(cur.scheme) == "http" and port != 80) or (String(cur.scheme) == "https" and port != 443):
		base += ":%d" % port
	if not loc.begins_with("/"):
		loc = "/" + loc
	return base + loc

static func _validate_url(url: String, allow_private: bool) -> Dictionary:
	var info := _parse_url(url)
	if not bool(info.get("ok", false)):
		return info
	var scheme := String(info.scheme)
	if scheme != "http" and scheme != "https":
		return {"ok": false, "error": "InvalidUrl"}
	var host := String(info.host).to_lower()
	if host == "" or host == "localhost" or host.ends_with(".localhost"):
		return {"ok": false, "error": "BlockedHost"}
	if allow_private:
		return {"ok": true}
	# Block private/loopback/link-local for obvious IP literals.
	if _is_private_ip_literal(host):
		return {"ok": false, "error": "BlockedHost"}
	# Try resolve host and block if any resolved IP is private.
	var ips0: Variant = IP.resolve_hostname(host, IP.TYPE_IPV4)
	var ips: Array[String] = []
	if typeof(ips0) == TYPE_PACKED_STRING_ARRAY:
		for s in ips0 as PackedStringArray:
			ips.append(String(s))
	elif typeof(ips0) == TYPE_ARRAY:
		for s2 in ips0 as Array:
			ips.append(String(s2))
	for ip in ips:
		if _is_private_ip_literal(ip):
			return {"ok": false, "error": "BlockedHost"}
	return {"ok": true}

static func _is_private_ip_literal(host: String) -> bool:
	var h := host.strip_edges()
	# IPv4
	var parts := h.split(".", false)
	if parts.size() == 4:
		var a := int(parts[0])
		var b := int(parts[1])
		if a == 127:
			return true
		if a == 10:
			return true
		if a == 192 and b == 168:
			return true
		if a == 172 and b >= 16 and b <= 31:
			return true
		if a == 169 and b == 254:
			return true
	# IPv6 basics
	if h == "::1":
		return true
	if h.begins_with("fe80:") or h.begins_with("fc") or h.begins_with("fd"):
		return true
	return false

static func _parse_url(url: String) -> Dictionary:
	# Very small URL parser (http/https only). Returns {ok, scheme, host, port, path}
	var u := url.strip_edges()
	var scheme := "https"
	if u.begins_with("http://"):
		scheme = "http"
		u = u.substr(7)
	elif u.begins_with("https://"):
		scheme = "https"
		u = u.substr(8)

	var slash := u.find("/")
	var hostport := u if slash < 0 else u.substr(0, slash)
	var path := "/" if slash < 0 else u.substr(slash)
	if path == "":
		path = "/"

	var host := hostport
	var port := 443 if scheme == "https" else 80
	var colon := hostport.rfind(":")
	if colon >= 0 and colon < hostport.length() - 1:
		var maybe := hostport.substr(colon + 1)
		var parsed := int(maybe)
		if parsed > 0:
			host = hostport.substr(0, colon)
			port = parsed

	if host.strip_edges() == "":
		return {"ok": false, "error": "InvalidUrl"}
	return {"ok": true, "scheme": scheme, "host": host, "port": port, "path": path}
