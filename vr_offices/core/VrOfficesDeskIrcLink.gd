extends Node

signal status_changed(status: String)
signal ready_changed(ready: bool)
signal message_received(msg: RefCounted)
signal error(msg: String)

const IrcClient := preload("res://addons/irc_client/IrcClient.gd")
const IrcNames := preload("res://vr_offices/core/VrOfficesIrcNames.gd")
const _OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")

var _config: Dictionary = {}
var _save_id: String = ""
var _workspace_id: String = ""
var _desk_id: String = ""

var _client: Node = null
var _status: String = "idle"
var _ready: bool = false
var _desired_channel: String = ""
var _joined_this_session: bool = false
var _log_lines: Array[String] = []
var _max_log_lines := 200
var _max_log_file_bytes := 256 * 1024

func configure(config: Dictionary, save_id: String, workspace_id: String, desk_id: String) -> void:
	_config = config if config != null else {}
	_save_id = save_id.strip_edges()
	_workspace_id = workspace_id.strip_edges()
	_desk_id = desk_id.strip_edges()

	var nicklen := int(_config.get("nicklen_default", 9))
	var channellen := int(_config.get("channellen_default", 50))
	var nick := String(IrcNames.derive_nick(_save_id, _desk_id, nicklen))
	_desired_channel = String(IrcNames.derive_channel_for_workspace(_save_id, _workspace_id, _desk_id, channellen))

	_ensure_client()
	_joined_this_session = false
	_set_ready(false)
	_clear_log()
	_log("config desk=%s ws=%s ch=%s" % [_desk_id, _workspace_id, _desired_channel])

	_client.call("set_cap_enabled", false)
	_client.call("set_auto_reconnect_enabled", true)
	_client.call("set_auto_rejoin_enabled", true)

	var password := String(_config.get("password", "")).strip_edges()
	if password != "":
		_client.call("set_password", password)

	_client.call("set_nick", nick)
	_client.call("set_user", nick, "0", "*", nick)

	_connect_if_needed()

func get_desired_channel() -> String:
	return _desired_channel

func get_status() -> String:
	return _status

func is_ready() -> bool:
	return _ready

func get_debug_lines() -> Array[String]:
	return _log_lines.duplicate()

func get_debug_snapshot() -> Dictionary:
	return {
		"save_id": _save_id,
		"workspace_id": _workspace_id,
		"desk_id": _desk_id,
		"desired_channel": _desired_channel,
		"status": _status,
		"ready": _ready,
		"log_file_user": _log_file_user_path(),
		"log_file_abs": _log_file_abs_path(),
		"log_lines": get_debug_lines(),
	}

func send_channel_message(text: String) -> void:
	if _client == null:
		return
	var msg := text.strip_edges()
	if msg == "" or _desired_channel.strip_edges() == "":
		return
	_client.call("privmsg", _desired_channel, msg)

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
	if DisplayServer.get_name() == "headless" or OS.has_feature("server") or OS.has_feature("headless"):
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
	_log("status=%s" % _status)
	status_changed.emit(_status)

func _set_ready(v: bool) -> void:
	if v == _ready:
		return
	_ready = v
	_log("ready=%s" % ("true" if _ready else "false"))
	ready_changed.emit(_ready)

func _on_connected() -> void:
	_joined_this_session = false
	_set_status("tcp_connected")

func _on_disconnected() -> void:
	_set_ready(false)
	_set_status("disconnected")

func _on_error(msg: String) -> void:
	_log("error: %s" % msg)
	error.emit(msg)

func _on_raw_line_received(line: String) -> void:
	# Keep a copy for debugging/verification.
	_log(line)

func _on_message_received(msg: RefCounted) -> void:
	message_received.emit(msg)
	if msg == null:
		return
	var obj := msg as Object
	var cmd := String(obj.get("command"))
	if cmd == "001":
		_set_status("registered")
		_try_join_after_welcome()
	elif cmd == "JOIN":
		_maybe_mark_joined(obj)

func _try_join_after_welcome() -> void:
	if _client == null:
		return
	if _joined_this_session:
		return
	var ch := _desired_channel.strip_edges()
	if ch == "":
		return
	_joined_this_session = true
	_client.call("join", ch)

func _maybe_mark_joined(msg: Object) -> void:
	if msg == null:
		return
	var ch := ""

	var params0: Variant = msg.get("params")
	if params0 is Array:
		var params := params0 as Array
		if not params.is_empty():
			ch = String(params[0]).strip_edges()

	# Some servers send `JOIN :#channel` (channel ends up in `trailing` for our parser).
	if ch == "":
		var trailing0: Variant = msg.get("trailing")
		if trailing0 == null:
			ch = ""
		else:
			ch = String(trailing0).strip_edges()
	if ch == "":
		return

	var desired := _desired_channel.strip_edges()
	if desired == "":
		return

	for part0 in ch.split(",", false):
		var part := String(part0).strip_edges()
		if part == desired:
			_set_status("joined")
			_set_ready(true)
			return

func _clear_log() -> void:
	_log_lines = []

func _log(line: String) -> void:
	var t := line.strip_edges()
	if t == "":
		return
	var entry := "[%s] %s" % [Time.get_time_string_from_system(), t]
	_log_lines.append(entry)
	while _log_lines.size() > _max_log_lines:
		_log_lines.pop_front()
	_append_log_to_disk(entry + "\n")

func _log_file_user_path() -> String:
	if _save_id == "" or _desk_id == "":
		return ""
	return "%s/vr_offices/desks/%s/irc.log" % [_OAPaths.save_root(_save_id), _desk_id]

func _log_file_abs_path() -> String:
	var p := _log_file_user_path()
	if p == "":
		return ""
	return ProjectSettings.globalize_path(p)

func _append_log_to_disk(text: String) -> void:
	var path := _log_file_user_path()
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
