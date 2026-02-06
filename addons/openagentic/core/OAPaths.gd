extends RefCounted
class_name OAPaths

const WORKSPACE_MANAGER_NPC_PREFIX := "workspace_manager__"

static func save_root(save_id: String) -> String:
	return "user://openagentic/saves/%s" % save_id

static func workspace_root(save_id: String, workspace_id: String) -> String:
	return "%s/workspaces/%s" % [save_root(save_id), workspace_id]

static func workspace_manager_root(save_id: String, workspace_id: String) -> String:
	return "%s/manager" % workspace_root(save_id, workspace_id)

static func workspace_manager_session_dir(save_id: String, workspace_id: String) -> String:
	return "%s/session" % workspace_manager_root(save_id, workspace_id)

static func workspace_manager_events_path(save_id: String, workspace_id: String) -> String:
	return "%s/events.jsonl" % workspace_manager_session_dir(save_id, workspace_id)

static func workspace_manager_meta_path(save_id: String, workspace_id: String) -> String:
	return "%s/meta.json" % workspace_manager_session_dir(save_id, workspace_id)

static func workspace_manager_state_path(save_id: String, workspace_id: String) -> String:
	return "%s/state.json" % workspace_manager_session_dir(save_id, workspace_id)

static func workspace_manager_summary_path(save_id: String, workspace_id: String) -> String:
	return "%s/memory/summary.txt" % workspace_manager_root(save_id, workspace_id)

static func workspace_manager_workspace_dir(save_id: String, workspace_id: String) -> String:
	return "%s/workspace" % workspace_manager_root(save_id, workspace_id)

static func workspace_manager_skills_dir(save_id: String, workspace_id: String) -> String:
	return "%s/skills" % workspace_manager_workspace_dir(save_id, workspace_id)

static func workspace_manager_skill_dir(save_id: String, workspace_id: String, skill_name: String) -> String:
	return "%s/%s" % [workspace_manager_skills_dir(save_id, workspace_id), skill_name]

static func workspace_manager_skill_md_path(save_id: String, workspace_id: String, skill_name: String) -> String:
	return "%s/SKILL.md" % workspace_manager_skill_dir(save_id, workspace_id, skill_name)

static func workspace_manager_npc_id(workspace_id: String) -> String:
	var wid := workspace_id.strip_edges()
	if wid == "":
		return WORKSPACE_MANAGER_NPC_PREFIX
	return "%s%s" % [WORKSPACE_MANAGER_NPC_PREFIX, wid]

static func workspace_id_from_manager_npc_id(npc_id: String) -> String:
	var nid := npc_id.strip_edges()
	if not nid.begins_with(WORKSPACE_MANAGER_NPC_PREFIX):
		return ""
	return nid.substr(WORKSPACE_MANAGER_NPC_PREFIX.length()).strip_edges()

static func npc_root(save_id: String, npc_id: String) -> String:
	var workspace_id := workspace_id_from_manager_npc_id(npc_id)
	if workspace_id != "":
		return workspace_manager_root(save_id, workspace_id)
	return "%s/npcs/%s" % [save_root(save_id), npc_id]

static func npc_session_dir(save_id: String, npc_id: String) -> String:
	var workspace_id := workspace_id_from_manager_npc_id(npc_id)
	if workspace_id != "":
		return workspace_manager_session_dir(save_id, workspace_id)
	return "%s/session" % npc_root(save_id, npc_id)

static func npc_events_path(save_id: String, npc_id: String) -> String:
	var workspace_id := workspace_id_from_manager_npc_id(npc_id)
	if workspace_id != "":
		return workspace_manager_events_path(save_id, workspace_id)
	return "%s/events.jsonl" % npc_session_dir(save_id, npc_id)

static func npc_meta_path(save_id: String, npc_id: String) -> String:
	var workspace_id := workspace_id_from_manager_npc_id(npc_id)
	if workspace_id != "":
		return workspace_manager_meta_path(save_id, workspace_id)
	return "%s/meta.json" % npc_session_dir(save_id, npc_id)

static func npc_state_path(save_id: String, npc_id: String) -> String:
	var workspace_id := workspace_id_from_manager_npc_id(npc_id)
	if workspace_id != "":
		return workspace_manager_state_path(save_id, workspace_id)
	return "%s/state.json" % npc_session_dir(save_id, npc_id)

static func shared_world_summary_path(save_id: String) -> String:
	return "%s/shared/world_summary.txt" % save_root(save_id)

static func npc_summary_path(save_id: String, npc_id: String) -> String:
	var workspace_id := workspace_id_from_manager_npc_id(npc_id)
	if workspace_id != "":
		return workspace_manager_summary_path(save_id, workspace_id)
	return "%s/memory/summary.txt" % npc_root(save_id, npc_id)

static func npc_workspace_dir(save_id: String, npc_id: String) -> String:
	var workspace_id := workspace_id_from_manager_npc_id(npc_id)
	if workspace_id != "":
		return workspace_manager_workspace_dir(save_id, workspace_id)
	return "%s/workspace" % npc_root(save_id, npc_id)

static func npc_skills_dir(save_id: String, npc_id: String) -> String:
	var workspace_id := workspace_id_from_manager_npc_id(npc_id)
	if workspace_id != "":
		return workspace_manager_skills_dir(save_id, workspace_id)
	return "%s/skills" % npc_workspace_dir(save_id, npc_id)

static func npc_skill_dir(save_id: String, npc_id: String, skill_name: String) -> String:
	var workspace_id := workspace_id_from_manager_npc_id(npc_id)
	if workspace_id != "":
		return workspace_manager_skill_dir(save_id, workspace_id, skill_name)
	return "%s/%s" % [npc_skills_dir(save_id, npc_id), skill_name]

static func npc_skill_md_path(save_id: String, npc_id: String, skill_name: String) -> String:
	var workspace_id := workspace_id_from_manager_npc_id(npc_id)
	if workspace_id != "":
		return workspace_manager_skill_md_path(save_id, workspace_id, skill_name)
	return "%s/SKILL.md" % npc_skill_dir(save_id, npc_id, skill_name)
