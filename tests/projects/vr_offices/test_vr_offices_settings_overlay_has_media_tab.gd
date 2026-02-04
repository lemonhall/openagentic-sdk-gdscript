extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var OverlayScene := load("res://vr_offices/ui/IrcOverlay.tscn")
	if OverlayScene == null:
		T.fail_and_quit(self, "Missing IrcOverlay.tscn")
		return
	var ov: Control = (OverlayScene as PackedScene).instantiate()
	get_root().add_child(ov)
	await process_frame

	var tabs := ov.get_node_or_null("Panel/VBox/Tabs") as TabContainer
	if not T.require_true(self, tabs != null, "Missing Tabs"):
		return

	var found := false
	for i in range(tabs.get_child_count()):
		var c := tabs.get_child(i) as Control
		if c != null and c.name == "Media":
			found = true
			break
	if not T.require_true(self, found, "Expected Media tab"):
		return

	T.pass_and_quit(self)

