extends RefCounted
class_name VrOfficesSharedSkillLibraryStore

const _Paths := preload("res://vr_offices/core/skill_library/VrOfficesSharedSkillLibraryPaths.gd")

static func load_manifest(save_id: String) -> Dictionary:
	var p := _Paths.manifest_path(save_id)
	if p == "":
		return {"ok": false, "error": "MissingSaveId"}
	if not FileAccess.file_exists(p) and not FileAccess.file_exists(ProjectSettings.globalize_path(p)):
		return {"ok": true, "manifest": {"version": 1, "skills": []}}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		f = FileAccess.open(ProjectSettings.globalize_path(p), FileAccess.READ)
	if f == null:
		return {"ok": false, "error": "ReadFailed"}
	var txt := f.get_as_text()
	f.close()
	var obj0: Variant = JSON.parse_string(txt)
	if typeof(obj0) != TYPE_DICTIONARY:
		return {"ok": false, "error": "BadJson"}
	var m: Dictionary = obj0 as Dictionary
	if typeof(m.get("skills", null)) != TYPE_ARRAY:
		m["skills"] = []
	if int(m.get("version", 0)) <= 0:
		m["version"] = 1
	return {"ok": true, "manifest": m}

static func save_manifest(save_id: String, manifest: Dictionary) -> Dictionary:
	var p := _Paths.manifest_path(save_id)
	if p == "":
		return {"ok": false, "error": "MissingSaveId"}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(p.get_base_dir()))
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": "WriteFailed"}
	var m := manifest if manifest != null else {"version": 1, "skills": []}
	f.store_string(JSON.stringify(m, "  ") + "\n")
	f.close()
	return {"ok": true, "path": p}

static func list_skills(save_id: String) -> Array[Dictionary]:
	var rd: Dictionary = load_manifest(save_id)
	if not bool(rd.get("ok", false)):
		return []
	var m: Dictionary = rd.get("manifest", {})
	var arr: Array = m.get("skills", [])
	var out: Array[Dictionary] = []
	for it0 in arr:
		if typeof(it0) == TYPE_DICTIONARY:
			out.append(it0 as Dictionary)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("name", "")).to_lower() < String(b.get("name", "")).to_lower()
	)
	return out

static func remove_skill(save_id: String, skill_name: String) -> Dictionary:
	var name := skill_name.strip_edges()
	if name == "":
		return {"ok": false, "error": "MissingName"}
	var rd: Dictionary = load_manifest(save_id)
	if not bool(rd.get("ok", false)):
		return rd
	var m: Dictionary = rd.get("manifest", {})
	var arr: Array = m.get("skills", [])
	var next := []
	var removed := false
	for it0 in arr:
		if typeof(it0) != TYPE_DICTIONARY:
			continue
		var it: Dictionary = it0 as Dictionary
		if String(it.get("name", "")).strip_edges() == name:
			removed = true
			continue
		next.append(it)
	m["skills"] = next
	var wr: Dictionary = save_manifest(save_id, m)
	if not bool(wr.get("ok", false)):
		return wr
	return {"ok": removed, "removed": removed}

static func add_skill_entry(save_id: String, entry: Dictionary) -> Dictionary:
	var rd: Dictionary = load_manifest(save_id)
	if not bool(rd.get("ok", false)):
		return rd
	var m: Dictionary = rd.get("manifest", {})
	var arr: Array = m.get("skills", [])
	arr.append(entry)
	m["skills"] = arr
	return save_manifest(save_id, m)

