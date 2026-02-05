extends RefCounted
class_name VrOfficesSkillLibraryFs

static func copy_tree(src_dir: String, dst_dir: String) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dst_dir))
	var abs_src_dir := ProjectSettings.globalize_path(src_dir)
	var d := DirAccess.open(src_dir)
	if d == null:
		d = DirAccess.open(abs_src_dir)
	if d == null:
		return {"ok": false, "error": "SrcOpenFailed"}
	d.list_dir_begin()
	while true:
		var name := d.get_next()
		if name == "":
			break
		if name == "." or name == "..":
			continue
		var sp := src_dir.rstrip("/") + "/" + name
		var dp := dst_dir.rstrip("/") + "/" + name
		if d.current_is_dir():
			var cr := copy_tree(sp, dp)
			if not bool(cr.get("ok", false)):
				d.list_dir_end()
				return cr
		else:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dp.get_base_dir()))
			var buf := FileAccess.get_file_as_bytes(sp)
			var f := FileAccess.open(dp, FileAccess.WRITE)
			if f == null:
				d.list_dir_end()
				return {"ok": false, "error": "DstWriteFailed", "path": dp}
			f.store_buffer(buf)
			f.close()
	d.list_dir_end()
	return {"ok": true}

static func rm_tree(dir_path: String) -> void:
	var abs_dir := ProjectSettings.globalize_path(dir_path)
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
			rm_tree(p)
			DirAccess.remove_absolute(p)
		else:
			DirAccess.remove_absolute(p)
	d.list_dir_end()
