extends RefCounted
class_name OAMediaHttp

static func request(method: int, url: String, headers: Dictionary, body: PackedByteArray, timeout_sec: float, transport: Callable = Callable()) -> Dictionary:
	if transport != null and not transport.is_null():
		var req := {"method": _method_name(method), "url": url, "headers": headers, "body": body}
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
