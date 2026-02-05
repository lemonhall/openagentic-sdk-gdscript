extends PopupPanel
class_name VrOfficesTeachSkillPopup

const _Teacher := preload("res://vr_offices/core/skill_library/VrOfficesTeachSkillToNpc.gd")

@onready var prev_button: Button = %TeachPrevNpcButton
@onready var next_button: Button = %TeachNextNpcButton
@onready var npc_name_label: Label = %TeachNpcNameLabel
@onready var status_label: Label = %TeachStatusLabel
@onready var learn_button: Button = %TeachLearnButton
@onready var cancel_button: Button = %TeachCancelButton

@onready var preview_container: Control = %TeachPreviewContainer
@onready var preview_viewport: SubViewport = %TeachPreviewViewport
@onready var preview_root: Node3D = %TeachPreviewRoot
@onready var preview_camera: Camera3D = %TeachPreviewCamera

var _teacher: RefCounted = _Teacher.new()
var _save_id: String = ""
var _skill_name: String = ""
var _npcs: Array[Dictionary] = []
var _idx: int = 0
var _switch_tween: Tween = null

func _ready() -> void:
	if prev_button != null:
		prev_button.pressed.connect(func() -> void:
			_shift(-1)
		)
	if next_button != null:
		next_button.pressed.connect(func() -> void:
			_shift(1)
		)
	if learn_button != null:
		learn_button.pressed.connect(_on_learn_pressed)
	if cancel_button != null:
		cancel_button.pressed.connect(func() -> void:
			hide()
		)
	_update_preview_visibility()

func open_for_skill(save_id: String, skill_name: String, npcs: Array) -> void:
	_save_id = save_id.strip_edges()
	_skill_name = skill_name.strip_edges()
	_npcs = []
	for it0 in npcs:
		if typeof(it0) == TYPE_DICTIONARY:
			_npcs.append(it0 as Dictionary)
	_idx = 0
	_set_status("")
	_update_ui()
	popup_centered(Vector2i(720, 420))

func _shift(delta: int) -> void:
	if _npcs.is_empty():
		return
	if _npcs.size() <= 1:
		return
	if _is_headless() or preview_container == null or npc_name_label == null:
		_idx = (_idx + delta) % _npcs.size()
		if _idx < 0:
			_idx += _npcs.size()
		_update_ui()
		return
	if _switch_tween != null:
		return

	_set_nav_enabled(false)
	if preview_viewport != null:
		preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var next_idx := (_idx + delta) % _npcs.size()
	if next_idx < 0:
		next_idx += _npcs.size()

	_switch_tween = create_tween()
	_switch_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_switch_tween.tween_property(preview_container, "modulate:a", 0.0, 0.12)
	_switch_tween.parallel().tween_property(npc_name_label, "modulate:a", 0.0, 0.12)
	_switch_tween.tween_callback(func() -> void:
		_idx = next_idx
		_update_ui()
	)
	_switch_tween.tween_property(preview_container, "modulate:a", 1.0, 0.12)
	_switch_tween.parallel().tween_property(npc_name_label, "modulate:a", 1.0, 0.12)
	_switch_tween.finished.connect(func() -> void:
		_switch_tween = null
		if preview_viewport != null:
			preview_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		_set_nav_enabled(true)
	)

func _on_learn_pressed() -> void:
	if _save_id == "" or _skill_name == "":
		_set_status("Missing context.")
		return
	if _npcs.is_empty():
		_set_status("No active NPCs.")
		return
	var npc := _npcs[_idx]
	var nid := String(npc.get("npc_id", "")).strip_edges()
	if nid == "":
		_set_status("Missing npc_id.")
		return
	_set_status("Teaching…")
	var rr: Dictionary = _teacher.call("teach_shared_skill_to_npc", _save_id, nid, _skill_name)
	if bool(rr.get("ok", false)):
		_set_status("Taught to %s." % _display_name(npc))
	else:
		_set_status("Failed: %s" % String(rr.get("error", "Error")))

func _update_ui() -> void:
	if npc_name_label != null:
		if _npcs.is_empty():
			npc_name_label.text = "(no NPCs)"
		else:
			npc_name_label.text = _display_name(_npcs[_idx])
	_update_preview_model()

func _display_name(npc: Dictionary) -> String:
	var dn := String(npc.get("display_name", "")).strip_edges()
	if dn != "":
		return dn
	var nid := String(npc.get("npc_id", "")).strip_edges()
	return nid if nid != "" else "(unknown)"

func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless" or OS.has_feature("server") or OS.has_feature("headless")

func _update_preview_visibility() -> void:
	if preview_container != null:
		preview_container.visible = not _is_headless()

