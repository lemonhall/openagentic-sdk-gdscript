extends RefCounted
class_name OASkillsMpConfigStore

const _OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")

static func config_path(save_id: String) -> String:
	var sid := save_id.strip_edges()
	if sid == "":
		return ""
	return "%s/shared/skillsmp_config.json" % _OAPaths.save_root(sid)

static func load_config(save_id: String) -> Dictionary:
	var p := config_path(save_id)
	if p == "":
		return {"ok": false, "error": "MissingSaveId"}
	if not FileAccess.file_exists(p):
		return {"ok": true, "config": {}}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {"ok": false, "error": "ReadFailed"}
	var txt := f.get_as_text()
	f.close()
	var obj0: Variant = JSON.parse_string(txt)
	if typeof(obj0) != TYPE_DICTIONARY:
		return {"ok": false, "error": "BadJson"}
	var obj: Dictionary = obj0 as Dictionary
	var base_url := String(obj.get("base_url", obj.get("baseUrl", ""))).strip_edges()
	var api_key := String(obj.get("api_key", obj.get("apiKey", ""))).strip_edges()
	if base_url.ends_with("/"):
		base_url = base_url.rstrip("/")
	return {"ok": true, "config": {"base_url": base_url, "api_key": api_key}}

static func save_config(save_id: String, config: Dictionary) -> Dictionary:
	var p := config_path(save_id)
	if p == "":
		return {"ok": false, "error": "MissingSaveId"}
	var base_url := String(config.get("base_url", config.get("baseUrl", ""))).strip_edges()
	var api_key := String(config.get("api_key", config.get("apiKey", ""))).strip_edges()
	if base_url.ends_with("/"):
		base_url = base_url.rstrip("/")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(p.get_base_dir()))
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": "WriteFailed"}
	f.store_string(JSON.stringify({"base_url": base_url, "api_key": api_key}, "  ") + "\n")
	f.close()
	return {"ok": true, "path": p}

