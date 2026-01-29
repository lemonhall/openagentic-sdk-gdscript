extends Control

@onready var label: Label = %SavingLabel

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

func show_saving(text: String = "Saving…") -> void:
	if label != null:
		label.text = text
	visible = true

func hide_saving() -> void:
	visible = false

