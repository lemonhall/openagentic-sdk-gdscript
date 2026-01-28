extends Control

# v2 Slice 1: placeholder. UI layout + streaming integration lands in later slices.

func open(_npc_id: String, _display_name: String) -> void:
	visible = true

func close() -> void:
	visible = false

