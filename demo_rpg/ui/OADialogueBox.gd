extends Control

signal message_submitted(text: String)
signal closed()

@onready var _speaker: Label = $"Panel/Margin/VBox/Speaker"
@onready var _text: RichTextLabel = $"Panel/Margin/VBox/Text"
@onready var _input: LineEdit = $"Panel/Margin/VBox/InputRow/Input"
@onready var _send: Button = $"Panel/Margin/VBox/InputRow/Send"
@onready var _close: Button = $"Panel/Margin/VBox/TopRow/Close"

var _busy: bool = false
var _npc_id: String = ""
var _display_name: String = ""
var _assistant_buf: String = ""

func _ready() -> void:
	_send.pressed.connect(_on_send_pressed)
	_input.text_submitted.connect(func(_t: String) -> void:
		_on_send_pressed()
	)
	_close.pressed.connect(func() -> void:
		close()
	)

func open(npc_id: String, display_name: String) -> void:
	_npc_id = npc_id
	_display_name = display_name
	_assistant_buf = ""
	_busy = false
	visible = true
	_set_busy(false)
	_set_speaker(display_name)
	_text.clear()
	_input.text = ""
	_input.grab_focus()

func close() -> void:
	visible = false
	_busy = false
	_assistant_buf = ""
	closed.emit()

func set_busy(b: bool) -> void:
	_set_busy(b)

func begin_assistant() -> void:
	_assistant_buf = ""
	_text.clear()

func append_assistant_delta(delta: String) -> void:
	_assistant_buf += delta
	_text.text = _assistant_buf

func end_assistant() -> void:
	_text.text = _assistant_buf

func get_npc_id() -> String:
	return _npc_id

func get_display_name() -> String:
	return _display_name

func _set_speaker(name: String) -> void:
	if _speaker != null:
		_speaker.text = name

func _set_busy(b: bool) -> void:
	_busy = b
	if _input != null:
		_input.editable = not b
	if _send != null:
		_send.disabled = b

func _on_send_pressed() -> void:
	if _busy:
		return
	var text := ""
	if _input != null:
		text = _input.text.strip_edges()
	if text == "":
		return
	if _input != null:
		_input.text = ""
	message_submitted.emit(text)
