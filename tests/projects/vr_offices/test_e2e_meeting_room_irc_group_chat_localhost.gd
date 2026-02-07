extends SceneTree

const T := preload("res://tests/_test_util.gd")
const IrcClient := preload("res://addons/irc_client/IrcClient.gd")
const IrcNames := preload("res://vr_offices/core/irc/VrOfficesIrcNames.gd")
const OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")

class FakeOpenAgentic:
	extends Node

	var save_id: String = ""

	func set_save_id(id: String) -> void:
		save_id = id

	func configure_proxy_openai_responses(_base_url: String, _model: String) -> void:
		pass

	func enable_default_tools() -> void:
		pass

	func set_approver(_fn: Callable) -> void:
		pass

	func add_before_turn_hook(_name: String, _npc_id_glob: String, _cb: Callable) -> void:
		pass

	func add_after_turn_hook(_name: String, _npc_id_glob: String, _cb: Callable) -> void:
		pass

	func run_npc_turn(_npc_id: String, user_text: String, on_event: Callable) -> void:
		var mentioned := user_text.find("你被点名：是") != -1
		var reply := "<<SILENCE>>"
		if mentioned:
			reply = "ACK"
			if user_text.find("[LONG]") != -1:
				reply = "LONG:"
				for _i in range(1400):
					reply += "x"
		on_event.call({"type": "assistant.delta", "text_delta": reply})
		await get_tree().process_frame
		on_event.call({"type": "result"})

