extends RefCounted

const DESK_KIND_STANDING := "standing_desk"

const _Geom := preload("res://vr_offices/core/desks/VrOfficesDeskGeometry.gd")

const _MAX_DESKS_PER_WORKSPACE := 3

var _desk_counter := 0
var _desks: Array[Dictionary] = []

func get_desk_counter() -> int:
	return _desk_counter

func get_max_desks_per_workspace() -> int:
	return _MAX_DESKS_PER_WORKSPACE

func get_standing_desk_footprint_size_xz(yaw: float) -> Vector2:
	return _Geom.standing_desk_footprint_size_xz(yaw)

func list_desks() -> Array:
	return _desks.duplicate(true)

func list_desks_ref() -> Array[Dictionary]:
	return _desks

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

func can_place_standing_desk(workspace_id: String, workspace_rect_xz: Rect2, center_xz: Vector2, yaw: float) -> Dictionary:
	var wid := workspace_id.strip_edges()
	if wid == "":
		return {"ok": false, "reason": "empty_workspace_id"}

	var max_per_ws := _MAX_DESKS_PER_WORKSPACE
	if _count_for_workspace(wid) >= max_per_ws:
		return {"ok": false, "reason": "too_many_desks", "limit": max_per_ws}

	# Workspace too small for a single desk.
	var min_size := _Geom.standing_desk_footprint_size_xz(yaw)
	if workspace_rect_xz.size.x + 1e-4 < min_size.x or workspace_rect_xz.size.y + 1e-4 < min_size.y:
		return {"ok": false, "reason": "workspace_too_small"}

	var footprint := _Geom.footprint_rect_xz(center_xz, yaw)
	if not _Geom.rect_contains_rect(workspace_rect_xz, footprint):
		return {"ok": false, "reason": "out_of_bounds"}

	if _overlaps_existing(wid, footprint):
		return {"ok": false, "reason": "overlap"}

	return {"ok": true}

func add_standing_desk(workspace_id: String, workspace_rect_xz: Rect2, pos: Vector3, yaw: float) -> Dictionary:
	var wid := workspace_id.strip_edges()
	if wid == "":
		return {"ok": false, "reason": "empty_workspace_id"}

	var yaw0 := _Geom.snap_yaw(yaw)
	var center_xz := Vector2(float(pos.x), float(pos.z))
	var can: Dictionary = can_place_standing_desk(wid, workspace_rect_xz, center_xz, yaw0)
	if not bool(can.get("ok", false)):
		return can

	_desk_counter += 1
	var desk_id := "desk_%d" % _desk_counter
	var footprint := _Geom.footprint_rect_xz(center_xz, yaw0)
	var d := {
		"id": desk_id,
		"workspace_id": wid,
		"kind": DESK_KIND_STANDING,
		"pos": [pos.x, pos.y, pos.z],
		"yaw": yaw0,
		"rect_xz": footprint,
	}
	_desks.append(d)
	return {"ok": true, "desk": d}

func delete_desks_for_workspace(workspace_id: String) -> Array[String]:
	var wid := workspace_id.strip_edges()
	if wid == "":
		return []

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
	return removed_ids

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
	_desk_counter = int(state.get("desk_counter", 0))

	var desks0: Variant = state.get("desks", [])
	if not (desks0 is Array):
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
		var yaw := _Geom.snap_yaw(float(e.get("yaw", 0.0)))
		var center_xz := Vector2(float(pos.x), float(pos.z))
		var footprint := _Geom.footprint_rect_xz(center_xz, yaw)
		var d := {
			"id": String(e.get("id", "")).strip_edges(),
			"workspace_id": String(e.get("workspace_id", "")).strip_edges(),
			"kind": String(e.get("kind", DESK_KIND_STANDING)),
			"pos": [pos.x, pos.y, pos.z],
			"yaw": yaw,
			"rect_xz": footprint,
		}
		if String(d.get("id", "")).strip_edges() == "":
			continue
		_desks.append(d)

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
		if _Geom.rects_overlap_exclusive(rect_xz, r0 as Rect2):
			return true
	return false

