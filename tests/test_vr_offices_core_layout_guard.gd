extends SceneTree

const T := preload("res://tests/_test_util.gd")

const _CORE_ROOT := "res://vr_offices/core"
const _MAX_LINES_PER_FILE := 200

func _init() -> void:
	# 1) Core root should not contain .gd files (must be organized into module subfolders).
	var root_gd: Array[String] = []
	for f in DirAccess.get_files_at(_CORE_ROOT):
		if String(f).to_lower().ends_with(".gd"):
			root_gd.append("%s/%s" % [_CORE_ROOT, f])
	root_gd.sort()
	if not T.require_true(self, root_gd.is_empty(), "Expected no .gd files directly under vr_offices/core (found: %s)" % str(root_gd)):
		return

	# 2) No core script should exceed the max line count.
	var gd_files := _collect_gd_files_recursive(_CORE_ROOT)
	gd_files.sort()
	var offenders: Array[String] = []
	for path in gd_files:
		var lines := _count_lines(path)
		if lines < 0:
			T.fail_and_quit(self, "Failed to read file: %s" % path)
			return
		if lines > _MAX_LINES_PER_FILE:
			offenders.append("%s (%d)" % [path, lines])

	if not T.require_true(self, offenders.is_empty(), "Core .gd files must be <= %d lines. Offenders: %s" % [_MAX_LINES_PER_FILE, str(offenders)]):
		return

	T.pass_and_quit(self)

func _collect_gd_files_recursive(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir_path):
		var fp := "%s/%s" % [dir_path, f]
		if fp.to_lower().ends_with(".gd"):
			out.append(fp)
	for d in DirAccess.get_directories_at(dir_path):
		var dp := "%s/%s" % [dir_path, d]
		out.append_array(_collect_gd_files_recursive(dp))
	return out

func _count_lines(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return -1
	var text := f.get_as_text()
	f.close()
	if text.length() == 0:
		return 0
	var n := int(text.count("\n"))
	if not text.ends_with("\n"):
		n += 1
	return n

