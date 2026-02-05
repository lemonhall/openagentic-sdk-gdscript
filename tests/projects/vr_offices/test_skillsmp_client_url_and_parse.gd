extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _transport_ok(req: Dictionary) -> Dictionary:
	if not String(req.get("method", "")).begins_with("GET"):
		return {"ok": false, "error": "ExpectedGET"}
	var hdrs: Dictionary = req.get("headers", {})
	var auth := String(hdrs.get("Authorization", ""))
	if auth != "Bearer k_test":
		return {"ok": false, "error": "BadAuth"}
	var body := JSON.stringify({
		"success": true,
		"data": {
			"items": [
				{
					"id": "s1",
					"name": "SEO Basics",
					"description": "Learn the fundamentals of SEO.",
					"stars": 12,
					"url": "https://skillsmp.com/skills/s1"
				}
			],
			"page": 2,
			"limit": 20,
			"total": 21,
			"totalPages": 2
		}
	})
	return {"ok": true, "status": 200, "headers": {"content-type": "application/json"}, "body": body.to_utf8_buffer()}

func _init() -> void:
	var ClientScript := load("res://vr_offices/core/skillsmp/VrOfficesSkillsMpClient.gd")
	if ClientScript == null:
		T.fail_and_quit(self, "Missing VrOfficesSkillsMpClient.gd")
		return
	var client0: Variant = (ClientScript as Script).new()
	if not (client0 is RefCounted):
		T.fail_and_quit(self, "Expected RefCounted client")
		return
	var client := client0 as RefCounted

	var url := String(client.call("build_search_url", "https://skillsmp.com", "SEO & stuff", 2, 50, "stars"))
	if not T.require_true(self, url.find("q=SEO%20%26%20stuff") != -1, "Expected URI-encoded q param"):
		return
	if not T.require_true(self, url.find("page=2") != -1, "Expected page=2 param"):
		return
	if not T.require_true(self, url.find("limit=50") != -1, "Expected limit=50 param"):
		return
	if not T.require_true(self, url.find("sortBy=stars") != -1, "Expected sortBy=stars param"):
		return

	var rr0: Variant = client.call("search", "https://skillsmp.com", "k_test", "SEO", 2, 20, "stars", Callable(self, "_transport_ok"))
	var rr: Dictionary = await rr0
	if not T.require_true(self, bool(rr.get("ok", false)), "Expected search ok"):
		return
	var items: Array = rr.get("items", [])
	if not T.require_eq(self, int(items.size()), 1, "Expected 1 item"):
		return
	var pg: Dictionary = rr.get("pagination", {})
	if not T.require_eq(self, int(pg.get("page", 0)), 2, "Expected page=2"):
		return
	if not T.require_eq(self, int(pg.get("total_pages", 0)), 2, "Expected total_pages=2"):
		return

	T.pass_and_quit(self)

