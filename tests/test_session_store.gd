extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var StoreScript := load("res://addons/openagentic/core/OAJsonlNpcSessionStore.gd")
	if StoreScript == null:
		T.fail_and_quit(self, "Missing OAJsonlNpcSessionStore.gd")
		return

	var store = StoreScript.new("slot_test_1")
	var npc_id := "npc_1"

	store.append_event(npc_id, {"type": "user.message", "text": "hi"})
	store.append_event(npc_id, {"type": "assistant.message", "text": "hello"})

	var events: Array = store.read_events(npc_id)
	T.assert_eq(events.size(), 2, "expected 2 events")
	T.assert_eq(events[0].type, "user.message")
	T.assert_eq(events[0].seq, 1)
	T.assert_eq(events[1].seq, 2)

	T.pass_and_quit(self)
