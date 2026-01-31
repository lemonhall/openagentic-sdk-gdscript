extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var scene := load("res://vr_offices/ui/DeskOverlay.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing res://vr_offices/ui/DeskOverlay.tscn")
		return

	var overlay := (scene as PackedScene).instantiate() as Control
	if overlay == null:
		T.fail_and_quit(self, "Failed to instantiate DeskOverlay.tscn")
		return
	get_root().add_child(overlay)
	await process_frame

	var menu := overlay.get_node_or_null("ContextMenu") as PopupMenu
	if not T.require_true(self, menu != null, "Missing DeskOverlay/ContextMenu"):
		return

	var expected := "Bind Device Code…"
	var found := false
	for i: int in range(menu.get_item_count()):
		if menu.get_item_text(i) == expected:
			found = true
			break
	if not T.require_true(self, found, "Context menu missing item: " + expected):
		return

	get_root().remove_child(overlay)
	overlay.free()
	await process_frame
	T.pass_and_quit(self)
