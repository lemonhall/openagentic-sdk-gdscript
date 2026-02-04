extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var StoreScript := load("res://vr_offices/core/media/VrOfficesMediaConfigStore.gd")
	if StoreScript == null:
		T.fail_and_quit(self, "Missing VrOfficesMediaConfigStore.gd")
		return

	var save_id := "slot_test_media_cfg_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	var cfg := {"base_url": "http://127.0.0.1:8788", "bearer_token": "tok"}

	var wr: Dictionary = (StoreScript as Script).call("save_config", save_id, cfg)
	if not T.require_true(self, bool(wr.get("ok", false)), "save_config should succeed"):
		return

	var rd: Dictionary = (StoreScript as Script).call("load_config", save_id)
	if not T.require_true(self, bool(rd.get("ok", false)), "load_config should succeed"):
		return
	var got: Dictionary = rd.get("config", {})
	if not T.require_eq(self, String(got.get("base_url", "")), "http://127.0.0.1:8788", "base_url"):
		return
	if not T.require_eq(self, String(got.get("bearer_token", "")), "tok", "bearer_token"):
		return

	T.pass_and_quit(self)

