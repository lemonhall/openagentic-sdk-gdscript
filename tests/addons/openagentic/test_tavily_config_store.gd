extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var StoreScript := load("res://addons/openagentic/core/OATavilyConfigStore.gd")
	if StoreScript == null:
		T.fail_and_quit(self, "Missing OATavilyConfigStore.gd")
		return

	var save_id: String = "slot_test_tavily_store_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	var p := String((StoreScript as Script).call("config_path", save_id))
	if not T.require_true(self, p.find("/shared/tavily_config.json") != -1, "Expected shared/tavily_config.json path"):
		return

	var cfg := {"base_url": "https://api.tavily.com", "api_key": "k_test"}
	var wr: Dictionary = (StoreScript as Script).call("save_config", save_id, cfg)
	if not T.require_true(self, bool(wr.get("ok", false)), "Expected save ok"):
		return

	var rd: Dictionary = (StoreScript as Script).call("load_config", save_id)
	if not T.require_true(self, bool(rd.get("ok", false)), "Expected load ok"):
		return
	var got: Dictionary = rd.get("config", {})
	if not T.require_eq(self, String(got.get("base_url", "")), "https://api.tavily.com", "base_url mismatch"):
		return
	if not T.require_eq(self, String(got.get("api_key", "")), "k_test", "api_key mismatch"):
		return

	# Cleanup best-effort.
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

	T.pass_and_quit(self)

