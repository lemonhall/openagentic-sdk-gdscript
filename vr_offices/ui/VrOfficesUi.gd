extends Control

signal add_npc_pressed
signal remove_selected_pressed

@onready var selected_label: Label = %SelectedLabel
@onready var add_button: Button = %AddNpcButton
@onready var remove_button: Button = %RemoveSelectedButton

func _ready() -> void:
	add_button.pressed.connect(func() -> void:
		add_npc_pressed.emit()
	)
	remove_button.pressed.connect(func() -> void:
		remove_selected_pressed.emit()
	)

	set_selected_text("")

func set_selected_text(text: String) -> void:
	if text.strip_edges() == "":
		selected_label.text = "Selected: (none)"
	else:
		selected_label.text = "Selected: " + text

