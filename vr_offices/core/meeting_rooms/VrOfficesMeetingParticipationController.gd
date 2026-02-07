extends RefCounted

var owner: Node = null
var npc_root: Node3D = null
var meeting_rooms_root: Node3D = null
var meeting_room_manager: RefCounted = null
var channel_hub: RefCounted = null
var _pending_room_by_npc_id: Dictionary = {}
var _pending_target_by_npc_id: Dictionary = {}

func _init(
	owner_in: Node,
	npc_root_in: Node3D,
	meeting_rooms_root_in: Node3D,
	meeting_room_manager_in: RefCounted,
	channel_hub_in: RefCounted = null
) -> void:
	owner = owner_in
	npc_root = npc_root_in
	meeting_rooms_root = meeting_rooms_root_in
	meeting_room_manager = meeting_room_manager_in
	channel_hub = channel_hub_in

	if npc_root != null:
		npc_root.child_entered_tree.connect(_on_npc_child_entered_tree)
		npc_root.child_exiting_tree.connect(_on_npc_child_exiting_tree)
		for c0 in npc_root.get_children():
			var c := c0 as Node
			if c != null:
				_try_connect_npc(c)

	if meeting_rooms_root != null:
		meeting_rooms_root.child_exiting_tree.connect(_on_meeting_room_child_exiting_tree)

func invite_npc_to_meeting_room(meeting_room_id: String, npc: Node) -> Vector3:
	var rid := meeting_room_id.strip_edges()
	if rid == "" or npc == null or not is_instance_valid(npc):
		return Vector3.ZERO
	var nid := _npc_id_for_node(npc)
	if nid == "":
		return Vector3.ZERO

	# If the NPC is already bound to a different meeting room, leave it immediately.
	if npc.has_method("get_bound_meeting_room_id") and npc.has_method("on_meeting_unbound"):
		var cur := String(npc.call("get_bound_meeting_room_id")).strip_edges()
		if cur != "" and cur != rid:
			if channel_hub != null and channel_hub.has_method("part_participant"):
				channel_hub.call("part_participant", cur, nid)
			npc.call("on_meeting_unbound", cur)

	var target := _pick_target_for_room(rid, nid)
	if target == Vector3.ZERO:
		return Vector3.ZERO
	_pending_room_by_npc_id[nid] = rid
	_pending_target_by_npc_id[nid] = target
	if npc.has_method("command_move_to"):
		npc.call("command_move_to", target)
	return target

func uninvite_npc_from_meeting_room(npc: Node) -> void:
	if npc == null or not is_instance_valid(npc):
		return
	var nid := _npc_id_for_node(npc)
	if nid != "":
		_pending_room_by_npc_id.erase(nid)
		_pending_target_by_npc_id.erase(nid)
	if not npc.has_method("get_bound_meeting_room_id") or not npc.has_method("on_meeting_unbound"):
		return
	var rid := String(npc.call("get_bound_meeting_room_id")).strip_edges()
	if rid == "":
		return
	if channel_hub != null and channel_hub.has_method("part_participant"):
		channel_hub.call("part_participant", rid, nid)
	npc.call("on_meeting_unbound", rid)

func _on_npc_child_entered_tree(n: Node) -> void:
	_try_connect_npc(n)

func _on_npc_child_exiting_tree(n: Node) -> void:
	# Clear meeting state when NPC is removed.
	if n == null:
		return
	if n.has_method("get_bound_meeting_room_id") and n.has_method("on_meeting_unbound"):
		var cur := String(n.call("get_bound_meeting_room_id")).strip_edges()
		if cur != "":
			if channel_hub != null and channel_hub.has_method("part_participant"):
				channel_hub.call("part_participant", cur, _npc_id_for_node(n))
			n.call("on_meeting_unbound", cur)

func _on_meeting_room_child_exiting_tree(n: Node) -> void:
	if n == null or not n.is_in_group("vr_offices_meeting_room"):
		return
	var rid := String(n.name).strip_edges()
	if n.has_method("get"):
		var v: Variant = n.get("meeting_room_id")
		if v != null and String(v).strip_edges() != "":
			rid = String(v).strip_edges()
	if rid == "":
		return
	_unbind_all_from_room(rid)

