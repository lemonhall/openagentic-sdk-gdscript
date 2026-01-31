extends RefCounted

const _Palette := preload("res://vr_offices/core/workspaces/VrOfficesWorkspacePalette.gd")
const _Decorations := preload("res://vr_offices/core/workspaces/VrOfficesWorkspaceDecorations.gd")

var _workspace_root: Node3D = null
var _workspace_scene: PackedScene = null
var _is_headless: Callable = Callable()
var _nodes_by_id: Dictionary = {}

func bind_scene(workspace_root: Node3D, workspace_scene: PackedScene, is_headless: Callable) -> void:
	_workspace_root = workspace_root
	_workspace_scene = workspace_scene
	_is_headless = is_headless

func rebuild_nodes(workspaces: Array[Dictionary]) -> void:
	# Keep state logic functional in headless/test environments even if visuals are unavailable.
	_nodes_by_id.clear()
	if _workspace_root == null or _workspace_scene == null:
		return

	for c0 in _workspace_root.get_children():
		var c := c0 as Node
		if c != null:
			c.queue_free()

	for ws in workspaces:
		spawn_node_for(ws)

func spawn_node_for(ws: Dictionary) -> void:
	if _workspace_root == null or _workspace_scene == null:
		return
	if ws == null:
		return
	var wid := String(ws.get("id", "")).strip_edges()
	if wid == "" or _nodes_by_id.has(wid):
		return
	var rect0: Variant = ws.get("rect_xz")
	if not (rect0 is Rect2):
		return
	var r := rect0 as Rect2
	var color_index := int(ws.get("color_index", 0))
	var color := _Palette.color_for_index(color_index)

	var node0 := _workspace_scene.instantiate()
	var n := node0 as Node
	if n == null:
		return
	_workspace_root.add_child(n)
	if n.has_method("set"):
		n.set("workspace_id", wid)
		n.set("workspace_name", String(ws.get("name", "")))
	if n.has_method("configure"):
		n.call("configure", r, color, false)
	_Decorations.decorate_workspace(n as Node3D, wid, r)
	n.name = wid
	_nodes_by_id[wid] = n

func play_spawn_fx_for(workspace_id: String) -> void:
	if _workspace_root == null:
		return
	if _is_headless.is_valid() and bool(_is_headless.call()):
		return
	var wid := workspace_id.strip_edges()
	if wid == "" or not _nodes_by_id.has(wid):
		return
	var n0: Variant = _nodes_by_id.get(wid)
	if typeof(n0) != TYPE_OBJECT:
		return
	var n := n0 as Node
	if n == null or not is_instance_valid(n):
		return
	if n.has_method("play_spawn_fx"):
		n.call("play_spawn_fx")

func free_node_for_id(workspace_id: String) -> void:
	var wid := workspace_id.strip_edges()
	if wid == "" or not _nodes_by_id.has(wid):
		return
	var n0: Variant = _nodes_by_id.get(wid)
	_nodes_by_id.erase(wid)
	if typeof(n0) != TYPE_OBJECT:
		return
	var n := n0 as Node
	if n != null and is_instance_valid(n):
		n.queue_free()