func _update_preview_model() -> void:
	_update_preview_visibility()
	if _is_headless():
		return
	if preview_root == null:
		return
	for c in preview_root.get_children():
		(c as Node).queue_free()
	if _npcs.is_empty():
		return
	var npc := _npcs[_idx]
	var mp := String(npc.get("model_path", "")).strip_edges()
	var inst: Node = null
	if mp != "":
		var res := load(mp)
		if res is PackedScene:
			inst = (res as PackedScene).instantiate()
	if inst == null:
		var mi := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.25
		mesh.height = 1.1
		mi.mesh = mesh
		inst = mi
	_preview_freeze_node(inst)
	preview_root.add_child(inst)
	_frame_camera_to_preview_root()
	if preview_viewport != null:
		preview_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _set_status(t: String) -> void:
	if status_label != null:
		status_label.text = t

func _set_nav_enabled(enabled: bool) -> void:
	if prev_button != null:
		prev_button.disabled = not enabled
	if next_button != null:
		next_button.disabled = not enabled
	if learn_button != null:
		learn_button.disabled = not enabled

func _preview_freeze_node(root: Node) -> void:
	if root == null:
		return
	# Disable processing so preview doesn't "run" gameplay scripts.
	if root.has_method("set_process"):
		root.set_process(false)
	if root.has_method("set_physics_process"):
		root.set_physics_process(false)
	root.process_mode = Node.PROCESS_MODE_DISABLED
	for n in root.find_children("*", "", true, false):
		var node := n as Node
		if node == null:
			continue
		if node.has_method("set_process"):
			node.set_process(false)
		if node.has_method("set_physics_process"):
			node.set_physics_process(false)
		node.process_mode = Node.PROCESS_MODE_DISABLED
	for ap0 in root.find_children("*", "AnimationPlayer", true, false):
		var ap := ap0 as AnimationPlayer
		if ap == null:
			continue
		ap.stop()

func _frame_camera_to_preview_root() -> void:
	if preview_camera == null or preview_root == null:
		return
	# Compute a merged AABB for all MeshInstance3D nodes to frame the model.
	var meshes := preview_root.find_children("*", "MeshInstance3D", true, false)
	var first := true
	var min_v: Vector3 = Vector3.ZERO
	var max_v: Vector3 = Vector3.ZERO
	var inv: Transform3D = preview_root.global_transform.affine_inverse()
	for m0 in meshes:
		var mi := m0 as MeshInstance3D
		if mi == null:
			continue
		if mi.mesh == null:
			continue
		var a := mi.get_aabb()
		var rel := inv * mi.global_transform
		var b := _aabb_transformed(a, rel)
		if first:
			min_v = b.position
			max_v = b.position + b.size
			first = false
		else:
			var bmin: Vector3 = b.position
			var bmax: Vector3 = b.position + b.size
			min_v = Vector3(minf(min_v.x, bmin.x), minf(min_v.y, bmin.y), minf(min_v.z, bmin.z))
			max_v = Vector3(maxf(max_v.x, bmax.x), maxf(max_v.y, bmax.y), maxf(max_v.z, bmax.z))

	var center: Vector3 = Vector3(0.0, 1.0, 0.0)
	var extent: float = 1.2
	if not first:
		var size: Vector3 = max_v - min_v
		center = min_v + size * 0.5
		extent = maxf(size.x, maxf(size.y, size.z))
		if extent <= 0.01:
			extent = 1.2

		# Narrower FOV makes the model appear larger.
		preview_camera.fov = 35.0
		var dist: float = clampf(extent * 1.6, 0.9, 6.0)
		var eye: Vector3 = center + Vector3(0.0, extent * 0.15, dist)
		preview_camera.position = eye
		preview_camera.look_at(center, Vector3.UP)

static func _aabb_transformed(aabb: AABB, xform: Transform3D) -> AABB:
	var p := aabb.position
	var s := aabb.size
	var corners: Array[Vector3] = [
		p,
		p + Vector3(s.x, 0.0, 0.0),
		p + Vector3(0.0, s.y, 0.0),
		p + Vector3(0.0, 0.0, s.z),
		p + Vector3(s.x, s.y, 0.0),
		p + Vector3(s.x, 0.0, s.z),
		p + Vector3(0.0, s.y, s.z),
		p + s,
	]
	var first := true
	var min_v := Vector3.ZERO
	var max_v := Vector3.ZERO
	for c in corners:
		var wc := xform * c
		if first:
			min_v = wc
			max_v = wc
			first = false
		else:
			min_v = Vector3(minf(min_v.x, wc.x), minf(min_v.y, wc.y), minf(min_v.z, wc.z))
			max_v = Vector3(maxf(max_v.x, wc.x), maxf(max_v.y, wc.y), maxf(max_v.z, wc.z))
	return AABB(min_v, max_v - min_v)
