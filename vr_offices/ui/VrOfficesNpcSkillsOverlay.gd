extends Control
class_name VrOfficesNpcSkillsOverlay

signal closed

const _OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")
const _Validator := preload("res://addons/openagentic/core/OASkillMdValidator.gd")
const _SkillFs := preload("res://vr_offices/core/skill_library/VrOfficesSkillLibraryFs.gd")
const _LibraryPaths := preload("res://vr_offices/core/skill_library/VrOfficesSharedSkillLibraryPaths.gd")
const _TeachPopup := preload("res://vr_offices/ui/VrOfficesTeachSkillPopup.gd")

@onready var title_label: Label = %TitleLabel
@onready var refresh_summary_button: Button = %RefreshSummaryButton
@onready var open_skills_folder_button: Button = %OpenSkillsFolderButton
@onready var close_button: Button = %CloseButton
@onready var summary_label: Label = %SummaryLabel

@onready var card_prev_button: Button = %CardPrevButton
@onready var card_next_button: Button = %CardNextButton
@onready var card_panel: PanelContainer = %CardPanel
@onready var card_thumb: TextureRect = %CardThumb
@onready var card_title: Label = %CardTitle
@onready var card_desc: Label = %CardDesc
@onready var card_uninstall_button: Button = %CardUninstallButton
@onready var card_empty_label: Label = %CardEmptyLabel
@onready var card_page_label: Label = %CardPageLabel

@onready var preview_container: Control = %PreviewContainer
@onready var preview_viewport: SubViewport = %PreviewViewport
@onready var preview_root: Node3D = %PreviewRoot
@onready var preview_camera: Camera3D = %PreviewCamera

var _save_id: String = ""
var _npc_id: String = ""
var _npc_name: String = ""
var _model_path: String = ""
var _thumb_cache: Dictionary = {}
var _skills: Array[Dictionary] = []
var _skill_idx: int = 0
var _card_tween: Tween = null

func _ready() -> void:
	if close_button != null:
		close_button.pressed.connect(close)
	if refresh_summary_button != null:
		refresh_summary_button.pressed.connect(func() -> void:
			_request_summary_refresh(true)
		)
	if open_skills_folder_button != null:
		open_skills_folder_button.pressed.connect(_on_open_skills_folder_pressed)
	if card_prev_button != null:
		card_prev_button.pressed.connect(func() -> void:
			_select_skill_delta(-1, true)
		)
	if card_next_button != null:
		card_next_button.pressed.connect(func() -> void:
			_select_skill_delta(1, true)
		)
	if card_uninstall_button != null:
		card_uninstall_button.pressed.connect(func() -> void:
			_uninstall_selected_skill()
		)
	var backdrop := get_node_or_null("Backdrop") as Control
	if backdrop != null:
		backdrop.gui_input.connect(_on_backdrop_gui_input)
	_update_preview_visibility()
	_setup_card_style()

func _on_open_skills_folder_pressed() -> void:
	if _is_headless():
		return
	if _save_id == "" or _npc_id == "":
		return
	var p := String(_OAPaths.npc_skills_dir(_save_id, _npc_id)).strip_edges()
	if p == "":
		return
	OS.shell_open(ProjectSettings.globalize_path(p))

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if preview_viewport != null:
			preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	if what == NOTIFICATION_RESIZED:
		_update_card_pivot()

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
	_skill_idx = 0
	if _save_id == "" or _npc_id == "":
		return
	visible = true
	_refresh_title()
	_refresh_skills()
	var info := _refresh_summary_cached()
	var cached_txt := String(info.get("summary", "")).strip_edges()
	var cached_err := String(info.get("last_error", "")).strip_edges()
	var force := cached_txt == "" or cached_err != ""
	_request_summary_refresh(force)
	_update_preview_model()

