extends RefCounted

const _ENTER_RADIUS_M := 2.0
const _EXIT_RADIUS_M := 2.2

var owner: Node = null
var npc_root: Node3D = null
var meeting_rooms_root: Node3D = null
var meeting_room_manager: RefCounted = null
var channel_hub: RefCounted = null

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
	if meeting_room_manager == null:
		return
	if not npc.has_method("get_bound_meeting_room_id"):
		return
	var cur_room := String(npc.call("get_bound_meeting_room_id")).strip_edges()

	var target_xz := Vector2(target.x, target.z)
	var best_room := ""
	var best_dist := 999999.0

	var rooms0: Variant = meeting_room_manager.call("list_meeting_rooms") if meeting_room_manager.has_method("list_meeting_rooms") else []
	var rooms: Array = rooms0 as Array if typeof(rooms0) == TYPE_ARRAY else []
	for r0 in rooms:
		if typeof(r0) != TYPE_DICTIONARY:
			continue
		var r: Dictionary = r0 as Dictionary
		var rid := String(r.get("id", "")).strip_edges()
		if rid == "":
			continue
		var anchor: Dictionary = _table_anchor_global(rid)
		if not bool(anchor.get("ok", false)):
			continue
		var a0: Variant = anchor.get("pos", null)
		if not (a0 is Vector3):
			continue
		var a := a0 as Vector3
		var d := target_xz.distance_to(Vector2(a.x, a.z))
		if d < best_dist:
			best_dist = d
			best_room = rid

	var want_room := best_room if best_dist <= _ENTER_RADIUS_M else ""
	if cur_room != "" and best_room == cur_room and best_dist <= _EXIT_RADIUS_M:
		want_room = cur_room

	if want_room == cur_room:
		return

	if cur_room != "" and npc.has_method("on_meeting_unbound"):
		if channel_hub != null and channel_hub.has_method("part_participant"):
			channel_hub.call("part_participant", cur_room, _npc_id_for_node(npc))
		npc.call("on_meeting_unbound", cur_room)
	if want_room != "" and npc.has_method("on_meeting_bound"):
		npc.call("on_meeting_bound", want_room)
		if channel_hub != null and channel_hub.has_method("join_participant"):
			channel_hub.call("join_participant", want_room, npc)

func _table_anchor_global(meeting_room_id: String) -> Dictionary:
	if meeting_room_manager == null or not meeting_room_manager.has_method("get_meeting_room_node"):
		return {"ok": false}
	var room := meeting_room_manager.call("get_meeting_room_node", meeting_room_id) as Node
	if room == null or not is_instance_valid(room):
		return {"ok": false}
	var table := room.get_node_or_null("Decor/Table") as Node3D
	if table != null:
		return {"ok": true, "pos": table.global_position}
	if room is Node3D:
		return {"ok": true, "pos": (room as Node3D).global_position}
	return {"ok": false}

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

func _npc_id_for_node(npc: Node) -> String:
	if npc == null:
		return ""
	if npc.has_method("get"):
		var v: Variant = npc.get("npc_id")
		if v != null:
			return String(v).strip_edges()
	return npc.name
