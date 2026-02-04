extends Control

signal message_submitted(text: String)
signal closed

const _OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")
const _OAMediaRef := preload("res://addons/openagentic/core/OAMediaRef.gd")
const _MediaCache := preload("res://vr_offices/ui/VrOfficesMediaCache.gd")

@onready var title_label: Label = %TitleLabel
@onready var session_log_size_label: Label = %SessionLogSizeLabel
@onready var clear_session_log_button: Button = %ClearSessionLogButton
@onready var messages: VBoxContainer = %Messages
@onready var scroll: ScrollContainer = %Scroll
@onready var input: LineEdit = %Input
@onready var send_button: Button = %SendButton
@onready var close_button: Button = %CloseButton
@onready var panel: Control = $Panel
@onready var backdrop: ColorRect = $Backdrop

var _npc_id: String = ""
var _npc_name: String = ""
var _save_id: String = ""

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
	if backdrop != null:
		backdrop.gui_input.connect(_on_backdrop_gui_input)
	if clear_session_log_button != null:
		clear_session_log_button.pressed.connect(_on_clear_session_log_pressed)

func _gui_input(event: InputEvent) -> void:
	# When the overlay is visible, it should "own" mouse interactions so that the
	# 3D camera rig doesn't treat clicks/drags/wheel as orbit/zoom/pan.
	if not visible:
		return
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		accept_event()

func _on_backdrop_gui_input(event: InputEvent) -> void:
	# Close the dialogue when the player clicks outside the panel:
	# - Right-click single
	# - Left double-click
	#
	# Also mark mouse events as handled so the 3D camera doesn't orbit/zoom while the
	# overlay is open.
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

func _on_send_pressed() -> void:
	_submit()

func _on_close_pressed() -> void:
	close()

func _on_input_submitted(_t: String) -> void:
	_submit()

func open(npc_id: String, npc_name: String, save_id: String = "") -> void:
	_npc_id = npc_id
	_npc_name = npc_name
	_save_id = save_id.strip_edges()
	title_label.text = _npc_name if _npc_name.strip_edges() != "" else _npc_id
	visible = true
	_busy = false
	_assistant_rtl = null
	_clear_messages()
	input.text = ""
	input.editable = true
	send_button.disabled = false
	_refresh_session_log_ui()
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
	_refresh_session_log_ui()

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
	var t := text.strip_edges()
	var media := _try_parse_media_ref(t)
	if typeof(media) == TYPE_DICTIONARY and bool((media as Dictionary).get("ok", false)):
		_add_media_message(is_user, (media as Dictionary).get("ref", {}))
		# Not a text message; return null.
		return null

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

func _try_parse_media_ref(text: String) -> Dictionary:
	if text == "" or text.length() > 512:
		return {}
	if not text.begins_with("OAMEDIA1 "):
		return {}
	var out: Dictionary = _OAMediaRef.decode_v1(text)
	return out if bool(out.get("ok", false)) else {}

func _add_media_message(is_user: bool, ref: Dictionary) -> void:
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

	var kind := String(ref.get("kind", "")).strip_edges()
	var mime := String(ref.get("mime", "")).strip_edges()
	if kind == "image" and (mime == "image/png" or mime == "image/jpeg"):
		var tr := TextureRect.new()
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.custom_minimum_size = Vector2(maxf(0.0, bubble_width - 24.0), 180.0)
		tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tr.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var sid := _resolve_save_id()
		var tex := _MediaCache.load_cached_image_texture(sid, ref)
		if tex != null:
			tr.texture = tex
		else:
			# Fallback placeholder (download will be added in later slices/e2e harness).
			var lbl := Label.new()
			lbl.text = "Image unavailable"
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bubble.add_child(lbl)
			_finish_media_row(is_user, row, spacer, bubble)
			return
		bubble.add_child(tr)
	else:
		var lbl2 := Label.new()
		lbl2.text = "Unsupported media"
		lbl2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bubble.add_child(lbl2)

	_finish_media_row(is_user, row, spacer, bubble)

