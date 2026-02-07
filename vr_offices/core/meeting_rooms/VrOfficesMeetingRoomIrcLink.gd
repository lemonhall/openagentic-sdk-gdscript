extends Node
signal status_changed(status: String)
signal ready_changed(ready: bool)
signal message_received(msg: RefCounted)
signal error(msg: String)
const IrcClient := preload("res://addons/irc_client/IrcClient.gd")
const IrcNames := preload("res://vr_offices/core/irc/VrOfficesIrcNames.gd")
const _NamesRequester := preload("res://vr_offices/core/irc/VrOfficesIrcNamesRequester.gd")
var _config: Dictionary = {}
var _save_id: String = ""
var _meeting_room_id: String = ""
var _desired_channel: String = ""
var _nick: String = ""
var _client: Node = null
var _status: String = "idle"
var _ready: bool = false
var _joined_this_session := false
var _connect_key: String = ""
func _online_tests_enabled() -> bool:
	return OS.get_cmdline_args().has("--oa-online-tests")
func configure(config: Dictionary, save_id: String, meeting_room_id: String, nick: String) -> void:
	_config = config if config != null else {}
	_save_id = save_id.strip_edges()
	_meeting_room_id = meeting_room_id.strip_edges()
	_nick = nick.strip_edges()
	if _nick == "":
		_nick = "host"
	var channellen := int(_config.get("channellen_default", 50))
	_desired_channel = String(IrcNames.derive_channel_for_meeting_room(_save_id, _meeting_room_id, channellen))
	_ensure_client()
	_joined_this_session = false
	_set_ready(false)
	_client.call("set_cap_enabled", false)
	_client.call("set_auto_reconnect_enabled", true)
	_client.call("set_auto_rejoin_enabled", true)
	var host := String(_config.get("host", "")).strip_edges()
	var port := int(_config.get("port", 0))
	var tls := bool(_config.get("tls", false))
	var server_name := String(_config.get("server_name", "")).strip_edges()
	var password := String(_config.get("password", "")).strip_edges()
	var new_key := "%s|%d|%s|%s|%s|%s" % [host, port, "tls" if tls else "tcp", server_name, password, _nick]
	var key_changed := _connect_key != "" and _connect_key != new_key
	_connect_key = new_key
	if password != "":
		_client.call("set_password", password)
	_client.call("set_nick", _nick)
	_client.call("set_user", _nick, "0", "*", _nick)
	if key_changed and _client != null:
		_set_status("reconnecting")
		_client.call("close_connection")
	_connect_if_needed()

func get_desired_channel() -> String:
	return _desired_channel
func get_nick() -> String:
	return _nick
func get_status() -> String:
	return _status
func is_ready() -> bool:
	return _ready
func send_channel_message(text: String) -> void:
	if _client == null:
		return
	var msg := text.strip_edges()
	if msg == "" or _desired_channel.strip_edges() == "":
		return
	_client.call("privmsg", _desired_channel, msg)
func close_connection() -> void:
	if _client != null:
		_client.call("close_connection")
func reconnect_now() -> void:
	_ensure_client()
	_joined_this_session = false
	_set_ready(false)
	if _client != null:
		_client.call("close_connection")
	_connect_if_needed()
func _process(dt: float) -> void:
	if _client != null:
		_client.call("poll", dt)
func _exit_tree() -> void:
	if _client != null:
		_client.call("close_connection")
func _ensure_client() -> void:
	if _client != null and is_instance_valid(_client):
		return
	_client = IrcClient.new()
	add_child(_client)
	_client.connected.connect(_on_connected)
	_client.disconnected.connect(_on_disconnected)
	_client.message_received.connect(_on_message_received)
	_client.raw_line_received.connect(_on_raw_line_received)
	_client.error.connect(_on_error)
func _connect_if_needed() -> void:
	if _client == null:
		return
	var headless := DisplayServer.get_name() == "headless" or OS.has_feature("server") or OS.has_feature("headless")
	if headless and not _online_tests_enabled():
		_set_status("headless")
		return
	var host := String(_config.get("host", "")).strip_edges()
	var port := int(_config.get("port", 0))
	if host == "" or port <= 0:
		_set_status("disabled")
		return
	_set_status("connecting")
	var tls := bool(_config.get("tls", false))
	if tls:
		var server_name := String(_config.get("server_name", "")).strip_edges()
		_client.call("connect_to_tls", host, port, server_name)
	else:
		_client.call("connect_to", host, port)
func _set_status(s: String) -> void:
	var ss := s.strip_edges()
	if ss == "":
		ss = "unknown"
	if ss == _status:
		return
	_status = ss
	status_changed.emit(_status)
func _set_ready(v: bool) -> void:
	if v == _ready:
		return
	_ready = v
	ready_changed.emit(_ready)
func _on_connected() -> void:
	_joined_this_session = false
	_set_status("tcp_connected")
func _on_disconnected() -> void:
	_set_ready(false)
	_set_status("disconnected")
func _on_error(msg0: String) -> void:
	error.emit(msg0)
func _on_raw_line_received(_line: String) -> void:
	pass
func _on_message_received(msg: RefCounted) -> void:
	message_received.emit(msg)
	if msg == null:
		return
	var obj := msg as Object
	var cmd := String(obj.get("command"))
	if cmd == "001":
		_set_status("registered")
		_try_join()
	elif cmd == "JOIN":
		if _join_matches_desired(obj):
			_set_status("joined")
			_set_ready(true)
func _try_join() -> void:
	if _client == null or _joined_this_session:
		return
	var ch := _desired_channel.strip_edges()
	if ch == "":
		return
	_joined_this_session = true
	_client.call("join", ch)
func _join_matches_desired(msg: Object) -> bool:
	if msg == null:
		return false
	var desired := _desired_channel.strip_edges()
	if desired == "":
		return false
	var ch := ""
	var params0: Variant = msg.get("params")
	if params0 is Array:
		var params := params0 as Array
		if not params.is_empty():
			ch = String(params[0]).strip_edges()
	if ch == "":
		var trailing0: Variant = msg.get("trailing")
		ch = "" if trailing0 == null else String(trailing0).strip_edges()
	if ch == "":
		return false
	for part0 in ch.split(",", false):
		if String(part0).strip_edges() == desired:
			return true
	return false
func request_names_for_desired_channel(timeout_frames: int = 240) -> Dictionary:
	if _NamesRequester == null or _client == null:
		return {}
	var ch := _desired_channel.strip_edges()
	if ch == "":
		return {}
	var res: Variant = await _NamesRequester.request_names(self, _client, ch, timeout_frames)
	return res as Dictionary if typeof(res) == TYPE_DICTIONARY else {}
