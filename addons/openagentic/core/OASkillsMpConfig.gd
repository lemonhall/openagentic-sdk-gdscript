extends RefCounted
class_name OASkillsMpConfig

static func from_environment() -> Dictionary:
	var base_url := OS.get_environment("SKILLSMP_BASE_URL").strip_edges()
	if base_url == "":
		base_url = "https://skillsmp.com"
	if base_url.ends_with("/"):
		base_url = base_url.rstrip("/")
	var api_key := OS.get_environment("SKILLSMP_API_KEY").strip_edges()
	return {"base_url": base_url, "api_key": api_key}

