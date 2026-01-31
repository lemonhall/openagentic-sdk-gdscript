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

	func list_desk_irc_snapshots() -> Array:
		return [{
			"desk_id": "desk_1",
			"workspace_id": "ws_1",
			"device_code": "ABCD1234",
			"bound_npc_id": "npc_a",
			"bound_npc_name": "Alice",
			"desired_channel": "#c",
			"status": "joined",
			"ready": true,
			"log_file_user": "user://openagentic/saves/slot1/vr_offices/desks/desk_1/irc.log",
			"log_file_abs": "/abs/path/irc.log",
			"log_lines": ["[t] hello"],
		}]

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
	var desks := FakeDeskManager.new()

	overlay.call("bind", world, desks)
	overlay.call("open")
	await process_frame

	var copy_btn := overlay.get_node_or_null("%CopyDeskInfoButton") as Button
	if not T.require_true(self, copy_btn != null, "Missing CopyDeskInfoButton"):
		return
	var divider := overlay.get_node_or_null("%DeskDivider") as Control
	if not T.require_true(self, divider != null, "Missing DeskDivider"):
		return
	var info_label := overlay.get_node_or_null("%DeskInfoLabel") as Label
	if not T.require_true(self, info_label != null, "Missing DeskInfoLabel"):
		return

	# Disabled until a desk is selected.
	if not T.require_true(self, copy_btn.disabled, "CopyDeskInfoButton should start disabled"):
		return

	# Select first desk -> copy button becomes enabled.
	overlay.call("_on_desk_selected", 0)
	await process_frame
	if not T.require_true(self, not copy_btn.disabled, "CopyDeskInfoButton should enable after selecting a desk"):
		return
	var info := info_label.text
	if not T.require_true(self, info.find("device_code=ABCD1234") != -1, "Desk info should include device_code"):
		return
	if not T.require_true(self, info.find("bound_npc_id=npc_a") != -1, "Desk info should include bound_npc_id"):
		return
	if not T.require_true(self, info.find("bound_npc_name=Alice") != -1, "Desk info should include bound_npc_name"):
		return

	get_root().remove_child(overlay)
	overlay.free()
	await process_frame
	world.free()
	T.pass_and_quit(self)
