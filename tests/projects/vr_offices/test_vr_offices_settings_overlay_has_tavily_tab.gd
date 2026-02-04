extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var OverlayScene := load("res://vr_offices/ui/SettingsOverlay.tscn")
	if OverlayScene == null:
		T.fail_and_quit(self, "Missing SettingsOverlay.tscn")
		return
	var ov: Control = (OverlayScene as PackedScene).instantiate()
	get_root().add_child(ov)
	await process_frame

	var tabs := ov.get_node_or_null("Panel/VBox/Tabs") as TabContainer
	if not T.require_true(self, tabs != null, "Missing Tabs"):
		return

	var tavily_tab: Control = null
	for i in range(tabs.get_child_count()):
		var c := tabs.get_child(i) as Control
		if c != null and c.name == "Tavily":
			tavily_tab = c
			break
	if not T.require_true(self, tavily_tab != null, "Expected Tavily tab"):
		return

	var base_edit := ov.get_node_or_null("%TavilyBaseUrlEdit") as LineEdit
	if not T.require_true(self, base_edit != null, "Missing TavilyBaseUrlEdit"):
		return
	if not T.require_true(self, base_edit.custom_minimum_size.x >= 520.0, "Base URL edit should be wide enough"):
		return

	var key_edit := ov.get_node_or_null("%TavilyApiKeyEdit") as LineEdit
	if not T.require_true(self, key_edit != null, "Missing TavilyApiKeyEdit"):
		return
	if not T.require_true(self, key_edit.custom_minimum_size.x >= 520.0, "API key edit should be wide enough"):
		return

	if not T.require_true(self, ov.get_node_or_null("%TavilySaveButton") != null, "Missing TavilySaveButton"):
		return
	if not T.require_true(self, ov.get_node_or_null("%TavilyReloadButton") != null, "Missing TavilyReloadButton"):
		return
	if not T.require_true(self, ov.get_node_or_null("%TavilyTestButton") != null, "Missing TavilyTestButton"):
		return

	T.pass_and_quit(self)
