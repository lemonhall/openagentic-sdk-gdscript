extends RefCounted
class_name VrOfficesNpcSkillsProfileStore

const _OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")

func read_meta(save_id: String, npc_id: String) -> Dictionary:
	var sid := save_id.strip_edges()
	var nid := npc_id.strip_edges()
	if sid == "" or nid == "":
		return {}
	var path := String(_OAPaths.npc_meta_path(sid, nid))
	if path.strip_edges() == "":
		return {}

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var abs := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(abs):
		return {"npc_id": nid, "created_at": int(Time.get_unix_time_from_system() * 1000.0)}

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		f = FileAccess.open(abs, FileAccess.READ)
	if f == null:
		return {"npc_id": nid}
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	var meta: Dictionary = parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {"npc_id": nid}
	meta["npc_id"] = nid
	return meta

func write_meta(save_id: String, npc_id: String, meta: Dictionary) -> void:
	var sid := save_id.strip_edges()
	var nid := npc_id.strip_edges()
	if sid == "" or nid == "":
		return
	var path := String(_OAPaths.npc_meta_path(sid, nid))
	if path.strip_edges() == "":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var out := meta.duplicate(true)
	out["npc_id"] = nid
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(out) + "\n")
	f.close()

