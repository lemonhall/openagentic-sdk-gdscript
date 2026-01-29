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

	# Add up to the max unique NPCs (12).
	var last_npc: Node = null
	for _i in range(12):
		last_npc = world.call("add_npc") as Node
		if not T.require_true(self, last_npc != null, "add_npc() must return the NPC instance"):
			return
	if not T.require_eq(self, npc_root.get_child_count(), 12, "Expected 12 NPCs after filling unique profiles"):
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

	if not T.require_eq(self, npc_root.get_child_count(), 11, "Expected 11 NPC after remove_selected()"):
		return

	var again: Node = world.call("add_npc") as Node
	if not T.require_true(self, again != null, "Expected add_npc() to succeed after removing one"):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)
