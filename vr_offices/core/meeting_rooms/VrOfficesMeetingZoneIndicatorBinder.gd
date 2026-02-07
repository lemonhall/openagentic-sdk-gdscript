extends RefCounted

const _Meeting := preload("res://vr_offices/core/meeting_rooms/VrOfficesMeetingConstants.gd")
const _IndicatorScene := preload("res://vr_offices/fx/MeetingZoneIndicator.tscn")

static func ensure_for_table(decor: Node3D, table_wrap: Node3D) -> void:
	if decor == null or table_wrap == null:
		return

	var table_body := table_wrap.get_node_or_null("TableCollision") as StaticBody3D
	var shape_node := table_body.get_node_or_null("Shape") as CollisionShape3D if table_body != null else null
	if shape_node == null or not (shape_node.shape is BoxShape3D):
		return
	var box := shape_node.shape as BoxShape3D

	# Use world meters for the shader so the highlight matches the gameplay radius.
	var sc := table_body.global_transform.basis.get_scale() if table_body != null else table_wrap.global_transform.basis.get_scale()
	var hx := float(box.size.x) * 0.5 * absf(float(sc.x))
	var hz := float(box.size.z) * 0.5 * absf(float(sc.z))
	var half_extents_m := Vector2(maxf(0.05, hx), maxf(0.05, hz))

	var n := decor.get_node_or_null("MeetingZoneIndicator") as Node3D
	if n == null:
		if _IndicatorScene == null:
			return
		var inst0 := _IndicatorScene.instantiate()
		n = inst0 as Node3D
		if n == null:
			return
		n.name = "MeetingZoneIndicator"
		decor.add_child(n)

	# Place at table center; copy yaw but never inherit scale.
	var basis := Basis(table_wrap.global_transform.basis.get_rotation_quaternion())
	var pos := table_wrap.global_position
	n.global_transform = Transform3D(basis, Vector3(pos.x, 0.03, pos.z))
	n.scale = Vector3.ONE

	if n.has_method("configure"):
		n.call("configure", half_extents_m, float(_Meeting.ENTER_RADIUS_M))

