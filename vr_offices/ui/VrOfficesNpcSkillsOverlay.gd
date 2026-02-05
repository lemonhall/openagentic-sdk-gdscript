extends Control
class_name VrOfficesNpcSkillsOverlay

const _OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")
const _Validator := preload("res://addons/openagentic/core/OASkillMdValidator.gd")
const _SkillFs := preload("res://vr_offices/core/skill_library/VrOfficesSkillLibraryFs.gd")
const _TeachPopup := preload("res://vr_offices/ui/VrOfficesTeachSkillPopup.gd")

@onready var title_label: Label = %TitleLabel
@onready var refresh_summary_button: Button = %RefreshSummaryButton
@onready var close_button: Button = %CloseButton
@onready var summary_label: Label = %SummaryLabel
@onready var skills_vbox: VBoxContainer = %SkillsVBox

@onready var preview_container: Control = %PreviewContainer
@onready var preview_viewport: SubViewport = %PreviewViewport
@onready var preview_root: Node3D = %PreviewRoot
@onready var preview_camera: Camera3D = %PreviewCamera

var _save_id: String = ""
var _npc_id: String = ""
var _npc_name: String = ""
var _model_path: String = ""

func _ready() -> void:
	if close_button != null:
		close_button.pressed.connect(close)
	if refresh_summary_button != null:
		refresh_summary_button.pressed.connect(func() -> void:
			_request_summary_refresh(true)
		)
	var backdrop := get_node_or_null("Backdrop") as Control
	if backdrop != null:
		backdrop.gui_input.connect(_on_backdrop_gui_input)
	_update_preview_visibility()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if preview_viewport != null:
			preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED

func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		accept_event()

func _on_backdrop_gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			close()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click:
			close()
			return

func open_for_npc(save_id: String, npc_id: String, npc_name: String, model_path: String = "") -> void:
	_save_id = save_id.strip_edges()
	_npc_id = npc_id.strip_edges()
	_npc_name = npc_name.strip_edges()
	_model_path = model_path.strip_edges()
	if _save_id == "" or _npc_id == "":
		return
	visible = true
	_refresh_title()
	_refresh_skills()
	_refresh_summary_cached()
	_request_summary_refresh(false)
	_update_preview_model()

func close() -> void:
	visible = false

func _refresh_title() -> void:
	if title_label == null:
		return
	var who := _npc_name if _npc_name != "" else _npc_id
	title_label.text = "%s — Skills" % who

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

	var inst: Node = null
	if _model_path != "":
		var res := load(_model_path)
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
	_TeachPopup.autoplay_idle_animation_for_preview(inst)
	_frame_camera_to_preview_root()
	if preview_viewport != null:
		preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func _preview_freeze_node(root: Node) -> void:
	if root == null:
		return
	var anim_players: Array = root.find_children("*", "AnimationPlayer", true, false)
	var ap_set: Dictionary = {}
	for ap0 in anim_players:
		if ap0 != null:
			ap_set[ap0] = true
	_TeachPopup._preview_disable_node_rec(root, ap_set)

func _frame_camera_to_preview_root() -> void:
	if preview_camera == null or preview_root == null:
		return
	var meshes := preview_root.find_children("*", "MeshInstance3D", true, false)
	var first := true
	var min_v: Vector3 = Vector3.ZERO
	var max_v: Vector3 = Vector3.ZERO
	var inv: Transform3D = preview_root.global_transform.affine_inverse()
	for m0 in meshes:
		var mi := m0 as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var a := mi.get_aabb()
		var rel := inv * mi.global_transform
		var b := _TeachPopup._aabb_transformed(a, rel)
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
		var bounds_size: Vector3 = max_v - min_v
		center = min_v + bounds_size * 0.5
		extent = maxf(bounds_size.x, maxf(bounds_size.y, bounds_size.z))
		if extent <= 0.01:
			extent = 1.2
		preview_camera.fov = 35.0
		var dist: float = clampf(extent * 1.6, 0.9, 6.0)
		var eye: Vector3 = center + Vector3(0.0, extent * 0.15, dist)
		preview_camera.position = eye
		preview_camera.look_at(center, Vector3.UP)

func _skills_service() -> Node:
	if get_tree() == null:
		return null
	var nodes := get_tree().get_nodes_in_group("vr_offices_npc_skills_service")
	return nodes[0] as Node if nodes.size() > 0 else null

