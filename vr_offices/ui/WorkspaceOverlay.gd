extends Control

signal create_confirmed(name: String)
signal create_meeting_room_confirmed(name: String)
signal create_canceled
signal delete_requested(workspace_id: String)
signal meeting_room_delete_requested(meeting_room_id: String)
signal add_standing_desk_requested(workspace_id: String)

const CREATE_POPUP_SIZE := Vector2i(520, 220)

@onready var create_popup: PopupPanel = %CreatePopup
@onready var room_type_option: OptionButton = %RoomTypeOption
@onready var name_edit: LineEdit = %NameEdit
@onready var context_menu: PopupMenu = %ContextMenu
@onready var toast: Label = %Toast

var _pending_workspace_id: String = ""
var _pending_meeting_room_id: String = ""
var _suppress_create_popup_hidden := false
var _toast_tween: Tween = null
var _default_workspace_name := "Workspace"
var _default_meeting_room_name := "Meeting Room"
var _last_auto_name := ""

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
	if room_type_option != null:
		room_type_option.clear()
		room_type_option.add_item("Workspace", 0)
		room_type_option.add_item("Meeting room", 1)
		room_type_option.selected = 0
		room_type_option.item_selected.connect(_on_room_type_selected)

	if context_menu != null:
		context_menu.id_pressed.connect(_on_context_menu_id_pressed)

func prompt_create(default_name: String) -> void:
	prompt_create_room(default_name, "Meeting Room")

func prompt_create_room(default_workspace_name: String, default_meeting_room_name: String) -> void:
	if create_popup == null or name_edit == null:
		return
	_default_workspace_name = default_workspace_name
	_default_meeting_room_name = default_meeting_room_name
	if room_type_option != null:
		room_type_option.selected = 0
	name_edit.text = _default_workspace_name
	_last_auto_name = _default_workspace_name
	_update_create_title_and_placeholder()
	# Keep the dialog wide enough so longer text isn't clipped.
	create_popup.popup_centered(CREATE_POPUP_SIZE)
	name_edit.grab_focus()
	name_edit.select_all()

func get_create_popup_size() -> Vector2i:
	return CREATE_POPUP_SIZE

func cancel_create() -> void:
	if create_popup != null and create_popup.visible:
		_suppress_create_popup_hidden = true
		create_popup.hide()
	create_canceled.emit()

func confirm_create() -> void:
	if name_edit == null:
		return
	var n := name_edit.text.strip_edges()
	var want_meeting := room_type_option != null and int(room_type_option.selected) == 1
	if n == "":
		n = "Meeting Room" if want_meeting else "Workspace"
	if create_popup != null and create_popup.visible:
		_suppress_create_popup_hidden = true
		create_popup.hide()
	if want_meeting:
		create_meeting_room_confirmed.emit(n)
	else:
		create_confirmed.emit(n)

func show_workspace_menu(screen_pos: Vector2, workspace_id: String) -> void:
	if context_menu == null:
		return
	context_menu.clear()
	context_menu.add_item("Add Standing Desk…", 2)
	context_menu.add_item("Delete workspace", 1)
	_pending_workspace_id = workspace_id
	_pending_meeting_room_id = ""
	context_menu.position = Vector2i(int(screen_pos.x), int(screen_pos.y))
	context_menu.popup()

func show_meeting_room_menu(screen_pos: Vector2, meeting_room_id: String) -> void:
	if context_menu == null:
		return
	context_menu.clear()
	context_menu.add_item("Delete meeting room", 3)
	_pending_meeting_room_id = meeting_room_id
	_pending_workspace_id = ""
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
	if id == 3 and _pending_meeting_room_id.strip_edges() != "":
		var rid := _pending_meeting_room_id
		_pending_meeting_room_id = ""
		meeting_room_delete_requested.emit(rid)

func _on_create_popup_hidden() -> void:
	# If the user closes the popup via ESC/click-outside, treat as cancel.
	if _suppress_create_popup_hidden:
		_suppress_create_popup_hidden = false
		return
	if create_popup != null and not create_popup.visible:
		create_canceled.emit()

func _on_room_type_selected(_idx: int) -> void:
	if name_edit == null:
		return
	var want_meeting := room_type_option != null and int(room_type_option.selected) == 1
	var next_default := _default_meeting_room_name if want_meeting else _default_workspace_name
	# Only switch the suggested name if the user hasn't edited away from the previous auto-default.
	if name_edit.text.strip_edges() == _last_auto_name.strip_edges():
		name_edit.text = next_default
		name_edit.select_all()
		_last_auto_name = next_default
	_update_create_title_and_placeholder()

func _update_create_title_and_placeholder() -> void:
	if create_popup == null:
		return
	var title := create_popup.get_node_or_null("Panel/VBox/Title") as Label
	if title == null:
		return
	var want_meeting := room_type_option != null and int(room_type_option.selected) == 1
	if want_meeting:
		title.text = "Create meeting room"
		if name_edit != null:
			name_edit.placeholder_text = "Meeting room name"
	else:
		title.text = "Create workspace"
		if name_edit != null:
			name_edit.placeholder_text = "Workspace name"
