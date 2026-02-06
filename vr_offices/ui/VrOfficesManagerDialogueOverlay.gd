extends Control
class_name VrOfficesManagerDialogueOverlay

@onready var title_label: Label = %TitleLabel
@onready var close_button: Button = %CloseButton
@onready var embedded_dialogue: Control = %EmbeddedDialogue
@onready var preview_container: SubViewportContainer = %PreviewContainer
@onready var preview_viewport: SubViewport = %PreviewViewport
@onready var preview_root: Node3D = %PreviewRoot
@onready var preview_camera: Camera3D = %PreviewCamera

var _model_path: String = ""
var _workspace_id: String = ""

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
	if title_label != null:
		title_label.text = "%s · %s" % [manager_name.strip_edges() if manager_name.strip_edges() != "" else "经理", _workspace_id]
	visible = true
	_update_preview_model()

func close() -> void:
	visible = false
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

func _update_preview_model() -> void:
	if preview_root == null:
		return
	for c0 in preview_root.get_children():
		var c := c0 as Node
		if c != null:
			c.queue_free()

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
	preview_root.add_child(inst)
	_frame_camera()

func _frame_camera() -> void:
	if preview_camera == null:
		return
	preview_camera.position = Vector3(0.0, 1.1, 2.2)
	preview_camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
