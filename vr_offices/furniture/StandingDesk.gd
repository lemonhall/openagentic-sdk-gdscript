extends Node3D

@export var desk_id: String = ""
@export var workspace_id: String = ""
@export var kind: String = "standing_desk"
@export var device_code: String = ""

var _is_preview := false
var _preview_valid := true
var _preview_overlay: StandardMaterial3D = null
var _centered_once := false
@onready var _irc_indicator: Node3D = get_node_or_null("IrcIndicator") as Node3D
@onready var _npc_bind_indicator: Node3D = get_node_or_null("NpcBindIndicator") as Node3D

func _ready() -> void:
	add_to_group("vr_offices_desk")
	ensure_centered()

func configure(desk_id_in: String, workspace_id_in: String, device_code_in: String = "") -> void:
	desk_id = desk_id_in
	workspace_id = workspace_id_in
	device_code = device_code_in

func set_preview(enabled: bool) -> void:
	_is_preview = enabled
	if _irc_indicator != null and _irc_indicator.has_method("set_suspended"):
		_irc_indicator.call("set_suspended", _is_preview)
	if _npc_bind_indicator != null and _npc_bind_indicator.has_method("set_suspended"):
		_npc_bind_indicator.call("set_suspended", _is_preview)
	if not _is_preview:
		return
	ensure_centered()
	_apply_preview_visuals()

func set_preview_valid(is_valid: bool) -> void:
	_preview_valid = is_valid
	if _is_preview:
		_apply_preview_visuals()

func ensure_centered() -> void:
	if not is_inside_tree():
		return
	if _centered_once:
		return
	_centered_once = true

	var model := get_node_or_null("Model") as Node3D
	if model == null:
		return

	var bounds := _compute_visual_bounds_local(model)
	if bounds.size == Vector3.ZERO:
		return
	var center := bounds.position + bounds.size * 0.5
	# Center only on XZ so the desk still sits on the floor naturally.
	model.position -= Vector3(center.x, 0.0, center.z)

func _apply_preview_visuals() -> void:
	if _preview_overlay == null:
		_preview_overlay = StandardMaterial3D.new()
		_preview_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_preview_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_preview_overlay.emission_enabled = true
		_preview_overlay.emission_energy_multiplier = 1.25

	# Use a strong tint (but keep original textures visible) so "can place" is obvious.
	var tint := Color(0.25, 0.85, 1.0, 0.45)
	if not _preview_valid:
		tint = Color(1.0, 0.20, 0.20, 0.55)
	_preview_overlay.albedo_color = tint
	_preview_overlay.emission = Color(0.25, 0.90, 1.00, 1.0) if _preview_valid else Color(1.0, 0.15, 0.20, 1.0)
	_preview_overlay.emission_energy_multiplier = 1.25 if _preview_valid else 2.0

	var model := get_node_or_null("Model") as Node3D
	if model == null:
		return

	for n0: Node in _iter_descendants(model):
		if n0 is MeshInstance3D:
			var mi: MeshInstance3D = n0 as MeshInstance3D
			if mi != null:
				# Keep original textures/materials; apply a semi-transparent overlay + per-instance transparency.
				mi.transparency = 0.25
				mi.material_overlay = _preview_overlay
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func play_spawn_fx() -> void:
	# Simple "gamey" arrival: pop + drop.
	var final_pos := position
	var final_scale := scale

	position = final_pos + Vector3(0.0, 0.6, 0.0)
	scale = final_scale * 0.15

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "position", final_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", final_scale, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _iter_descendants(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back() as Node
		if n == null:
			continue
		for c0 in n.get_children():
			var c: Node = c0 as Node
			if c == null:
				continue
			out.append(c)
			stack.append(c)
	return out

func _compute_visual_bounds_local(root: Node) -> AABB:
	# Returns bounds in this node's local space, based on MeshInstance3D AABBs.
	var min_x := INF
	var min_y := INF
	var min_z := INF
	var max_x := -INF
	var max_y := -INF
	var max_z := -INF
	var any := false

	for n0: Node in _iter_descendants(root):
		if not (n0 is MeshInstance3D):
			continue
		var mi := n0 as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var aabb := mi.get_aabb()
		var corners := _aabb_corners(aabb)
		for p0 in corners:
			var p_world := mi.global_transform * p0
			var p_local := to_local(p_world)
			min_x = minf(min_x, float(p_local.x))
			min_y = minf(min_y, float(p_local.y))
			min_z = minf(min_z, float(p_local.z))
			max_x = maxf(max_x, float(p_local.x))
			max_y = maxf(max_y, float(p_local.y))
			max_z = maxf(max_z, float(p_local.z))
			any = true

	if not any:
		return AABB()
	return AABB(Vector3(min_x, min_y, min_z), Vector3(max_x - min_x, max_y - min_y, max_z - min_z))

static func _aabb_corners(aabb: AABB) -> Array[Vector3]:
	var p := aabb.position
	var s := aabb.size
	return [
		Vector3(p.x, p.y, p.z),
		Vector3(p.x + s.x, p.y, p.z),
		Vector3(p.x, p.y + s.y, p.z),
		Vector3(p.x, p.y, p.z + s.z),
		Vector3(p.x + s.x, p.y + s.y, p.z),
		Vector3(p.x + s.x, p.y, p.z + s.z),
		Vector3(p.x, p.y + s.y, p.z + s.z),
		Vector3(p.x + s.x, p.y + s.y, p.z + s.z),
	]
