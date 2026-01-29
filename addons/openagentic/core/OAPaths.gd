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

static func npc_workspace_dir(save_id: String, npc_id: String) -> String:
	return "%s/workspace" % npc_root(save_id, npc_id)

static func npc_skills_dir(save_id: String, npc_id: String) -> String:
	return "%s/skills" % npc_workspace_dir(save_id, npc_id)

static func npc_skill_dir(save_id: String, npc_id: String, skill_name: String) -> String:
	return "%s/%s" % [npc_skills_dir(save_id, npc_id), skill_name]

static func npc_skill_md_path(save_id: String, npc_id: String, skill_name: String) -> String:
	return "%s/SKILL.md" % npc_skill_dir(save_id, npc_id, skill_name)
