extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var scene0 := load("res://vr_offices/ui/VrOfficesManagerDialogueOverlay.tscn")
	if scene0 == null or not (scene0 is PackedScene):
		T.fail_and_quit(self, "Missing VrOfficesManagerDialogueOverlay.tscn")
		return

	var overlay := (scene0 as PackedScene).instantiate() as Control
	if overlay == null:
		T.fail_and_quit(self, "Failed to instantiate VrOfficesManagerDialogueOverlay")
		return

	get_root().add_child(overlay)
	await process_frame

	overlay.call("open_for_manager", "workspace_alpha", "经理", "")
	await process_frame

	var name_label := overlay.get_node_or_null("Panel/RootVBox/Body/RightPreview/IdentityPanel/IdentityVBox/IdentityNameLabel") as Label
	if not T.require_true(self, name_label != null, "Missing identity name label in shell preview panel"):
		return
	var workspace_label := overlay.get_node_or_null("Panel/RootVBox/Body/RightPreview/IdentityPanel/IdentityVBox/IdentityWorkspaceLabel") as Label
	if not T.require_true(self, workspace_label != null, "Missing workspace label in shell preview panel"):
		return

	if not T.require_true(self, name_label.text.find("经理") != -1, "Expected identity label to show manager name"):
		return
	if not T.require_true(self, workspace_label.text.find("workspace_alpha") != -1, "Expected workspace label to show manager workspace"):
		return

	overlay.call("open_for_npc", "npc_1", "小李", "", "workspace_beta")
	await process_frame
	if not T.require_true(self, name_label.text.find("小李") != -1, "Expected identity label to show NPC name"):
		return
	if not T.require_true(self, workspace_label.text.find("workspace_beta") != -1, "Expected workspace label to update for NPC"):
		return

	overlay.free()
	await process_frame
	T.pass_and_quit(self)
