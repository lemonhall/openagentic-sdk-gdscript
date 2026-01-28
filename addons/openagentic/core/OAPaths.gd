extends RefCounted
class_name OAPaths

static func save_root(save_id: String) -> String:
	return "user://openagentic/saves/%s" % save_id

static func npc_root(save_id: String, npc_id: String) -> String:
	return "%s/npcs/%s" % [save_root(save_id), npc_id]

static func npc_session_dir(save_id: String, npc_id: String) -> String:
	return "%s/session" % npc_root(save_id, npc_id)

static func npc_events_path(save_id: String, npc_id: String) -> String:
	return "%s/events.jsonl" % npc_session_dir(save_id, npc_id)

static func npc_meta_path(save_id: String, npc_id: String) -> String:
	return "%s/meta.json" % npc_session_dir(save_id, npc_id)

static func npc_state_path(save_id: String, npc_id: String) -> String:
	return "%s/state.json" % npc_session_dir(save_id, npc_id)

static func shared_world_summary_path(save_id: String) -> String:
	return "%s/shared/world_summary.txt" % save_root(save_id)

static func npc_summary_path(save_id: String, npc_id: String) -> String:
	return "%s/memory/summary.txt" % npc_root(save_id, npc_id)

