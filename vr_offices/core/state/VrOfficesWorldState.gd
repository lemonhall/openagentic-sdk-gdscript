extends RefCounted

const _OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")

func state_path(save_id: String) -> String:
	return "%s/vr_offices/state.json" % _OAPaths.save_root(save_id)

func read_state(save_id: String) -> Dictionary:
	var path := state_path(save_id)
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func write_state(save_id: String, state: Dictionary) -> void:
	var path := state_path(save_id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(state) + "\n")
	f.close()

func build_state(
	save_id: String,
	culture_code: String,
	npc_counter: int,
	npc_root: Node,
	workspaces: Array = [],
	workspace_counter: int = 0,
	desks: Array = [],
	desk_counter: int = 0,
	irc: Dictionary = {}
) -> Dictionary:
	var npcs: Array = []
	if npc_root != null:
		for child0 in npc_root.get_children():
			var child := child0 as Node
			if child == null:
				continue
			if not child.has_method("get"):
				continue
			var npc_id := String(child.get("npc_id")).strip_edges()
			if npc_id == "":
				npc_id = child.name
			var model_path := String(child.get("model_path")).strip_edges()
			var pos := Vector3.ZERO
			var yaw := 0.0
			if child is Node3D:
				var n3 := child as Node3D
				pos = n3.position
				yaw = n3.rotation.y
			npcs.append({
				"npc_id": npc_id,
				"model_path": model_path,
				"pos": [pos.x, pos.y, pos.z],
				"yaw": yaw,
			})
	return {
		"version": 3,
		"save_id": save_id,
		"culture_code": culture_code,
		"npc_counter": npc_counter,
		"npcs": npcs,
		"workspace_counter": workspace_counter,
		"workspaces": workspaces,
		"desk_counter": desk_counter,
		"desks": desks,
		"irc": irc,
	}
