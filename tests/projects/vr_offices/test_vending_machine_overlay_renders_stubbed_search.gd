extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _transport_ok(_req: Dictionary) -> Dictionary:
	var body := JSON.stringify({
		"success": true,
		"data": {
			"items": [
				{"id": "s1", "name": "Skill A", "description": "Desc A", "stars": 1, "url": "https://skillsmp.com/skills/s1"},
				{"id": "s2", "name": "Skill B", "description": "Desc B", "stars": 2, "url": "https://skillsmp.com/skills/s2"},
				{"id": "s3", "name": "Skill C", "description": "Desc C", "stars": 3, "url": "https://skillsmp.com/skills/s3"}
			],
			"page": 1,
			"limit": 20,
			"total": 60,
			"totalPages": 3
		}
	})
	return {"ok": true, "status": 200, "headers": {"content-type": "application/json"}, "body": body.to_utf8_buffer()}

func _init() -> void:
	# Isolated save slot so existing state doesn't affect the test.
	var save_id: String = "slot_test_vend_skillsmp_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	var oa := get_root().get_node_or_null("OpenAgentic") as Node
	if oa == null:
		var OAScript := load("res://addons/openagentic/OpenAgentic.gd")
		if OAScript == null:
			T.fail_and_quit(self, "Missing res://addons/openagentic/OpenAgentic.gd")
			return
		oa = (OAScript as Script).new() as Node
		if oa == null:
			T.fail_and_quit(self, "Failed to instantiate OpenAgentic.gd")
			return
		oa.name = "OpenAgentic"
		get_root().add_child(oa)
		await process_frame
	oa.call("set_save_id", save_id)

	var StoreScript := load("res://addons/openagentic/core/OASkillsMpConfigStore.gd")
	if StoreScript == null:
		T.fail_and_quit(self, "Missing OASkillsMpConfigStore.gd")
		return
	var wr: Dictionary = (StoreScript as Script).call("save_config", save_id, {"base_url": "https://skillsmp.com", "api_key": "k_test"})
	if not T.require_true(self, bool(wr.get("ok", false)), "Expected store save ok"):
		return

	var OverlayScene := load("res://vr_offices/ui/VendingMachineOverlay.tscn")
	if OverlayScene == null or not (OverlayScene is PackedScene):
		T.fail_and_quit(self, "Missing VendingMachineOverlay.tscn")
		return
	var overlay0 := (OverlayScene as PackedScene).instantiate()
	if overlay0 == null or not (overlay0 is Control):
		T.fail_and_quit(self, "Expected overlay Control")
		return
	var overlay := overlay0 as Control
	root.add_child(overlay)
	await process_frame

	if overlay.has_method("set_skillsmp_transport_override"):
		overlay.call("set_skillsmp_transport_override", Callable(self, "_transport_ok"))

	if overlay.has_method("open"):
		overlay.call("open")
	await process_frame

	if not overlay.has_method("search_skills"):
		T.fail_and_quit(self, "Missing overlay.search_skills()")
		return
	var rr0: Variant = overlay.call("search_skills", "test")
	var rr: Dictionary = await rr0
	if not T.require_true(self, bool(rr.get("ok", false)), "Expected overlay search ok"):
		return

	var list := overlay.get_node_or_null("%ResultsList") as ItemList
	if list == null:
		T.fail_and_quit(self, "Missing %ResultsList")
		return
	if not T.require_eq(self, int(list.item_count), 3, "Expected 3 rendered results"):
		return

	var page_label := overlay.get_node_or_null("%PageLabel") as Label
	if page_label == null:
		T.fail_and_quit(self, "Missing %PageLabel")
		return
	if not T.require_true(self, page_label.text.find("1") != -1 and page_label.text.find("3") != -1, "Expected page label to mention 1 and 3"):
		return

	T.pass_and_quit(self)