func close() -> void:
	var was_visible := visible
	visible = false
	if was_visible:
		emit_signal("closed")

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
			var dist: float = clampf(extent * 2.2, 1.1, 8.0)
			var eye: Vector3 = center + Vector3(0.0, extent * 0.15, dist)
			preview_camera.position = eye
			preview_camera.look_at(center, Vector3.UP)

func _skills_service() -> Node:
	if get_tree() == null:
		return null
	var nodes := get_tree().get_nodes_in_group("vr_offices_npc_skills_service")
	return nodes[0] as Node if nodes.size() > 0 else null

func _refresh_summary_cached() -> Dictionary:
	if summary_label == null:
		return {"summary": "", "last_error": "MissingLabel"}
	var svc := _skills_service()
	if svc == null or not svc.has_method("get_cached_summary"):
		summary_label.text = ""
		return {"summary": "", "last_error": "MissingService"}
	var rr: Dictionary = svc.call("get_cached_summary", _save_id, _npc_id)
	var txt := String(rr.get("summary", "")).strip_edges()
	var err := String(rr.get("last_error", "")).strip_edges()
	if txt != "":
		summary_label.text = txt
	elif err != "":
		summary_label.text = "(summary error: %s)" % err
	else:
		summary_label.text = "(summary pending)"
	return {"summary": txt, "last_error": err}

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
	_thumb_cache.clear()
	_skills = _discover_skills()
	if _skill_idx < 0:
		_skill_idx = 0
	if _skills.is_empty():
		_skill_idx = 0
	elif _skill_idx >= _skills.size():
		_skill_idx = _skills.size() - 1
	_render_selected_skill(false, 0)

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

func _setup_card_style() -> void:
	if card_panel != null:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.08, 0.1, 0.92)
		sb.corner_radius_top_left = 14
		sb.corner_radius_top_right = 14
		sb.corner_radius_bottom_left = 14
		sb.corner_radius_bottom_right = 14
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 12
		sb.content_margin_bottom = 12
		card_panel.add_theme_stylebox_override("panel", sb)
	_update_card_pivot()

func _update_card_pivot() -> void:
	if card_panel == null:
		return
	card_panel.pivot_offset = card_panel.size * 0.5

func _select_skill_delta(delta: int, animate: bool) -> void:
	if _skills.size() <= 1:
		return
	var next_idx := (_skill_idx + delta) % _skills.size()
	if next_idx < 0:
		next_idx += _skills.size()
	_select_skill_index(next_idx, delta, animate)

func _select_skill_index(next_idx: int, delta_dir: int, animate: bool) -> void:
	if _skills.is_empty():
		_skill_idx = 0
		_render_selected_skill(false, 0)
		return
	var idx := clampi(next_idx, 0, _skills.size() - 1)
	if idx == _skill_idx and animate:
		return
	_skill_idx = idx
	_render_selected_skill(animate, delta_dir)

func _uninstall_selected_skill() -> void:
	if _skills.is_empty():
		return
	var cur: Dictionary = _skills[_skill_idx]
	var dir_name := String(cur.get("dir_name", "")).strip_edges()
	if dir_name == "":
		return
	_uninstall_skill(dir_name)

func _render_selected_skill(animate: bool, delta_dir: int) -> void:
	if card_panel == null:
		return
	if not animate:
		_apply_selected_skill_content()
		return

	if _card_tween != null:
		_card_tween.kill()
	var out_rot := -0.03 if delta_dir >= 0 else 0.03
	var in_rot := 0.03 if delta_dir >= 0 else -0.03
	_card_tween = create_tween()
	_card_tween.set_trans(Tween.TRANS_CUBIC)
	_card_tween.set_ease(Tween.EASE_OUT)
	_card_tween.tween_property(card_panel, "scale", Vector2(0.98, 0.98), 0.08)
	_card_tween.parallel().tween_property(card_panel, "rotation", out_rot, 0.08)
	_card_tween.parallel().tween_property(card_panel, "modulate:a", 0.0, 0.08)
	_card_tween.tween_callback(func() -> void:
		_apply_selected_skill_content()
		card_panel.scale = Vector2(1.02, 1.02)
		card_panel.rotation = in_rot
		card_panel.modulate.a = 0.0
	)
	_card_tween.tween_property(card_panel, "modulate:a", 1.0, 0.16)
	_card_tween.parallel().tween_property(card_panel, "scale", Vector2(1.0, 1.0), 0.16)
	_card_tween.parallel().tween_property(card_panel, "rotation", 0.0, 0.16)

