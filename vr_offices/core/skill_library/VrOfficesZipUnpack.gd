extends RefCounted
class_name VrOfficesZipUnpack

static func unzip_to_dir(
	zip_path: String,
	dst_dir: String,
	max_files: int,
	max_unzipped_bytes: int
) -> Dictionary:
	var reader := ZIPReader.new()
	var err := reader.open(zip_path)
	if err != OK:
		return {"ok": false, "error": "ZipOpenFailed", "code": err}
	var files := reader.get_files()
	if max_files > 0 and files.size() > max_files:
		reader.close()
		return {"ok": false, "error": "TooManyFiles", "count": files.size()}

	var total := 0
	for fp0 in files:
		var fp := String(fp0)
		if fp.ends_with("/"):
			continue
		if _is_unsafe_zip_path(fp):
			reader.close()
			return {"ok": false, "error": "UnsafePath", "path": fp}
		var buf := reader.read_file(fp)
		total += buf.size()
		if max_unzipped_bytes > 0 and total > max_unzipped_bytes:
			reader.close()
			return {"ok": false, "error": "TooLargeUnpacked", "bytes": total}

		var out_path := dst_dir.rstrip("/") + "/" + fp
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f == null:
			reader.close()
			return {"ok": false, "error": "WriteFailed", "path": out_path}
		f.store_buffer(buf)
		f.close()
	reader.close()

	return {"ok": true, "root": _single_child_dir(dst_dir)}

static func _single_child_dir(dir_path: String) -> String:
	var abs := ProjectSettings.globalize_path(dir_path)
	var d := DirAccess.open(dir_path)
	if d == null:
		d = DirAccess.open(abs)
	if d == null:
		return dir_path
	var children := []
	d.list_dir_begin()
	while true:
		var n := d.get_next()
		if n == "":
			break
		if n == "." or n == "..":
			continue
		if d.current_is_dir():
			children.append(n)
	d.list_dir_end()
	if children.size() == 1:
		return dir_path.rstrip("/") + "/" + String(children[0])
	return dir_path

static func _is_unsafe_zip_path(p: String) -> bool:
	var s := p.strip_edges()
	if s == "" or s.begins_with("/") or s.begins_with("\\"):
		return true
	if s.find("..") != -1:
		return true
	if s.find(":") != -1:
		return true
	return false

