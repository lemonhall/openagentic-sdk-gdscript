extends RefCounted
class_name OASkills

const _OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")

static func list_skill_names(save_id: String, npc_id: String) -> Array[String]:
	var out: Array[String] = []
	if save_id.strip_edges() == "" or npc_id.strip_edges() == "":
		return out
	var dir_path := _OAPaths.npc_skills_dir(save_id, npc_id)
	var dir_abs := ProjectSettings.globalize_path(dir_path)
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		d = DirAccess.open(dir_abs)
	if d == null:
		return out
	d.list_dir_begin()
	while true:
		var name := d.get_next()
		if name == "":
			break
		if name == "." or name == "..":
			continue
		if not d.current_is_dir():
			continue
		# A "skill" directory is only considered valid if it contains SKILL.md.
		var md_path := _OAPaths.npc_skill_md_path(save_id, npc_id, name)
		if FileAccess.file_exists(md_path) or FileAccess.file_exists(ProjectSettings.globalize_path(md_path)):
			out.append(name)
	d.list_dir_end()
	out.sort()
	return out

static func read_skill_md(save_id: String, npc_id: String, skill_name: String, max_bytes: int = 128 * 1024) -> String:
	var p := _OAPaths.npc_skill_md_path(save_id, npc_id, skill_name)
	var abs := ProjectSettings.globalize_path(p)
	if not FileAccess.file_exists(p) and not FileAccess.file_exists(abs):
		return ""
	var f: FileAccess = FileAccess.open(p, FileAccess.READ)
	if f == null:
		f = FileAccess.open(abs, FileAccess.READ)
	if f == null:
		return ""
	var txt := f.get_as_text()
	f.close()
	if max_bytes > 0 and txt.to_utf8_buffer().size() > max_bytes:
		# Conservative truncation by bytes.
		var buf := txt.to_utf8_buffer()
		buf = buf.slice(0, max_bytes)
		txt = buf.get_string_from_utf8()
	return String(txt).strip_edges()