func _finish_media_row(is_user: bool, row: HBoxContainer, spacer: Control, bubble: PanelContainer) -> void:
	if is_user:
		row.add_child(spacer)
		row.add_child(bubble)
	else:
		row.add_child(bubble)
		row.add_child(spacer)
	messages.add_child(row)
	_scroll_to_bottom_deferred()

# ---- test helpers ----

func _test_get_media_cache_path(ref: Dictionary) -> String:
	var sid := _resolve_save_id()
	return _MediaCache.media_cache_path(sid, ref)

func _test_has_any_image_message() -> bool:
	if messages == null:
		return false
	for row0 in messages.get_children():
		var row := row0 as Node
		if row == null:
			continue
		var tr := _find_texture_rect(row)
		if tr != null:
			return true
	return false

func _find_texture_rect(n: Node) -> TextureRect:
	if n is TextureRect:
		return n as TextureRect
	for c0 in n.get_children():
		var c := c0 as Node
		if c == null:
			continue
		var found := _find_texture_rect(c)
		if found != null:
			return found
	return null

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

func _resolve_save_id() -> String:
	if _save_id.strip_edges() != "":
		return _save_id.strip_edges()
	var oa := get_node_or_null("/root/OpenAgentic") as Node
	if oa == null:
		return ""
	var v: Variant = oa.get("save_id") if oa.has_method("get") else null
	return String(v).strip_edges() if v != null else ""

func _format_bytes(n: int) -> String:
	if n < 0:
		return "?"
	if n < 1024:
		return "%dB" % n
	if n < 1024 * 1024:
		return "%.1fKB (%dB)" % [float(n) / 1024.0, n]
	if n < 1024 * 1024 * 1024:
		return "%.1fMB (%dB)" % [float(n) / (1024.0 * 1024.0), n]
	return "%.1fGB (%dB)" % [float(n) / (1024.0 * 1024.0 * 1024.0), n]

func _session_events_path() -> String:
	if _npc_id.strip_edges() == "":
		return ""
	var sid := _resolve_save_id()
	if sid == "":
		return ""
	return String(_OAPaths.npc_events_path(sid, _npc_id))

func _read_file_len(path: String) -> int:
	if path.strip_edges() == "" or not FileAccess.file_exists(path):
		return 0
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var n := int(f.get_length())
	f.close()
	return n

func _refresh_session_log_ui() -> void:
	if session_log_size_label == null:
		return
	var path := _session_events_path()
	var bytes := -1
	if path != "":
		bytes = _read_file_len(path)
		session_log_size_label.text = "events.jsonl=%s" % _format_bytes(bytes)
		if path != "":
			var abs_path := ProjectSettings.globalize_path(path)
			session_log_size_label.tooltip_text = abs_path
			if clear_session_log_button != null:
				clear_session_log_button.tooltip_text = "Truncate: " + abs_path
	if clear_session_log_button != null:
		clear_session_log_button.disabled = _busy or path == ""

func _on_clear_session_log_pressed() -> void:
	if _busy:
		return
	var path := _session_events_path()
	if path == "":
		return
	# Ensure session dir exists so WRITE creates/overwrites the file reliably.
	var sid := _resolve_save_id()
	if sid != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_OAPaths.npc_session_dir(sid, _npc_id)))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string("")
		f.close()
	_assistant_rtl = null
	_clear_messages()
	_scroll_to_bottom_deferred()
	_refresh_session_log_ui()

func _scroll_to_bottom_deferred() -> void:
	call_deferred("_scroll_to_bottom")

func _scroll_to_bottom() -> void:
	if scroll == null:
		return
	var bar := scroll.get_v_scroll_bar()
	if bar != null:
		scroll.scroll_vertical = int(bar.max_value)
