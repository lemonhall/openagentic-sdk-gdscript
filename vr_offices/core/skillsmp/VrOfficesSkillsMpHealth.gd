extends RefCounted
class_name VrOfficesSkillsMpHealth

const _Client := preload("res://vr_offices/core/skillsmp/VrOfficesSkillsMpClient.gd")

static func check_health(base_url: String, api_key: String, transport: Callable = Callable()) -> Dictionary:
	var client := _Client.new()
	var rr: Dictionary = await client.search(base_url, api_key, "health check", 1, 1, "", transport)
	if bool(rr.get("ok", false)):
		return {"ok": true}
	return {"ok": false, "error": String(rr.get("error", "Error")), "status": int(rr.get("status", 0)), "error_code": String(rr.get("error_code", "")), "message": String(rr.get("message", ""))}

