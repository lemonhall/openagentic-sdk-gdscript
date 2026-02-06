extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var save_id: String = "slot_test_vr_offices_skills_restore_shell_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
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
	if world == null:
		T.fail_and_quit(self, "Failed to instantiate VrOffices.tscn")
		return
	get_root().add_child(world)
	await process_frame

	var npc := world.call("add_npc") as Node
	if not T.require_true(self, npc != null, "Expected add_npc() to return npc"):
		return

	world.call("_enter_talk", npc)
	await process_frame

	var shell := world.get_node_or_null("UI/VrOfficesManagerDialogueOverlay") as Control
	if not T.require_true(self, shell != null and shell.visible, "Expected dialogue shell visible after enter talk"):
		return

	var skills_service := world.get_node_or_null("NpcSkillsService") as Node
	if skills_service != null:
		skills_service.remove_from_group("vr_offices_npc_skills_service")

	var npc_id := ""
	var npc_name := ""
	if npc.has_method("get"):
		var id0: Variant = npc.get("npc_id")
		if id0 != null:
			npc_id = String(id0).strip_edges()
	if npc.has_method("get_display_name"):
		npc_name = String(npc.call("get_display_name")).strip_edges()

	world.call("_on_dialogue_skills_pressed", save_id, npc_id, npc_name)
	await process_frame

	var skills := world.get_node_or_null("UI/VrOfficesNpcSkillsOverlay") as Control
	if not T.require_true(self, skills != null and skills.visible, "Expected NPC skills overlay visible"):
		return
	if not T.require_true(self, shell.visible == false, "Expected dialogue shell hidden while skills open"):
		return

	skills.call("close")
	await process_frame

	if not T.require_true(self, shell.visible, "Expected dialogue shell to restore after closing skills"):
		return
	var embedded: Control = null
	if shell.has_method("get_embedded_dialogue"):
		embedded = shell.call("get_embedded_dialogue") as Control
	if not T.require_true(self, embedded != null and embedded.visible, "Expected embedded dialogue visible after restore"):
		return
	if embedded != null and embedded.has_method("get_npc_id"):
		if not T.require_eq(self, String(embedded.call("get_npc_id")), npc_id, "Expected restored dialogue to target previous NPC"):
			return

	var bgm := world.get_node_or_null("Bgm") as AudioStreamPlayer
	if bgm != null:
		bgm.stop()
		bgm.stream = null
	get_root().remove_child(world)
	world.free()
	await process_frame

	T.pass_and_quit(self)
