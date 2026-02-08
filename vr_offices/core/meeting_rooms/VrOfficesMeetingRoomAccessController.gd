extends Node

var npc_root: Node3D = null
var meeting_room_manager: RefCounted = null
var participation: RefCounted = null

var _tick_left := 0.0
var _occupants_by_room_id: Dictionary = {}

func bind(npc_root_in: Node3D, meeting_room_manager_in: RefCounted, participation_in: RefCounted) -> void:
	npc_root = npc_root_in
	meeting_room_manager = meeting_room_manager_in
	participation = participation_in

func get_occupant_ids(meeting_room_id: String) -> Array[String]:
	var rid := meeting_room_id.strip_edges()
	if rid == "" or not _occupants_by_room_id.has(rid):
		return []
	var arr0: Variant = _occupants_by_room_id.get(rid, [])
	return arr0 as Array[String] if typeof(arr0) == TYPE_ARRAY else []

func _physics_process(delta: float) -> void:
	_tick_left = maxf(0.0, _tick_left - delta)
	if _tick_left > 0.0:
		return
	_tick_left = 0.18
	_enforce_once()

func _enforce_once() -> void:
	_occupants_by_room_id = {}
	if npc_root == null or meeting_room_manager == null:
		return
	if not meeting_room_manager.has_method("list_meeting_rooms"):
		return

	var rooms0: Variant = meeting_room_manager.call("list_meeting_rooms")
	if typeof(rooms0) != TYPE_ARRAY:
		return
	var rooms := rooms0 as Array
	if rooms.is_empty():
		return

	var room_rects: Array[Dictionary] = []
	for r0 in rooms:
		if typeof(r0) != TYPE_DICTIONARY:
			continue
		var r := r0 as Dictionary
		var rid := String(r.get("id", "")).strip_edges()
		if rid == "":
			continue
		var rect0: Variant = r.get("rect_xz")
		if not (rect0 is Rect2):
			continue
		room_rects.append({"id": rid, "rect": rect0 as Rect2})

	if room_rects.is_empty():
		return

	for c0 in npc_root.get_children():
		var npc := c0 as Node
		if npc == null or not is_instance_valid(npc) or not (npc is Node3D):
			continue
		var pos := (npc as Node3D).global_position
		var xz := Vector2(pos.x, pos.z)
		var found_rid := ""
		var found_rect := Rect2()
		for rr0 in room_rects:
			var rid0 := String(rr0.get("id", "")).strip_edges()
			var rect: Rect2 = rr0.get("rect") as Rect2
			if rid0 != "" and rect.has_point(xz):
				found_rid = rid0
				found_rect = rect
				break
		if found_rid == "":
			continue

		var nid := _npc_id_for_node(npc)
		if nid != "":
			if not _occupants_by_room_id.has(found_rid):
				_occupants_by_room_id[found_rid] = [] as Array[String]
			var arr := _occupants_by_room_id[found_rid] as Array[String]
			arr.append(nid)
			_occupants_by_room_id[found_rid] = arr

		var allowed := false
		if participation != null and participation.has_method("is_npc_allowed_in_room"):
			allowed = bool(participation.call("is_npc_allowed_in_room", found_rid, npc))
		if allowed:
			continue

		if npc.has_method("command_move_to"):
			var out_xz := _eject_point(found_rect, xz, 0.55)
			npc.call("command_move_to", Vector3(out_xz.x, 0.0, out_xz.y))

static func _npc_id_for_node(npc: Node) -> String:
	if npc == null:
		return ""
	if npc.has_method("get"):
		var v: Variant = npc.get("npc_id")
		if v != null:
			return String(v).strip_edges()
	return npc.name

static func _eject_point(rect: Rect2, point_xz: Vector2, pad: float) -> Vector2:
	var x := float(point_xz.x)
	var z := float(point_xz.y)
	var min_x := float(rect.position.x)
	var max_x := float(rect.position.x + rect.size.x)
	var min_z := float(rect.position.y)
	var max_z := float(rect.position.y + rect.size.y)

	var d_left := x - min_x
	var d_right := max_x - x
	var d_bottom := z - min_z
	var d_top := max_z - z

	var best := d_left
	var side := "left"
	if d_right < best:
		best = d_right
		side = "right"
	if d_bottom < best:
		best = d_bottom
		side = "bottom"
	if d_top < best:
		side = "top"

	if side == "left":
		return Vector2(min_x - pad, clampf(z, min_z, max_z))
	if side == "right":
		return Vector2(max_x + pad, clampf(z, min_z, max_z))
	if side == "bottom":
		return Vector2(clampf(x, min_x, max_x), min_z - pad)
	return Vector2(clampf(x, min_x, max_x), max_z + pad)
