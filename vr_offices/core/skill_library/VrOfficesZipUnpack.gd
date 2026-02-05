extends RefCounted
class_name VrOfficesZipUnpack

static func unzip_to_dir(
	zip_path: String,
	dst_dir: String,
	max_files: int,
	max_unzipped_bytes: int,
	include_subdir: String = ""
) -> Dictionary:
	var reader := ZIPReader.new()
	var err := reader.open(zip_path)
	if err != OK:
		return {"ok": false, "error": "ZipOpenFailed", "code": err}
	var files := reader.get_files()
	var subdir := include_subdir.strip_edges().rstrip("/")

	var included_count := 0
	var skipped_count := 0
	var total := 0
	for fp0 in files:
		var fp := String(fp0)
		if fp.ends_with("/"):
			continue
		if subdir != "" and not _matches_subdir_filter(fp, subdir):
			skipped_count += 1
			continue
		included_count += 1
		if max_files > 0 and included_count > max_files:
			reader.close()
			return {"ok": false, "error": "TooManyFiles", "count": included_count}
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

	return {
		"ok": true,
		"root": _effective_root_dir(dst_dir, subdir),
		"included_files": included_count,
		"skipped_files": skipped_count,
	}

static func _matches_subdir_filter(zip_path: String, subdir: String) -> bool:
	var fp := zip_path.strip_edges().lstrip("/")
	var sd := subdir.strip_edges().rstrip("/")
	if sd == "":
		return true
	# 1) Direct match (no leading top-level dir).
	if fp == sd or fp.begins_with(sd + "/"):
		return true
	# 2) Match after stripping the first path segment (GitHub zips: <repo>-<ref>/...).
	var slash := fp.find("/")
	if slash == -1:
		return false
	var rest := fp.substr(slash + 1)
	return rest == sd or rest.begins_with(sd + "/")

static func _effective_root_dir(dst_dir: String, include_subdir: String) -> String:
	var root := _single_child_dir(dst_dir)
	if include_subdir.strip_edges() == "":
		return root
	if root == dst_dir:
		return root
	var only_child := root.get_file().strip_edges()
	if only_child == "":
		return root
	var sd := include_subdir.strip_edges().rstrip("/")
	if sd == "":
		return root
	# If we extracted only the requested subdir and the "single child" is the first
	# segment of that subdir (e.g. `ai/...`), returning the child would duplicate
	# path segments when the caller later scopes to `<root>/<subdir>`.
	if sd == only_child or sd.begins_with(only_child + "/"):
		return dst_dir
	return root

static func _single_child_dir(dir_path: String) -> String:
	var abs_dir := ProjectSettings.globalize_path(dir_path)
	var d := DirAccess.open(dir_path)
	if d == null:
		d = DirAccess.open(abs_dir)
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
