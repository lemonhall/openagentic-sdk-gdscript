extends RefCounted
class_name OAJsonlNpcSessionStore

const _OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")

var _save_id: String

func _init(save_id: String) -> void:
	_save_id = save_id

func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)

func _ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _write_text(path: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(text)
	f.close()

func _append_line(path: String, line: String) -> void:
	# Prefer a real append (seek_end) for performance; fallback to conservative read+write if needed.
	if not FileAccess.file_exists(path):
		_write_text(path, line)
		return

	var f: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE)
	if f != null:
		f.seek_end()
		f.store_string(line)
		f.close()
		return

	# Fallback: conservative read+write append.
	var rf: FileAccess = FileAccess.open(path, FileAccess.READ)
	if rf == null:
		return
	var existing := rf.get_as_text()
	rf.close()
	_write_text(path, existing + line)

func append_stream_delta(npc_id: String, event: Dictionary) -> void:
	# Optional debug log for streaming deltas. This is intentionally separate from
	# `events.jsonl` so that replay/history stays clean and bounded.
	#
	# This method does NOT manage seq numbers and should not be used for replay.
	var nid := npc_id.strip_edges()
	if nid == "":
		return
	_ensure_session(nid)
	var line := JSON.stringify(event) + "\n"
	_append_line(_OAPaths.npc_stream_deltas_path(_save_id, nid), line)

func _load_next_seq(npc_id: String) -> int:
	var st := _read_json(_OAPaths.npc_state_path(_save_id, npc_id))
	var ns: Variant = st.get("next_seq", 1)
	return int(ns) if (typeof(ns) == TYPE_INT or typeof(ns) == TYPE_FLOAT) else 1

func _store_next_seq(npc_id: String, next_seq: int) -> void:
	var path := _OAPaths.npc_state_path(_save_id, npc_id)
	_write_text(path, JSON.stringify({"next_seq": next_seq}) + "\n")

func _ensure_session(npc_id: String) -> void:
	_ensure_dir(_OAPaths.npc_session_dir(_save_id, npc_id))
	_ensure_dir(_OAPaths.npc_workspace_dir(_save_id, npc_id))
	_ensure_dir(_OAPaths.npc_skills_dir(_save_id, npc_id))
	var meta_path := _OAPaths.npc_meta_path(_save_id, npc_id)
	if not FileAccess.file_exists(meta_path):
		_write_text(meta_path, JSON.stringify({"npc_id": npc_id, "created_at": _now_ms()}) + "\n")
	var state_path := _OAPaths.npc_state_path(_save_id, npc_id)
	if not FileAccess.file_exists(state_path):
		_store_next_seq(npc_id, 1)

func append_event(npc_id: String, event: Dictionary) -> void:
	_ensure_session(npc_id)
	var seq: Variant = event.get("seq", null)
	if typeof(seq) != TYPE_INT:
		seq = _load_next_seq(npc_id)
		_store_next_seq(npc_id, int(seq) + 1)

	var stored := event.duplicate(true)
	stored["seq"] = int(seq)
	if typeof(stored.get("ts", null)) != TYPE_INT:
		stored["ts"] = _now_ms()

	var line := JSON.stringify(stored) + "\n"
	_append_line(_OAPaths.npc_events_path(_save_id, npc_id), line)

func read_events(npc_id: String) -> Array:
	_ensure_session(npc_id)
	var path := _OAPaths.npc_events_path(_save_id, npc_id)
	if not FileAccess.file_exists(path):
		return []
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var out: Array = []
	while not f.eof_reached():
		var line := f.get_line()
		var trimmed := String(line).strip_edges()
		if trimmed == "":
			continue
		# Streaming deltas can be extremely high-volume; never include them in replay/history reads.
		if trimmed.find("\"type\":\"assistant.delta\"") != -1 or trimmed.find("\"type\": \"assistant.delta\"") != -1:
			continue
		var obj: Variant = JSON.parse_string(trimmed)
		if typeof(obj) == TYPE_DICTIONARY:
			out.append(obj)
	f.close()
	return out
