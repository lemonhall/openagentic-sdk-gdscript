extends RefCounted
class_name VrOfficesSkillLibraryDiscovery

static func discover_skill_dirs(root: String, depth: int) -> Array[String]:
	var out: Array[String] = []
	_discover_rec(root, depth, out)
	out.sort()
	return out

static func _discover_rec(dir_path: String, depth: int, out: Array[String]) -> void:
	if depth < 0:
		return
	var md := dir_path.rstrip("/") + "/SKILL.md"
	if FileAccess.file_exists(md) or FileAccess.file_exists(ProjectSettings.globalize_path(md)):
		out.append(dir_path)
		return
	var abs_dir := ProjectSettings.globalize_path(dir_path)
	var d := DirAccess.open(dir_path)
	if d == null:
		d = DirAccess.open(abs_dir)
	if d == null:
		return
	d.list_dir_begin()
	while true:
		var n := d.get_next()
		if n == "":
			break
		if n == "." or n == "..":
			continue
		if not d.current_is_dir():
			continue
		_discover_rec(dir_path.rstrip("/") + "/" + n, depth - 1, out)
	d.list_dir_end()
