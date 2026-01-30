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

class FakeDeskManager:
	extends RefCounted
	var reconnect_calls := 0

	func reconnect_all_irc_links() -> void:
		reconnect_calls += 1

	func list_desk_irc_snapshots() -> Array:
		return []

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
	world.cfg = {"enabled": false, "host": "", "port": 6667, "tls": false, "test_nick": "tester", "test_channel": "#test"}
	var desks := FakeDeskManager.new()

	overlay.call("bind", world, desks)
	overlay.call("open")
	await process_frame

	var btn := overlay.get_node_or_null("%ReconnectAllButton") as Button
	if not T.require_true(self, btn != null, "Missing ReconnectAllButton in IrcOverlay Desks tab"):
		return

	btn.emit_signal("pressed")
	await process_frame

	if not T.require_eq(self, int(desks.reconnect_calls), 1, "ReconnectAllButton should call desk_manager.reconnect_all_irc_links()"):
		return

	get_root().remove_child(overlay)
	overlay.free()
	await process_frame
	T.pass_and_quit(self)

