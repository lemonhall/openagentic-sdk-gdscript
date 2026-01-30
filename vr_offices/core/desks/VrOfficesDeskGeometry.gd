extends RefCounted

const DEFAULT_FOOTPRINT_XZ := Vector2(1.755, 0.975) # X,Z meters (approx; tweak later)

static func snap_yaw(yaw: float) -> float:
	# Snap to 0/90/180/270.
	var step := PI * 0.5
	var k := int(round(yaw / step))
	return float(posmod(k, 4)) * step

static func standing_desk_footprint_size_xz(yaw: float, base_size_xz: Vector2 = DEFAULT_FOOTPRINT_XZ) -> Vector2:
	var snap := snap_yaw(yaw)
	# 90° and 270° swap X/Z.
	if absf(snap - PI * 0.5) < 1e-3 or absf(snap - PI * 1.5) < 1e-3:
		return Vector2(base_size_xz.y, base_size_xz.x)
	return base_size_xz

static func footprint_rect_xz(center_xz: Vector2, yaw: float, base_size_xz: Vector2 = DEFAULT_FOOTPRINT_XZ) -> Rect2:
	var size := standing_desk_footprint_size_xz(yaw, base_size_xz)
	var pos := center_xz - size * 0.5
	return Rect2(pos, size)

static func rects_overlap_exclusive(a: Rect2, b: Rect2) -> bool:
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

static func rect_contains_rect(outer: Rect2, inner: Rect2) -> bool:
	var ox0 := float(outer.position.x)
	var oz0 := float(outer.position.y)
	var ox1 := float(outer.position.x + outer.size.x)
	var oz1 := float(outer.position.y + outer.size.y)

	var ix0 := float(inner.position.x)
	var iz0 := float(inner.position.y)
	var ix1 := float(inner.position.x + inner.size.x)
	var iz1 := float(inner.position.y + inner.size.y)

	return ix0 >= ox0 - 1e-4 and iz0 >= oz0 - 1e-4 and ix1 <= ox1 + 1e-4 and iz1 <= oz1 + 1e-4

