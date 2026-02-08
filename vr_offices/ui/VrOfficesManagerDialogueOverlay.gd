extends Control
class_name VrOfficesManagerDialogueOverlay

const _TeachPopup := preload("res://vr_offices/ui/VrOfficesTeachSkillPopup.gd")

@onready var title_label: Label = %TitleLabel
@onready var close_button: Button = %CloseButton
@onready var embedded_dialogue: Control = %EmbeddedDialogue
@onready var preview_container: SubViewportContainer = %PreviewContainer
@onready var preview_viewport: SubViewport = %PreviewViewport
@onready var preview_root: Node3D = %PreviewRoot
@onready var preview_camera: Camera3D = %PreviewCamera
@onready var identity_name_label: Label = %IdentityNameLabel
@onready var identity_workspace_label: Label = %IdentityWorkspaceLabel

var _model_path: String = ""
var _workspace_id: String = ""

var _preview_gen := 0
var _preview_loading := false
var _preview_loading_path: String = ""
var _preview_placeholder: Node = null

func _ready() -> void:
	visible = false
	if close_button != null:
		close_button.pressed.connect(close)
	if embedded_dialogue != null and embedded_dialogue.has_signal("closed"):
		if not embedded_dialogue.is_connected("closed", Callable(self, "_on_embedded_dialogue_closed")):
			embedded_dialogue.connect("closed", Callable(self, "_on_embedded_dialogue_closed"))
		var inner_backdrop := embedded_dialogue.get_node_or_null("Backdrop") as ColorRect
		if inner_backdrop != null:
			inner_backdrop.color = Color(0, 0, 0, 0.0)
	var backdrop := get_node_or_null("Backdrop") as Control
	if backdrop != null:
		backdrop.gui_input.connect(_on_backdrop_gui_input)

func open_for_manager(workspace_id: String, manager_name: String, manager_model_path: String = "") -> void:
	_workspace_id = workspace_id.strip_edges()
	_model_path = manager_model_path.strip_edges()
	var who := manager_name.strip_edges() if manager_name.strip_edges() != "" else "经理"
	if title_label != null:
		title_label.text = "%s · %s" % [who, _workspace_id]
	_set_identity_labels(who, _workspace_id)
	visible = true
	_schedule_preview_update()

func open_for_npc(npc_id: String, npc_name: String, npc_model_path: String = "", workspace_id: String = "") -> void:
	_workspace_id = workspace_id.strip_edges()
	_model_path = npc_model_path.strip_edges()
	var who := npc_name.strip_edges()
	if who == "":
		who = npc_id.strip_edges()
	if who == "":
		who = "同事"
	if title_label != null:
		title_label.text = who
	_set_identity_labels(who, _workspace_id)
	visible = true
	_schedule_preview_update()

func _set_identity_labels(name_text: String, workspace_id: String) -> void:
	var who := name_text.strip_edges()
	if who == "":
		who = "未知对象"
	if identity_name_label != null:
		identity_name_label.text = "对象：%s" % who
	var wid := workspace_id.strip_edges()
	if identity_workspace_label != null:
		identity_workspace_label.text = "工作区：%s" % (wid if wid != "" else "全局")

func close() -> void:
	visible = false
	_cancel_preview_load()
	if embedded_dialogue != null and embedded_dialogue.has_method("close") and embedded_dialogue.visible:
		embedded_dialogue.call("close")

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

func _on_embedded_dialogue_closed() -> void:
	if visible:
		visible = false

func get_embedded_dialogue() -> Control:
	return embedded_dialogue

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and preview_viewport != null:
		preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED

func _is_headless() -> bool:
	var force := bool(ProjectSettings.get_setting("vr_offices/preview_force_non_headless", false))
	if force:
		return false
	return DisplayServer.get_name() == "headless" or OS.has_feature("server") or OS.has_feature("headless")

func _update_preview_visibility() -> void:
	if preview_container != null:
		var enabled := bool(ProjectSettings.get_setting("vr_offices/manager_preview_enabled", true))
		preview_container.visible = enabled and not _is_headless()

func _schedule_preview_update() -> void:
	_cancel_preview_load()
	call_deferred("_update_preview_model_deferred", _preview_gen)

func _cancel_preview_load() -> void:
	_preview_gen += 1
	_preview_loading = false
	_preview_loading_path = ""
	_preview_placeholder = null
	set_process(false)

func _update_preview_model_deferred(gen: int) -> void:
	if gen != _preview_gen:
		return
	_update_preview_visibility()
	var enabled := bool(ProjectSettings.get_setting("vr_offices/manager_preview_enabled", true))
	if not enabled or _is_headless():
		return
	if preview_root == null:
		return
	for c0 in preview_root.get_children():
		var c := c0 as Node
		if c != null:
			c.queue_free()

	var inst: Node = null
	# Always show a lightweight placeholder first so the overlay can appear instantly.
	_preview_placeholder = _make_placeholder()
	inst = _preview_placeholder
	preview_root.add_child(inst)
	_frame_camera()

	var path := _model_path.strip_edges()
	if path == "":
		return

	_preview_loading = true
	_preview_loading_path = path
	ResourceLoader.load_threaded_request(path)
	set_process(true)

func _preview_freeze_node(root: Node) -> void:
	if root == null:
		return
	var anim_players: Array = root.find_children("*", "AnimationPlayer", true, false)
	var ap_set: Dictionary = {}
	for ap0 in anim_players:
		if ap0 != null:
			ap_set[ap0] = true
	_TeachPopup._preview_disable_node_rec(root, ap_set)

