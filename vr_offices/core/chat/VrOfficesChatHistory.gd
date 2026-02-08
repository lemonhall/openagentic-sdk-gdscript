extends RefCounted

const _SessionStoreScript := preload("res://addons/openagentic/core/OAJsonlNpcSessionStore.gd")
const _OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")

const _MAX_UI_ITEMS := 200
const _TAIL_CHUNK_BYTES := 65536
const _TAIL_MAX_SCAN_BYTES := 4 * 1024 * 1024

func read_ui_history(save_id: String, npc_id: String) -> Array:
	# Translate the persisted per-NPC JSONL event log into a simple UI chat history.
	# Only include final user/assistant messages (ignore deltas/tool events).
	var out: Array = []
	if save_id.strip_edges() == "" or npc_id.strip_edges() == "":
		return out

	var events_path := String(_OAPaths.npc_events_path(save_id, npc_id))
	var items := _read_ui_history_tail_from_path(events_path, _MAX_UI_ITEMS)
	if items.is_empty():
		var workspace_id := _OAPaths.workspace_id_from_manager_npc_id(npc_id)
		if workspace_id != "":
			var old_manager_npc_id := "%s_manager" % workspace_id
			var old_path := String(_OAPaths.npc_events_path(save_id, old_manager_npc_id))
			items = _read_ui_history_tail_from_path(old_path, _MAX_UI_ITEMS)
	return items

static func _read_ui_history_tail_from_path(path: String, max_items: int) -> Array:
	if path.strip_edges() == "" or not FileAccess.file_exists(path) or max_items <= 0:
		return []
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []

	var file_len := int(f.get_length())
	var pos := file_len
	var scanned := 0
	var carry := PackedByteArray()
	var rev: Array[Dictionary] = []

	while pos > 0 and rev.size() < max_items and scanned < _TAIL_MAX_SCAN_BYTES:
		var step: int = min(_TAIL_CHUNK_BYTES, pos)
		pos -= step
		scanned += step
		f.seek(pos)
		var chunk := f.get_buffer(step)
		if chunk.is_empty():
			break
		# buf = chunk + carry
		var buf := chunk
		if not carry.is_empty():
			buf.append_array(carry)

		var end := buf.size()
		var i := buf.size() - 1
		while i >= 0:
			if rev.size() >= max_items:
				break
			if int(buf[i]) == 10:
				var lb := i + 1
				if lb < end:
					var line_bytes := buf.slice(lb, end)
					_consume_ui_line_bytes(line_bytes, rev, max_items)
				end = i
			i -= 1

		carry = buf.slice(0, end)

	if rev.size() < max_items and pos == 0 and not carry.is_empty():
		_consume_ui_line_bytes(carry, rev, max_items)
	f.close()

	rev.reverse()
	var out: Array = []
	for it in rev:
		out.append(it)
	return out

static func _consume_ui_line_bytes(line_bytes: PackedByteArray, rev_out: Array[Dictionary], max_items: int) -> void:
	if rev_out.size() >= max_items or line_bytes.is_empty():
		return
	var s := line_bytes.get_string_from_utf8().strip_edges()
	if s == "":
		return
	# Perf: events.jsonl contains many non-UI events (tool.*, hook.*, assistant.delta). Avoid JSON.parse unless
	# it's likely a final user/assistant message.
	if s.find("\"type\":\"user.message\"") == -1 and s.find("\"type\": \"user.message\"") == -1 and s.find("\"type\":\"assistant.message\"") == -1 and s.find("\"type\": \"assistant.message\"") == -1:
		return
	var obj: Variant = JSON.parse_string(s)
	if typeof(obj) != TYPE_DICTIONARY:
		return
	var e := obj as Dictionary
	var typ := String(e.get("type", "")).strip_edges()
	if typ == "user.message":
		var tx0: Variant = e.get("text", null)
		if typeof(tx0) == TYPE_STRING:
			rev_out.append({"role": "user", "text": String(tx0)})
	elif typ == "assistant.message":
		var tx1: Variant = e.get("text", null)
		if typeof(tx1) == TYPE_STRING:
			rev_out.append({"role": "assistant", "text": String(tx1)})
