extends RefCounted

const _Palette := preload("res://vr_offices/core/workspaces/VrOfficesWorkspacePalette.gd")

var floor_bounds_xz: Rect2

var _meeting_room_counter := 0
var _meeting_rooms: Array[Dictionary] = []

func _init(bounds_xz: Rect2) -> void:
	floor_bounds_xz = bounds_xz

func get_meeting_room_counter() -> int:
	return _meeting_room_counter

func list_meeting_rooms() -> Array:
	return _meeting_rooms.duplicate(true)

func list_meeting_rooms_ref() -> Array[Dictionary]:
	return _meeting_rooms

func get_meeting_room(meeting_room_id: String) -> Dictionary:
	var rid := meeting_room_id.strip_edges()
	if rid == "":
		return {}
	for r0 in _meeting_rooms:
		var r := r0 as Dictionary
		if r == null:
			continue
		if String(r.get("id", "")) == rid:
			return r.duplicate(true)
	return {}

func get_meeting_room_rect_xz(meeting_room_id: String) -> Rect2:
	var r := get_meeting_room(meeting_room_id)
	var v0: Variant = r.get("rect_xz")
	return v0 as Rect2 if (v0 is Rect2) else Rect2()

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

func create_meeting_room(rect_xz: Rect2, name: String) -> Dictionary:
	var r := clamp_rect_to_floor(rect_xz)
	if r.size.x <= 0.001 or r.size.y <= 0.001:
		return {"ok": false, "reason": "rect_too_small"}
	if _overlaps_any(r):
		return {"ok": false, "reason": "overlap"}

	_meeting_room_counter += 1
	var color_index := (_meeting_room_counter - 1) % _Palette.PASTEL_COLORS.size()
	var room := {
		"id": "mr_%d" % _meeting_room_counter,
		"name": name.strip_edges(),
		"rect_xz": r,
		"color_index": color_index,
	}
	_meeting_rooms.append(room)
	return {"ok": true, "meeting_room": room}

func delete_meeting_room(meeting_room_id: String) -> Dictionary:
	var rid := meeting_room_id.strip_edges()
	if rid == "":
		return {"ok": false, "reason": "empty_id"}
	var idx := -1
	for i in range(_meeting_rooms.size()):
		var r0 := _meeting_rooms[i]
		if typeof(r0) != TYPE_DICTIONARY:
			continue
		var r := r0 as Dictionary
		if String(r.get("id", "")) == rid:
			idx = i
			break
	if idx < 0:
		return {"ok": false, "reason": "not_found"}
	_meeting_rooms.remove_at(idx)
	return {"ok": true, "meeting_room_id": rid}

func to_state_array() -> Array:
	var arr: Array = []
	for r0 in _meeting_rooms:
		var r := r0 as Dictionary
		if r == null:
			continue
		var rect0: Variant = r.get("rect_xz")
		if not (rect0 is Rect2):
			continue
		var rr := rect0 as Rect2
		var min_x := float(rr.position.x)
		var min_z := float(rr.position.y)
		var max_x := float(rr.position.x + rr.size.x)
		var max_z := float(rr.position.y + rr.size.y)
		arr.append({
			"id": String(r.get("id", "")),
			"name": String(r.get("name", "")),
			"rect": [min_x, min_z, max_x, max_z],
			"color_index": int(r.get("color_index", 0)),
		})
	return arr

func load_from_state_dict(state: Dictionary) -> void:
	_meeting_rooms.clear()
	_meeting_room_counter = int(state.get("meeting_room_counter", 0))

	var rooms0: Variant = state.get("meeting_rooms", [])
	if not (rooms0 is Array):
		return
	var arr := rooms0 as Array
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
		var room := {
			"id": String(e.get("id", "")),
			"name": String(e.get("name", "")),
			"rect_xz": r,
			"color_index": int(e.get("color_index", 0)),
		}
		_meeting_rooms.append(room)

func _overlaps_any(r: Rect2) -> bool:
	for e0 in _meeting_rooms:
		var room := e0 as Dictionary
		if room == null:
			continue
		var rect0: Variant = room.get("rect_xz")
		if not (rect0 is Rect2):
			continue
		var o := rect0 as Rect2
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

