extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var Scene0 := load("res://vr_offices/ui/WorkspaceOverlay.tscn")
	if Scene0 == null or not (Scene0 is PackedScene):
		T.fail_and_quit(self, "Missing res://vr_offices/ui/WorkspaceOverlay.tscn")
		return
	var overlay := (Scene0 as PackedScene).instantiate() as Control
	if overlay == null:
		T.fail_and_quit(self, "Failed to instantiate WorkspaceOverlay")
		return
	get_root().add_child(overlay)
	await process_frame

	var confirmed: Array = []
	var canceled := [0]
	var deleted: Array = []

	overlay.connect("create_confirmed", func(n: String) -> void:
		confirmed.append(n)
	)
	overlay.connect("create_canceled", func() -> void:
		canceled[0] += 1
	)
	overlay.connect("delete_requested", func(wid: String) -> void:
		deleted.append(wid)
	)

	overlay.call("prompt_create", "  Alpha  ")
	await process_frame
	overlay.call("confirm_create")
	await process_frame
	if not T.require_eq(self, confirmed.size(), 1, "Expected create_confirmed once"):
		return
	if not T.require_eq(self, String(confirmed[0]), "Alpha", "Expected trimmed name"):
		return

	overlay.call("prompt_create", "Beta")
	await process_frame
	overlay.call("cancel_create")
	await process_frame
	if not T.require_true(self, int(canceled[0]) >= 1, "Expected create_canceled"):
		return

	overlay.call("show_workspace_menu", Vector2(10, 10), "ws_9")
	overlay.call("_on_context_menu_id_pressed", 1)
	await process_frame
	if not T.require_eq(self, deleted.size(), 1, "Expected delete_requested once"):
		return
	if not T.require_eq(self, String(deleted[0]), "ws_9", "Expected workspace id"):
		return

	get_root().remove_child(overlay)
	overlay.free()
	await process_frame
	T.pass_and_quit(self)