func _init() -> void:
	var args := OS.get_cmdline_args()
	if not _has_flag(args, "--oa-online-tests"):
		print("SKIP: pass --oa-online-tests to run the meeting-room IRC group-chat localhost E2E test.")
		T.pass_and_quit(self)
		return

	var irc_host := _arg_value(args, "--oa-irc-host=")
	if irc_host == "":
		irc_host = "127.0.0.1"
	var irc_port := int(_arg_value(args, "--oa-irc-port="))
	if irc_port <= 0:
		irc_port = 6667
	print("ONLINE TEST: irc=%s:%d" % [irc_host, irc_port])

	var save_id: String = "slot_test_meeting_irc_group_chat_e2e_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	var oa := FakeOpenAgentic.new()
	oa.name = "OpenAgentic"
	oa.set_save_id(save_id)
	get_root().add_child(oa)
	await process_frame

	var VrScene := load("res://vr_offices/VrOffices.tscn")
	if VrScene == null or not (VrScene is PackedScene):
		_cleanup(null, null, oa)
		T.fail_and_quit(self, "Missing VrOffices scene")
		return
	var s := (VrScene as PackedScene).instantiate()
	root.add_child(s)
	await process_frame

	# Configure IRC for meeting rooms.
	var cfg := {
		"host": irc_host,
		"port": irc_port,
		"tls": false,
		"server_name": "",
		"password": "",
		"nicklen_default": 9,
		"channellen_default": 50,
	}
	if not s.has_method("set_irc_config"):
		_cleanup(s, null, oa)
		T.fail_and_quit(self, "VrOffices must implement set_irc_config")
		return
	s.call("set_irc_config", cfg)
	await process_frame

	# Create meeting room.
	var mgr0: Variant = s.get("_meeting_room_manager")
	if not (mgr0 is RefCounted):
		_cleanup(s, null, oa)
		T.fail_and_quit(self, "Missing _meeting_room_manager")
		return
	var mgr := mgr0 as RefCounted
	var res: Dictionary = mgr.call("create_meeting_room", Rect2(Vector2(-2, -2), Vector2(4, 4)), "Room A")
	if not T.require_true(self, bool(res.get("ok", false)), "Expected create_meeting_room ok"):
		_cleanup(s, null, oa)
		return
	await process_frame
	await process_frame

	var room_dict0: Variant = res.get("meeting_room", {})
	if typeof(room_dict0) != TYPE_DICTIONARY:
		_cleanup(s, null, oa)
		T.fail_and_quit(self, "Expected meeting_room dict")
		return
	var room_dict := room_dict0 as Dictionary
	var rid := String(room_dict.get("id", "")).strip_edges()
	if rid == "":
		_cleanup(s, null, oa)
		T.fail_and_quit(self, "Meeting room id empty")
		return

	# Find room node + table.
	var rooms_root := s.get_node_or_null("MeetingRooms") as Node3D
	if rooms_root == null or rooms_root.get_child_count() < 1:
		_cleanup(s, null, oa)
		T.fail_and_quit(self, "Missing MeetingRooms child")
		return
	var room := rooms_root.get_child(0) as Node
	if room == null:
		_cleanup(s, null, oa)
		T.fail_and_quit(self, "Missing meeting room node")
		return
	var table := room.get_node_or_null("Decor/Table") as Node3D
	if table == null:
		_cleanup(s, null, oa)
		T.fail_and_quit(self, "Missing Decor/Table")
		return

	# Spawn 3 NPCs and bind into meeting state.
	var npc_scene := load("res://vr_offices/npc/Npc.tscn")
	if npc_scene == null or not (npc_scene is PackedScene):
		_cleanup(s, null, oa)
		T.fail_and_quit(self, "Missing Npc.tscn")
		return
	var npc_root := s.get_node_or_null("NpcRoot") as Node3D
	if npc_root == null:
		_cleanup(s, null, oa)
		T.fail_and_quit(self, "Missing NpcRoot")
		return

	var roster := [
		{"id": "npc_01", "name": "Alice"},
		{"id": "npc_02", "name": "Bob"},
		{"id": "npc_03", "name": "Carol"},
	]
	for p in roster:
		var nid := String(p.get("id", "")).strip_edges()
		var dn := String(p.get("name", "")).strip_edges()
		var n := (npc_scene as PackedScene).instantiate() as Node
		n.name = nid
		if n.has_method("set"):
			n.set("npc_id", nid)
			n.set("display_name", dn)
		npc_root.add_child(n)
	await process_frame

	# Invite NPCs explicitly (no proximity auto-join).
	var part0: Variant = s.get("_meeting_participation")
	if not (part0 is RefCounted):
		_cleanup(s, null, oa)
		T.fail_and_quit(self, "Missing _meeting_participation controller")
		return
	var part := part0 as RefCounted
	if not part.has_method("invite_npc_to_meeting_room"):
		_cleanup(s, null, oa)
		T.fail_and_quit(self, "MeetingParticipationController must implement invite_npc_to_meeting_room(meeting_room_id, npc) -> Vector3")
		return
	for p in roster:
		var nid2 := String(p.get("id", "")).strip_edges()
		var n2 := npc_root.get_node_or_null(NodePath(nid2)) as Node
		if n2 == null:
			_cleanup(s, null, oa)
			T.fail_and_quit(self, "Missing NPC node: %s" % nid2)
			return
		var target0: Variant = part.call("invite_npc_to_meeting_room", rid, n2)
		if not (target0 is Vector3):
			_cleanup(s, null, oa)
			T.fail_and_quit(self, "invite_npc_to_meeting_room must return a Vector3 target for %s" % nid2)
			return
		var target := target0 as Vector3
		if target == Vector3.ZERO:
			_cleanup(s, null, oa)
			T.fail_and_quit(self, "invite_npc_to_meeting_room returned Vector3.ZERO for %s" % nid2)
			return
		# Headless E2E: shortcut pathfinding by directly emitting the reached signal.
		n2.emit_signal("move_target_reached", nid2, target)
	await process_frame

	# Open overlay via mic.
	var mic := room.get_node_or_null("Decor/Table/Mic") as Node
	if mic == null:
		_cleanup(s, null, oa)
		T.fail_and_quit(self, "Missing Decor/Table/Mic")
		return
	if s.has_method("open_meeting_room_chat_for_mic"):
		s.call("open_meeting_room_chat_for_mic", mic)
	await process_frame

	var overlay := s.get_node_or_null("UI/MeetingRoomChatOverlay") as Control
	if overlay == null or not overlay.visible:
		_cleanup(s, null, oa)
		T.fail_and_quit(self, "Expected meeting room overlay visible")
		return

	var ch := String(IrcNames.derive_channel_for_meeting_room(save_id, rid, 50)).strip_edges()
	if not T.require_true(self, ch.begins_with("#"), "Expected derived meeting channel to start with #"):
		_cleanup(s, null, oa)
		return

	var bridge := s.get_node_or_null("MeetingRoomIrcBridge") as Node
	if bridge == null:
		_cleanup(s, null, oa)
		T.fail_and_quit(self, "Missing MeetingRoomIrcBridge")
		return

	# NEW FLOW: meeting room creation should immediately establish the host IRC link and JOIN the derived channel.
	if not bridge.has_method("peek_host_link"):
		_cleanup(s, null, oa)
		T.fail_and_quit(self, "MeetingRoomIrcBridge must implement peek_host_link(meeting_room_id) without creating new links.")
		return
	var host_link0: Variant = bridge.call("peek_host_link", rid)
	var host_link := host_link0 as Node
	if host_link == null or not is_instance_valid(host_link):
		_cleanup(s, null, oa)
		T.fail_and_quit(self, "Expected host IRC link to exist immediately after room creation (auto-join lifecycle).")
		return

	# Sanity: ensure host + three NPCs are present.
	var want_nicks: Array[String] = []
	want_nicks.append(String(IrcNames.derive_nick(save_id, "meetingroom_%s" % rid, 9)).strip_edges())
	for p in roster:
		want_nicks.append(String(IrcNames.derive_nick(save_id, String(p.get("id", "")), 9)).strip_edges())

	var npc_ids := ["npc_01", "npc_02", "npc_03"]
	var npc_links: Dictionary = {}
	for nid in npc_ids:
		var l0: Variant = bridge.call("get_npc_link", rid, nid) if bridge.has_method("get_npc_link") else null
		var l := l0 as Node
		if l == null or not is_instance_valid(l):
			_cleanup(s, null, oa)
			T.fail_and_quit(self, "Missing NPC IRC link: %s" % nid)
			return
		npc_links[nid] = l

	if not await _wait_for_ready(host_link, 900):
		if bridge.has_method("close_room_connections"):
			bridge.call("close_room_connections", rid)
		_cleanup(s, null, oa)
		T.fail_and_quit(self, "Host IRC link did not become ready (JOIN)")
		return
	for nid in npc_ids:
		if not await _wait_for_ready(npc_links[nid] as Node, 900):
			if bridge.has_method("close_room_connections"):
				bridge.call("close_room_connections", rid)
			_cleanup(s, null, oa)
			T.fail_and_quit(self, "NPC IRC link did not become ready (JOIN): %s" % nid)
			return

	var missing: Array[String] = []
	var ready := false
	for _attempt in range(18):
		var names0: Variant = await host_link.call("request_names_for_desired_channel", 240) if host_link.has_method("request_names_for_desired_channel") else {}
		var names: Dictionary = names0 as Dictionary if typeof(names0) == TYPE_DICTIONARY else {}
		missing = _missing_nicks(names, want_nicks)
		if missing.is_empty():
			ready = true
			break
		await _pump_links([host_link, npc_links["npc_01"], npc_links["npc_02"], npc_links["npc_03"]], 30)
	if not T.require_true(self, ready, "Expected all participants JOIN. Missing: %s" % ", ".join(missing)):
		if bridge.has_method("close_room_connections"):
			bridge.call("close_room_connections", rid)
		_cleanup(s, null, oa)
		return

	# Wire inboxes for real IRC messages (no extra monitor connection).
	var host_inbox: Array[RefCounted] = []
	host_link.message_received.connect(func(m: RefCounted) -> void:
		host_inbox.append(m)
	)
	var inbox_01: Array[RefCounted] = []
	var inbox_02: Array[RefCounted] = []
	var inbox_03: Array[RefCounted] = []
	(npc_links["npc_01"] as Node).message_received.connect(func(m: RefCounted) -> void: inbox_01.append(m))
	(npc_links["npc_02"] as Node).message_received.connect(func(m: RefCounted) -> void: inbox_02.append(m))
	(npc_links["npc_03"] as Node).message_received.connect(func(m: RefCounted) -> void: inbox_03.append(m))

	# Send a forced-mention prompt; NPCs must receive host message via IRC, and host must receive Alice's reply via IRC.
	overlay.emit_signal("message_submitted", "hi @Alice")
	var host_nick := want_nicks[0]
	var alice_nick := want_nicks[1]
	if not await _wait_for_privmsg_in_inbox(inbox_01, host_nick, ch, 420, [host_link, npc_links["npc_01"], npc_links["npc_02"], npc_links["npc_03"]]):
		if bridge.has_method("close_room_connections"):
			bridge.call("close_room_connections", rid)
		_cleanup(s, null, oa)
		T.fail_and_quit(self, "Expected NPC_01 to receive host PRIVMSG to meeting channel")
		return
	if not await _wait_for_privmsg_in_inbox(inbox_02, host_nick, ch, 420, [host_link, npc_links["npc_01"], npc_links["npc_02"], npc_links["npc_03"]]):
		if bridge.has_method("close_room_connections"):
			bridge.call("close_room_connections", rid)
		_cleanup(s, null, oa)
		T.fail_and_quit(self, "Expected NPC_02 to receive host PRIVMSG to meeting channel")
		return
	if not await _wait_for_privmsg_in_inbox(inbox_03, host_nick, ch, 420, [host_link, npc_links["npc_01"], npc_links["npc_02"], npc_links["npc_03"]]):
		if bridge.has_method("close_room_connections"):
			bridge.call("close_room_connections", rid)
		_cleanup(s, null, oa)
		T.fail_and_quit(self, "Expected NPC_03 to receive host PRIVMSG to meeting channel")
		return

	if not await _wait_for_privmsg_in_inbox(host_inbox, alice_nick, ch, 420, [host_link, npc_links["npc_01"], npc_links["npc_02"], npc_links["npc_03"]]):
		if bridge.has_method("close_room_connections"):
			bridge.call("close_room_connections", rid)
		_cleanup(s, null, oa)
		T.fail_and_quit(self, "Expected host to receive Alice PRIVMSG to meeting channel")
		return
	if not await _wait_for_privmsg_in_inbox(inbox_02, alice_nick, ch, 420, [host_link, npc_links["npc_01"], npc_links["npc_02"], npc_links["npc_03"]]):
		if bridge.has_method("close_room_connections"):
			bridge.call("close_room_connections", rid)
		_cleanup(s, null, oa)
		T.fail_and_quit(self, "Expected NPC_02 to receive Alice PRIVMSG to meeting channel")
		return

	# Verify Bob's session has a line from Alice (group chat awareness).
	var bob_events := String(OAPaths.npc_events_path(save_id, "npc_02"))
	var bob_abs := ProjectSettings.globalize_path(bob_events)
	if not T.require_true(self, FileAccess.file_exists(bob_abs), "Expected Bob events.jsonl to exist (meeting transcript injection)"):
		if bridge.has_method("close_room_connections"):
			bridge.call("close_room_connections", rid)
		_cleanup(s, null, oa)
		return
	var bob_text := _read_file_text(bob_abs)
	if not T.require_true(self, bob_text.find("Alice") != -1, "Expected Bob session to include Alice public message"):
		if bridge.has_method("close_room_connections"):
			bridge.call("close_room_connections", rid)
		_cleanup(s, null, oa)
		return

	# Send a long prompt to force a long reply and assert it is not truncated on IRC (REQ-008).
	# Wait for the previous fanout run to fully finish; IRC receive can happen before the
	# in-engine broadcast clears its busy flag.
	await _pump_links([host_link, npc_links["npc_01"], npc_links["npc_02"], npc_links["npc_03"]], 60)
	host_inbox.clear()
	overlay.emit_signal("message_submitted", "[LONG] @Alice")
	var got := await _collect_privmsg_text_from_inbox(host_inbox, alice_nick, ch, 1200, 720, [host_link, npc_links["npc_01"], npc_links["npc_02"], npc_links["npc_03"]])
	var want_prefix := "LONG:"
	if not T.require_true(self, got.begins_with(want_prefix), "Expected long reply prefix. Got: %s" % got.substr(0, min(32, got.length()))):
		if bridge.has_method("close_room_connections"):
			bridge.call("close_room_connections", rid)
		_cleanup(s, null, oa)
		return
	if not T.require_true(self, got.length() >= 1200, "Expected long reply to survive IRC transport without truncation. Got len=%d" % got.length()):
		if bridge.has_method("close_room_connections"):
			bridge.call("close_room_connections", rid)
		_cleanup(s, null, oa)
		return

	# Verify meeting-room event log exists (REQ-009).
	var log_path := "%s/vr_offices/meeting_rooms/%s/events.jsonl" % [String(OAPaths.save_root(save_id)), rid]
	var log_abs := ProjectSettings.globalize_path(log_path)
	if not T.require_true(self, FileAccess.file_exists(log_abs), "Expected meeting-room events log at: %s" % log_path):
		if bridge.has_method("close_room_connections"):
			bridge.call("close_room_connections", rid)
		_cleanup(s, null, oa)
		return
	var log_text := _read_file_text(log_abs)
	if not T.require_true(self, log_text.find("\"type\":\"join\"") != -1 and log_text.find("\"type\":\"msg\"") != -1, "Expected join+msg events in meeting log"):
		if bridge.has_method("close_room_connections"):
			bridge.call("close_room_connections", rid)
		_cleanup(s, null, oa)
		return

	if bridge.has_method("close_room_connections"):
		bridge.call("close_room_connections", rid)
	_cleanup(s, null, oa)
	T.pass_and_quit(self)

