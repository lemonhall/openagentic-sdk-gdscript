extends RefCounted

const DESK_KIND_STANDING := "standing_desk"

const _DEFAULT_FOOTPRINT_XZ := Vector2(1.755, 0.975) # X,Z meters (approx; tweak later)
const _MAX_DESKS_PER_WORKSPACE := 3

const _DeskIrcLinkScript := preload("res://vr_offices/core/VrOfficesDeskIrcLink.gd")

var _desk_counter := 0
var _desks: Array[Dictionary] = []

var _root: Node3D = null
var _desk_scene: PackedScene = null
var _is_headless: Callable = Callable()
var _nodes_by_id: Dictionary = {}
var _get_save_id: Callable = Callable()
var _irc_config: Dictionary = {}

func get_desk_counter() -> int:
	return _desk_counter

func get_max_desks_per_workspace() -> int:
	return _MAX_DESKS_PER_WORKSPACE

func get_standing_desk_footprint_size_xz(yaw: float) -> Vector2:
	return _desk_footprint_size_xz(yaw)

func list_desks() -> Array:
	return _desks.duplicate(true)

func list_desks_for_workspace(workspace_id: String) -> Array:
	var wid := workspace_id.strip_edges()
	var out: Array = []
	for d0 in _desks:
		var d := d0 as Dictionary
		if d == null:
			continue
		if String(d.get("workspace_id", "")).strip_edges() == wid:
			out.append(d.duplicate(true))
	return out

func list_desk_irc_snapshots() -> Array:
	var out: Array = []
	if _is_headless.is_valid() and bool(_is_headless.call()):
		return out
	for d0 in _desks:
		var d := d0 as Dictionary
		if d == null:
			continue
		var did := String(d.get("id", "")).strip_edges()
		var wid := String(d.get("workspace_id", "")).strip_edges()
		var snap := {
			"desk_id": did,
			"workspace_id": wid,
			"desired_channel": "",
			"status": "no_node",
			"ready": false,
			"log_lines": [],
		}
		if did != "" and _nodes_by_id.has(did):
			var n0: Variant = _nodes_by_id.get(did)
			var node := n0 as Node
			if node != null:
				var link := node.get_node_or_null("DeskIrcLink") as Node
				if link != null and link.has_method("get_debug_snapshot"):
					var l0: Variant = link.call("get_debug_snapshot")
					if typeof(l0) == TYPE_DICTIONARY:
						var l := l0 as Dictionary
						snap["desired_channel"] = String(l.get("desired_channel", ""))
						snap["status"] = String(l.get("status", ""))
						snap["ready"] = bool(l.get("ready", false))
						snap["log_lines"] = l.get("log_lines", [])
				elif link != null:
					if link.has_method("get_status"):
						snap["status"] = String(link.call("get_status"))
					if link.has_method("is_ready"):
						snap["ready"] = bool(link.call("is_ready"))
					if link.has_method("get_desired_channel"):
						snap["desired_channel"] = String(link.call("get_desired_channel"))
		out.append(snap)
	return out

func bind_scene(root: Node3D, desk_scene: PackedScene, is_headless: Callable, get_save_id: Callable = Callable()) -> void:
	_root = root
	_desk_scene = desk_scene
	_is_headless = is_headless
	_get_save_id = get_save_id
	_rebuild_nodes()

func set_irc_config(config: Dictionary) -> void:
	_irc_config = config if config != null else {}
	_refresh_irc_links()

func can_place_standing_desk(workspace_id: String, workspace_rect_xz: Rect2, center_xz: Vector2, yaw: float) -> Dictionary:
	var wid := workspace_id.strip_edges()
	if wid == "":
		return {"ok": false, "reason": "empty_workspace_id"}

	var max_per_ws := _MAX_DESKS_PER_WORKSPACE
	if _count_for_workspace(wid) >= max_per_ws:
		return {"ok": false, "reason": "too_many_desks", "limit": max_per_ws}

	# Workspace too small for a single desk.
	var min_size := _desk_footprint_size_xz(yaw)
	if workspace_rect_xz.size.x + 1e-4 < min_size.x or workspace_rect_xz.size.y + 1e-4 < min_size.y:
		return {"ok": false, "reason": "workspace_too_small"}

	var footprint := _footprint_rect_xz(center_xz, yaw)
	if not _rect_contains_rect(workspace_rect_xz, footprint):
		return {"ok": false, "reason": "out_of_bounds"}

	if _overlaps_existing(wid, footprint):
		return {"ok": false, "reason": "overlap"}

	return {"ok": true}

