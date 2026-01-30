extends RefCounted

const _DeskIrcLinkScript := preload("res://vr_offices/core/desks/VrOfficesDeskIrcLink.gd")
const _Snapshots := preload("res://vr_offices/core/desks/VrOfficesDeskIrcSnapshots.gd")

var _root: Node3D = null
var _desk_scene: PackedScene = null
var _is_headless: Callable = Callable()
var _nodes_by_id: Dictionary = {}
var _get_save_id: Callable = Callable()

func bind_scene(root: Node3D, desk_scene: PackedScene, is_headless: Callable, get_save_id: Callable = Callable()) -> void:
	_root = root
	_desk_scene = desk_scene
	_is_headless = is_headless
	_get_save_id = get_save_id

func rebuild_nodes(desks: Array[Dictionary], irc_config: Dictionary) -> void:
	_nodes_by_id.clear()
	if _root == null or _desk_scene == null:
		return
	if _is_headless.is_valid() and bool(_is_headless.call()):
		return

	for c0 in _root.get_children():
		var c := c0 as Node
		if c != null:
			c.queue_free()

	for d in desks:
		spawn_node_for(d, irc_config)

func spawn_node_for(desk: Dictionary, irc_config: Dictionary) -> void:
	if _root == null or _desk_scene == null:
		return
	if desk == null:
		return
	if _is_headless.is_valid() and bool(_is_headless.call()):
		return

	var did := String(desk.get("id", "")).strip_edges()
	if did == "" or _nodes_by_id.has(did):
		return

	var pos0: Variant = desk.get("pos")
	if not (pos0 is Array):
		return
	var p := pos0 as Array
	if p.size() != 3:
		return
	var pos := Vector3(float(p[0]), float(p[1]), float(p[2]))
	var yaw := float(desk.get("yaw", 0.0))

	var node0 := _desk_scene.instantiate()
	var n := node0 as Node3D
	if n == null:
		return
	_root.add_child(n)
	n.name = did
	n.position = pos
	n.rotation = Vector3(0.0, yaw, 0.0)

	if n.has_method("configure"):
		n.call("configure", did, String(desk.get("workspace_id", "")))
	if n.has_method("play_spawn_fx"):
		n.call("play_spawn_fx")

	_ensure_irc_link(n, desk, irc_config)
	_nodes_by_id[did] = n

func delete_nodes_for_ids(ids: Array[String]) -> void:
	for id0 in ids:
		_free_node_for_id(id0)

func list_desk_irc_snapshots(desks: Array[Dictionary]) -> Array:
	if _is_headless.is_valid() and bool(_is_headless.call()):
		return []
	return _Snapshots.list_desk_irc_snapshots(desks, _nodes_by_id)

func refresh_irc_links(desks: Array[Dictionary], irc_config: Dictionary) -> void:
	if _is_headless.is_valid() and bool(_is_headless.call()):
		return
	var host := String(irc_config.get("host", "")).strip_edges()
	var port := int(irc_config.get("port", 6667))
	var configured := host != "" and port > 0

	for d0 in desks:
		var d := d0 as Dictionary
		if d == null:
			continue
		var did := String(d.get("id", "")).strip_edges()
		if did == "" or not _nodes_by_id.has(did):
			continue
		var n0: Variant = _nodes_by_id.get(did)
		if typeof(n0) != TYPE_OBJECT:
			continue
		var desk_node := n0 as Node3D
		if desk_node == null or not is_instance_valid(desk_node):
			continue

		var link := desk_node.get_node_or_null("DeskIrcLink") as Node
		if not configured:
			if link != null:
				link.queue_free()
			continue

		if link == null:
			_ensure_irc_link(desk_node, d, irc_config)
		elif link.has_method("configure"):
			link.call("configure", irc_config, _effective_save_id(), String(d.get("workspace_id", "")), did)

func reconnect_all_irc_links(desks: Array[Dictionary], irc_config: Dictionary) -> void:
	# Manual operator action: force reconnect (close + connect) for all desk links.
	if _is_headless.is_valid() and bool(_is_headless.call()):
		return
	refresh_irc_links(desks, irc_config)

	for d0 in desks:
		var d := d0 as Dictionary
		if d == null:
			continue
		var did := String(d.get("id", "")).strip_edges()
		if did == "" or not _nodes_by_id.has(did):
			continue
		var n0: Variant = _nodes_by_id.get(did)
		var desk_node := n0 as Node3D
		if desk_node == null or not is_instance_valid(desk_node):
			continue
		var link := desk_node.get_node_or_null("DeskIrcLink") as Node
		if link == null:
			continue
		if link.has_method("reconnect_now"):
			link.call("reconnect_now")
		elif link.has_method("configure"):
			link.call("configure", irc_config, _effective_save_id(), String(d.get("workspace_id", "")), did)

func _effective_save_id() -> String:
	var sid := ""
	if _get_save_id.is_valid():
		sid = String(_get_save_id.call()).strip_edges()
	if sid == "":
		sid = "slot1"
	return sid

func _ensure_irc_link(desk_node: Node3D, desk: Dictionary, irc_config: Dictionary) -> void:
	if desk_node == null:
		return
	var host := String(irc_config.get("host", "")).strip_edges()
	var port := int(irc_config.get("port", 6667))
	if host == "" or port <= 0:
		return
	if desk == null:
		return
	var desk_id := String(desk.get("id", "")).strip_edges()
	if desk_id == "":
		return
	var workspace_id := String(desk.get("workspace_id", "")).strip_edges()

	var link := desk_node.get_node_or_null("DeskIrcLink") as Node
	if link == null:
		link = _DeskIrcLinkScript.new() as Node
		if link == null:
			return
		link.name = "DeskIrcLink"
		desk_node.add_child(link)
	if link.has_method("configure"):
		link.call("configure", irc_config, _effective_save_id(), workspace_id, desk_id)

func _free_node_for_id(desk_id: String) -> void:
	var did := desk_id.strip_edges()
	if did == "" or not _nodes_by_id.has(did):
		return
	var n0: Variant = _nodes_by_id.get(did)
	_nodes_by_id.erase(did)
	if typeof(n0) != TYPE_OBJECT:
		return
	var n := n0 as Node
	if n != null and is_instance_valid(n):
		n.queue_free()
