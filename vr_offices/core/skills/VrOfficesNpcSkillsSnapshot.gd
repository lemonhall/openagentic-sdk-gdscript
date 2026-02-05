extends RefCounted
class_name VrOfficesNpcSkillsSnapshot

const _OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")
const _Validator := preload("res://addons/openagentic/core/OASkillMdValidator.gd")

func snapshot_skills(save_id: String, npc_id: String) -> Array[Dictionary]:
	var sid := save_id.strip_edges()
	var nid := npc_id.strip_edges()
	var out: Array[Dictionary] = []
	if sid == "" or nid == "":
		return out

	var root := String(_OAPaths.npc_skills_dir(sid, nid)).rstrip("/")
	if root.strip_edges() == "":
		return out
	var abs_root := ProjectSettings.globalize_path(root)
	if not DirAccess.dir_exists_absolute(abs_root):
		return out

	var d := DirAccess.open(abs_root)
	if d == null:
		return out
	d.list_dir_begin()
	while true:
		var n: String = d.get_next()
		if n == "":
			break
		if n == "." or n == "..":
			continue
		if not d.current_is_dir():
			continue
		var dir_name := String(n).strip_edges()
		if dir_name == "":
			continue
		var md_path := root + "/" + dir_name + "/SKILL.md"
		var vr: Dictionary = _Validator.validate_skill_md_path(md_path)
		if not bool(vr.get("ok", false)):
			continue
		out.append({
			"dir_name": dir_name,
			"name": String(vr.get("name", dir_name)).strip_edges(),
			"description": String(vr.get("description", "")).strip_edges(),
		})
	d.list_dir_end()

	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("name", "")).to_lower() < String(b.get("name", "")).to_lower()
	)
	return out

func input_hash(skills: Array[Dictionary]) -> String:
	var arr: Array = []
	for s0 in skills:
		if typeof(s0) != TYPE_DICTIONARY:
			continue
		var s: Dictionary = s0 as Dictionary
		arr.append({
			"name": String(s.get("name", "")).strip_edges(),
			"description": String(s.get("description", "")).strip_edges(),
		})
	return _sha256_hex(JSON.stringify(arr))

func _sha256_hex(txt: String) -> String:
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	hc.update(txt.to_utf8_buffer())
	return hc.finish().hex_encode()

