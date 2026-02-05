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
	_idx = (_idx + delta) % _npcs.size()
	if _idx < 0:
		_idx += _npcs.size()
	_update_ui()

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
	preview_root.add_child(inst)
	if preview_camera != null:
		preview_camera.position = Vector3(0.0, 1.1, 2.2)
		preview_camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	if preview_viewport != null:
		preview_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _set_status(t: String) -> void:
	if status_label != null:
		status_label.text = t