func add_standing_desk(workspace_id: String, workspace_rect_xz: Rect2, pos: Vector3, yaw: float) -> Dictionary:
	var wid := workspace_id.strip_edges()
	if wid == "":
		return {"ok": false, "reason": "empty_workspace_id"}

	var yaw0 := _snap_yaw(yaw)
	var center_xz := Vector2(float(pos.x), float(pos.z))
	var can: Dictionary = can_place_standing_desk(wid, workspace_rect_xz, center_xz, yaw0)
	if not bool(can.get("ok", false)):
		return can

	_desk_counter += 1
	var desk_id := "desk_%d" % _desk_counter
	var footprint := _footprint_rect_xz(center_xz, yaw0)
	var d := {
		"id": desk_id,
		"workspace_id": wid,
		"kind": DESK_KIND_STANDING,
		"pos": [pos.x, pos.y, pos.z],
		"yaw": yaw0,
		"rect_xz": footprint,
	}
	_desks.append(d)
	_spawn_node_for(d)
	return {"ok": true, "desk": d}

func delete_desks_for_workspace(workspace_id: String) -> int:
	var wid := workspace_id.strip_edges()
	if wid == "":
		return 0

	var kept: Array[Dictionary] = []
	var removed_ids: Array[String] = []
	for d0 in _desks:
		var d := d0 as Dictionary
		if d == null:
			continue
		var dwid := String(d.get("workspace_id", "")).strip_edges()
		if dwid == wid:
			removed_ids.append(String(d.get("id", "")).strip_edges())
		else:
			kept.append(d)
	_desks = kept

	for id0 in removed_ids:
		_free_node_for_id(id0)

	return removed_ids.size()

func to_state_array() -> Array:
	var arr: Array = []
	for d0 in _desks:
		var d := d0 as Dictionary
		if d == null:
			continue
		var pos0: Variant = d.get("pos")
		if not (pos0 is Array):
			continue
		var p := pos0 as Array
		if p.size() != 3:
			continue
		arr.append({
			"id": String(d.get("id", "")),
			"workspace_id": String(d.get("workspace_id", "")),
			"kind": String(d.get("kind", DESK_KIND_STANDING)),
			"pos": [float(p[0]), float(p[1]), float(p[2])],
			"yaw": float(d.get("yaw", 0.0)),
		})
	return arr

func load_from_state_dict(state: Dictionary) -> void:
	_desks.clear()
	_nodes_by_id.clear()
	_desk_counter = int(state.get("desk_counter", 0))

	var desks0: Variant = state.get("desks", [])
	if not (desks0 is Array):
		_rebuild_nodes()
		return
	for e0 in desks0 as Array:
		if typeof(e0) != TYPE_DICTIONARY:
			continue
		var e := e0 as Dictionary
		var pos0: Variant = e.get("pos")
		if not (pos0 is Array):
			continue
		var p := pos0 as Array
		if p.size() != 3:
			continue
		var pos := Vector3(float(p[0]), float(p[1]), float(p[2]))
		var yaw := _snap_yaw(float(e.get("yaw", 0.0)))
		var center_xz := Vector2(float(pos.x), float(pos.z))
		var footprint := _footprint_rect_xz(center_xz, yaw)
		var d := {
			"id": String(e.get("id", "")),
			"workspace_id": String(e.get("workspace_id", "")),
			"kind": String(e.get("kind", DESK_KIND_STANDING)),
			"pos": [pos.x, pos.y, pos.z],
			"yaw": yaw,
			"rect_xz": footprint,
		}
		if String(d.get("id", "")).strip_edges() == "":
			continue
		_desks.append(d)

	_rebuild_nodes()

func _count_for_workspace(workspace_id: String) -> int:
	var wid := workspace_id.strip_edges()
	var n := 0
	for d0 in _desks:
		var d := d0 as Dictionary
		if d == null:
			continue
		if String(d.get("workspace_id", "")).strip_edges() == wid:
			n += 1
	return n

func _desk_footprint_size_xz(yaw: float) -> Vector2:
	var s := _DEFAULT_FOOTPRINT_XZ
	var snap := _snap_yaw(yaw)
	# 90° and 270° swap X/Z.
	if absf(snap - PI * 0.5) < 1e-3 or absf(snap - PI * 1.5) < 1e-3:
		return Vector2(s.y, s.x)
	return s

