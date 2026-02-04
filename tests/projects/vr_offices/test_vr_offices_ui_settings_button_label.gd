extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var UiScene := load("res://vr_offices/ui/VrOfficesUi.tscn")
	if UiScene == null:
		T.fail_and_quit(self, "Missing VrOfficesUi.tscn")
		return
	var ui: Control = (UiScene as PackedScene).instantiate()
	get_root().add_child(ui)
	await process_frame

	var btn := ui.get_node_or_null("Panel/VBox/Buttons/IrcButton") as Button
	if not T.require_true(self, btn != null, "Missing IrcButton"):
		return
	if not T.require_eq(self, btn.text, "Settings…", "Expected Settings button label"):
		return

	T.pass_and_quit(self)