func _try_connect_npc(n: Node) -> void:
	if n == null or not is_instance_valid(n):
		return
	if not n.has_signal("move_target_reached"):
		return
	var cb := Callable(self, "_on_npc_move_target_reached").bind(n)
	if not n.is_connected("move_target_reached", cb):
		n.connect("move_target_reached", cb)

func _on_npc_move_target_reached(_npc_id: String, target: Vector3, npc: Node) -> void:
	if npc == null or not is_instance_valid(npc):
		return
	var nid := _npc_id_for_node(npc)
	if nid == "":
		nid = _npc_id.strip_edges()
	if nid == "":
		return
	var rid0: Variant = _pending_room_by_npc_id.get(nid, "")
	var rid := String(rid0).strip_edges()
	if rid == "":
		return

	_pending_room_by_npc_id.erase(nid)
	_pending_target_by_npc_id.erase(nid)

	if npc.has_method("on_meeting_bound"):
		npc.call("on_meeting_bound", rid)
	if channel_hub != null and channel_hub.has_method("join_participant"):
		channel_hub.call("join_participant", rid, npc)

func _pick_target_for_room(meeting_room_id: String, npc_id: String) -> Vector3:
	if meeting_room_manager == null or not meeting_room_manager.has_method("get_meeting_room_node"):
		return Vector3.ZERO
	var room := meeting_room_manager.call("get_meeting_room_node", meeting_room_id) as Node
	if room == null or not is_instance_valid(room):
		return Vector3.ZERO
	var table := room.get_node_or_null("Decor/Table") as Node3D
	var base := Vector3.ZERO
	if table != null:
		base = table.global_position
	elif room is Node3D:
		base = (room as Node3D).global_position
	if base == Vector3.ZERO:
		return Vector3.ZERO

	var h: int = int(abs(int(npc_id.hash())))
	var angle_steps := 8
	var ang := float(h % angle_steps) * (TAU / float(angle_steps))
	var radius := 1.25 + float((h / 13) % 3) * 0.15
	var p := base + Vector3(cos(ang) * radius, 0.0, sin(ang) * radius)

	# Clamp to room rect when available (keeps targets inside walls).
	if meeting_room_manager != null and meeting_room_manager.has_method("get_meeting_room_rect_xz"):
		var rect0: Variant = meeting_room_manager.call("get_meeting_room_rect_xz", meeting_room_id)
		var rect: Rect2 = rect0 as Rect2 if rect0 is Rect2 else Rect2()
		if rect.size != Vector2.ZERO:
			var pad := 0.35
			var min_x := float(rect.position.x + pad)
			var max_x := float(rect.position.x + rect.size.x - pad)
			var min_z := float(rect.position.y + pad)
			var max_z := float(rect.position.y + rect.size.y - pad)
			p.x = clampf(p.x, min_x, max_x)
			p.z = clampf(p.z, min_z, max_z)
	return p

func _unbind_all_from_room(meeting_room_id: String) -> void:
	if npc_root == null:
		return
	var rid := meeting_room_id.strip_edges()
	if rid == "":
		return
	for c0 in npc_root.get_children():
		var npc := c0 as Node
		if npc == null:
			continue
		if npc.has_method("get_bound_meeting_room_id") and npc.has_method("on_meeting_unbound"):
			var cur := String(npc.call("get_bound_meeting_room_id")).strip_edges()
			if cur == rid:
				if channel_hub != null and channel_hub.has_method("part_participant"):
					channel_hub.call("part_participant", rid, _npc_id_for_node(npc))
				npc.call("on_meeting_unbound", rid)
		var nid := _npc_id_for_node(npc)
		if nid != "" and String(_pending_room_by_npc_id.get(nid, "")).strip_edges() == rid:
			_pending_room_by_npc_id.erase(nid)
			_pending_target_by_npc_id.erase(nid)

func _npc_id_for_node(npc: Node) -> String:
	if npc == null:
		return ""
	if npc.has_method("get"):
		var v: Variant = npc.get("npc_id")
		if v != null:
			return String(v).strip_edges()
	return npc.name
