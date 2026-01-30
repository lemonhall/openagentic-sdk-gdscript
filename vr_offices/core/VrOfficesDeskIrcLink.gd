extends Node

signal status_changed(status: String)
signal ready_changed(ready: bool)
signal message_received(msg: RefCounted)
signal error(msg: String)

const IrcClient := preload("res://addons/irc_client/IrcClient.gd")
const IrcNames := preload("res://vr_offices/core/VrOfficesIrcNames.gd")

var _config: Dictionary = {"enabled": false}
var _save_id: String = ""
var _desk_id: String = ""

var _client: Node = null
var _status: String = "idle"
var _ready: bool = false
var _desired_channel: String = ""
var _joined_this_session: bool = false

func configure(config: Dictionary, save_id: String, desk_id: String) -> void:
	_config = config if config != null else {"enabled": false}
	_save_id = save_id.strip_edges()
	_desk_id = desk_id.strip_edges()

	var nicklen := int(_config.get("nicklen_default", 9))
	var channellen := int(_config.get("channellen_default", 50))
	var nick := String(IrcNames.derive_nick(_save_id, _desk_id, nicklen))
	_desired_channel = String(IrcNames.derive_channel(_save_id, _desk_id, channellen))

	_ensure_client()
	_joined_this_session = false
	_set_ready(false)

	_client.call("set_cap_enabled", false)
	_client.call("set_auto_reconnect_enabled", true)
	_client.call("set_auto_rejoin_enabled", true)

	var password := String(_config.get("password", "")).strip_edges()
	if password != "":
		_client.call("set_password", password)

	_client.call("set_nick", nick)
	_client.call("set_user", nick, "0", "*", nick)

	if bool(_config.get("enabled", false)):
		_connect_if_needed()

func get_desired_channel() -> String:
	return _desired_channel

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
	_client.error.connect(_on_error)

func _connect_if_needed() -> void:
	if _client == null:
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

func _on_error(msg: String) -> void:
	error.emit(msg)

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
	var params0: Variant = msg.get("params")
	if not (params0 is Array):
		return
	var params := params0 as Array
	if params.is_empty():
		return
	var ch := String(params[0]).strip_edges()
	if ch == "" or ch != _desired_channel:
		return
	_set_status("joined")
	_set_ready(true)

