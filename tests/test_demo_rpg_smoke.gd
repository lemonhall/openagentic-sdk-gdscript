extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var scene := load("res://demo_rpg/World.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing res://demo_rpg/World.tscn")
		return

	var world := (scene as PackedScene).instantiate()
	if world == null:
		T.fail_and_quit(self, "Failed to instantiate World.tscn")
		return

	# Root expectations.
	if not T.require_true(self, world.name == "World", "World.tscn root must be named 'World'"):
		return

	# Core nodes.
	if not T.require_true(self, world.get_node_or_null("Ground") != null, "Missing node World/Ground"):
		return
	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Missing node World/Player"):
		return
	if not T.require_true(self, player.get_node_or_null("Visual") != null, "Missing node World/Player/Visual"):
		return
	var pvis := player.get_node_or_null("Visual")
	if not T.require_true(self, pvis.has_method("set_walking") and pvis.has_method("set_move_dir"), "Expected Player/Visual to be character sprite script"):
		return

	# At least one NPC exists.
	var npc_container := world.get_node_or_null("NPCs")
	if not T.require_true(self, npc_container != null, "Missing node World/NPCs"):
		return
	if not T.require_true(self, npc_container.get_child_count() >= 1, "Expected at least 1 NPC under World/NPCs"):
		return
	if not T.require_true(self, npc_container.get_child(0).get_node_or_null("InteractionArea") != null, "Expected NPC to have InteractionArea"):
		return
	if not T.require_true(self, npc_container.get_child(0).get_node_or_null("Visual") != null, "Expected NPC to have Visual"):
		return
	var nvis := npc_container.get_child(0).get_node_or_null("Visual")
	if not T.require_true(self, nvis.has_method("set_walking") and nvis.has_method("set_move_dir"), "Expected NPC/Visual to be character sprite script"):
		return

	# UI exists.
	var ui := world.get_node_or_null("UI")
	if not T.require_true(self, ui != null, "Missing node World/UI"):
		return
	if not T.require_true(self, ui.get_node_or_null("DialogueBox") != null, "Missing node World/UI/DialogueBox"):
		return
	if not T.require_true(self, ui.get_node_or_null("InteractPrompt") != null, "Missing node World/UI/InteractPrompt"):
		return

	world.queue_free()
	T.pass_and_quit(self)
