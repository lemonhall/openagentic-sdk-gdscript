extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _find_descendant_named(root: Node, want: String) -> Node:
	if root == null:
		return null
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var cur := stack.pop_back() as Node
		if cur == null:
			continue
		if cur.name == want:
			return cur
		for c0 in cur.get_children():
			var c := c0 as Node
			if c != null:
				stack.append(c)
	return null

func _init() -> void:
	var ManagerScript := load("res://vr_offices/core/workspaces/VrOfficesWorkspaceManager.gd")
	var AreaScene0 := load("res://vr_offices/workspaces/WorkspaceArea.tscn")
	if ManagerScript == null or AreaScene0 == null or not (AreaScene0 is PackedScene):
		T.fail_and_quit(self, "Missing workspace manager / area scene")
		return

	var root := Node3D.new()
	root.name = "Workspaces"
	get_root().add_child(root)
	await process_frame

	var bounds := Rect2(Vector2(-10, -10), Vector2(20, 20))
	var mgr := (ManagerScript as Script).new(bounds) as RefCounted
	if mgr == null:
		T.fail_and_quit(self, "Failed to instantiate manager")
		return
	mgr.call("bind_scene", root, AreaScene0, Callable())

	var res: Dictionary = mgr.call("create_workspace", Rect2(Vector2(-2, -2), Vector2(3, 4)), "Team A")
	if not T.require_true(self, bool(res.get("ok", false)), "Expected create_workspace ok"):
		return
	await process_frame
	if not T.require_eq(self, root.get_child_count(), 1, "Expected one workspace node spawned"):
		return

	var child := root.get_child(0) as Node
	if not T.require_true(self, child != null and child.is_in_group("vr_offices_workspace"), "Expected workspace node group"):
		return
	if not T.require_eq(self, String(child.get("workspace_name")), "Team A", "Expected name on node"):
		return
	# Visual: workspace should have wall nodes (purely visual, no collision required).
	var walls := child.get_node_or_null("Walls") as Node3D
	if not T.require_true(self, walls != null, "Expected workspace Walls node"):
		return
	var px := walls.get_node_or_null("WallPosX") as Node
	var nx := walls.get_node_or_null("WallNegX") as Node
	var pz := walls.get_node_or_null("WallPosZ") as Node
	var nz := walls.get_node_or_null("WallNegZ") as Node
	if not T.require_true(self, px != null and nx != null and pz != null and nz != null, "Expected 4 wall mesh nodes"):
		return

	# Visual: workspace should include decoration wrapper nodes.
	var decor := child.get_node_or_null("Decor") as Node3D
	if not T.require_true(self, decor != null, "Expected workspace Decor node"):
		return
	# Floor props are parented under Decor for organization.
	if not T.require_true(self, decor.get_node_or_null("FileCabinet") != null, "Expected Decor/FileCabinet"):
		return
	if not T.require_true(self, decor.get_node_or_null("Houseplant") != null, "Expected Decor/Houseplant"):
		return
	if not T.require_true(self, decor.get_node_or_null("TrashcanSmall") != null, "Expected Decor/TrashcanSmall"):
		return
	if not T.require_true(self, decor.get_node_or_null("WaterCooler") != null, "Expected Decor/WaterCooler"):
		return
	var vending := decor.get_node_or_null("VendingMachine") as Node3D
	if not T.require_true(self, vending != null, "Expected Decor/VendingMachine"):
		return
	# Basic invariants: placed near a wall and faces inward.
	var pos := vending.position
	var hx := 1.5 # create_workspace rect size.x / 2
	var hz := 2.0 # create_workspace rect size.y / 2
	if not T.require_true(self, absf(absf(pos.x) - hx) <= 0.7, "Expected VendingMachine near an X wall"):
		return
	if not T.require_true(self, absf(pos.z) <= hz - 0.2 + 1e-4, "Expected VendingMachine within Z bounds"):
		return
	var to_center := Vector3(-pos.x, 0.0, -pos.z)
	if not T.require_true(self, to_center.length() > 0.01, "Expected VendingMachine not at workspace center"):
		return
	var forward := -vending.global_transform.basis.z
	if not T.require_true(self, forward.dot(to_center.normalized()) > 0.6, "Expected VendingMachine facing workspace center"):
		return

	# Wall props may be attached under wall mesh nodes for visibility.
	if not T.require_true(self, _find_descendant_named(child, "AnalogClock") != null, "Expected AnalogClock node"):
		return
	if not T.require_true(self, _find_descendant_named(child, "Dartboard") != null, "Expected Dartboard node"):
		return
	if not T.require_true(self, _find_descendant_named(child, "FireExitSign") != null, "Expected FireExitSign node"):
		return
	if not T.require_true(self, _find_descendant_named(child, "WallArt03") != null, "Expected WallArt03 node"):
		return
	if not T.require_true(self, _find_descendant_named(child, "Whiteboard") != null, "Expected Whiteboard node"):
		return

	var wid := String(child.get("workspace_id"))
	var del: Dictionary = mgr.call("delete_workspace", wid)
	if not T.require_true(self, bool(del.get("ok", false)), "Expected delete ok"):
		return
	await process_frame

	# Allow queued frees to process.
	await process_frame
	if not T.require_eq(self, root.get_child_count(), 0, "Expected no workspace nodes after delete"):
		return

	get_root().remove_child(root)
	root.free()
	await process_frame
	T.pass_and_quit(self)
