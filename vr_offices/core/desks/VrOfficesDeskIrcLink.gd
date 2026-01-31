extends Node

signal status_changed(status: String)
signal ready_changed(ready: bool)
signal message_received(msg: RefCounted)
signal error(msg: String)

const IrcClient := preload("res://addons/irc_client/IrcClient.gd")
const IrcNames := preload("res://vr_offices/core/irc/VrOfficesIrcNames.gd")
const _DeskIrcLog := preload("res://vr_offices/core/desks/VrOfficesDeskIrcLog.gd")
const _JoinTracker := preload("res://vr_offices/core/desks/VrOfficesDeskIrcJoinTracker.gd")

var _config: Dictionary = {}
var _save_id: String = ""
var _workspace_id: String = ""
var _desk_id: String = ""

var _client: Node = null
var _status: String = "idle"
var _ready: bool = false
var _desired_channel: String = ""
var _nick: String = ""
var _join_tracker := _JoinTracker.new()
var _log: RefCounted = null

func configure(config: Dictionary, save_id: String, workspace_id: String, desk_id: String) -> void:
	_config = config if config != null else {}
	_save_id = save_id.strip_edges()
	_workspace_id = workspace_id.strip_edges()
	_desk_id = desk_id.strip_edges()

	var nicklen := int(_config.get("nicklen_default", 9))
	var channellen := int(_config.get("channellen_default", 50))
	var nick := String(IrcNames.derive_nick(_save_id, _desk_id, nicklen))
	_nick = nick
	_desired_channel = String(IrcNames.derive_channel_for_workspace(_save_id, _workspace_id, _desk_id, channellen))

	_ensure_client()
	_join_tracker.reset()
	_set_ready(false)
	_ensure_logger()
	_log.call("configure", _save_id, _desk_id)
	_log.call("clear")
	_log_line("config desk=%s ws=%s ch=%s" % [_desk_id, _workspace_id, _desired_channel])

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

func get_nick() -> String:
	return _nick

func get_status() -> String:
	return _status

func is_ready() -> bool:
	return _ready

func get_debug_lines() -> Array[String]:
	if _log == null:
		return []
	var v: Variant = _log.call("get_lines")
	return v as Array[String] if (v is Array) else []

func get_debug_snapshot() -> Dictionary:
	return {
		"save_id": _save_id,
		"workspace_id": _workspace_id,
		"desk_id": _desk_id,
		"desired_channel": _desired_channel,
		"status": _status,
		"ready": _ready,
		"log_file_user": "" if _log == null else String(_log.call("get_log_file_user_path")),
		"log_file_abs": "" if _log == null else String(_log.call("get_log_file_abs_path")),
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
	_join_tracker.reset()
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
	_log_line("status=%s" % _status)
	status_changed.emit(_status)

func _set_ready(v: bool) -> void:
	if v == _ready:
		return
	_ready = v
	_log_line("ready=%s" % ("true" if _ready else "false"))
	ready_changed.emit(_ready)

func _on_connected() -> void:
	_join_tracker.reset()
	_set_status("tcp_connected")

func _on_disconnected() -> void:
	_set_ready(false)
	_set_status("disconnected")

func _on_error(msg: String) -> void:
	_log_line("error: %s" % msg)
	error.emit(msg)

func _on_raw_line_received(line: String) -> void:
	# Keep a copy for debugging/verification.
	_log_line(line)

func _on_message_received(msg: RefCounted) -> void:
	message_received.emit(msg)
	if msg == null:
		return
	var obj := msg as Object
	var cmd := String(obj.get("command"))
	if cmd == "001":
		_set_status("registered")
		_join_tracker.try_join_after_welcome(_client, _desired_channel)
	elif cmd == "JOIN":
		if _join_tracker.join_matches_desired(obj, _desired_channel):
			_set_status("joined")
			_set_ready(true)

func _ensure_logger() -> void:
	if _log != null and is_instance_valid(_log):
		return
	_log = _DeskIrcLog.new()

func _log_line(line: String) -> void:
	if line.strip_edges() == "":
		return
	_ensure_logger()
	_log.call("append", line)
