extends RefCounted

const IrcClientTransport := preload("res://addons/irc_client/IrcClientTransport.gd")
const IrcParser := preload("res://addons/irc_client/IrcParser.gd")
const IrcClientCap := preload("res://addons/irc_client/IrcClientCap.gd")
const IrcClientPing := preload("res://addons/irc_client/IrcClientPing.gd")
const IrcClientCtcp := preload("res://addons/irc_client/IrcClientCtcp.gd")
const IrcClientChannels := preload("res://addons/irc_client/IrcClientChannels.gd")
const IrcClientReconnect := preload("res://addons/irc_client/IrcClientReconnect.gd")
const IrcClientInbound := preload("res://addons/irc_client/IrcClientInbound.gd")
const IrcClientRegistration := preload("res://addons/irc_client/IrcClientRegistration.gd")
const IrcClientServerInfo := preload("res://addons/irc_client/IrcClientServerInfo.gd")
const IrcWire := preload("res://addons/irc_client/IrcWire.gd")

const IrcClientCoreCommands := preload("res://addons/irc_client/IrcClientCoreCommands.gd")
const IrcClientCoreEngine := preload("res://addons/irc_client/IrcClientCoreEngine.gd")

var _transport = null
var _parser = null
var _wire = null
var _cap = null
var _ping = null
var _ctcp = null
var _channels = null
var _reconnect = null
var _inbound = null
var _reg = null
var _server_info = null

var _cmd = null
var _engine = null

func _ensure_init() -> void:
	if _engine != null:
		return
	_parser = IrcParser.new()
	_wire = IrcWire.new()
	_transport = IrcClientTransport.new()
	_cap = IrcClientCap.new()
	_ping = IrcClientPing.new()
	_ctcp = IrcClientCtcp.new()
	_channels = IrcClientChannels.new()
	_reconnect = IrcClientReconnect.new()
	_inbound = IrcClientInbound.new()
	_reg = IrcClientRegistration.new()
	_server_info = IrcClientServerInfo.new()

	_cmd = IrcClientCoreCommands.new()
	_cmd.call("configure", _wire, _transport, _cap, _ctcp, _channels, _reg)

	_engine = IrcClientCoreEngine.new()

func configure_callbacks(
	emit_connected: Callable,
	emit_disconnected: Callable,
	emit_raw_line: Callable,
	emit_message: Callable,
	emit_ctcp_action: Callable,
	emit_error: Callable,
) -> void:
	_ensure_init()
	_engine.call("configure",
		_transport,
		_parser,
		_cap,
		_ping,
		_ctcp,
		_inbound,
		_channels,
		_reconnect,
		_cmd,
		_server_info,
		emit_connected,
		emit_disconnected,
		emit_raw_line,
		emit_message,
		emit_ctcp_action,
		emit_error,
	)

func get_isupport() -> Dictionary:
	_ensure_init()
	if _server_info == null or not _server_info.has_method("get_isupport"):
		return {}
	return _server_info.call("get_isupport")

func get_isupport_int(key: String, default_value: int = 0) -> int:
	_ensure_init()
	if _server_info == null or not _server_info.has_method("get_int"):
		return default_value
	return int(_server_info.call("get_int", key, default_value))

func set_peer(peer: Object) -> void:
	_ensure_init()
	_engine.call("set_peer", peer)

func set_peer_factory(peer_factory: Callable) -> void:
	_ensure_init()
	_transport.call("set_peer_factory", peer_factory)

func set_cap_enabled(enabled: bool) -> void:
	_ensure_init()
	_cap.call("set_enabled", enabled)

func set_requested_caps(caps: Array) -> void:
	_ensure_init()
	_cap.call("set_requested_caps", caps)

func set_sasl_plain(user: String, password: String) -> void:
	_ensure_init()
	_cap.call("set_sasl_plain", user, password)

func set_auto_reconnect_enabled(enabled: bool) -> void:
	_ensure_init()
	_reconnect.call("set_enabled", enabled)

func set_reconnect_backoff_seconds(backoff: Array) -> void:
	_ensure_init()
	_reconnect.call("set_backoff_seconds", backoff)

func set_auto_rejoin_enabled(enabled: bool) -> void:
	_ensure_init()
	_channels.call("set_auto_rejoin_enabled", enabled)

func set_password(password: String) -> void:
	_ensure_init()
	_reg.call("set_password", password)

func set_nick(nick: String) -> void:
	_ensure_init()
	_reg.call("set_nick", nick)

func set_user(user: String, mode: String = "0", unused: String = "*", realname: String = "") -> void:
	_ensure_init()
	_reg.call("set_user", user, mode, unused, realname)

func connect_to(host: String, port: int) -> void:
	_ensure_init()
	_engine.call("connect_to", host, port)

func connect_to_tls_over_stream(stream: StreamPeerTCP, server_name: String) -> void:
	_ensure_init()
	_engine.call("connect_to_tls_over_stream", stream, server_name)

func connect_to_tls(host: String, port: int, server_name: String = "") -> void:
	_ensure_init()
	_engine.call("connect_to_tls", host, port, server_name)

func poll(dt_sec: float = 0.0) -> void:
	_ensure_init()
	_engine.call("poll", dt_sec)

func send_raw_line(line: String) -> void:
	_ensure_init()
	_cmd.call("send_raw_line", line)

func close_connection() -> void:
	_ensure_init()
	_engine.call("close_connection")

func quit(reason: String = "") -> void:
	_ensure_init()
	_engine.call("quit", reason)

func send_message(command: String, params: Array = [], trailing: String = "") -> void:
	_ensure_init()
	_cmd.call("send_message", command, params, trailing)

func join(channel: String) -> void:
	_ensure_init()
	_cmd.call("join", channel)

func part(channel: String, reason: String = "") -> void:
	_ensure_init()
	_cmd.call("part", channel, reason)

func privmsg(target: String, text: String) -> void:
	_ensure_init()
	_cmd.call("privmsg", target, text)

func notice(target: String, text: String) -> void:
	_ensure_init()
	_cmd.call("notice", target, text)

func ctcp_action(target: String, text: String) -> void:
	_ensure_init()
	_cmd.call("ctcp_action", target, text)