func _refresh_summary_cached() -> void:
	if summary_label == null:
		return
	var svc := _skills_service()
	if svc == null or not svc.has_method("get_cached_summary"):
		summary_label.text = ""
		return
	var rr: Dictionary = svc.call("get_cached_summary", _save_id, _npc_id)
	var txt := String(rr.get("summary", "")).strip_edges()
	var err := String(rr.get("last_error", "")).strip_edges()
	if txt != "":
		summary_label.text = txt
	elif err != "":
		summary_label.text = "(summary error: %s)" % err
	else:
		summary_label.text = "(summary pending)"

func _request_summary_refresh(force: bool) -> void:
	var svc := _skills_service()
	if svc == null or not svc.has_method("queue_regenerate"):
		return
	if not svc.is_connected("profile_updated", Callable(self, "_on_profile_updated")):
		svc.connect("profile_updated", Callable(self, "_on_profile_updated"))
	svc.call("queue_regenerate", _save_id, _npc_id, force)

func _on_profile_updated(save_id: String, npc_id: String, ok: bool, summary: String) -> void:
	if save_id != _save_id or npc_id != _npc_id:
		return
	if not visible:
		return
	if ok and summary_label != null:
		summary_label.text = summary
	elif summary_label != null and summary_label.text.strip_edges() == "":
		summary_label.text = "(summary pending)"

func _refresh_skills() -> void:
	if skills_vbox == null:
		return
	for c0 in skills_vbox.get_children():
		var n := c0 as Node
		if n != null:
			n.queue_free()

	var skills := _discover_skills()
	for s in skills:
		_add_skill_card(s)

func _discover_skills() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _save_id == "" or _npc_id == "":
		return out
	var root := String(_OAPaths.npc_skills_dir(_save_id, _npc_id)).rstrip("/")
	var abs_root := ProjectSettings.globalize_path(root)
	if not DirAccess.dir_exists_absolute(abs_root):
		return out
	var d := DirAccess.open(abs_root)
	if d == null:
		return out
	d.list_dir_begin()
	while true:
		var n := d.get_next()
		if n == "":
			break
		if n == "." or n == "..":
			continue
		if not d.current_is_dir():
			continue
		var dir_name := String(n).strip_edges()
		if dir_name == "":
			continue
		var md_path := root + "/" + dir_name + "/SKILL.md"
		var vr: Dictionary = _Validator.validate_skill_md_path(md_path)
		if not bool(vr.get("ok", false)):
			continue
		out.append({
			"dir_name": dir_name,
			"name": String(vr.get("name", dir_name)).strip_edges(),
			"description": String(vr.get("description", "")).strip_edges(),
		})
	d.list_dir_end()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("name", "")).to_lower() < String(b.get("name", "")).to_lower()
	)
	return out

func _add_skill_card(skill: Dictionary) -> void:
	if skills_vbox == null:
		return
	var dir_name := String(skill.get("dir_name", "")).strip_edges()
	var name := String(skill.get("name", "")).strip_edges()
	var desc := String(skill.get("description", "")).strip_edges()

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var thumb := ColorRect.new()
	thumb.custom_minimum_size = Vector2(72, 72)
	thumb.color = Color(1, 1, 1, 0.08)
	row.add_child(thumb)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mid)

	var title := Label.new()
	title.text = name if name != "" else dir_name
	mid.add_child(title)

	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = desc
	mid.add_child(body)

	var uninstall := Button.new()
	uninstall.text = "Uninstall"
	uninstall.pressed.connect(func() -> void:
		_uninstall_skill(dir_name)
	)
	row.add_child(uninstall)

	skills_vbox.add_child(card)

func _uninstall_skill(dir_name: String) -> void:
	var dn := dir_name.strip_edges()
	if dn == "" or _save_id == "" or _npc_id == "":
		return
	var dir := String(_OAPaths.npc_skill_dir(_save_id, _npc_id, dn))
	var abs := ProjectSettings.globalize_path(dir)
	if DirAccess.dir_exists_absolute(abs):
		_SkillFs.rm_tree(dir)
		DirAccess.remove_absolute(abs)
	_refresh_skills()
	_refresh_summary_cached()
	_request_summary_refresh(false)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and k.keycode == KEY_ESCAPE:
			close()
			accept_event()

func _test_skill_names() -> Array:
	var out: Array = []
	var skills := _discover_skills()
	for s in skills:
		out.append(String(s.get("dir_name", "")))
	return out

func _test_uninstall_skill(dir_name: String) -> void:
	_uninstall_skill(dir_name)

