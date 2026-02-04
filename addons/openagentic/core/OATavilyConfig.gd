extends RefCounted
class_name OATavilyConfig

static func from_environment() -> Dictionary:
	var base_url := OS.get_environment("TAVILY_BASE_URL").strip_edges()
	if base_url == "":
		base_url = "https://api.tavily.com"
	if base_url.ends_with("/"):
		base_url = base_url.rstrip("/")
	var api_key := OS.get_environment("TAVILY_API_KEY").strip_edges()
	return {"base_url": base_url, "api_key": api_key}

