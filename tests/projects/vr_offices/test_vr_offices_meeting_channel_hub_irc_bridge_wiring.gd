extends SceneTree

const T := preload("res://tests/_test_util.gd")

class FakeBridge:
	extends Node

	var joins: Array[Dictionary] = []
	var parts: Array[Dictionary] = []
	var human_msgs: Array[Dictionary] = []
	var npc_msgs: Array[Dictionary] = []

	func join_participant(meeting_room_id: String, npc_id: String, display_name: String, irc_nick: String, channel: String) -> void:
		joins.append({
			"meeting_room_id": meeting_room_id,
			"npc_id": npc_id,
			"display_name": display_name,
			"irc_nick": irc_nick,
			"channel": channel,
		})

	func part_participant(meeting_room_id: String, npc_id: String) -> void:
		parts.append({"meeting_room_id": meeting_room_id, "npc_id": npc_id})

	func send_human_message(meeting_room_id: String, text: String) -> void:
		human_msgs.append({"meeting_room_id": meeting_room_id, "text": text})

	func send_npc_message(meeting_room_id: String, npc_id: String, text: String) -> void:
		npc_msgs.append({"meeting_room_id": meeting_room_id, "npc_id": npc_id, "text": text})

class FakeOpenAgentic:
	extends Node

	func run_npc_turn(_npc_id: String, user_text: String, on_event: Callable) -> void:
		on_event.call({"type": "assistant.delta", "text_delta": "ACK:"})
		on_event.call({"type": "assistant.delta", "text_delta": user_text})
		await get_tree().process_frame
		on_event.call({"type": "result"})

func _init() -> void:
	var HubScript := load("res://vr_offices/core/meeting_rooms/VrOfficesMeetingRoomChannelHub.gd")
	if HubScript == null or not (HubScript is Script) or not (HubScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing or invalid VrOfficesMeetingRoomChannelHub.gd")
		return

	var oa := FakeOpenAgentic.new()
	get_root().add_child(oa)
	await process_frame

	var bridge := FakeBridge.new()
	get_root().add_child(bridge)
	await process_frame

	var npc := Node.new()
	npc.name = "npc_01"
	npc.set("npc_id", "npc_01")
	npc.set("display_name", "Alice")
	get_root().add_child(npc)
	await process_frame

	var hub := (HubScript as Script).new(
		oa,
		func() -> String: return "slot_test",
		func(id: String) -> Node:
			return npc if id.strip_edges() == "npc_01" else null
	) as RefCounted
	if hub == null:
		T.fail_and_quit(self, "Failed to instantiate channel hub")
		return
	if not hub.has_method("set_irc_bridge"):
		T.fail_and_quit(self, "Channel hub must support set_irc_bridge(...)")
		return
	hub.call("set_irc_bridge", bridge)

	hub.call("join_participant", "room_1", npc)
	if not T.require_true(self, bridge.joins.size() == 1, "Expected join_participant forwarded to IRC bridge"):
		return
	var ch := String(bridge.joins[0].get("channel", ""))
	if not T.require_true(self, ch.begins_with("#"), "Expected derived channel to start with #"):
		return

	await hub.call("broadcast_human_message", "room_1", "meetingroom_room_1", "hello", null)
	for _i in range(3):
		await process_frame
	if not T.require_true(self, bridge.human_msgs.size() == 1, "Expected send_human_message forwarded to IRC bridge"):
		return
	if not T.require_true(self, bridge.npc_msgs.size() >= 1, "Expected at least one send_npc_message forwarded to IRC bridge"):
		return

	hub.call("part_participant", "room_1", "npc_01")
	if not T.require_true(self, bridge.parts.size() == 1, "Expected part_participant forwarded to IRC bridge"):
		return

	T.pass_and_quit(self)
