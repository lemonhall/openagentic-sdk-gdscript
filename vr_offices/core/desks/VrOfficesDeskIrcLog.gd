extends RefCounted

const _OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")

var _save_id: String = ""
var _desk_id: String = ""

var _log_lines: Array[String] = []
var _max_log_lines := 200
var _max_log_file_bytes := 256 * 1024

func configure(save_id: String, desk_id: String) -> void:
	_save_id = save_id.strip_edges()
	_desk_id = desk_id.strip_edges()

func set_limits(max_lines: int, max_file_bytes: int) -> void:
	_max_log_lines = max(1, max_lines)
	_max_log_file_bytes = max(1024, max_file_bytes)

func clear() -> void:
	_log_lines = []

func get_lines() -> Array[String]:
	return _log_lines.duplicate()

func get_log_file_user_path() -> String:
	if _save_id == "" or _desk_id == "":
		return ""
	return "%s/vr_offices/desks/%s/irc.log" % [_OAPaths.save_root(_save_id), _desk_id]

func get_log_file_abs_path() -> String:
	var p := get_log_file_user_path()
	if p == "":
		return ""
	return ProjectSettings.globalize_path(p)

func append(raw_line: String) -> void:
	var t := raw_line.strip_edges()
	if t == "":
		return
	var entry := "[%s] %s" % [Time.get_time_string_from_system(), t]
	_log_lines.append(entry)
	while _log_lines.size() > _max_log_lines:
		_log_lines.pop_front()
	_append_to_disk(entry + "\n")

func _append_to_disk(text: String) -> void:
	var path := get_log_file_user_path()
	if path == "":
		return
	var abs_dir := ProjectSettings.globalize_path(path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(abs_dir)

	var f: FileAccess = null
	var append := FileAccess.file_exists(path)
	if append:
		f = FileAccess.open(path, FileAccess.READ_WRITE)
	else:
		# Create the file first (READ_WRITE may fail if the file doesn't exist).
		f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	if append:
		f.seek_end()
	f.store_string(text)
	var size := int(f.get_length())
	f.close()
	if size <= _max_log_file_bytes:
		return

	# Keep disk logs bounded by rewriting the last in-memory lines.
	var f2 := FileAccess.open(path, FileAccess.WRITE)
	if f2 == null:
		return
	for line in _log_lines:
		f2.store_string(String(line) + "\n")
	f2.close()

