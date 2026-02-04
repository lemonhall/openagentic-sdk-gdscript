extends Control

@onready var backdrop: ColorRect = $Backdrop
@onready var close_button: Button = %CloseButton

func _ready() -> void:
	visible = false
	if close_button != null:
		close_button.pressed.connect(close)
	if backdrop != null:
		backdrop.gui_input.connect(_on_backdrop_gui_input)

func open() -> void:
	visible = true
	call_deferred("_grab_focus")

func close() -> void:
	visible = false

func _grab_focus() -> void:
	if close_button != null:
		close_button.grab_focus()

func _on_backdrop_gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if backdrop != null and (event is InputEventMouseButton or event is InputEventMouseMotion):
		backdrop.accept_event()
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

