extends RefCounted
class_name VrOfficesAttachmentQueue

signal changed

const STATE_PENDING := "pending"
const STATE_UPLOADING := "uploading"
const STATE_SENT := "sent"
const STATE_FAILED := "failed"
const STATE_CANCELLED := "cancelled"

var _next_id: int = 1
var _items: Array[Dictionary] = []

func enqueue(path: String, meta: Dictionary = {}) -> int:
	var p := path.strip_edges()
	if p == "":
		return 0

	var name := _basename(p)
	var item := {
		"id": _next_id,
		"path": p,
		"name": name,
		"bytes": int(meta.get("bytes", -1)),
		"mime": String(meta.get("mime", "")).strip_edges(),
		"state": STATE_PENDING,
		"error": "",
		"progress": 0.0,
		"line": "",
	}
	_next_id += 1
	_items.append(item)
	changed.emit()
	return int(item["id"])

func get_item(id: int) -> Dictionary:
	for it0 in _items:
		var it: Dictionary = it0
		if int(it.get("id", 0)) == id:
			return it.duplicate(true)
	return {}

func list_items() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it0 in _items:
		out.append((it0 as Dictionary).duplicate(true))
	return out

func mark_uploading(id: int) -> bool:
	return _transition(id, [STATE_PENDING], STATE_UPLOADING, "", 0.0)

func mark_sent(id: int, oamedia_line: String = "") -> bool:
	return _transition(id, [STATE_PENDING, STATE_UPLOADING], STATE_SENT, "", 1.0, oamedia_line)

func mark_failed(id: int, error: String) -> bool:
	return _transition(id, [STATE_PENDING, STATE_UPLOADING], STATE_FAILED, error.strip_edges(), 0.0)

func cancel_item(id: int) -> bool:
	return _transition(id, [STATE_PENDING, STATE_UPLOADING], STATE_CANCELLED, "", 0.0)

func cancel_all() -> void:
	var changed_any := false
	for idx in range(_items.size()):
		var it: Dictionary = _items[idx]
		var st := String(it.get("state", ""))
		if st == STATE_PENDING or st == STATE_UPLOADING:
			it["state"] = STATE_CANCELLED
			it["error"] = ""
			it["progress"] = 0.0
			_items[idx] = it
			changed_any = true
	if changed_any:
		changed.emit()

func _transition(
	id: int,
	allowed_from: Array[String],
	to_state: String,
	error: String,
	progress: float,
	oamedia_line: String = ""
) -> bool:
	for idx in range(_items.size()):
		var it: Dictionary = _items[idx]
		if int(it.get("id", 0)) != id:
			continue
		var from := String(it.get("state", ""))
		if not allowed_from.has(from):
			return false
		it["state"] = to_state
		it["error"] = error
		it["progress"] = clampf(progress, 0.0, 1.0)
		if oamedia_line.strip_edges() != "":
			it["line"] = oamedia_line
		_items[idx] = it
		changed.emit()
		return true
	return false

static func _basename(path: String) -> String:
	var p := path
	p = p.replace("\\", "/")
	return p.get_file()