func _cleanup(vr_scene: Node, monitor: Node, oa: Node) -> void:
	if monitor != null and is_instance_valid(monitor):
		if monitor.has_method("close_connection"):
			monitor.call("close_connection")
		if monitor.get_parent() != null:
			monitor.get_parent().remove_child(monitor)
		monitor.free()
	if vr_scene != null and is_instance_valid(vr_scene):
		if vr_scene.get_parent() != null:
			vr_scene.get_parent().remove_child(vr_scene)
		vr_scene.free()
	if oa != null and is_instance_valid(oa):
		if oa.get_parent() != null:
			oa.get_parent().remove_child(oa)
		oa.free()

static func _has_flag(args: PackedStringArray, flag: String) -> bool:
	for a0 in args:
		if String(a0) == flag:
			return true
	return false

static func _arg_value(args: PackedStringArray, prefix: String) -> String:
	for a0 in args:
		var s := String(a0)
		if s.begins_with(prefix):
			return s.substr(prefix.length()).strip_edges()
	return ""

static func _monitor_nick() -> String:
	var pid := int(OS.get_process_id()) % 100000
	var t := int(Time.get_unix_time_from_system()) % 100000
	return ("mon%05d%03d" % [pid, t % 1000]).substr(0, 9)

static func _strip_mode_prefix(nick: String) -> String:
	var s := nick.strip_edges()
	while s.length() > 0:
		var c := s.substr(0, 1)
		if c == "@" or c == "+" or c == "~" or c == "%" or c == "&":
			s = s.substr(1).strip_edges()
		else:
			break
	return s

