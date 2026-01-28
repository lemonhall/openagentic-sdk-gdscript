extends Control

func show_for(display_name: String) -> void:
	set_prompt_text("Press E to talk to %s" % display_name)
	visible = true

func hide_prompt() -> void:
	visible = false

func set_prompt_text(t: String) -> void:
	var label := get_node_or_null("Label") as Label
	if label != null:
		label.text = t
