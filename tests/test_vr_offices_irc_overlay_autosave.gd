extends SceneTree

const T := preload("res://tests/_test_util.gd")

class FakeWorld:
	extends Node
	var cfg: Dictionary = {}
	var saved: Dictionary = {}

	func get_irc_config() -> Dictionary:
		return cfg.duplicate(true)

	func set_irc_config(c: Dictionary) -> void:
		saved = c.duplicate(true)

func _init() -> void:
	var scene := load("res://vr_offices/ui/IrcOverlay.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing res://vr_offices/ui/IrcOverlay.tscn")
		return

	var overlay := (scene as PackedScene).instantiate() as Control
	if overlay == null:
		T.fail_and_quit(self, "Failed to instantiate IrcOverlay")
		return
	get_root().add_child(overlay)
	await process_frame

	var world := FakeWorld.new()
	world.cfg = {"host": "", "port": 6667, "tls": false, "test_nick": "tester", "test_channel": "#test"}
	overlay.call("bind", world, null)
	overlay.call("open")
	await process_frame

	# UX: no redundant Enabled checkbox (saving a host is enough).
	if not T.require_true(self, overlay.get_node_or_null("%EnabledCheck") == null, "EnabledCheck should be removed from IrcOverlay"):
		return

	# Set host, then use Test connect without explicitly clicking Save.
	var host_edit := overlay.get_node_or_null("%HostEdit") as LineEdit
	if not T.require_true(self, host_edit != null, "Missing HostEdit"):
		return
	host_edit.text = "irc.example.net"

	overlay.call("_on_test_connect_pressed")
	await process_frame

	if not T.require_eq(self, String(world.saved.get("host", "")), "irc.example.net", "Test connect should persist host via set_irc_config"):
		return
	if not T.require_true(self, not world.saved.has("enabled"), "Saved config should not include `enabled`"):
		return

	get_root().remove_child(overlay)
	overlay.free()
	await process_frame
	T.pass_and_quit(self)
