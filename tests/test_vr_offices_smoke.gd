extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var scene := load("res://vr_offices/VrOffices.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing res://vr_offices/VrOffices.tscn")
		return

	var world := (scene as PackedScene).instantiate()
	if world == null:
		T.fail_and_quit(self, "Failed to instantiate VrOffices.tscn")
		return

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

	var npc := world.call("add_npc")
	if not T.require_true(self, npc != null, "add_npc() must return the NPC instance"):
		return
	if not T.require_eq(self, npc_root.get_child_count(), 1, "Expected 1 NPC after add_npc()"):
		return

	world.call("select_npc", npc_root.get_child(0))
	world.call("remove_selected")
	if not T.require_eq(self, npc_root.get_child_count(), 1, "Expected NPC queued for free (still present before processing)"):
		return

	# Simulate a frame so queued frees can run in real execution environments.
	get_root().add_child(world)
	await process_frame

	if not T.require_eq(self, npc_root.get_child_count(), 0, "Expected 0 NPC after remove_selected()"):
		return

	world.queue_free()
	T.pass_and_quit(self)

