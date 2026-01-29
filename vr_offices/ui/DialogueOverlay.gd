extends Control

signal message_submitted(text: String)
signal closed

@onready var title_label: Label = %TitleLabel
@onready var messages: VBoxContainer = %Messages
@onready var scroll: ScrollContainer = %Scroll
@onready var input: LineEdit = %Input
@onready var send_button: Button = %SendButton
@onready var close_button: Button = %CloseButton
@onready var panel: Control = $Panel

var _npc_id: String = ""
var _npc_name: String = ""

var _busy := false
var _assistant_rtl: RichTextLabel = null

const _BUBBLE_MIN_WIDTH := 320.0
const _BUBBLE_MAX_WIDTH := 720.0
const _BUBBLE_WIDTH_RATIO := 0.72

func _ready() -> void:
	visible = false
	send_button.pressed.connect(_on_send_pressed)
	close_button.pressed.connect(_on_close_pressed)
	input.text_submitted.connect(_on_input_submitted)

func _gui_input(event: InputEvent) -> void:
	# When the overlay is visible, it should "own" mouse interactions so that the
	# 3D camera rig doesn't treat clicks/drags/wheel as orbit/zoom/pan.
	if not visible:
		return
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		accept_event()

func _on_send_pressed() -> void:
	_submit()

func _on_close_pressed() -> void:
	close()

func _on_input_submitted(_t: String) -> void:
	_submit()

func open(npc_id: String, npc_name: String) -> void:
	_npc_id = npc_id
	_npc_name = npc_name
	title_label.text = _npc_name if _npc_name.strip_edges() != "" else _npc_id
	visible = true
	_busy = false
	_assistant_rtl = null
	_clear_messages()
	input.text = ""
	input.editable = true
	send_button.disabled = false
	call_deferred("_grab_focus")

func _grab_focus() -> void:
	if input != null:
		input.grab_focus()

func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()

func get_npc_id() -> String:
	return _npc_id

func set_busy(is_busy: bool) -> void:
	_busy = is_busy
	input.editable = not is_busy
	send_button.disabled = is_busy

func add_user_message(text: String) -> void:
	_add_message(true, text)

func set_history(items: Array) -> void:
	# items: [{role: "user"|"assistant", text: String}, ...]
	_assistant_rtl = null
	_clear_messages()
	for it0 in items:
		if typeof(it0) != TYPE_DICTIONARY:
			continue
		var it: Dictionary = it0 as Dictionary
		var role := String(it.get("role", ""))
		var text := String(it.get("text", ""))
		if text.strip_edges() == "":
			continue
		_add_message(role == "user", text)
	_scroll_to_bottom_deferred()

func begin_assistant() -> void:
	_assistant_rtl = _add_message(false, "")

func append_assistant_delta(delta: String) -> void:
	if _assistant_rtl == null:
		begin_assistant()
	_assistant_rtl.text += delta
	_scroll_to_bottom_deferred()

func end_assistant() -> void:
	_assistant_rtl = null

func _submit() -> void:
	if not visible or _busy:
		return
	var t := input.text.strip_edges()
	if t == "":
		return
	input.text = ""
	add_user_message(t)
	message_submitted.emit(t)

func _add_message(is_user: bool, text: String) -> RichTextLabel:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bubble := PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if is_user else Control.SIZE_SHRINK_BEGIN
	bubble.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var bubble_width := _get_bubble_width()
	bubble.custom_minimum_size = Vector2(bubble_width, 0.0)

	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.bg_color = Color(0.20, 0.45, 1.0, 0.22) if is_user else Color(1, 1, 1, 0.12)
	sb.border_color = Color(1, 1, 1, 0.14)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	bubble.add_theme_stylebox_override("panel", sb)

	var rtl := RichTextLabel.new()
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.bbcode_enabled = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.text = text
	rtl.selection_enabled = true
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# Force a sensible width so RichText doesn't wrap every character into a tall "barcode".
	rtl.custom_minimum_size = Vector2(maxf(0.0, bubble_width - 24.0), 0.0)

	bubble.add_child(rtl)

	if is_user:
		row.add_child(spacer)
		row.add_child(bubble)
	else:
		row.add_child(bubble)
		row.add_child(spacer)

	messages.add_child(row)
	_scroll_to_bottom_deferred()
	return rtl

func _get_bubble_width() -> float:
	var base_width := 0.0
	if panel != null and panel.size.x > 0.0:
		base_width = panel.size.x
	else:
		base_width = get_viewport_rect().size.x
	if base_width <= 0.0:
		base_width = 800.0

	var min_w := minf(_BUBBLE_MIN_WIDTH, base_width)
	var max_w := minf(_BUBBLE_MAX_WIDTH, base_width)
	return clampf(base_width * _BUBBLE_WIDTH_RATIO, min_w, max_w)

func _clear_messages() -> void:
	if messages == null:
		return
	for child0 in messages.get_children():
		var child := child0 as Node
		if child == null:
			continue
		messages.remove_child(child)
		child.queue_free()

func _scroll_to_bottom_deferred() -> void:
	call_deferred("_scroll_to_bottom")

func _scroll_to_bottom() -> void:
	if scroll == null:
		return
	var bar := scroll.get_v_scroll_bar()
	if bar != null:
		scroll.scroll_vertical = int(bar.max_value)
