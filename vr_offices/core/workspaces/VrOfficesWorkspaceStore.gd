extends RefCounted

const _Palette := preload("res://vr_offices/core/workspaces/VrOfficesWorkspacePalette.gd")

var floor_bounds_xz: Rect2

var _workspace_counter := 0
var _workspaces: Array[Dictionary] = []

func _init(bounds_xz: Rect2) -> void:
	floor_bounds_xz = bounds_xz

func get_workspace_counter() -> int:
	return _workspace_counter

func list_workspaces() -> Array:
	# Intentionally untyped return for caller flexibility.
	return _workspaces.duplicate(true)

func list_workspaces_ref() -> Array[Dictionary]:
	return _workspaces

func get_workspace(workspace_id: String) -> Dictionary:
	var wid := workspace_id.strip_edges()
	if wid == "":
		return {}
	for ws0 in _workspaces:
		var ws := ws0 as Dictionary
		if ws == null:
			continue
		if String(ws.get("id", "")) == wid:
			return ws.duplicate(true)
	return {}

func get_workspace_rect_xz(workspace_id: String) -> Rect2:
	var ws := get_workspace(workspace_id)
	var r0: Variant = ws.get("rect_xz")
	return r0 as Rect2 if (r0 is Rect2) else Rect2()

func clamp_rect_to_floor(r: Rect2) -> Rect2:
	var min_x := float(floor_bounds_xz.position.x)
	var max_x := float(floor_bounds_xz.position.x + floor_bounds_xz.size.x)
	var min_z := float(floor_bounds_xz.position.y)
	var max_z := float(floor_bounds_xz.position.y + floor_bounds_xz.size.y)

	var x0 := clampf(float(r.position.x), min_x, max_x)
	var z0 := clampf(float(r.position.y), min_z, max_z)
	var x1 := clampf(float(r.position.x + r.size.x), min_x, max_x)
	var z1 := clampf(float(r.position.y + r.size.y), min_z, max_z)

	var minp := Vector2(minf(x0, x1), minf(z0, z1))
	var maxp := Vector2(maxf(x0, x1), maxf(z0, z1))
	return Rect2(minp, maxp - minp)

func can_place(rect_xz: Rect2) -> bool:
	var r := clamp_rect_to_floor(rect_xz)
	if r.size.x <= 0.001 or r.size.y <= 0.001:
		return false
	return not _overlaps_any(r)

func create_workspace(rect_xz: Rect2, name: String) -> Dictionary:
	var r := clamp_rect_to_floor(rect_xz)
	if r.size.x <= 0.001 or r.size.y <= 0.001:
		return {"ok": false, "reason": "rect_too_small"}
	if _overlaps_any(r):
		return {"ok": false, "reason": "overlap"}

	_workspace_counter += 1
	var color_index := (_workspace_counter - 1) % _Palette.PASTEL_COLORS.size()
	var ws := {
		"id": "ws_%d" % _workspace_counter,
		"name": name.strip_edges(),
		"rect_xz": r,
		"color_index": color_index,
	}
	_workspaces.append(ws)
	return {"ok": true, "workspace": ws}

func delete_workspace(workspace_id: String) -> Dictionary:
	var wid := workspace_id.strip_edges()
	if wid == "":
		return {"ok": false, "reason": "empty_id"}
	var idx := -1
	for i in range(_workspaces.size()):
		var ws0 := _workspaces[i]
		if typeof(ws0) != TYPE_DICTIONARY:
			continue
		var ws := ws0 as Dictionary
		if String(ws.get("id", "")) == wid:
			idx = i
			break
	if idx < 0:
		return {"ok": false, "reason": "not_found"}
	_workspaces.remove_at(idx)
	return {"ok": true, "workspace_id": wid}

func to_state_array() -> Array:
	var arr: Array = []
	for ws0 in _workspaces:
		var ws := ws0 as Dictionary
		if ws == null:
			continue
		var r0: Variant = ws.get("rect_xz")
		if not (r0 is Rect2):
			continue
		var r := r0 as Rect2
		var min_x := float(r.position.x)
		var min_z := float(r.position.y)
		var max_x := float(r.position.x + r.size.x)
		var max_z := float(r.position.y + r.size.y)
		arr.append({
			"id": String(ws.get("id", "")),
			"name": String(ws.get("name", "")),
			"rect": [min_x, min_z, max_x, max_z],
			"color_index": int(ws.get("color_index", 0)),
		})
	return arr

func load_from_state_dict(state: Dictionary) -> void:
	_workspaces.clear()
	_workspace_counter = int(state.get("workspace_counter", 0))

	var ws0: Variant = state.get("workspaces", [])
	if not (ws0 is Array):
		return
	var arr := ws0 as Array
	for e0 in arr:
		if typeof(e0) != TYPE_DICTIONARY:
			continue
		var e := e0 as Dictionary
		var rect0: Variant = e.get("rect")
		if not (rect0 is Array):
			continue
		var rr := rect0 as Array
		if rr.size() != 4:
			continue
		var min_x := float(rr[0])
		var min_z := float(rr[1])
		var max_x := float(rr[2])
		var max_z := float(rr[3])
		var r := Rect2(Vector2(min_x, min_z), Vector2(max_x - min_x, max_z - min_z))
		r = clamp_rect_to_floor(r)
		var ws := {
			"id": String(e.get("id", "")),
			"name": String(e.get("name", "")),
			"rect_xz": r,
			"color_index": int(e.get("color_index", 0)),
		}
		_workspaces.append(ws)

func _overlaps_any(r: Rect2) -> bool:
	for ws0 in _workspaces:
		var ws := ws0 as Dictionary
		if ws == null:
			continue
		var r0: Variant = ws.get("rect_xz")
		if not (r0 is Rect2):
			continue
		var o := r0 as Rect2
		if _rects_overlap_exclusive(r, o):
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

