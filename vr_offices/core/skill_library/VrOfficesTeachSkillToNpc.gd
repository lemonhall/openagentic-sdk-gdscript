extends RefCounted
class_name VrOfficesTeachSkillToNpc

const _OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")
const _LibraryPaths := preload("res://vr_offices/core/skill_library/VrOfficesSharedSkillLibraryPaths.gd")
const _Fs := preload("res://vr_offices/core/skill_library/VrOfficesSkillLibraryFs.gd")

func teach_shared_skill_to_npc(save_id: String, npc_id: String, skill_name: String) -> Dictionary:
	var sid := save_id.strip_edges()
	if sid == "":
		return {"ok": false, "error": "MissingSaveId"}
	var nid := npc_id.strip_edges()
	if nid == "":
		return {"ok": false, "error": "MissingNpcId"}
	var name := skill_name.strip_edges()
	if name == "":
		return {"ok": false, "error": "MissingSkillName"}

	var src_root := _LibraryPaths.library_root(sid)
	if src_root == "":
		return {"ok": false, "error": "MissingLibraryRoot"}
	var src_dir := src_root.rstrip("/") + "/" + name
	var abs_src := ProjectSettings.globalize_path(src_dir)
	if not DirAccess.dir_exists_absolute(abs_src):
		return {"ok": false, "error": "SkillNotFound", "skill": name}

	var dst_dir := _OAPaths.npc_skill_dir(sid, nid, name)
	var abs_dst := ProjectSettings.globalize_path(dst_dir)
	if DirAccess.dir_exists_absolute(abs_dst):
		_rm_tree_and_root(abs_dst)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dst_dir.get_base_dir()))
	var cr := _Fs.copy_tree(src_dir, dst_dir)
	if not bool(cr.get("ok", false)):
		return {"ok": false, "error": String(cr.get("error", "CopyFailed")), "path": String(cr.get("path", ""))}
	return {"ok": true, "dst_dir": dst_dir}

static func _rm_tree_and_root(abs_dir: String) -> void:
	if abs_dir.strip_edges() == "":
		return
	if not DirAccess.dir_exists_absolute(abs_dir):
		return
	var d := DirAccess.open(abs_dir)
	if d == null:
		return
	d.list_dir_begin()
	while true:
		var n := d.get_next()
		if n == "":
			break
		if n == "." or n == "..":
			continue
		var p := abs_dir.rstrip("/") + "/" + n
		if d.current_is_dir():
			_rm_tree_and_root(p)
			DirAccess.remove_absolute(p)
		else:
			DirAccess.remove_absolute(p)
	d.list_dir_end()
	DirAccess.remove_absolute(abs_dir)

