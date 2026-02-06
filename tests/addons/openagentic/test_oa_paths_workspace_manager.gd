extends SceneTree

const T := preload("res://tests/_test_util.gd")
const OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")

func _init() -> void:
	var save_id := "slot_test_paths_manager"
	var workspace_id := "ws_7"

	var root := String(OAPaths.workspace_manager_root(save_id, workspace_id))
	if not T.require_eq(self, root, "user://openagentic/saves/slot_test_paths_manager/workspaces/ws_7/manager", "workspace_manager_root path mismatch"):
		return

	var session_dir := String(OAPaths.workspace_manager_session_dir(save_id, workspace_id))
	if not T.require_eq(self, session_dir, root + "/session", "workspace_manager_session_dir path mismatch"):
		return

	var events := String(OAPaths.workspace_manager_events_path(save_id, workspace_id))
	if not T.require_eq(self, events, root + "/session/events.jsonl", "workspace_manager_events_path path mismatch"):
		return

	var mem := String(OAPaths.workspace_manager_summary_path(save_id, workspace_id))
	if not T.require_eq(self, mem, root + "/memory/summary.txt", "workspace_manager_summary_path path mismatch"):
		return

	var ws := String(OAPaths.workspace_manager_workspace_dir(save_id, workspace_id))
	if not T.require_eq(self, ws, root + "/workspace", "workspace_manager_workspace_dir path mismatch"):
		return

	var skills := String(OAPaths.workspace_manager_skills_dir(save_id, workspace_id))
	if not T.require_eq(self, skills, root + "/workspace/skills", "workspace_manager_skills_dir path mismatch"):
		return

	T.pass_and_quit(self)
