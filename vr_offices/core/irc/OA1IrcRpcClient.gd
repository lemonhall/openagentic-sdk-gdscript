extends Node
const _Codec = preload("res://vr_offices/core/irc/OA1IrcRpcCodec.gd")
@export_range(32, 480, 1) var max_frame_payload_bytes := 240
@export_range(1024, 1024 * 1024, 1024) var max_aggregate_bytes := 128 * 1024
@export_range(1.0, 120.0, 1.0) var default_timeout_sec := 30.0
@export_range(1.0, 120.0, 1.0) var idle_timeout_sec := 10.0
var _link: Node = null
var _inflight: Dictionary = {}
var _rng := RandomNumberGenerator.new()
func _ready() -> void:
	_rng.randomize()
	# Default wiring: if mounted as a child of DeskIrcLink, auto-bind to the parent.
	var p := get_parent() as Node
	if p != null:
		bind_link(p)
func bind_link(link: Node) -> void:
	if link == null or not is_instance_valid(link):
		return
	if _link == link:
		return
	_unbind_link()
	_link = link
	var cb := Callable(self, "_on_link_message_received")
	if _link.has_signal("message_received") and not _link.is_connected("message_received", cb):
		_link.connect("message_received", cb)
func _unbind_link() -> void:
	if _link == null or not is_instance_valid(_link):
		_link = null
		return
	var cb := Callable(self, "_on_link_message_received")
	if _link.has_signal("message_received") and _link.is_connected("message_received", cb):
		_link.disconnect("message_received", cb)
	_link = null
func _exit_tree() -> void:
	_unbind_link()
func request_text(payload: String, timeout_sec: float = -1.0) -> String:
	# Be robust to callers invoking request_text before _ready() runs.
	if _link == null:
		var p := get_parent() as Node
		if p != null:
			bind_link(p)
	# Be robust to callers invoking request_text before the node enters the SceneTree.
	if not is_inside_tree():
		await tree_entered
	var link := _link
	if link == null or not is_instance_valid(link):
		return "ERROR: MissingDeskIrcLink"
	if not link.has_method("send_channel_message"):
		return "ERROR: DeskIrcLinkMissingSend"

	var to := timeout_sec if timeout_sec > 0.0 else default_timeout_sec
	var req_id := _new_req_id()
	var escaped = _Codec.escape_payload(payload)
	var chunks = _Codec.chunk_utf8_by_bytes(escaped, max_frame_payload_bytes)
	if chunks.is_empty():
		chunks = [""]

	var rec := {
		"done": false,
		"error": false,
		"truncated": false,
		"bytes": 0,
		"last_ms": _now_ms(),
		"chunks": {},
	}
	_inflight[req_id] = rec

	for i in range(chunks.size()):
		var seq := i + 1
		var more := 1 if i < chunks.size() - 1 else 0
		var frame = _Codec.make_frame("REQ", req_id, seq, more, String(chunks[i]))
		link.call("send_channel_message", frame)
	var start_ms := _now_ms()
	while true:
		if not _inflight.has(req_id):
			return "ERROR: RequestLost"
		var cur: Dictionary = _inflight[req_id]
		if bool(cur.get("done", false)):
			return _finalize_and_pop(req_id, cur)
		var now_ms := _now_ms()
		if now_ms - start_ms > int(to * 1000.0):
			_inflight.erase(req_id)
			return "ERROR: timeout"
		var last_ms := int(cur.get("last_ms", start_ms))
		if idle_timeout_sec > 0.0 and now_ms - last_ms > int(idle_timeout_sec * 1000.0):
			_inflight.erase(req_id)
			return "ERROR: timeout"
		await (get_tree() as SceneTree).process_frame
	return "ERROR: unreachable"
func _finalize_and_pop(req_id: String, rec: Dictionary) -> String:
	_inflight.erase(req_id)
	var chunks0: Variant = rec.get("chunks", {})
	var chunks: Dictionary = chunks0 as Dictionary if typeof(chunks0) == TYPE_DICTIONARY else {}
	var keys := chunks.keys()
	keys.sort()
	var parts := PackedStringArray()
	for k in keys:
		parts.append(String(chunks.get(k, "")))
	var joined := "".join(parts)
	var text = _Codec.unescape_payload(joined)
	if bool(rec.get("truncated", false)):
		text += "\n...[truncated]..."
	if bool(rec.get("error", false)):
		return "ERROR: " + text
	return text
func _on_link_message_received(msg: RefCounted) -> void:
	if _link == null or not is_instance_valid(_link):
		return
	if msg == null:
		return
	var obj := msg as Object
	if obj == null:
		return
	if String(obj.get("command")).to_upper() != "PRIVMSG":
		return

	var params0: Variant = obj.get("params")
	if not (params0 is Array):
		return
	var params := params0 as Array
	if params.is_empty():
		return
	var target := String(params[0])

	var desired := ""
	if _link.has_method("get_desired_channel"):
		desired = String(_link.call("get_desired_channel"))
	if desired.strip_edges() == "" or target != desired:
		return

	var sender_nick := _irc_prefix_nick(String(obj.get("prefix")))
	var self_nick := ""
	if _link.has_method("get_nick"):
		self_nick = String(_link.call("get_nick"))
	if sender_nick != "" and self_nick != "" and sender_nick == self_nick:
		return

	var trailing := String(obj.get("trailing"))
	if not trailing.begins_with("OA1 "):
		return
	var fr = _Codec.parse_frame(trailing)
	if not bool(fr.get("ok", false)):
		return
	var typ := String(fr.get("type", ""))
	if typ != "RES" and typ != "ERR":
		return
	var req_id := String(fr.get("req_id", ""))
	if req_id == "" or not _inflight.has(req_id):
		return
	var seq := int(fr.get("seq", 0))
	if seq <= 0:
		return
	var more := int(fr.get("more", 0))
	var payload_escaped := String(fr.get("payload", ""))

	var rec: Dictionary = _inflight[req_id]
	var chunks0: Variant = rec.get("chunks", {})
	var chunks: Dictionary = chunks0 as Dictionary if typeof(chunks0) == TYPE_DICTIONARY else {}
	if not chunks.has(seq):
		chunks[seq] = payload_escaped
		rec["chunks"] = chunks

	rec["last_ms"] = _now_ms()
	rec["bytes"] = int(rec.get("bytes", 0)) + payload_escaped.to_utf8_buffer().size()
	if int(rec.get("bytes", 0)) > max_aggregate_bytes:
		rec["truncated"] = true
		rec["done"] = true

	if typ == "ERR":
		rec["error"] = true
		rec["done"] = true
	elif more == 0:
		rec["done"] = true

	_inflight[req_id] = rec

func _new_req_id(count: int = 12) -> String:
	var alphabet := "abcdefghijklmnopqrstuvwxyz0123456789"
	var out := ""
	for _i in range(count):
		out += alphabet[_rng.randi_range(0, alphabet.length() - 1)]
	return out

static func _irc_prefix_nick(prefix: String) -> String:
	var p := prefix.strip_edges()
	if p == "":
		return ""
	var bang := p.find("!")
	if bang != -1:
		return p.substr(0, bang)
	var at := p.find("@")
	if at != -1:
		return p.substr(0, at)
	return p

func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)
