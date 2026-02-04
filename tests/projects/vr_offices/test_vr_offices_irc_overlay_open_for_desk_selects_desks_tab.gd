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

	if not T.require_true(self, ov.has_method("open_for_desk"), "Expected SettingsOverlay.open_for_desk()"):
		return
	ov.call("open_for_desk", "desk_test")
	await process_frame

	var tabs := ov.get_node_or_null("Panel/VBox/Tabs") as TabContainer
	if not T.require_true(self, tabs != null, "Missing Tabs"):
		return
	if not T.require_true(self, tabs.get_child_count() >= 1, "Tabs should have at least one child"):
		return

	var idx := tabs.current_tab
	var selected := tabs.get_child(idx) as Control
	if not T.require_true(self, selected != null, "Selected tab should be a Control"):
		return
	if not T.require_true(self, selected.name == "Desks", "Expected open_for_desk() selects Desks tab"):
		return

	T.pass_and_quit(self)
