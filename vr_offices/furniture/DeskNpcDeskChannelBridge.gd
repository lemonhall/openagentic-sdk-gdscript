extends Node

@export_range(0, 16, 1) var max_queue := 4
@export_range(50, 450, 10) var max_irc_message_len := 360

const _OAMediaRef := preload("res://addons/openagentic/core/OAMediaRef.gd")

var _indicator: Node = null
var _desk: Node = null
var _link: Node = null

var _busy := false
var _queue: Array[String] = []
var _reply_buf := ""

# Fragment reassembly: mid -> {total:int, parts:Dictionary<int,String>}
var _media_frags: Dictionary = {}

func _ready() -> void:
	_indicator = get_parent() as Node
	if _indicator != null and is_instance_valid(_indicator):
		_desk = _indicator.get_parent() as Node

	if _desk != null:
		_desk.child_entered_tree.connect(_on_desk_child_entered_tree)
		_desk.child_exiting_tree.connect(_on_desk_child_exiting_tree)
	_try_bind_link()

func _on_desk_child_entered_tree(child: Node) -> void:
	if child != null and child.name == "DeskIrcLink":
		_try_bind_link()

func _on_desk_child_exiting_tree(child: Node) -> void:
	if _link != null and child == _link:
		_unbind_link()

func _try_bind_link() -> void:
	if _desk == null:
		return
	var link := _desk.get_node_or_null("DeskIrcLink") as Node
	if link == null or not is_instance_valid(link):
		return
	if _link == link:
		return
	_unbind_link()
	_link = link
	if _link.has_signal("message_received"):
		_link.connect("message_received", Callable(self, "_on_irc_message_received"))

func _unbind_link() -> void:
	if _link == null or not is_instance_valid(_link):
		_link = null
		return
	var cb := Callable(self, "_on_irc_message_received")
	if _link.has_signal("message_received") and _link.is_connected("message_received", cb):
		_link.disconnect("message_received", cb)
	_link = null

func _on_irc_message_received(msg: RefCounted) -> void:
	if _link == null or _indicator == null or not is_instance_valid(_indicator):
		return
	if _indicator.has_method("is_suspended") and bool(_indicator.call("is_suspended")):
		return

	var npc_id := _current_bound_npc_id()
	if npc_id == "":
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

	var text := String(obj.get("trailing")).strip_edges()
	if text == "":
		return
	# OA1 is a transport-level RPC protocol used by desk-bound tools (v40).
	# Do not treat OA1 frames as NPC command messages.
	if text.begins_with("OA1 "):
		return

	if _try_absorb_media_fragment(text):
		return

	_enqueue(text)

func _try_absorb_media_fragment(text: String) -> bool:
	if text.begins_with("OAMEDIA1F "):
		if _media_frags.size() > 32:
			# Safety: avoid unbounded growth if fragments are spammed.
			_media_frags.clear()
		var p: Dictionary = _OAMediaRef.irc_parse_fragment(text)
		if not bool(p.get("ok", false)):
			return false
		var mid := String(p.get("message_id", "")).strip_edges()
		var idx := int(p.get("index", 0))
		var total := int(p.get("total", 0))
		var payload := String(p.get("payload_part", ""))
		if mid == "" or idx < 1 or total < 1 or payload == "":
			return true
		var st0: Variant = _media_frags.get(mid, null)
		var st: Dictionary = st0 as Dictionary if typeof(st0) == TYPE_DICTIONARY else {"total": total, "parts": {}}
		if int(st.get("total", total)) != total:
			_media_frags.erase(mid)
			st = {"total": total, "parts": {}}
		var parts0: Variant = st.get("parts", {})
		var parts: Dictionary = parts0 as Dictionary if typeof(parts0) == TYPE_DICTIONARY else {}
		parts[idx] = payload
		st["parts"] = parts
		st["total"] = total
		_media_frags[mid] = st
		if parts.size() >= total:
			var rr: Dictionary = _OAMediaRef.irc_reassemble(mid, total, parts)
			_media_frags.erase(mid)
			if bool(rr.get("ok", false)):
				_enqueue(String(rr.get("line", "")))
		return true
	return false

func _enqueue(text: String) -> void:
	if _busy:
		if max_queue > 0 and _queue.size() < max_queue:
			_queue.append(text)
		return
	_start_turn(text)

func _start_turn(text: String) -> void:
	_busy = true
	_reply_buf = ""
	call_deferred("_run_turn", text)

func _run_turn(text: String) -> void:
	var npc_id := _current_bound_npc_id()
	if npc_id == "":
		_finish_turn()
		return

	var oa := get_node_or_null("/root/OpenAgentic") as Node
	if oa == null or not oa.has_method("run_npc_turn"):
		_finish_turn()
		return

	await oa.run_npc_turn(npc_id, text, Callable(self, "_on_openagentic_event"))
	# Safety: if we never got a "result", still finalize.
	if _busy:
		_finish_turn()

func _on_openagentic_event(ev: Dictionary) -> void:
	var t := String(ev.get("type", ""))
	if t == "assistant.delta":
		_reply_buf += String(ev.get("text_delta", ""))
		return
	if t == "result":
		if _reply_buf.strip_edges() != "":
			_send_irc_text(_reply_buf)
		_finish_turn()

func _finish_turn() -> void:
	_busy = false
	_reply_buf = ""
	if not _queue.is_empty():
		var next := String(_queue.pop_front())
		_start_turn(next)

func _send_irc_text(text: String) -> void:
	if _link == null or not is_instance_valid(_link):
		return
	if not _link.has_method("send_channel_message"):
		return
	var msg := text.strip_edges()
	if msg == "":
		return
	var max_len := max_irc_message_len
	if max_len < 50:
		max_len = 50

	# Never chunk-split OAMEDIA1 base64 payload without explicit fragment headers.
	if msg.begins_with("OAMEDIA1 "):
		var lines: Array[String] = _OAMediaRef.irc_encode_lines(msg, max_len)
		if lines.size() == 0:
			_link.call("send_channel_message", "[OAMEDIA] message too long to send safely")
			return
		for l in lines:
			_link.call("send_channel_message", l)
		return

	while msg.length() > max_len:
		_link.call("send_channel_message", msg.substr(0, max_len))
		msg = msg.substr(max_len)
	if msg != "":
		_link.call("send_channel_message", msg)

func _current_bound_npc_id() -> String:
	if _indicator == null or not is_instance_valid(_indicator):
		return ""
	if not _indicator.has_method("get_bound_npc_id"):
		return ""
	return String(_indicator.call("get_bound_npc_id")).strip_edges()

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
