extends SceneTree

const T := preload("res://tests/_test_util.gd")
const IrcMessage := preload("res://addons/irc_client/IrcMessage.gd")

class FakeDeskIrcLink:
	extends Node

	signal message_received(msg: RefCounted)

	var desired_channel := "#oa-test"
	var nick := "oa_desk_test"
	var sent: Array[String] = []

	func get_desired_channel() -> String:
		return desired_channel

	func get_nick() -> String:
		return nick

	func send_channel_message(text: String) -> void:
		sent.append(text)

class FakeOpenAgentic:
	extends Node

	var calls: Array[Dictionary] = []

	func run_npc_turn(npc_id: String, user_text: String, on_event: Callable) -> void:
		calls.append({"npc_id": npc_id, "user_text": user_text})
		on_event.call({"type": "assistant.delta", "text_delta": "ACK:"})
		on_event.call({"type": "assistant.delta", "text_delta": user_text})
		await get_tree().process_frame
		on_event.call({"type": "result"})

func _init() -> void:
	var oa := FakeOpenAgentic.new()
	oa.name = "OpenAgentic"
	get_root().add_child(oa)

	var floor := _make_floor()
	get_root().add_child(floor)

	var desk_scene := load("res://vr_offices/furniture/StandingDesk.tscn")
	if desk_scene == null or not (desk_scene is PackedScene):
		T.fail_and_quit(self, "Missing res://vr_offices/furniture/StandingDesk.tscn")
		return
	var desk := (desk_scene as PackedScene).instantiate() as Node3D
	if desk == null:
		T.fail_and_quit(self, "Failed to instantiate StandingDesk.tscn")
		return
	if desk.has_method("configure"):
		desk.call("configure", "desk_1", "ws_1")
	get_root().add_child(desk)
	await process_frame

	var indicator := desk.get_node_or_null("NpcBindIndicator") as Node3D
	if not T.require_true(self, indicator != null, "Missing StandingDesk/NpcBindIndicator"):
		return
	if not T.require_true(self, float(indicator.position.y) <= 0.2, "NpcBindIndicator must sit near the floor, got y=%s" % [str(indicator.position.y)]):
		return

	var visual := indicator.get_node_or_null("Visual") as Node
	if not T.require_true(self, visual != null, "Missing NpcBindIndicator/Visual"):
		return
	var unbound_color := Color(0, 0, 0, 0)
	if visual.has_method("get"):
		var c0: Variant = visual.get("color")
		if c0 is Color:
			unbound_color = c0 as Color

	var npc_scene := load("res://vr_offices/npc/Npc.tscn")
	if npc_scene == null or not (npc_scene is PackedScene):
		T.fail_and_quit(self, "Missing res://vr_offices/npc/Npc.tscn")
		return
	var npc1 := (npc_scene as PackedScene).instantiate() as Node3D
	npc1.name = "npc_a"
	if npc1.has_method("set"):
		npc1.set("npc_id", "npc_a")
	npc1.position = Vector3(0.0, 0.0, 0.0)
	get_root().add_child(npc1)

	var npc2 := (npc_scene as PackedScene).instantiate() as Node3D
	npc2.name = "npc_b"
	if npc2.has_method("set"):
		npc2.set("npc_id", "npc_b")
	npc2.position = Vector3(0.0, 0.0, 0.2)
	get_root().add_child(npc2)
	await _wait_on_floor(npc1)

	var area := indicator.get_node_or_null("Area") as Area3D
	if not T.require_true(self, area != null, "Missing NpcBindIndicator/Area"):
		return

	# Bind: first NPC should win.
	area.emit_signal("body_entered", npc1)
	await process_frame

	if not T.require_eq(self, String(npc1.call("get_bound_desk_id")), "desk_1", "NPC must become desk-bound on enter"):
		return
	if not T.require_eq(self, String(npc2.call("get_bound_desk_id")), "", "Other NPC must not steal binding"):
		return

	# Color should change on bind.
	var bound_color := Color(0, 0, 0, 0)
	if visual.has_method("get"):
		var c1: Variant = visual.get("color")
		if c1 is Color:
			bound_color = c1 as Color
	if not T.require_true(self, bound_color != unbound_color, "Indicator color must change between unbound/bound"):
		return
	if not T.require_true(self, bound_color.g > bound_color.r, "Bound indicator should be green-ish"):
		return

	# Entering with another NPC should not change binding.
	area.emit_signal("body_entered", npc2)
	await process_frame
	if not T.require_eq(self, String(npc1.call("get_bound_desk_id")), "desk_1", "Binding must remain on first NPC"):
		return
	if not T.require_eq(self, String(npc2.call("get_bound_desk_id")), "", "Second NPC still not bound"):
		return

	# Unbind should only happen when the bound NPC exits.
	area.emit_signal("body_exited", npc2)
	await process_frame
	if not T.require_eq(self, String(npc1.call("get_bound_desk_id")), "desk_1", "Unrelated exit must not unbind"):
		return

	area.emit_signal("body_exited", npc1)
	await process_frame
	if not T.require_eq(self, String(npc1.call("get_bound_desk_id")), "", "Bound NPC exit must unbind"):
		return
	if not T.require_true(self, bool(npc1.get("wander_enabled")), "Unbound NPC should return to wandering"):
		return

	# Normal move-to: should enter waiting-for-work.
	npc1.call("command_move_to", Vector3(0.0, 0.0, 0.0))
	await process_frame
	await process_frame
	if not T.require_true(self, float(npc1.get("_waiting_for_work_left")) > 0.0, "Normal move-to should start waiting-for-work"):
		return

	# Desk-bound move-to: should skip waiting-for-work after leaving desk.
	npc1.call("on_desk_bound", "desk_1")
	npc1.call("command_move_to", Vector3(0.0, 0.0, 0.0))
	npc1.call("on_desk_unbound", "desk_1")
	await process_frame
	await process_frame
	if not T.require_true(self, float(npc1.get("_waiting_for_work_left")) <= 0.0, "Move-to after desk-unbind should skip waiting-for-work"):
		return
	if not T.require_true(self, bool(npc1.get("wander_enabled")), "After desk-unbind move, NPC should resume wandering"):
		return

	# Desk channel bridge: PRIVMSG should trigger an OpenAgentic turn and reply back.
	var link := FakeDeskIrcLink.new()
	link.name = "DeskIrcLink"
	desk.add_child(link)
	await process_frame

	area.emit_signal("body_entered", npc1)
	await process_frame

	var msg := IrcMessage.new()
	msg.prefix = "alice!u@h"
	msg.command = "PRIVMSG"
	msg.params = [link.desired_channel]
	msg.trailing = "hello"
	link.message_received.emit(msg)

	# Wait for the async fake OpenAgentic turn to finish.
	for _i in range(6):
		await process_frame

	if not T.require_true(self, not oa.calls.is_empty(), "Desk IRC message should trigger OpenAgentic.run_npc_turn"):
		return
	if not T.require_eq(self, String(oa.calls[-1].get("npc_id")), "npc_a", "OpenAgentic must run bound NPC id"):
		return
	if not T.require_eq(self, String(oa.calls[-1].get("user_text")), "hello", "OpenAgentic must receive IRC trailing text"):
		return
	if not T.require_true(self, not link.sent.is_empty(), "Desk IRC bridge must send a reply message"):
		return

	T.pass_and_quit(self)

func _make_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "Floor"
	# NPCs collide with layer 1.
	floor.collision_layer = 1
	floor.collision_mask = 0

	var shape := BoxShape3D.new()
	shape.size = Vector3(20.0, 0.2, 20.0)

	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0.0, -0.1, 0.0)

	floor.add_child(cs)
	return floor

func _wait_on_floor(npc: Node) -> void:
	for _i in range(60):
		await process_frame
		if npc != null and is_instance_valid(npc) and npc.has_method("is_on_floor") and bool(npc.call("is_on_floor")):
			return