func _footprint_rect_xz(center_xz: Vector2, yaw: float) -> Rect2:
	var size := _desk_footprint_size_xz(yaw)
	var pos := center_xz - size * 0.5
	return Rect2(pos, size)

func _overlaps_existing(workspace_id: String, rect_xz: Rect2) -> bool:
	var wid := workspace_id.strip_edges()
	for d0 in _desks:
		var d := d0 as Dictionary
		if d == null:
			continue
		if String(d.get("workspace_id", "")).strip_edges() != wid:
			continue
		var r0: Variant = d.get("rect_xz")
		if not (r0 is Rect2):
			continue
		if _rects_overlap_exclusive(rect_xz, r0 as Rect2):
			return true
	return false

static func _rects_overlap_exclusive(a: Rect2, b: Rect2) -> bool:
	# Border-touch is allowed: treat borders as non-overlapping.
	var ax0 := float(a.position.x)
	var az0 := float(a.position.y)
	var ax1 := float(a.position.x + a.size.x)
	var az1 := float(a.position.y + a.size.y)

	var bx0 := float(b.position.x)
	var bz0 := float(b.position.y)
	var bx1 := float(b.position.x + b.size.x)
	var bz1 := float(b.position.y + b.size.y)

	return (ax0 < bx1) and (ax1 > bx0) and (az0 < bz1) and (az1 > bz0)

static func _rect_contains_rect(outer: Rect2, inner: Rect2) -> bool:
	var ox0 := float(outer.position.x)
	var oz0 := float(outer.position.y)
	var ox1 := float(outer.position.x + outer.size.x)
	var oz1 := float(outer.position.y + outer.size.y)

	var ix0 := float(inner.position.x)
	var iz0 := float(inner.position.y)
	var ix1 := float(inner.position.x + inner.size.x)
	var iz1 := float(inner.position.y + inner.size.y)

	return ix0 >= ox0 - 1e-4 and iz0 >= oz0 - 1e-4 and ix1 <= ox1 + 1e-4 and iz1 <= oz1 + 1e-4

static func _snap_yaw(yaw: float) -> float:
	# Snap to 0/90/180/270.
	var step := PI * 0.5
	var k := int(round(yaw / step))
	return float(posmod(k, 4)) * step

func _rebuild_nodes() -> void:
	_nodes_by_id.clear()
	if _root == null or _desk_scene == null:
		return
	if _is_headless.is_valid() and bool(_is_headless.call()):
		return

	for c0 in _root.get_children():
		var c := c0 as Node
		if c != null:
			c.queue_free()

	for d in _desks:
		_spawn_node_for(d)

func _spawn_node_for(desk: Dictionary) -> void:
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

	_maybe_attach_irc_link(n, desk)
	_nodes_by_id[did] = n

func _maybe_attach_irc_link(desk_node: Node3D, desk: Dictionary) -> void:
	if desk_node == null:
		return
	if _irc_config.is_empty() or not bool(_irc_config.get("enabled", false)):
		return
	if desk == null:
		return
	var desk_id := String(desk.get("id", "")).strip_edges()
	if desk_id == "":
		return
	var workspace_id := String(desk.get("workspace_id", "")).strip_edges()

	var sid := ""
	if _get_save_id.is_valid():
		sid = String(_get_save_id.call()).strip_edges()
	if sid == "":
		sid = "slot1"

	var link := _DeskIrcLinkScript.new() as Node
	if link == null:
		return
	link.name = "DeskIrcLink"
	desk_node.add_child(link)
	if link.has_method("configure"):
		link.call("configure", _irc_config, sid, workspace_id, desk_id)

func _refresh_irc_links() -> void:
	if _is_headless.is_valid() and bool(_is_headless.call()):
		return
	for d0 in _desks:
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
		var enabled := bool(_irc_config.get("enabled", false))
		if not enabled:
			if link != null:
				link.queue_free()
			continue

		if link == null:
			_maybe_attach_irc_link(desk_node, d)
		elif link.has_method("configure"):
			var sid := ""
			if _get_save_id.is_valid():
				sid = String(_get_save_id.call()).strip_edges()
			if sid == "":
				sid = "slot1"
			link.call("configure", _irc_config, sid, String(d.get("workspace_id", "")), did)

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
