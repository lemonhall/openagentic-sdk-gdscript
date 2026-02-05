extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _wait_frames(frames: int) -> void:
	for _i in range(frames):
		await process_frame

func _init() -> void:
	# Ensure save_id exists (overlay.open() calls library_refresh()).
	var save_id: String = "slot_test_teach_popup_switch_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	var oa := get_root().get_node_or_null("OpenAgentic") as Node
	if oa == null:
		var OAScript := load("res://addons/openagentic/OpenAgentic.gd")
		if OAScript == null:
			T.fail_and_quit(self, "Missing res://addons/openagentic/OpenAgentic.gd")
			return
		oa = (OAScript as Script).new() as Node
		oa.name = "OpenAgentic"
		get_root().add_child(oa)
		await process_frame
	oa.call("set_save_id", save_id)

	var OverlayScene := load("res://vr_offices/ui/VendingMachineOverlay.tscn")
	if OverlayScene == null or not (OverlayScene is PackedScene):
		T.fail_and_quit(self, "Missing VendingMachineOverlay.tscn")
		return
	var overlay := (OverlayScene as PackedScene).instantiate() as Control
	get_root().add_child(overlay)
	await process_frame
	if overlay.has_method("open"):
		overlay.call("open")
	await _wait_frames(2)

	var popup := overlay.get_node_or_null("%TeachSkillPopup") as PopupPanel
	if popup == null:
		T.fail_and_quit(self, "Missing %TeachSkillPopup")
		return
	if not popup.has_method("debug_set_headless_override"):
		T.fail_and_quit(self, "Missing debug_set_headless_override()")
		return
	popup.call("debug_set_headless_override", false)
	if not popup.has_method("debug_set_instant_switch"):
		T.fail_and_quit(self, "Missing debug_set_instant_switch()")
		return
	popup.call("debug_set_instant_switch", true)

	var vp := overlay.get_node_or_null("%TeachPreviewViewport") as SubViewport
	if vp == null:
		T.fail_and_quit(self, "Missing %TeachPreviewViewport")
		return

	# Open the popup with two dummy NPCs so switching uses the tween path.
	if not popup.has_method("open_for_skill"):
		T.fail_and_quit(self, "Missing open_for_skill()")
		return
	popup.call(
		"open_for_skill",
		save_id,
		"some-skill",
		[
			{"npc_id": "npc_a", "display_name": "A", "model_path": ""},
			{"npc_id": "npc_b", "display_name": "B", "model_path": ""},
		]
	)
	await _wait_frames(2)

	var next_btn := overlay.get_node_or_null("%TeachNextNpcButton") as Button
	if next_btn == null:
		T.fail_and_quit(self, "Missing %TeachNextNpcButton")
		return
	next_btn.pressed.emit()

	if not T.require_eq(self, int(vp.render_target_update_mode), int(SubViewport.UPDATE_ALWAYS), "Expected preview viewport stays UPDATE_ALWAYS after switch"):
		return

	T.pass_and_quit(self)
