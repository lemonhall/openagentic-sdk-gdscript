extends RefCounted

const _WorkspaceStore := preload("res://vr_offices/core/workspaces/VrOfficesWorkspaceStore.gd")
const _WorkspaceSceneBinder := preload("res://vr_offices/core/workspaces/VrOfficesWorkspaceSceneBinder.gd")

var floor_bounds_xz: Rect2

var _store: RefCounted = null
var _scene: RefCounted = null

func _init(bounds_xz: Rect2, workspace_root: Node3D = null, workspace_scene: PackedScene = null, is_headless: Callable = Callable()) -> void:
	floor_bounds_xz = bounds_xz
	_store = _WorkspaceStore.new(bounds_xz)
	_scene = _WorkspaceSceneBinder.new()
	if workspace_root != null and workspace_scene != null:
		bind_scene(workspace_root, workspace_scene, is_headless)

func get_workspace_counter() -> int:
	return int(_store.call("get_workspace_counter"))

func list_workspaces() -> Array:
	return _store.call("list_workspaces")

func get_workspace(workspace_id: String) -> Dictionary:
	return _store.call("get_workspace", workspace_id)

func get_workspace_rect_xz(workspace_id: String) -> Rect2:
	return _store.call("get_workspace_rect_xz", workspace_id)

func bind_scene(workspace_root: Node3D, workspace_scene: PackedScene, is_headless: Callable) -> void:
	_scene.call("bind_scene", workspace_root, workspace_scene, is_headless)
	_scene.call("rebuild_nodes", _store.call("list_workspaces_ref"))

func clamp_rect_to_floor(r: Rect2) -> Rect2:
	return _store.call("clamp_rect_to_floor", r)

func can_place(rect_xz: Rect2) -> bool:
	return bool(_store.call("can_place", rect_xz))

func create_workspace(rect_xz: Rect2, name: String) -> Dictionary:
	var res: Dictionary = _store.call("create_workspace", rect_xz, name)
	if bool(res.get("ok", false)):
		var ws0: Variant = res.get("workspace")
		if typeof(ws0) == TYPE_DICTIONARY:
			var ws := ws0 as Dictionary
			_scene.call("spawn_node_for", ws)
			_scene.call("play_spawn_fx_for", String(ws.get("id", "")))
	return res

func delete_workspace(workspace_id: String) -> Dictionary:
	var res: Dictionary = _store.call("delete_workspace", workspace_id)
	if bool(res.get("ok", false)):
		_scene.call("free_node_for_id", workspace_id)
	return res

func to_state_array() -> Array:
	return _store.call("to_state_array")

func load_from_state_dict(state: Dictionary) -> void:
	_store.call("load_from_state_dict", state)
	_scene.call("rebuild_nodes", _store.call("list_workspaces_ref"))

func workspace_id_from_collider(obj: Object) -> String:
	var cur := obj
	while cur != null and cur is Node:
		var n := cur as Node
		if n.is_in_group("vr_offices_workspace") and n.has_method("get"):
			var v: Variant = n.get("workspace_id")
			if v != null:
				return String(v)
			return n.name
		cur = n.get_parent()
	return ""

