extends Node

signal log_line(line: String)
signal status_changed(status: String)

const IrcClient := preload("res://addons/irc_client/IrcClient.gd")

var _config: Dictionary = {}
var _client: Node = null
var _status: String = ""

func _ready() -> void:
	_client = IrcClient.new()
	add_child(_client)
	_client.connected.connect(func() -> void:
		_set_status("connected")
		log_line.emit("connected")
	)
	_client.disconnected.connect(func() -> void:
		_set_status("disconnected")
		log_line.emit("disconnected")
	)
	_client.error.connect(func(msg: String) -> void:
		log_line.emit("error: %s" % msg)
	)
	_client.raw_line_received.connect(func(line: String) -> void:
		log_line.emit(line)
	)
	_client.message_received.connect(func(msg: RefCounted) -> void:
		if msg == null:
			return
		var obj := msg as Object
		var cmd := String(obj.get("command"))
		if cmd == "001":
			_set_status("registered")
	)

	_client.call("set_cap_enabled", false)
	_client.call("set_auto_reconnect_enabled", false)
	_client.call("set_auto_rejoin_enabled", false)

func set_config(cfg: Dictionary) -> void:
	_config = cfg if cfg != null else {}

func get_status() -> String:
	return _status

func connect_now() -> void:
	if _client == null:
		return
	var host := String(_config.get("host", "")).strip_edges()
	var port := int(_config.get("port", 6667))
	if host == "":
		log_line.emit("missing host")
		return

	var nick := String(_config.get("test_nick", "tester")).strip_edges()
	if nick == "":
		nick = "tester"
	_client.call("set_nick", nick)
	_client.call("set_user", nick, "0", "*", nick)
	var pw := String(_config.get("password", "")).strip_edges()
	if pw != "":
		_client.call("set_password", pw)

	_set_status("connecting")
	if bool(_config.get("tls", false)):
		_client.call("connect_to_tls", host, port, String(_config.get("server_name", "")))
	else:
		_client.call("connect_to", host, port)

func disconnect_now() -> void:
	if _client == null:
		return
	_client.call("close_connection")
	_set_status("")

func join_test_channel() -> void:
	if _client == null:
		return
	var ch := String(_config.get("test_channel", "#test")).strip_edges()
	if ch == "":
		log_line.emit("missing test channel")
		return
	_client.call("join", ch)
	log_line.emit("JOIN %s" % ch)

func send_test_message(text: String) -> void:
	if _client == null:
		return
	var ch := String(_config.get("test_channel", "#test")).strip_edges()
	var msg := text.strip_edges()
	if ch == "" or msg == "":
		return
	_client.call("privmsg", ch, msg)
	log_line.emit("-> %s: %s" % [ch, msg])

func _process(dt: float) -> void:
	if _client != null:
		_client.call("poll", dt)

func _set_status(s: String) -> void:
	var ss := s.strip_edges()
	if ss == _status:
		return
	_status = ss
	status_changed.emit(_status)

