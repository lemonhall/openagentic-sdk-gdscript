extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	# Keep this smoke test isolated from any existing saves.
	var save_id: String = "slot_test_vr_offices_irc_overlay_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
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

	var scene := load("res://vr_offices/VrOffices.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing res://vr_offices/VrOffices.tscn")
		return

	var world := (scene as PackedScene).instantiate()
	get_root().add_child(world)
	await process_frame

	if not T.require_true(self, world.get_node_or_null("UI/VrOfficesUi") != null, "Missing VrOffices/UI/VrOfficesUi"):
		return
	if not T.require_true(self, world.get_node_or_null("UI/SettingsOverlay") != null, "Missing VrOffices/UI/SettingsOverlay"):
		return

	# Reduce shutdown noise in headless runs by releasing audio/resources explicitly.
	var bgm := world.get_node_or_null("Bgm") as AudioStreamPlayer
	if bgm != null:
		bgm.stop()
		bgm.stream = null

	get_root().remove_child(world)
	world.free()
	await process_frame
	T.pass_and_quit(self)
