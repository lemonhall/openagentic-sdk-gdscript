extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var StoreScript := load("res://addons/openagentic/core/OAJsonlNpcSessionStore.gd")
	if StoreScript == null:
		T.fail_and_quit(self, "Missing OAJsonlNpcSessionStore.gd")
		return

	var save_id := "slot_test_1_%s" % str(Time.get_ticks_msec())
	var store = StoreScript.new(save_id)
	var npc_id := "npc_1"

	store.append_event(npc_id, {"type": "user.message", "text": "hi"})
	store.append_event(npc_id, {"type": "assistant.message", "text": "hello"})

	var events: Array = store.read_events(npc_id)
	if not T.require_eq(self, events.size(), 2, "expected 2 events"):
		return
	if not T.require_eq(self, String((events[0] as Dictionary).get("type", "")), "user.message"):
		return
	if not T.require_eq(self, int((events[0] as Dictionary).get("seq", 0)), 1):
		return
	if not T.require_eq(self, int((events[1] as Dictionary).get("seq", 0)), 2):
		return

	T.pass_and_quit(self)
