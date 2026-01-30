extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var scene := load("res://demo_irc/Main.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing res://demo_irc/Main.tscn")
		return

	var main := (scene as PackedScene).instantiate()
	if main == null:
		T.fail_and_quit(self, "Failed to instantiate demo_irc/Main.tscn")
		return

	if not T.require_true(self, main.name == "Main", "demo_irc/Main.tscn root must be named 'Main'"):
		return

	# UI expectations.
	if not T.require_true(self, main.get_node_or_null("Root") != null, "Missing node Main/Root"):
		return
	if not T.require_true(self, main.get_node_or_null("Root/ConnectionPanel") != null, "Missing node Main/Root/ConnectionPanel"):
		return

	if not T.require_true(self, main.get_node_or_null("Root/ConnectionPanel/VBox/Fields/Host") != null, "Missing node Main/Root/ConnectionPanel/VBox/Fields/Host"):
		return
	if not T.require_true(self, main.get_node_or_null("Root/ConnectionPanel/VBox/Fields/Port") != null, "Missing node Main/Root/ConnectionPanel/VBox/Fields/Port"):
		return
	if not T.require_true(self, main.get_node_or_null("Root/ConnectionPanel/VBox/Fields/Tls") != null, "Missing node Main/Root/ConnectionPanel/VBox/Fields/Tls"):
		return
	if not T.require_true(self, main.get_node_or_null("Root/ConnectionPanel/VBox/Fields/Nick") != null, "Missing node Main/Root/ConnectionPanel/VBox/Fields/Nick"):
		return
	if not T.require_true(self, main.get_node_or_null("Root/ConnectionPanel/VBox/Fields/User") != null, "Missing node Main/Root/ConnectionPanel/VBox/Fields/User"):
		return
	if not T.require_true(self, main.get_node_or_null("Root/ConnectionPanel/VBox/Fields/Realname") != null, "Missing node Main/Root/ConnectionPanel/VBox/Fields/Realname"):
		return
	if not T.require_true(self, main.get_node_or_null("Root/ConnectionPanel/VBox/Fields/Channel") != null, "Missing node Main/Root/ConnectionPanel/VBox/Fields/Channel"):
		return

	if not T.require_true(self, main.get_node_or_null("Root/ConnectionPanel/VBox/Buttons/Connect") != null, "Missing node Main/Root/ConnectionPanel/VBox/Buttons/Connect"):
		return
	if not T.require_true(self, main.get_node_or_null("Root/ConnectionPanel/VBox/Buttons/Disconnect") != null, "Missing node Main/Root/ConnectionPanel/VBox/Buttons/Disconnect"):
		return
	if not T.require_true(self, main.get_node_or_null("Root/ConnectionPanel/VBox/Buttons/Join") != null, "Missing node Main/Root/ConnectionPanel/VBox/Buttons/Join"):
		return

	if not T.require_true(self, main.get_node_or_null("Root/ChatLog") != null, "Missing node Main/Root/ChatLog"):
		return
	if not T.require_true(self, main.get_node_or_null("Root/InputRow/Input") != null, "Missing node Main/Root/InputRow/Input"):
		return
	if not T.require_true(self, main.get_node_or_null("Root/InputRow/Send") != null, "Missing node Main/Root/InputRow/Send"):
		return

	main.queue_free()
	T.pass_and_quit(self)