func _frame_camera() -> void:
	if preview_camera == null:
		return
	preview_camera.position = Vector3(0.0, 1.1, 2.2)
	preview_camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)

func _frame_camera_to_preview_root() -> void:
	if preview_camera == null or preview_root == null:
		return
	var meshes := preview_root.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		_frame_camera()
		return
	var first := true
	var min_v := Vector3.ZERO
	var max_v := Vector3.ZERO
	for m0 in meshes:
		var mi := m0 as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var local_xf := preview_root.global_transform.affine_inverse() * mi.global_transform
		var box := _aabb_transformed(mi.get_aabb(), local_xf)
		var bmin := box.position
		var bmax := box.position + box.size
		if first:
			min_v = bmin
			max_v = bmax
			first = false
		else:
			min_v = Vector3(minf(min_v.x, bmin.x), minf(min_v.y, bmin.y), minf(min_v.z, bmin.z))
			max_v = Vector3(maxf(max_v.x, bmax.x), maxf(max_v.y, bmax.y), maxf(max_v.z, bmax.z))
	if first:
		_frame_camera()
		return
	var bounds_size := max_v - min_v
	var center := min_v + bounds_size * 0.5
	var extent := maxf(bounds_size.x, maxf(bounds_size.y, bounds_size.z))
	if extent <= 0.01:
		extent = 1.2
	preview_camera.fov = 35.0
	var dist := clampf(extent * 2.2, 1.1, 9.0)
	var eye := center + Vector3(0.0, extent * 0.18, dist)
	preview_camera.position = eye
	preview_camera.look_at(center, Vector3.UP)

func _process(_delta: float) -> void:
	if not visible:
		_cancel_preview_load()
		return
	if not _preview_loading or _preview_loading_path == "" or _is_headless():
		set_process(false)
		return

	# 0=invalid, 1=in-progress, 2=failed, 3=loaded (Godot 4.x ResourceLoader API).
	var status := int(ResourceLoader.load_threaded_get_status(_preview_loading_path))
	if status == 1:
		return
	_preview_loading = false
	set_process(false)

	if status != 3:
		return

	var res := ResourceLoader.load_threaded_get(_preview_loading_path)
	if res == null or not (res is PackedScene):
		return

	if preview_root == null:
		return

	var inst := (res as PackedScene).instantiate()
	if inst == null:
		return

	# Replace placeholder with the loaded model.
	if _preview_placeholder != null and is_instance_valid(_preview_placeholder):
		_preview_placeholder.queue_free()
	_preview_placeholder = null

	_preview_freeze_node(inst)
	preview_root.add_child(inst)
	_TeachPopup.autoplay_idle_animation_for_preview(inst)
	# Framing can be a bit expensive; do it next frame so it never blocks talk-open.
	call_deferred("_frame_camera_to_preview_root")

func _make_placeholder() -> Node:
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.25
	mesh.height = 1.1
	mi.mesh = mesh
	mi.name = "PreviewPlaceholder"
	return mi

func _aabb_transformed(aabb: AABB, xf: Transform3D) -> AABB:
	var corners := [
		aabb.position,
		aabb.position + Vector3(aabb.size.x, 0, 0),
		aabb.position + Vector3(0, aabb.size.y, 0),
		aabb.position + Vector3(0, 0, aabb.size.z),
		aabb.position + Vector3(aabb.size.x, aabb.size.y, 0),
		aabb.position + Vector3(aabb.size.x, 0, aabb.size.z),
		aabb.position + Vector3(0, aabb.size.y, aabb.size.z),
		aabb.position + aabb.size,
	]
	var min_v := Vector3(INF, INF, INF)
	var max_v := Vector3(-INF, -INF, -INF)
	for c0 in corners:
		var p: Vector3 = xf * c0
		min_v = Vector3(minf(min_v.x, p.x), minf(min_v.y, p.y), minf(min_v.z, p.z))
		max_v = Vector3(maxf(max_v.x, p.x), maxf(max_v.y, p.y), maxf(max_v.z, p.z))
	return AABB(min_v, max_v - min_v)

func _test_frame_with_capsule_height(height: float) -> float:
	if preview_root == null:
		return 0.0
	for c0 in preview_root.get_children():
		var c := c0 as Node
		if c != null:
			c.queue_free()
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.25
	cap.height = maxf(0.2, height)
	mi.mesh = cap
	preview_root.add_child(mi)
	_frame_camera_to_preview_root()
	return preview_camera.position.z if preview_camera != null else 0.0

func _test_autoplay_idle_prefers_idle() -> bool:
	var root := Node3D.new()
	var ap := AnimationPlayer.new()
	root.add_child(ap)
	var walk := Animation.new()
	walk.length = 1.0
	walk.loop_mode = Animation.LOOP_NONE
	var idle := Animation.new()
	idle.length = 1.0
	idle.loop_mode = Animation.LOOP_NONE
	var lib := AnimationLibrary.new()
	lib.add_animation(&"walk", walk)
	lib.add_animation(&"idle_pose", idle)
	ap.add_animation_library(&"", lib)
	var started := _TeachPopup.autoplay_idle_animation_for_preview(root)
	var current_ok := String(ap.current_animation) == "idle_pose"
	var idle_anim := ap.get_animation(&"idle_pose")
	var loop_ok := idle_anim != null and idle_anim.loop_mode != Animation.LOOP_NONE
	root.free()
	return started and current_ok and loop_ok
