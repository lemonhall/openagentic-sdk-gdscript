extends Control

signal device_code_submitted(desk_id: String, device_code: String)
signal device_code_canceled(desk_id: String)

const DEVICE_POPUP_SIZE := Vector2i(520, 200)

@onready var context_menu: PopupMenu = %ContextMenu
@onready var device_popup: PopupPanel = %DevicePopup
@onready var code_edit: LineEdit = %CodeEdit
@onready var toast: Label = %Toast

var _pending_desk_id: String = ""
var _pending_current_code: String = ""
var _suppress_device_popup_hidden := false
var _toast_tween: Tween = null

func _ready() -> void:
	if device_popup != null:
		device_popup.popup_hide.connect(_on_device_popup_hidden)
	var cancel_btn := device_popup.get_node_or_null("Panel/VBox/Buttons/CancelButton") as Button
	var ok_btn := device_popup.get_node_or_null("Panel/VBox/Buttons/OkButton") as Button
	if cancel_btn != null:
		cancel_btn.pressed.connect(cancel_device_code)
	if ok_btn != null:
		ok_btn.pressed.connect(confirm_device_code)
	if code_edit != null:
		code_edit.text_submitted.connect(func(_t: String) -> void:
			confirm_device_code()
		)

	if context_menu != null:
		context_menu.clear()
		context_menu.add_item("绑定设备码…", 1)
		context_menu.id_pressed.connect(_on_context_menu_id_pressed)

func show_desk_menu(screen_pos: Vector2, desk_id: String, current_device_code: String = "") -> void:
	if context_menu == null:
		return
	_pending_desk_id = desk_id.strip_edges()
	_pending_current_code = current_device_code.strip_edges()
	context_menu.position = Vector2i(int(screen_pos.x), int(screen_pos.y))
	context_menu.popup()

func prompt_device_code() -> void:
	if device_popup == null or code_edit == null:
		return
	code_edit.text = _pending_current_code
	device_popup.popup_centered(DEVICE_POPUP_SIZE)
	code_edit.grab_focus()
	code_edit.select_all()

func cancel_device_code() -> void:
	var did := _pending_desk_id
	if device_popup != null and device_popup.visible:
		_suppress_device_popup_hidden = true
		device_popup.hide()
	_pending_desk_id = ""
	_pending_current_code = ""
	device_code_canceled.emit(did)

func confirm_device_code() -> void:
	if code_edit == null:
		return
	var did := _pending_desk_id
	var code := code_edit.text
	if device_popup != null and device_popup.visible:
		_suppress_device_popup_hidden = true
		device_popup.hide()
	_pending_desk_id = ""
	_pending_current_code = ""
	device_code_submitted.emit(did, code)

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
	if id == 1 and _pending_desk_id.strip_edges() != "":
		prompt_device_code()

func _on_device_popup_hidden() -> void:
	# If the user closes the popup via ESC/click-outside, treat as cancel.
	if _suppress_device_popup_hidden:
		_suppress_device_popup_hidden = false
		return
	if device_popup != null and not device_popup.visible:
		cancel_device_code()

