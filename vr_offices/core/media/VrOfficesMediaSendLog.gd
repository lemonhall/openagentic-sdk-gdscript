extends RefCounted
class_name VrOfficesMediaSendLog

const _OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")

const MAX_BYTES := 1024 * 1024

static func log_path(save_id: String) -> String:
	var sid := save_id.strip_edges()
	if sid == "":
		return ""
	return "%s/vr_offices/media_sent.jsonl" % _OAPaths.save_root(sid)

static func append(save_id: String, entry: Dictionary) -> Dictionary:
	var p := log_path(save_id)
	if p == "":
		return {"ok": false, "error": "MissingSaveId"}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(p.get_base_dir()))
	var f := FileAccess.open(p, FileAccess.READ_WRITE)
	if f == null:
		# Fallback: create file.
		f = FileAccess.open(p, FileAccess.WRITE)
		if f == null:
			return {"ok": false, "error": "WriteFailed"}
	else:
		f.seek_end()
	var line := JSON.stringify(entry)
	if typeof(line) != TYPE_STRING:
		f.close()
		return {"ok": false, "error": "BadEntry"}
	f.store_string(String(line).rstrip("\r\n") + "\n")
	f.close()
	return {"ok": true}

static func list_recent(save_id: String, limit: int = 50) -> Dictionary:
	var p := log_path(save_id)
	if p == "":
		return {"ok": false, "error": "MissingSaveId"}
	if not FileAccess.file_exists(p):
		return {"ok": true, "items": []}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {"ok": false, "error": "ReadFailed"}
	if int(f.get_length()) > MAX_BYTES:
		# Best-effort: avoid reading huge files; take the tail region.
		f.seek(maxi(0, int(f.get_length()) - MAX_BYTES))
	var txt := f.get_as_text()
	f.close()
	var lines := txt.split("\n", false)
	var out: Array[Dictionary] = []
	for i in range(lines.size()):
		var s := String(lines[i]).strip_edges()
		if s == "":
			continue
		var obj0: Variant = JSON.parse_string(s)
		if typeof(obj0) != TYPE_DICTIONARY:
			continue
		out.append(obj0 as Dictionary)
	if limit > 0 and out.size() > limit:
		out = out.slice(out.size() - limit, out.size())
	return {"ok": true, "items": out}

