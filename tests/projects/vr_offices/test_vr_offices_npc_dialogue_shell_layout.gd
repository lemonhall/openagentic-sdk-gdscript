extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var save_id: String = "slot_test_vr_offices_npc_shell_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
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

	var VrScene := load("res://vr_offices/VrOffices.tscn")
	if VrScene == null or not (VrScene is PackedScene):
		T.fail_and_quit(self, "Missing VrOffices scene")
		return

	var world := (VrScene as PackedScene).instantiate()
	get_root().add_child(world)
	await process_frame

	var npc := world.call("add_npc") as Node
	if not T.require_true(self, npc != null, "Expected add_npc to return npc"):
		return
	if npc != null and npc.has_method("set"):
		npc.set("display_name", "测试同事")

	world.call("_enter_talk", npc)
	await process_frame

	var shell := world.get_node_or_null("UI/VrOfficesManagerDialogueOverlay") as Control
	if not T.require_true(self, shell != null, "Missing UI/VrOfficesManagerDialogueOverlay"):
		return
	if not T.require_true(self, shell.visible, "Expected NPC dialogue to open manager-style shell"):
		return

	var embedded: Control = null
	if shell.has_method("get_embedded_dialogue"):
		embedded = shell.call("get_embedded_dialogue") as Control
	if not T.require_true(self, embedded != null, "Expected embedded dialogue in manager shell"):
		return
	if not T.require_true(self, embedded.visible, "Expected embedded dialogue to be visible"):
		return

	var title := shell.get_node_or_null("Panel/RootVBox/Header/TitleLabel") as Label
	if not T.require_true(self, title != null, "Missing manager shell title label"):
		return
	if not T.require_true(self, title.text.find("测试同事") != -1, "Expected shell title to show NPC name"):
		return

	var legacy := world.get_node_or_null("UI/DialogueOverlay") as Control
	if not T.require_true(self, legacy != null, "Missing legacy UI/DialogueOverlay"):
		return
	if not T.require_true(self, legacy.visible == false, "Legacy UI/DialogueOverlay should stay hidden for NPC talk"):
		return

	T.pass_and_quit(self)
