extends RefCounted
class_name OASkillMdValidator

const MAX_SKILL_MD_BYTES := 256 * 1024

static func validate_skill_md_text(txt: String) -> Dictionary:
	var t := String(txt)
	if t.strip_edges() == "":
		return {"ok": false, "error": "Empty"}
	var lines := t.split("\n", false)
	var i := 0
	while i < lines.size() and String(lines[i]).strip_edges() == "":
		i += 1
	if i >= lines.size() or String(lines[i]).strip_edges() != "---":
		return {"ok": false, "error": "MissingFrontmatter"}
	i += 1

	var header_lines := PackedStringArray()
	while i < lines.size():
		var ln := String(lines[i]).rstrip("\r")
		if ln.strip_edges() == "---":
			break
		header_lines.append(ln)
		i += 1
	if i >= lines.size():
		return {"ok": false, "error": "UnclosedFrontmatter"}

	var header: Dictionary = _parse_simple_yaml_header(header_lines)
	var name := String(header.get("name", "")).strip_edges()
	var desc := String(header.get("description", "")).strip_edges()
	if name == "":
		return {"ok": false, "error": "MissingName"}
	if desc == "":
		return {"ok": false, "error": "MissingDescription"}
	if not _is_safe_skill_name(name):
		return {"ok": false, "error": "UnsafeName", "name": name}
	return {"ok": true, "name": name, "description": desc, "header": header}

static func validate_skill_md_bytes(buf: PackedByteArray) -> Dictionary:
	if buf.size() <= 0:
		return {"ok": false, "error": "Empty"}
	if buf.size() > MAX_SKILL_MD_BYTES:
		return {"ok": false, "error": "TooLarge", "bytes": buf.size()}
	var txt := buf.get_string_from_utf8()
	# Godot replaces invalid sequences with U+FFFD. Treat that as invalid encoding for now.
	if txt.find("\uFFFD") != -1:
		return {"ok": false, "error": "BadUtf8"}
	return validate_skill_md_text(txt)

static func validate_skill_md_path(path: String) -> Dictionary:
	var p := path.strip_edges()
	if p == "":
		return {"ok": false, "error": "MissingPath"}
	var abs := ProjectSettings.globalize_path(p)
	if not FileAccess.file_exists(p) and not FileAccess.file_exists(abs):
		return {"ok": false, "error": "NotFound"}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		f = FileAccess.open(abs, FileAccess.READ)
	if f == null:
		return {"ok": false, "error": "ReadFailed"}
	var buf := f.get_buffer(f.get_length())
	f.close()
	return validate_skill_md_bytes(buf)

static func _parse_simple_yaml_header(lines: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for ln0 in lines:
		var ln := String(ln0)
		var s := ln.strip_edges()
		if s == "" or s.begins_with("#"):
			continue
		var idx := s.find(":")
		if idx <= 0:
			continue
		var k := s.substr(0, idx).strip_edges()
		var v := s.substr(idx + 1).strip_edges()
		if v.begins_with("\"") and v.ends_with("\"") and v.length() >= 2:
			v = v.substr(1, v.length() - 2)
		if v.begins_with("'") and v.ends_with("'") and v.length() >= 2:
			v = v.substr(1, v.length() - 2)
		out[k] = v
	return out

static func _is_safe_skill_name(name: String) -> bool:
	var n := name.strip_edges()
	if n == "" or n.length() > 64:
		return false
	if n.find("/") != -1 or n.find("\\") != -1:
		return false
	if n.find("..") != -1:
		return false
	var re := RegEx.new()
	var err := re.compile("^[a-z0-9][a-z0-9._-]{0,63}$")
	if err != OK:
		# Conservative: if regex can't compile, reject.
		return false
	return re.search(n) != null
