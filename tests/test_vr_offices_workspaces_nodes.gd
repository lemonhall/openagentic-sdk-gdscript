extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var ManagerScript := load("res://vr_offices/core/VrOfficesWorkspaceManager.gd")
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

