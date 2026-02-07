extends RefCounted

const _Palette := preload("res://vr_offices/core/workspaces/VrOfficesWorkspacePalette.gd")

var _root: Node3D = null
var _scene: PackedScene = null
var _is_headless: Callable = Callable()
var _nodes_by_id: Dictionary = {}

func bind_scene(root: Node3D, scene: PackedScene, is_headless: Callable) -> void:
	_root = root
	_scene = scene
	_is_headless = is_headless

func rebuild_nodes(rooms: Array[Dictionary]) -> void:
	_nodes_by_id.clear()
	if _root == null or _scene == null:
		return

	for c0 in _root.get_children():
		var c := c0 as Node
		if c != null:
			c.queue_free()

	for r in rooms:
		spawn_node_for(r)

func spawn_node_for(room: Dictionary) -> void:
	if _root == null or _scene == null:
		return
	if room == null:
		return
	var rid := String(room.get("id", "")).strip_edges()
	if rid == "" or _nodes_by_id.has(rid):
		return
	var rect0: Variant = room.get("rect_xz")
	if not (rect0 is Rect2):
		return
	var r := rect0 as Rect2
	var color_index := int(room.get("color_index", 0))
	var color := _Palette.color_for_index(color_index)

	var node0 := _scene.instantiate()
	var n := node0 as Node
	if n == null:
		return
	_root.add_child(n)
	if n.has_method("set"):
		n.set("meeting_room_id", rid)
		n.set("meeting_room_name", String(room.get("name", "")))
	if n.has_method("configure"):
		n.call("configure", r, color, false)
	n.name = rid
	_nodes_by_id[rid] = n

func play_spawn_fx_for(meeting_room_id: String) -> void:
	if _root == null:
		return
	if _is_headless.is_valid() and bool(_is_headless.call()):
		return
	var rid := meeting_room_id.strip_edges()
	if rid == "" or not _nodes_by_id.has(rid):
		return
	var n0: Variant = _nodes_by_id.get(rid)
	if typeof(n0) != TYPE_OBJECT:
		return
	var n := n0 as Node
	if n == null or not is_instance_valid(n):
		return
	if n.has_method("play_spawn_fx"):
		n.call("play_spawn_fx")

func free_node_for_id(meeting_room_id: String) -> void:
	var rid := meeting_room_id.strip_edges()
	if rid == "" or not _nodes_by_id.has(rid):
		return
	var n0: Variant = _nodes_by_id.get(rid)
	_nodes_by_id.erase(rid)
	if typeof(n0) != TYPE_OBJECT:
		return
	var n := n0 as Node
	if n != null and is_instance_valid(n):
		n.queue_free()

