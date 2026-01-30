extends RefCounted

const _SessionStoreScript := preload("res://addons/openagentic/core/OAJsonlNpcSessionStore.gd")

func read_ui_history(save_id: String, npc_id: String) -> Array:
	# Translate the persisted per-NPC JSONL event log into a simple UI chat history.
	# Only include final user/assistant messages (ignore deltas/tool events).
	var out: Array = []
	if save_id.strip_edges() == "" or npc_id.strip_edges() == "":
		return out

	var store = _SessionStoreScript.new(save_id)
	var events: Array = store.read_events(npc_id)
	for e0 in events:
		if typeof(e0) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = e0 as Dictionary
		var typ := String(e.get("type", ""))
		if typ == "user.message":
			var tx0: Variant = e.get("text", null)
			if typeof(tx0) == TYPE_STRING:
				out.append({"role": "user", "text": String(tx0)})
		elif typ == "assistant.message":
			var tx1: Variant = e.get("text", null)
			if typeof(tx1) == TYPE_STRING:
				out.append({"role": "assistant", "text": String(tx1)})
	return out

