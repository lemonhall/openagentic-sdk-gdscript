extends Control

signal create_confirmed(name: String)
signal create_canceled
signal delete_requested(workspace_id: String)
signal add_standing_desk_requested(workspace_id: String)

@onready var create_popup: PopupPanel = %CreatePopup
@onready var name_edit: LineEdit = %NameEdit
@onready var context_menu: PopupMenu = %ContextMenu
@onready var toast: Label = %Toast

var _pending_workspace_id: String = ""
var _suppress_create_popup_hidden := false
var _toast_tween: Tween = null

func _ready() -> void:
	if create_popup != null:
		create_popup.popup_hide.connect(_on_create_popup_hidden)
	var cancel_btn := create_popup.get_node_or_null("Panel/VBox/Buttons/CancelButton") as Button
	var ok_btn := create_popup.get_node_or_null("Panel/VBox/Buttons/OkButton") as Button
	if cancel_btn != null:
		cancel_btn.pressed.connect(cancel_create)
	if ok_btn != null:
		ok_btn.pressed.connect(confirm_create)
	if name_edit != null:
		name_edit.text_submitted.connect(func(_t: String) -> void:
			confirm_create()
		)

	if context_menu != null:
		context_menu.clear()
		context_menu.add_item("Add Standing Desk…", 2)
		context_menu.add_item("Delete workspace", 1)
		context_menu.id_pressed.connect(_on_context_menu_id_pressed)

func prompt_create(default_name: String) -> void:
	if create_popup == null or name_edit == null:
		return
	name_edit.text = default_name
	create_popup.popup_centered()
	name_edit.grab_focus()
	name_edit.select_all()

func cancel_create() -> void:
	if create_popup != null and create_popup.visible:
		_suppress_create_popup_hidden = true
		create_popup.hide()
	create_canceled.emit()

func confirm_create() -> void:
	if name_edit == null:
		return
	var n := name_edit.text.strip_edges()
	if n == "":
		n = "Workspace"
	if create_popup != null and create_popup.visible:
		_suppress_create_popup_hidden = true
		create_popup.hide()
	create_confirmed.emit(n)

func show_workspace_menu(screen_pos: Vector2, workspace_id: String) -> void:
	if context_menu == null:
		return
	_pending_workspace_id = workspace_id
	context_menu.position = Vector2i(int(screen_pos.x), int(screen_pos.y))
	context_menu.popup()

func show_toast(message: String, seconds: float = 2.0) -> void:
	if toast == null:
		return
	toast.text = message
	toast.visible = true
	toast.modulate = Color(1, 1, 1, 1)

	if _toast_tween != null and is_instance_valid(_toast_tween):
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(maxf(0.05, seconds))
	_toast_tween.tween_property(toast, "modulate", Color(1, 1, 1, 0), 0.25)
	_toast_tween.tween_callback(func() -> void:
		if toast != null:
			toast.visible = false
	)

func _on_context_menu_id_pressed(id: int) -> void:
	if id == 1 and _pending_workspace_id.strip_edges() != "":
		var wid := _pending_workspace_id
		_pending_workspace_id = ""
		delete_requested.emit(wid)
	if id == 2 and _pending_workspace_id.strip_edges() != "":
		var wid2 := _pending_workspace_id
		_pending_workspace_id = ""
		add_standing_desk_requested.emit(wid2)

func _on_create_popup_hidden() -> void:
	# If the user closes the popup via ESC/click-outside, treat as cancel.
	if _suppress_create_popup_hidden:
		_suppress_create_popup_hidden = false
		return
	if create_popup != null and not create_popup.visible:
		create_canceled.emit()
