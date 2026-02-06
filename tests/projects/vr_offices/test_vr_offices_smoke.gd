extends SceneTree

const T := preload("res://tests/_test_util.gd")
const _OAData := preload("res://vr_offices/core/data/VrOfficesData.gd")

func _init() -> void:
	# Ensure this smoke test runs against an isolated save slot (vr_offices now auto-loads saved NPCs).
	var save_id: String = "slot_test_vr_offices_smoke_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
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

	# Add to the tree so @onready vars and _ready() run (Godot 4.6 strict mode expects this).
	get_root().add_child(world)
	await process_frame

	if not T.require_true(self, world.name == "VrOffices", "VrOffices.tscn root must be named 'VrOffices'"):
		return
	if not T.require_true(self, world.get_node_or_null("Floor") != null, "Missing node VrOffices/Floor"):
		return
	if not T.require_true(self, world.get_node_or_null("CameraRig") != null, "Missing node VrOffices/CameraRig"):
		return
	if not T.require_true(self, world.get_node_or_null("NpcRoot") != null, "Missing node VrOffices/NpcRoot"):
		return
	if not T.require_true(self, world.get_node_or_null("UI/VrOfficesUi") != null, "Missing node VrOffices/UI/VrOfficesUi"):
		return

	if not T.require_true(self, world.has_method("add_npc"), "Expected VrOffices.gd to have add_npc()"):
		return
	if not T.require_true(self, world.has_method("remove_selected"), "Expected VrOffices.gd to have remove_selected()"):
		return
	if not T.require_true(self, world.has_method("select_npc"), "Expected VrOffices.gd to have select_npc()"):
		return

	var npc_root := world.get_node("NpcRoot") as Node
	if not T.require_eq(self, npc_root.get_child_count(), 0, "Expected empty NpcRoot before spawning"):
		return

	# Add up to the max unique non-manager NPC profiles.
	var last_npc: Node = null
	var expected_max := _OAData.MODEL_PATHS.size() - 1
	for _i in range(expected_max):
		last_npc = world.call("add_npc") as Node
		if not T.require_true(self, last_npc != null, "add_npc() must return the NPC instance"):
			return
	if not T.require_eq(self, npc_root.get_child_count(), expected_max, "Expected max NPCs after filling unique non-manager profiles"):
		return

	# 13th add should fail (no more unique profiles).
	var extra: Node = world.call("add_npc") as Node
	if not T.require_true(self, extra == null, "Expected add_npc() to return null when at max profiles"):
		return

	# Remove one, then add again should succeed.
	var first_npc: Node = npc_root.get_child(0) as Node
	world.call("select_npc", first_npc)
	world.call("remove_selected")

	# Simulate a frame so queued frees can run in real execution environments.
	await process_frame

	if not T.require_eq(self, npc_root.get_child_count(), expected_max - 1, "Expected one fewer NPC after remove_selected()"):
		return

	var again: Node = world.call("add_npc") as Node
	if not T.require_true(self, again != null, "Expected add_npc() to succeed after removing one"):
		return

	# Opening the dialogue should disable the orbit camera controls (prevents mouse wheel/drag from moving the view).
	var cam_rig := world.get_node_or_null("CameraRig") as Node
	if not T.require_true(self, cam_rig != null, "Missing node VrOffices/CameraRig"):
		return
	if cam_rig.has_method("set_controls_enabled"):
		world.call("_enter_talk", again)
		if not T.require_true(self, bool(cam_rig.get("controls_enabled")) == false, "CameraRig should be disabled while dialogue is open"):
			return
		var shell := world.get_node_or_null("UI/VrOfficesManagerDialogueOverlay") as Control
		if not T.require_true(self, shell != null, "Missing node VrOffices/UI/VrOfficesManagerDialogueOverlay"):
			return
		if not T.require_true(self, shell.visible, "Manager-style dialogue shell should be visible while talking"):
			return
		world.call("_exit_talk")
		if not T.require_true(self, bool(cam_rig.get("controls_enabled")) == true, "CameraRig should re-enable after dialogue closes"):
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
