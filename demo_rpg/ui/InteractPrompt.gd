extends Control

# v2 Slice 1: placeholder. Proximity prompt wiring lands in later slices.

func set_prompt_text(t: String) -> void:
	var label := get_node_or_null("Label") as Label
	if label != null:
		label.text = t

