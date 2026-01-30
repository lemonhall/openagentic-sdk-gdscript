extends Control

@onready var panel: PanelContainer = $Panel
@onready var label: Label = $Panel/Label

func show_hint(text: String) -> void:
	if label != null:
		label.text = text
	visible = true

func hide_hint() -> void:
	visible = false

