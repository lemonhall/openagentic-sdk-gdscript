extends RefCounted
class_name OAOpenAIResponsesProvider

const DEFAULT_PORT_HTTP := 80
const DEFAULT_PORT_HTTPS := 443

var name: String = "openai-responses"

var _base_url: String
var _auth_header: String
var _auth_token: String
var _auth_is_bearer: bool

const _OASseParserScript := preload("res://addons/openagentic/providers/OASseParser.gd")
var _parser = _OASseParserScript.new()

func _init(base_url: String, auth_header: String = "", auth_token: String = "", auth_is_bearer: bool = true) -> void:
	_base_url = String(base_url).rstrip("/")
	_auth_header = String(auth_header).strip_edges()
	_auth_token = String(auth_token)
	_auth_is_bearer = auth_is_bearer

func _parse_base_url(url: String) -> Dictionary:
	# Very small URL parser (http/https only).
	# Returns: {scheme, host, port, path_prefix}
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
	var path_prefix := "" if slash < 0 else u.substr(slash)
	path_prefix = path_prefix.rstrip("/")

	var host := hostport
	var port := DEFAULT_PORT_HTTPS if scheme == "https" else DEFAULT_PORT_HTTP
	var colon := hostport.rfind(":")
	if colon >= 0 and colon < hostport.length() - 1:
		var maybe_port := hostport.substr(colon + 1)
		var parsed_port := int(maybe_port)
		if parsed_port > 0:
			host = hostport.substr(0, colon)
			port = parsed_port

	return {"scheme": scheme, "host": host, "port": port, "path_prefix": path_prefix}

func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

func _headers() -> PackedStringArray:
	var out := PackedStringArray()
	out.append("content-type: application/json")
	out.append("accept: text/event-stream")

	var h := _auth_header if _auth_header != "" else ""
	if _auth_token != "":
		if h == "":
			h = "authorization"
		if h.to_lower() == "authorization" and _auth_is_bearer:
			out.append("%s: Bearer %s" % [h, _auth_token])
		else:
			out.append("%s: %s" % [h, _auth_token])

	return out

func stream(req: Dictionary, on_event: Callable) -> void:
	var info := _parse_base_url(_base_url)
	var scheme := String(info.scheme)
	var host := String(info.host)
	var port := int(info.port)
	var prefix := String(info.path_prefix)
	var path := "%s/responses" % prefix
	if not path.begins_with("/"):
		path = "/" + path

	var payload: Dictionary = {
		"model": req.get("model", ""),
		"input": req.get("input", []),
		"store": req.get("store", true),
		"stream": true,
	}
	if req.has("tools") and typeof(req.tools) == TYPE_ARRAY and (req.tools as Array).size() > 0:
		payload["tools"] = req.tools
	if req.has("instructions") and typeof(req.instructions) == TYPE_STRING and String(req.instructions).strip_edges() != "":
		payload["instructions"] = req.instructions
	if req.has("previous_response_id") and typeof(req.previous_response_id) == TYPE_STRING and String(req.previous_response_id) != "":
		payload["previous_response_id"] = req.previous_response_id

	var body := JSON.stringify(payload)
	var client := HTTPClient.new()
	var tls := TLSOptions.client() if scheme == "https" else null
	var err := client.connect_to_host(host, port, tls)
	if err != OK:
		push_error("OAOpenAIResponsesProvider: connect failed: %s" % err)
		on_event.call({"type": "done", "error": "connect_failed"})
		return

	while true:
		client.poll()
		var st := client.get_status()
		if st == HTTPClient.STATUS_CONNECTED:
			break
		if st == HTTPClient.STATUS_CANT_CONNECT or st == HTTPClient.STATUS_CONNECTION_ERROR:
			push_error("OAOpenAIResponsesProvider: connection error")
			on_event.call({"type": "done", "error": "connection_error"})
			return
		await _tree().process_frame

	var req_err := client.request(HTTPClient.METHOD_POST, path, _headers(), body)
	if req_err != OK:
		push_error("OAOpenAIResponsesProvider: request failed: %s" % req_err)
		on_event.call({"type": "done", "error": "request_failed"})
		return

	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		await _tree().process_frame

	if not client.has_response():
		push_error("OAOpenAIResponsesProvider: no response")
		on_event.call({"type": "done", "error": "no_response"})
		return

	var code := client.get_response_code()
	if code >= 400:
		push_error("OAOpenAIResponsesProvider: HTTP %s" % code)
		on_event.call({"type": "done", "error": "http_%s" % code})
		return

	_parser.reset()
	var buf := ""
	var done := false

	while client.get_status() == HTTPClient.STATUS_BODY and not done:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.size() == 0:
			await _tree().process_frame
			continue
		buf += chunk.get_string_from_utf8()
		while true:
			var idx := buf.find("\n")
			if idx < 0:
				break
			var line := buf.substr(0, idx + 1)
			buf = buf.substr(idx + 1)
			done = _parser.feed_line(line, on_event)
			if done:
				break

	# Flush any tail.
	if not done and buf.strip_edges() != "":
		_parser.feed_line(buf, on_event)
	_parser.feed_line("", on_event)
