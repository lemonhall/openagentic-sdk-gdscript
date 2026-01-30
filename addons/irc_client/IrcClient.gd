extends Node

signal connected
signal disconnected
signal raw_line_received(line: String)
signal message_received(msg: RefCounted)
signal ctcp_action_received(prefix: String, target: String, text: String)
signal error(msg: String)

const IrcClientCore := preload("res://addons/irc_client/IrcClientCore.gd")

var _core = null

func _ensure_init() -> void:
	if _core != null:
		return
	_core = IrcClientCore.new()
	_core.call("configure_callbacks",
		func() -> void: connected.emit(),
		func() -> void: disconnected.emit(),
		func(line: String) -> void: raw_line_received.emit(line),
		func(msg: RefCounted) -> void: message_received.emit(msg),
		func(prefix: String, target: String, text: String) -> void: ctcp_action_received.emit(prefix, target, text),
		func(msg: String) -> void: error.emit(msg),
	)

func set_peer(peer: Object) -> void:
	_ensure_init()
	_core.call("set_peer", peer)

func set_peer_factory(peer_factory: Callable) -> void:
	_ensure_init()
	_core.call("set_peer_factory", peer_factory)

func set_cap_enabled(enabled: bool) -> void:
	_ensure_init()
	_core.call("set_cap_enabled", enabled)

func set_requested_caps(caps: Array) -> void:
	_ensure_init()
	_core.call("set_requested_caps", caps)

func set_sasl_plain(user: String, password: String) -> void:
	_ensure_init()
	_core.call("set_sasl_plain", user, password)

func set_auto_reconnect_enabled(enabled: bool) -> void:
	_ensure_init()
	_core.call("set_auto_reconnect_enabled", enabled)

func set_reconnect_backoff_seconds(backoff: Array) -> void:
	_ensure_init()
	_core.call("set_reconnect_backoff_seconds", backoff)

func set_auto_rejoin_enabled(enabled: bool) -> void:
	_ensure_init()
	_core.call("set_auto_rejoin_enabled", enabled)

func set_password(password: String) -> void:
	_ensure_init()
	_core.call("set_password", password)

func set_nick(nick: String) -> void:
	_ensure_init()
	_core.call("set_nick", nick)

func set_user(user: String, mode: String = "0", unused: String = "*", realname: String = "") -> void:
	_ensure_init()
	_core.call("set_user", user, mode, unused, realname)

func connect_to(host: String, port: int) -> void:
	_ensure_init()
	_core.call("connect_to", host, port)

func connect_to_tls_over_stream(stream: StreamPeerTCP, server_name: String) -> void:
	_ensure_init()
	_core.call("connect_to_tls_over_stream", stream, server_name)

func connect_to_tls(host: String, port: int, server_name: String = "") -> void:
	_ensure_init()
	_core.call("connect_to_tls", host, port, server_name)

func poll(dt_sec: float = 0.0) -> void:
	_ensure_init()
	_core.call("poll", dt_sec)

func send_raw_line(line: String) -> void:
	_ensure_init()
	_core.call("send_raw_line", line)

func close_connection() -> void:
	_ensure_init()
	_core.call("close_connection")

func quit(reason: String = "") -> void:
	_ensure_init()
	_core.call("quit", reason)

func send_message(command: String, params: Array = [], trailing: String = "") -> void:
	_ensure_init()
	_core.call("send_message", command, params, trailing)

func join(channel: String) -> void:
	_ensure_init()
	_core.call("join", channel)

func part(channel: String, reason: String = "") -> void:
	_ensure_init()
	_core.call("part", channel, reason)

func privmsg(target: String, text: String) -> void:
	_ensure_init()
	_core.call("privmsg", target, text)

func notice(target: String, text: String) -> void:
	_ensure_init()
	_core.call("notice", target, text)

func ctcp_action(target: String, text: String) -> void:
	_ensure_init()
	_core.call("ctcp_action", target, text)

func get_isupport() -> Dictionary:
	_ensure_init()
	if not _core.has_method("get_isupport"):
		return {}
	return _core.call("get_isupport")

func get_isupport_int(key: String, default_value: int = 0) -> int:
	_ensure_init()
	if not _core.has_method("get_isupport_int"):
		return default_value
	return int(_core.call("get_isupport_int", key, default_value))