func _apply_selected_skill_content() -> void:
	var has := not _skills.is_empty()
	if card_empty_label != null:
		card_empty_label.visible = not has
	if card_panel != null:
		card_panel.visible = has
	if card_page_label != null:
		card_page_label.text = "" if not has else ("%d / %d" % [_skill_idx + 1, _skills.size()])
	if card_prev_button != null:
		card_prev_button.disabled = _skills.size() <= 1
	if card_next_button != null:
		card_next_button.disabled = _skills.size() <= 1
	if card_uninstall_button != null:
		card_uninstall_button.disabled = not has

	if not has:
		if card_title != null:
			card_title.text = ""
		if card_desc != null:
			card_desc.text = ""
		if card_thumb != null:
			card_thumb.texture = null
		return

	var cur: Dictionary = _skills[_skill_idx]
	var dir_name := String(cur.get("dir_name", "")).strip_edges()
	var display_name := String(cur.get("name", dir_name)).strip_edges()
	var desc := String(cur.get("description", "")).strip_edges()

	if card_title != null:
		card_title.text = display_name if display_name != "" else dir_name
	if card_desc != null:
		card_desc.text = desc
	if card_thumb != null:
		card_thumb.texture = _thumbnail_texture_for_skill(dir_name)

func _thumbnail_texture_for_skill(skill_name: String) -> Texture2D:
	var skill_key := skill_name.strip_edges()
	if skill_key == "" or _save_id == "":
		return null
	if _thumb_cache.has(skill_key):
		return _thumb_cache.get(skill_key) as Texture2D
	var p := _LibraryPaths.thumbnail_path(_save_id, skill_key)
	if p == "" or not (FileAccess.file_exists(p) or FileAccess.file_exists(ProjectSettings.globalize_path(p))):
		_thumb_cache[skill_key] = null
		return null
	var abs_path := ProjectSettings.globalize_path(p)
	var img := Image.new()
	var err := img.load(abs_path)
	if err != OK:
		_thumb_cache[skill_key] = null
		return null
	var tex := ImageTexture.create_from_image(img)
	_thumb_cache[skill_key] = tex
	return tex

func _uninstall_skill(dir_name: String) -> void:
	var dn := dir_name.strip_edges()
	if dn == "" or _save_id == "" or _npc_id == "":
		return
	var dir := String(_OAPaths.npc_skill_dir(_save_id, _npc_id, dn))
	var abs_path := ProjectSettings.globalize_path(dir)
	if DirAccess.dir_exists_absolute(abs_path):
		_SkillFs.rm_tree(dir)
		DirAccess.remove_absolute(abs_path)
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
			return
		if k.pressed and (k.keycode == KEY_LEFT or k.keycode == KEY_A):
			_select_skill_delta(-1, true)
			accept_event()
			return
		if k.pressed and (k.keycode == KEY_RIGHT or k.keycode == KEY_D):
			_select_skill_delta(1, true)
			accept_event()
			return

func _test_skill_names() -> Array:
	var out: Array = []
	var skills := _discover_skills()
	for s in skills:
		out.append(String(s.get("dir_name", "")))
	return out

func _test_uninstall_skill(dir_name: String) -> void:
	_uninstall_skill(dir_name)

func _test_selected_skill_name() -> String:
	if _skills.is_empty():
		return ""
	return String(_skills[_skill_idx].get("dir_name", "")).strip_edges()

func _test_next_skill() -> void:
	_select_skill_delta(1, false)

func _test_prev_skill() -> void:
	_select_skill_delta(-1, false)
