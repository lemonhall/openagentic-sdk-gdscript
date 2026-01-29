extends Control

signal add_npc_pressed
signal remove_selected_pressed
signal culture_changed(culture_code: String)

@onready var selected_label: Label = %SelectedLabel
@onready var add_button: Button = %AddNpcButton
@onready var remove_button: Button = %RemoveSelectedButton
@onready var status_label: Label = %StatusLabel
@onready var culture_option: OptionButton = %CultureOption

func _ready() -> void:
	add_button.pressed.connect(_on_add_pressed)
	remove_button.pressed.connect(_on_remove_pressed)

	set_selected_text("")
	set_status_text("")
	_setup_culture_options()

func _on_add_pressed() -> void:
	add_npc_pressed.emit()

func _on_remove_pressed() -> void:
	remove_selected_pressed.emit()

func _setup_culture_options() -> void:
	culture_option.clear()
	culture_option.add_item("中文 (zh-CN)")
	culture_option.set_item_metadata(0, "zh-CN")
	culture_option.add_item("English (en-US)")
	culture_option.set_item_metadata(1, "en-US")
	culture_option.add_item("日本語 (ja-JP)")
	culture_option.set_item_metadata(2, "ja-JP")

	culture_option.item_selected.connect(_on_culture_selected)

func _on_culture_selected(idx: int) -> void:
	var meta: Variant = culture_option.get_item_metadata(idx)
	var code: String = String(meta) if meta != null else ""
	if code.strip_edges() != "":
		culture_changed.emit(code)

func set_selected_text(text: String) -> void:
	if text.strip_edges() == "":
		selected_label.text = "Selected: (none)"
	else:
		selected_label.text = "Selected: " + text

func set_status_text(text: String) -> void:
	status_label.text = text

func set_can_add(can_add: bool) -> void:
	add_button.disabled = not can_add

func set_culture(code: String) -> void:
	for i in range(culture_option.item_count):
		var meta: Variant = culture_option.get_item_metadata(i)
		if String(meta) == code:
			culture_option.select(i)
			return
