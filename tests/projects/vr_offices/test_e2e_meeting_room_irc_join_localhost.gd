extends SceneTree

const T := preload("res://tests/_test_util.gd")
const IrcClient := preload("res://addons/irc_client/IrcClient.gd")
const IrcNames := preload("res://vr_offices/core/irc/VrOfficesIrcNames.gd")

func _init() -> void:
	var args := OS.get_cmdline_args()
	if not _has_flag(args, "--oa-online-tests"):
		print("SKIP: pass --oa-online-tests to run the meeting-room IRC localhost E2E test.")
		T.pass_and_quit(self)
		return

	var irc_host := _arg_value(args, "--oa-irc-host=")
	if irc_host == "":
		irc_host = "127.0.0.1"
	var irc_port := int(_arg_value(args, "--oa-irc-port="))
	if irc_port <= 0:
		irc_port = 6667
	print("ONLINE TEST: irc=%s:%d" % [irc_host, irc_port])

	var save_id: String = "slot_test_meeting_irc_e2e_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	var oa := get_root().get_node_or_null("OpenAgentic") as Node
	var created_oa := false
	if oa == null:
		var OAScript := load("res://addons/openagentic/OpenAgentic.gd")
		if OAScript == null:
			T.fail_and_quit(self, "Missing res://addons/openagentic/OpenAgentic.gd")
			return
		oa = (OAScript as Script).new() as Node
		if oa == null:
			T.fail_and_quit(self, "Failed to instantiate OpenAgentic.gd")
			return
		oa.name = "OpenAgentic"
		get_root().add_child(oa)
		created_oa = true
		await process_frame
	oa.call("set_save_id", save_id)

	var VrScene := load("res://vr_offices/VrOffices.tscn")
	if VrScene == null or not (VrScene is PackedScene):
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
		T.fail_and_quit(self, "VrOffices must implement set_irc_config")
		return
	s.call("set_irc_config", cfg)
	await process_frame

	# Create meeting room.
	var mgr0: Variant = s.get("_meeting_room_manager")
	if not (mgr0 is RefCounted):
		T.fail_and_quit(self, "Missing _meeting_room_manager")
		return
	var mgr := mgr0 as RefCounted
	var res: Dictionary = mgr.call("create_meeting_room", Rect2(Vector2(-2, -2), Vector2(4, 4)), "Room A")
	if not T.require_true(self, bool(res.get("ok", false)), "Expected create_meeting_room ok"):
		return
	await process_frame
	await process_frame

	var room_dict0: Variant = res.get("meeting_room", {})
	if typeof(room_dict0) != TYPE_DICTIONARY:
		T.fail_and_quit(self, "Expected meeting_room dict")
		return
	var room_dict := room_dict0 as Dictionary
	var rid := String(room_dict.get("id", "")).strip_edges()
	if rid == "":
		T.fail_and_quit(self, "Meeting room id empty")
		return

	# Find room node + table.
	var rooms_root := s.get_node_or_null("MeetingRooms") as Node3D
	if rooms_root == null or rooms_root.get_child_count() < 1:
		T.fail_and_quit(self, "Missing MeetingRooms child")
		return
	var room := rooms_root.get_child(0) as Node
	if room == null:
		T.fail_and_quit(self, "Missing meeting room node")
		return
	var table := room.get_node_or_null("Decor/Table") as Node3D
	if table == null:
		T.fail_and_quit(self, "Missing Decor/Table")
		return

	# Spawn 3 NPCs and bind into meeting state.
	var npc_scene := load("res://vr_offices/npc/Npc.tscn")
	if npc_scene == null or not (npc_scene is PackedScene):
		T.fail_and_quit(self, "Missing Npc.tscn")
		return
	var npc_root := s.get_node_or_null("NpcRoot") as Node3D
	if npc_root == null:
		T.fail_and_quit(self, "Missing NpcRoot")
		return

	var npc_ids := ["npc_01", "npc_02", "npc_03"]
	for nid in npc_ids:
		var n := (npc_scene as PackedScene).instantiate() as Node
		n.name = nid
		if n.has_method("set"):
			n.set("npc_id", nid)
			n.set("display_name", nid)
		npc_root.add_child(n)
	await process_frame

	var near := table.global_position + Vector3(1.0, 0.0, 0.0)
	for nid in npc_ids:
		var n2 := npc_root.get_node_or_null(NodePath(nid)) as Node
		if n2 == null:
			T.fail_and_quit(self, "Missing NPC node: %s" % nid)
			return
		n2.emit_signal("move_target_reached", nid, Vector3(near.x, 0.0, near.z))
	await process_frame

	# Open overlay via mic and send one host message to ensure host link is created.
	var mic := room.get_node_or_null("Decor/Table/Mic") as Node
	if mic == null:
		T.fail_and_quit(self, "Missing Decor/Table/Mic")
		return
	if s.has_method("open_meeting_room_chat_for_mic"):
		s.call("open_meeting_room_chat_for_mic", mic)
	await process_frame
	var overlay := s.get_node_or_null("UI/MeetingRoomChatOverlay") as Control
	if overlay != null:
		overlay.emit_signal("message_submitted", "e2e ping")
	await process_frame

	var ch := String(IrcNames.derive_channel_for_meeting_room(save_id, rid, 50)).strip_edges()
	if not T.require_true(self, ch.begins_with("#"), "Expected derived meeting channel to start with #"):
		return

	var host_nick := String(IrcNames.derive_nick(save_id, "meetingroom_%s" % rid, 9)).strip_edges()
	var want_nicks: Array[String] = [host_nick]
	for nid in npc_ids:
		want_nicks.append(String(IrcNames.derive_nick(save_id, nid, 9)).strip_edges())

	var bridge := s.get_node_or_null("MeetingRoomIrcBridge") as Node
	if bridge == null:
		_cleanup(s, oa, created_oa)
		T.fail_and_quit(self, "Missing MeetingRoomIrcBridge")
		return

	# Use the host's real IRC connection to query NAMES (avoid extra monitor connection;
	# some servers cap connections per IP).
	var host_link0: Variant = bridge.call("get_host_link", rid) if bridge.has_method("get_host_link") else null
	var host_link := host_link0 as Node
	if host_link == null or not is_instance_valid(host_link):
		_cleanup(s, oa, created_oa)
		T.fail_and_quit(self, "Missing host IRC link")
		return
	if not await _wait_for_ready(host_link, 900):
		if bridge.has_method("close_room_connections"):
			bridge.call("close_room_connections", rid)
		_cleanup(s, oa, created_oa)
		T.fail_and_quit(self, "Host IRC link did not become ready (JOIN) to %s:%d" % [irc_host, irc_port])
		return

	# Retry NAMES until the server reports all expected nicks in the channel.
	var missing_last: Array[String] = []
	var ok := false
	for _attempt in range(18):
		var names0: Variant = await host_link.call("request_names_for_desired_channel", 240) if host_link.has_method("request_names_for_desired_channel") else {}
		var names: Dictionary = names0 as Dictionary if typeof(names0) == TYPE_DICTIONARY else {}
		var missing := _missing_nicks(names, want_nicks)
		if missing.is_empty():
			print("E2E OK: channel=%s nicks=%s" % [ch, ", ".join(want_nicks)])
			ok = true
			break
		missing_last = missing
		await _pump(null, 30)

	if bridge.has_method("close_room_connections"):
		bridge.call("close_room_connections", rid)
	_cleanup(s, oa, created_oa)
	if ok:
		T.pass_and_quit(self)
		return
	T.fail_and_quit(self, "E2E FAIL: channel=%s missing=%s (expected=%s)" % [ch, ", ".join(missing_last), ", ".join(want_nicks)])

func _cleanup(vr_scene: Node, oa: Node, created_oa: bool) -> void:
	if vr_scene != null and is_instance_valid(vr_scene):
		if vr_scene.get_parent() != null:
			vr_scene.get_parent().remove_child(vr_scene)
		vr_scene.free()
	if created_oa and oa != null and is_instance_valid(oa):
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

static func _pump(client: Node, frames: int) -> void:
	for _i in range(max(1, frames)):
		if client != null:
			client.call("poll", 0.016)
		await Engine.get_main_loop().process_frame

static func _wait_for_ready(link: Node, max_frames: int) -> bool:
	if link == null or not is_instance_valid(link) or not link.has_method("is_ready"):
		return false
	for _i in range(max_frames):
		if bool(link.call("is_ready")):
			return true
		await _pump(null, 1)
	return false

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
				# params: <me> <symbol> <#channel> ; trailing: names
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
