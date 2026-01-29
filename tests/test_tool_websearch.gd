extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var tools: Array = OAStandardTools.tools()
	var websearch = _find_tool(tools, "WebSearch")
	if not T.require_true(self, websearch != null, "Missing WebSearch tool"):
		return

	var transport := func(payload: Dictionary) -> Dictionary:
		# Mimic Tavily response shape.
		return {"results": [
			{"title": "A", "url": "https://a.com/x", "content": "ax"},
			{"title": "B", "url": "https://b.com/y", "content": "by"},
		]}

	var ctx := {"tavily_api_key": "k", "web_search_transport": transport}
	var out = await websearch.run_async({"query": "q", "max_results": 5, "allowed_domains": ["a.com"]}, ctx)
	if not T.require_true(self, typeof(out) == TYPE_DICTIONARY, "WebSearch output must be dict"):
		return
	var results: Array = (out as Dictionary).get("results", [])
	if not T.require_eq(self, results.size(), 1, "Expected 1 filtered result"):
		return
	if not T.require_eq(self, String((results[0] as Dictionary).get("url", "")), "https://a.com/x", "Expected a.com result"):
		return

	# Missing API key should error.
	var out2 = await websearch.run_async({"query": "q"}, {"web_search_transport": transport})
	if not T.require_true(self, typeof(out2) == TYPE_DICTIONARY and String((out2 as Dictionary).get("error", "")) == "MissingApiKey", "Expected MissingApiKey"):
		return

	T.pass_and_quit(self)

func _find_tool(tools: Array, name: String):
	for t in tools:
		if t != null and typeof(t) == TYPE_OBJECT and String(t.name) == name:
			return t
	return null
