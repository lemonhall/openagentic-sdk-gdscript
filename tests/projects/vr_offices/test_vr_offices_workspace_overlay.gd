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
	var meeting_confirmed: Array = []
	var canceled := [0]
	var deleted: Array = []
	var meeting_deleted: Array = []

	overlay.connect("create_confirmed", func(n: String) -> void:
		confirmed.append(n)
	)
	if overlay.has_signal("create_meeting_room_confirmed"):
		overlay.connect("create_meeting_room_confirmed", func(n: String) -> void:
			meeting_confirmed.append(n)
		)
	overlay.connect("create_canceled", func() -> void:
		canceled[0] += 1
	)
	overlay.connect("delete_requested", func(wid: String) -> void:
		deleted.append(wid)
	)
	if overlay.has_signal("meeting_room_delete_requested"):
		overlay.connect("meeting_room_delete_requested", func(rid: String) -> void:
			meeting_deleted.append(rid)
		)

	overlay.call("prompt_create", "  Alpha  ")
	await process_frame
	var popup := overlay.get_node_or_null("%CreatePopup") as PopupPanel
	if popup == null:
		T.fail_and_quit(self, "Missing %CreatePopup")
		return
	# Regression: ensure the configured popup size is wide enough.
	var s0: Variant = overlay.call("get_create_popup_size")
	if not (s0 is Vector2i):
		T.fail_and_quit(self, "Expected get_create_popup_size() -> Vector2i")
		return
	var s := s0 as Vector2i
	if not T.require_true(self, int(s.x) >= 480, "Expected CreatePopup configured width >= 480"):
		return
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

	# Meeting room create should emit a dedicated signal when the user selects Meeting Room.
	if not overlay.has_signal("create_meeting_room_confirmed"):
		T.fail_and_quit(self, "WorkspaceOverlay missing create_meeting_room_confirmed signal")
		return
	overlay.call("prompt_create", "Workspace 1")
	await process_frame
	var type_opt := overlay.get_node_or_null("%RoomTypeOption") as OptionButton
	if type_opt == null:
		T.fail_and_quit(self, "Missing %RoomTypeOption")
		return
	type_opt.selected = 1
	var name_edit := overlay.get_node_or_null("%NameEdit") as LineEdit
	if name_edit == null:
		T.fail_and_quit(self, "Missing %NameEdit")
		return
	name_edit.text = "  Gamma  "
	overlay.call("confirm_create")
	await process_frame
	if not T.require_eq(self, meeting_confirmed.size(), 1, "Expected create_meeting_room_confirmed once"):
		return
	if not T.require_eq(self, String(meeting_confirmed[0]), "Gamma", "Expected trimmed meeting room name"):
		return

	# Meeting room delete should emit a dedicated signal.
	if not overlay.has_signal("meeting_room_delete_requested"):
		T.fail_and_quit(self, "WorkspaceOverlay missing meeting_room_delete_requested signal")
		return
	overlay.call("show_meeting_room_menu", Vector2(10, 10), "mr_2")
	overlay.call("_on_context_menu_id_pressed", 3)
	await process_frame
	if not T.require_eq(self, meeting_deleted.size(), 1, "Expected meeting_room_delete_requested once"):
		return
	if not T.require_eq(self, String(meeting_deleted[0]), "mr_2", "Expected meeting room id"):
		return

	get_root().remove_child(overlay)
	overlay.free()
	await process_frame
	T.pass_and_quit(self)
