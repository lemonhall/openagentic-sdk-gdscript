extends RefCounted
class_name OAWorkspaceFs

var _root: String

func _init(workspace_root: String) -> void:
	_root = String(workspace_root).rstrip("/")

func _sanitize_rel_path(rel_path: String) -> Dictionary:
	var p := String(rel_path).strip_edges()
	if p == "":
		return {"ok": true, "rel": ""}
	# Only allow simple relative paths.
	if p.find("\\") != -1:
		return {"ok": false, "error": "InvalidPath"}
	if p.begins_with("/") or p.begins_with("res://") or p.begins_with("user://"):
		return {"ok": false, "error": "InvalidPath"}
	if p.find(":") != -1:
		return {"ok": false, "error": "InvalidPath"}

	var parts := p.split("/", false)
	for part0 in parts:
		var part := String(part0)
		if part == "" or part == "." or part == "..":
			return {"ok": false, "error": "InvalidPath"}
	return {"ok": true, "rel": "/".join(parts)}

func resolve(rel_path: String) -> Dictionary:
	var s := _sanitize_rel_path(rel_path)
	if not bool(s.get("ok", false)):
		return s
	var rel := String(s.get("rel", ""))
	var full := _root if rel == "" else (_root + "/" + rel)
	return {"ok": true, "path": full}

func ensure_dir(rel_dir: String) -> Dictionary:
	var r := resolve(rel_dir)
	if not bool(r.get("ok", false)):
		return r
	var p := String(r.get("path", ""))
	var abs := ProjectSettings.globalize_path(p)
	var err := DirAccess.make_dir_recursive_absolute(abs)
	return {"ok": err == OK, "error": "" if err == OK else "IOError"}

func write_text(rel_path: String, text: String) -> Dictionary:
	var r := resolve(rel_path)
	if not bool(r.get("ok", false)):
		return r
	var p := String(r.get("path", ""))
	var abs := ProjectSettings.globalize_path(p)
	DirAccess.make_dir_recursive_absolute(abs.get_base_dir())
	var f: FileAccess = FileAccess.open(abs, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": "IOError"}
	f.store_string(String(text))
	f.close()
	return {"ok": true}

func write_bytes(rel_path: String, bytes: PackedByteArray) -> Dictionary:
	var r := resolve(rel_path)
	if not bool(r.get("ok", false)):
		return r
	var p := String(r.get("path", ""))
	var abs := ProjectSettings.globalize_path(p)
	DirAccess.make_dir_recursive_absolute(abs.get_base_dir())
	var f: FileAccess = FileAccess.open(abs, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": "IOError"}
	f.store_buffer(bytes)
	f.close()
	return {"ok": true}

func read_text(rel_path: String) -> Dictionary:
	var r := resolve(rel_path)
	if not bool(r.get("ok", false)):
		return r
	var p := String(r.get("path", ""))
	var abs := ProjectSettings.globalize_path(p)
	if not FileAccess.file_exists(abs):
		return {"ok": false, "error": "NotFound"}
	var f: FileAccess = FileAccess.open(abs, FileAccess.READ)
	if f == null:
		return {"ok": false, "error": "IOError"}
	var txt := f.get_as_text()
	f.close()
	return {"ok": true, "text": String(txt)}

func read_bytes(rel_path: String) -> Dictionary:
	var r := resolve(rel_path)
	if not bool(r.get("ok", false)):
		return r
	var p := String(r.get("path", ""))
	var abs := ProjectSettings.globalize_path(p)
	if not FileAccess.file_exists(abs):
		return {"ok": false, "error": "NotFound"}
	var f: FileAccess = FileAccess.open(abs, FileAccess.READ)
	if f == null:
		return {"ok": false, "error": "IOError"}
	var buf := f.get_buffer(f.get_length())
	f.close()
	return {"ok": true, "bytes": buf}

func list_dir(rel_dir: String = "") -> Dictionary:
	var r := resolve(rel_dir)
	if not bool(r.get("ok", false)):
		return r
	var p := String(r.get("path", ""))
	var abs := ProjectSettings.globalize_path(p)
	var d: DirAccess = DirAccess.open(abs)
	if d == null:
		return {"ok": false, "error": "NotFound"}
	var out: Array = []
	d.list_dir_begin()
	while true:
		var name := d.get_next()
		if name == "":
			break
		if name == "." or name == "..":
			continue
		out.append({"name": name, "is_dir": d.current_is_dir()})
	d.list_dir_end()
	return {"ok": true, "entries": out}