static func _missing_nicks(names: Dictionary, want: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for w0 in want:
		var w := String(w0).strip_edges()
		if w == "":
			continue
		if not names.has(w):
			out.append(w)
	return out

static func _parse_names_line(trailing: String) -> Array[String]:
	var out: Array[String] = []
	var t := trailing.strip_edges()
	if t == "":
		return out
	for tok0 in t.split(" ", false):
		var tok := _strip_mode_prefix(String(tok0))
		if tok != "":
			out.append(tok)
	return out

static func _get_cmd(msg: RefCounted) -> String:
	var obj := msg as Object
	if obj == null:
		return ""
	var v: Variant = obj.get("command")
	return "" if v == null else String(v).strip_edges()

static func _get_params(msg: RefCounted) -> Array:
	var obj := msg as Object
	if obj == null:
		return []
	var v: Variant = obj.get("params")
	return v as Array if v is Array else []

static func _get_trailing(msg: RefCounted) -> String:
	var obj := msg as Object
	if obj == null:
		return ""
	var v: Variant = obj.get("trailing")
	return "" if v == null else String(v)

static func _get_prefix(msg: RefCounted) -> String:
	var obj := msg as Object
	if obj == null:
		return ""
	var v: Variant = obj.get("prefix")
	return "" if v == null else String(v)

static func _nick_from_prefix(prefix: String) -> String:
	var p := prefix.strip_edges()
	if p == "":
		return ""
	var bang := p.find("!")
	return (p.substr(0, bang) if bang != -1 else p).strip_edges()

static func _pump(client: Node, frames: int) -> void:
	for _i in range(max(1, frames)):
		if client != null:
			client.call("poll", 0.016)
		await Engine.get_main_loop().process_frame

static func _pump_links(links: Array, frames: int) -> void:
	for _i in range(max(1, frames)):
		for l0 in links:
			var l := l0 as Node
			if l != null and is_instance_valid(l) and l.has_method("_process"):
				l.call("_process", 0.016)
		await Engine.get_main_loop().process_frame

static func _wait_for_ready(link: Node, max_frames: int) -> bool:
	if link == null or not is_instance_valid(link) or not link.has_method("is_ready"):
		return false
	for _i in range(max_frames):
		if bool(link.call("is_ready")):
			return true
		await _pump_links([link], 1)
	return false

static func _wait_for_privmsg_in_inbox(inbox: Array[RefCounted], want_nick: String, want_channel: String, max_frames: int, links: Array) -> bool:
	var wn := want_nick.strip_edges()
	var wc := want_channel.strip_edges()
	for _i in range(max_frames):
		for m in inbox:
			if _get_cmd(m) != "PRIVMSG":
				continue
			var params := _get_params(m)
			if params.size() < 1 or String(params[0]).strip_edges() != wc:
				continue
			if _nick_from_prefix(_get_prefix(m)) == wn:
				return true
		await _pump_links(links, 1)
	return false

static func _collect_privmsg_text_from_inbox(inbox: Array[RefCounted], from_nick: String, channel: String, want_len: int, max_frames: int, links: Array) -> String:
	var wn := from_nick.strip_edges()
	var wc := channel.strip_edges()
	var buf := PackedStringArray()
	var saw_any := false
	for _i in range(max_frames):
		for m in inbox:
			if _get_cmd(m) != "PRIVMSG":
				continue
			var params := _get_params(m)
			if params.size() < 1 or String(params[0]).strip_edges() != wc:
				continue
			if _nick_from_prefix(_get_prefix(m)) != wn:
				continue
			saw_any = true
			var t := _get_trailing(m)
			if t != "":
				buf.append(t)
		var joined := "\n".join(buf)
		if saw_any and joined.length() >= want_len:
			return joined
		await _pump_links(links, 1)
	if buf.is_empty():
		return ""
	return "\n".join(buf)

static func _wait_for_command(client: Node, inbox: Array[RefCounted], want_cmd: String, max_frames: int) -> bool:
	for _i in range(max_frames):
		for m in inbox:
			if _get_cmd(m) == want_cmd:
				return true
		await _pump(client, 1)
	return false

static func _names_for_channel(client: Node, inbox: Array[RefCounted], channel: String, max_frames: int) -> Dictionary:
	inbox.clear()
	client.call("send_message", "NAMES", [channel], "")

	var names: Dictionary = {}
	var ch := channel.strip_edges()
	for _i in range(max_frames):
		for m in inbox:
			var cmd := _get_cmd(m)
			if cmd == "353":
				var params := _get_params(m)
				if params.size() >= 3 and String(params[2]).strip_edges() == ch:
					for n in _parse_names_line(_get_trailing(m)):
						names[n] = true
			elif cmd == "366":
				var params2 := _get_params(m)
				if params2.size() >= 2 and String(params2[1]).strip_edges() == ch:
					return names
		await _pump(client, 1)
	return names

static func _wait_for_privmsg_from(client: Node, inbox: Array[RefCounted], want_nick: String, want_channel: String, max_frames: int) -> bool:
	var wn := want_nick.strip_edges()
	var wc := want_channel.strip_edges()
	for _i in range(max_frames):
		for m in inbox:
			if _get_cmd(m) != "PRIVMSG":
				continue
			var params := _get_params(m)
			if params.size() < 1 or String(params[0]).strip_edges() != wc:
				continue
			if _nick_from_prefix(_get_prefix(m)) == wn:
				return true
		await _pump(client, 1)
	return false

static func _collect_privmsg_text(client: Node, inbox: Array[RefCounted], from_nick: String, channel: String, want_len: int, max_frames: int) -> String:
	var wn := from_nick.strip_edges()
	var wc := channel.strip_edges()
	var buf := PackedStringArray()
	var saw_any := false
	for _i in range(max_frames):
		for m in inbox:
			if _get_cmd(m) != "PRIVMSG":
				continue
			var params := _get_params(m)
			if params.size() < 1 or String(params[0]).strip_edges() != wc:
				continue
			if _nick_from_prefix(_get_prefix(m)) != wn:
				continue
			saw_any = true
			var t := _get_trailing(m)
			if t != "":
				buf.append(t)
		var joined := "\n".join(buf)
		if saw_any and joined.length() >= want_len:
			return joined
		await _pump(client, 1)
	if buf.is_empty():
		return ""
	return "\n".join(buf)

static func _read_file_text(abs_path: String) -> String:
	if abs_path.strip_edges() == "" or not FileAccess.file_exists(abs_path):
		return ""
	var f := FileAccess.open(abs_path, FileAccess.READ)
	if f == null:
		return ""
	var s := String(f.get_as_text())
	f.close()
	return s
