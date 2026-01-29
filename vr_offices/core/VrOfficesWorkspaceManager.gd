extends RefCounted

const PASTEL_COLORS: Array[Color] = [
	Color(0.98, 0.80, 0.82, 0.35), # pink
	Color(0.80, 0.92, 0.98, 0.35), # blue
	Color(0.86, 0.98, 0.84, 0.35), # mint
	Color(0.99, 0.93, 0.77, 0.35), # peach
	Color(0.88, 0.83, 0.98, 0.35), # lavender
	Color(0.82, 0.98, 0.96, 0.35), # aqua
]

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

func create_workspace(rect_xz: Rect2, name: String) -> Dictionary:
	var r := clamp_rect_to_floor(rect_xz)
	if r.size.x <= 0.001 or r.size.y <= 0.001:
		return {"ok": false, "reason": "rect_too_small"}
	if _overlaps_any(r):
		return {"ok": false, "reason": "overlap"}

	_workspace_counter += 1
	var color_index := (_workspace_counter - 1) % PASTEL_COLORS.size()
	var ws := {
		"id": "ws_%d" % _workspace_counter,
		"name": name.strip_edges(),
		"rect_xz": r,
		"color_index": color_index,
	}
	_workspaces.append(ws)
	return {"ok": true, "workspace": ws}

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

	return (ax0 < bx1) and (ax1 > bx0) and (az0 < bz1) and (az1 > bz0) and not (ax1 == bx0 or bx1 == ax0 or az1 == bz0 or bz1 == az0)

