extends RefCounted
class_name VrOfficesMediaConfig

static func from_environment() -> Dictionary:
	var base_url := OS.get_environment("OPENAGENTIC_MEDIA_BASE_URL").strip_edges()
	var bearer := OS.get_environment("OPENAGENTIC_MEDIA_BEARER_TOKEN").strip_edges()
	return {"base_url": base_url, "bearer_token": bearer}

static func is_configured(cfg: Dictionary) -> bool:
	return String(cfg.get("base_url", "")).strip_edges() != "" and String(cfg.get("bearer_token", "")).strip_edges() != ""

