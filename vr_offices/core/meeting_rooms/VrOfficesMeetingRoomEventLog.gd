extends RefCounted

const _OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")

static func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)

static func _safe_id(id: String) -> String:
	var s := id.strip_edges()
	s = s.replace("/", "_").replace("\\", "_").replace(":", "_")
	return s

static func events_path(save_id: String, meeting_room_id: String) -> String:
	var sid := save_id.strip_edges()
	var rid := _safe_id(meeting_room_id)
	if sid == "" or rid == "":
		return ""
	return "%s/vr_offices/meeting_rooms/%s/events.jsonl" % [String(_OAPaths.save_root(sid)), rid]

static func append(save_id: String, meeting_room_id: String, event: Dictionary) -> void:
	var path := events_path(save_id, meeting_room_id)
	if path == "":
		return
	var abs := ProjectSettings.globalize_path(path)
	var dir := abs.get_base_dir()
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)

	var stored := event.duplicate(true) if event != null else {}
	if typeof(stored.get("ts", null)) != TYPE_INT:
		stored["ts"] = _now_ms()
	var line := JSON.stringify(stored) + "\n"

	# Conservative append: read+write to avoid platform differences.
	if not FileAccess.file_exists(abs):
		var wf := FileAccess.open(abs, FileAccess.WRITE)
		if wf != null:
			wf.store_string(line)
			wf.close()
		return

	var rf := FileAccess.open(abs, FileAccess.READ)
	if rf == null:
		return
	var existing := rf.get_as_text()
	rf.close()
	var wf2 := FileAccess.open(abs, FileAccess.WRITE)
	if wf2 != null:
		wf2.store_string(existing + line)
		wf2.close()

