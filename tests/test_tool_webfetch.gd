extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var tools: Array = OAStandardTools.tools()
	var webfetch = _find_tool(tools, "WebFetch")
	if not T.require_true(self, webfetch != null, "Missing WebFetch tool"):
		return

	# Deterministic transport with a redirect hop.
	var transport := func(u: String, _headers: Dictionary) -> Dictionary:
		if u.ends_with("/a"):
			return {"status": 302, "headers": {"location": "https://example.com/b"}, "body": PackedByteArray()}
		return {"status": 200, "headers": {"content-type": "text/plain"}, "body": "ok".to_utf8_buffer()}

	var ctx := {"web_fetch_transport": transport, "allow_private_networks": true}
	var out = webfetch.run({"url": "https://example.com/a", "max_redirects": 5}, ctx)
	if T.is_function_state(out):
		out = await out
	if not T.require_true(self, typeof(out) == TYPE_DICTIONARY, "WebFetch output must be dict"):
		return
	if not T.require_eq(self, int((out as Dictionary).get("status", 0)), 200, "Expected status=200"):
		return
	var chain: Array = (out as Dictionary).get("redirect_chain", [])
	if not T.require_true(self, chain.size() == 2, "Expected redirect chain of length 2"):
		return
	if not T.require_eq(self, String((out as Dictionary).get("text", "")), "ok", "Expected body text"):
		return

	# SSRF block: loopback should be rejected before transport.
	var ctx2 := {"web_fetch_transport": transport, "allow_private_networks": false}
	var out2 = webfetch.run({"url": "http://127.0.0.1/"}, ctx2)
	if T.is_function_state(out2):
		out2 = await out2
	if not T.require_true(self, typeof(out2) == TYPE_DICTIONARY and String((out2 as Dictionary).get("error", "")) == "BlockedHost", "Expected BlockedHost"):
		return

	T.pass_and_quit(self)

func _find_tool(tools: Array, name: String):
	for t in tools:
		if t != null and typeof(t) == TYPE_OBJECT and String(t.name) == name:
			return t
	return null
