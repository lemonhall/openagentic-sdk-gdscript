extends RefCounted
class_name OAMediaHttp

static func request(method: int, url: String, headers: Dictionary, body: PackedByteArray, timeout_sec: float, transport: Callable = Callable(), options: Dictionary = {}) -> Dictionary:
	if transport != null and not transport.is_null():
		var req := {"method": _method_name(method), "url": url, "headers": headers, "body": body, "options": options}
		var out0: Variant = transport.call(req)
		if typeof(out0) != TYPE_DICTIONARY:
			return {"ok": false, "error": "TransportError"}
		var out: Dictionary = out0 as Dictionary
		if not bool(out.get("ok", true)):
			return {"ok": false, "error": String(out.get("error", "TransportError")), "status": int(out.get("status", 0))}
		return {
			"ok": true,
			"status": int(out.get("status", 0)),
			"headers": out.get("headers", {}),
			"body": out.get("body", PackedByteArray()),
		}

	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return {"ok": false, "error": "NoSceneTree"}

	var req_node := HTTPRequest.new()
	req_node.timeout = timeout_sec
	tree.root.add_child(req_node)

	var proxy_http := str(options.get("proxy_http", "")).strip_edges()
	if proxy_http != "":
		var pr: Dictionary = _parse_proxy_host_port(proxy_http)
		if not bool(pr.get("ok", false)):
			req_node.queue_free()
			return {"ok": false, "error": "BadProxy", "kind": "http", "message": str(pr.get("error", "InvalidProxy")).strip_edges()}
		req_node.set_http_proxy(str(pr.get("host", "")), int(pr.get("port", -1)))

	var proxy_https := str(options.get("proxy_https", "")).strip_edges()
	if proxy_https != "":
		var pr2: Dictionary = _parse_proxy_host_port(proxy_https)
		if not bool(pr2.get("ok", false)):
			req_node.queue_free()
			return {"ok": false, "error": "BadProxy", "kind": "https", "message": str(pr2.get("error", "InvalidProxy")).strip_edges()}
		req_node.set_https_proxy(str(pr2.get("host", "")), int(pr2.get("port", -1)))

	var header_lines := PackedStringArray()
	for k0 in headers.keys():
		var k := String(k0).strip_edges()
		if k == "":
			continue
		header_lines.append("%s: %s" % [k, String(headers.get(k0, ""))])

	var err := req_node.request_raw(url, header_lines, method, body)
	if err != OK:
		req_node.queue_free()
		return {"ok": false, "error": "RequestError", "code": err}

	var result0: Array = await req_node.request_completed
	req_node.queue_free()
	if result0.size() < 4:
		return {"ok": false, "error": "RequestError"}

	var response_code := int(result0[1])
	var resp_headers := result0[2] as PackedStringArray
	var resp_body := result0[3] as PackedByteArray
	var hdrs: Dictionary = {}
	for line in resp_headers:
		var s := String(line)
		var idx := s.find(":")
		if idx <= 0:
			continue
		var hk := s.substr(0, idx).strip_edges().to_lower()
		var hv := s.substr(idx + 1).strip_edges()
		hdrs[hk] = hv

	return {"ok": true, "status": response_code, "headers": hdrs, "body": resp_body}

static func _parse_proxy_host_port(proxy_url: String) -> Dictionary:
	var s := proxy_url.strip_edges()
	if s == "":
		return {"ok": false, "error": "EmptyProxy"}
	var scheme_idx := s.find("://")
	if scheme_idx != -1:
		s = s.substr(scheme_idx + 3)
	var slash_idx := s.find("/")
	if slash_idx != -1:
		s = s.substr(0, slash_idx)
	var at_idx := s.rfind("@")
	if at_idx != -1:
		s = s.substr(at_idx + 1)
	s = s.strip_edges().rstrip("/")
	if s == "":
		return {"ok": false, "error": "BadProxy"}

	var host := ""
	var port_str := ""
	if s.begins_with("["):
		var end := s.find("]")
		if end == -1:
			return {"ok": false, "error": "BadProxy"}
		host = s.substr(1, end - 1)
		var rest := s.substr(end + 1)
		if not rest.begins_with(":"):
			return {"ok": false, "error": "MissingPort"}
		port_str = rest.substr(1)
	else:
		var colon := s.rfind(":")
		if colon == -1:
			return {"ok": false, "error": "MissingPort"}
		host = s.substr(0, colon)
		port_str = s.substr(colon + 1)

	host = host.strip_edges()
	port_str = port_str.strip_edges()
	if host == "" or port_str == "":
		return {"ok": false, "error": "BadProxy"}
	if not port_str.is_valid_int():
		return {"ok": false, "error": "BadPort"}
	var port := int(port_str)
	if port <= 0 or port > 65535:
		return {"ok": false, "error": "BadPort"}
	return {"ok": true, "host": host, "port": port}

static func _method_name(method: int) -> String:
	if method == HTTPClient.METHOD_GET:
		return "GET"
	if method == HTTPClient.METHOD_POST:
		return "POST"
	if method == HTTPClient.METHOD_PUT:
		return "PUT"
	if method == HTTPClient.METHOD_DELETE:
		return "DELETE"
	return "METHOD_%d" % method
