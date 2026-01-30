extends Node
signal connected
signal disconnected
signal raw_line_received(line: String)
signal message_received(msg: RefCounted)
signal ctcp_action_received(prefix: String, target: String, text: String)
signal error(msg: String)
const IrcClientTransport := preload("res://addons/irc_client/IrcClientTransport.gd")
const IrcParser := preload("res://addons/irc_client/IrcParser.gd")
const IrcClientCap := preload("res://addons/irc_client/IrcClientCap.gd")
const IrcClientPing := preload("res://addons/irc_client/IrcClientPing.gd")
const IrcClientCtcp := preload("res://addons/irc_client/IrcClientCtcp.gd")
const IrcClientRegistration := preload("res://addons/irc_client/IrcClientRegistration.gd")
const IrcWire := preload("res://addons/irc_client/IrcWire.gd")
var _parser = null
var _wire = null
var _transport = null
var _cap = null
var _ping = null
var _ctcp = null
var _reg = null
var _was_connected: bool = false
func _ensure_init() -> void:
	if _parser == null: _parser = IrcParser.new()
	if _wire == null: _wire = IrcWire.new()
	if _transport == null: _transport = IrcClientTransport.new()
	if _cap == null: _cap = IrcClientCap.new()
	if _ping == null: _ping = IrcClientPing.new()
	if _ctcp == null: _ctcp = IrcClientCtcp.new()
	if _reg == null: _reg = IrcClientRegistration.new()

func set_peer(peer: Object) -> void:
	_ensure_init()
	_transport.call("set_peer", peer)
	_reg.call("reset")
	_was_connected = false

func set_cap_enabled(enabled: bool) -> void:
	_ensure_init()
	_cap.call("set_enabled", enabled)

func set_requested_caps(caps: Array) -> void:
	_ensure_init()
	_cap.call("set_requested_caps", caps)

func set_sasl_plain(user: String, password: String) -> void:
	_ensure_init()
	_cap.call("set_sasl_plain", user, password)

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
	_reg.call("reset")
	var err: int = int(_transport.call("connect_to", host, port))
	if err != OK:
		error.emit("connect_to_host failed: %s" % str(err))

func connect_to_tls_over_stream(stream: StreamPeerTCP, server_name: String) -> void:
	_ensure_init()
	_reg.call("reset")
	_transport.call("connect_to_tls_over_stream", stream, server_name)

func connect_to_tls(host: String, port: int, server_name: String = "") -> void:
	_ensure_init()
	_reg.call("reset")
	var err: int = int(_transport.call("connect_to_tls", host, port, server_name))
	if err != OK:
		error.emit("connect_to_host failed: %s" % str(err))

func poll() -> void:
	_ensure_init()
	if not bool(_transport.call("has_peer")):
		return

	if not bool(_transport.call("poll_pre")):
		var tls_err: int = int(_transport.call("take_tls_last_err"))
		if tls_err != OK:
			error.emit("tls.connect_to_stream failed: %s" % str(tls_err))
		return

	_transport.call("poll_peer")
	var status: int = int(_transport.call("get_status"))

	if status == StreamPeerTCP.STATUS_CONNECTED and not _was_connected:
		_was_connected = true
		connected.emit()
		_cap.call("on_connected", func(line: String) -> void: send_raw_line(line))
		if not bool(_cap.call("is_in_progress")):
			_send_registration_if_ready()

	if status == StreamPeerTCP.STATUS_NONE or status == StreamPeerTCP.STATUS_ERROR:
		if _was_connected:
			_was_connected = false
			disconnected.emit()
		return

	# Avoid reading/writing until the peer is fully connected (e.g. TLS may be handshaking).
	if status != StreamPeerTCP.STATUS_CONNECTED:
		return

	_read_available()

func send_raw_line(line: String) -> void:
	_ensure_init()
	_transport.call("send_line", line)

func close_connection() -> void:
	_ensure_init()
	if not bool(_transport.call("has_peer")):
		return
	var status: int = int(_transport.call("close"))

	if _was_connected or status == StreamPeerTCP.STATUS_CONNECTED:
		_was_connected = false
		disconnected.emit()

func quit(reason: String = "") -> void:
	if reason.strip_edges() == "":
		send_message("QUIT")
	else:
		send_message("QUIT", [], reason)
	close_connection()

func send_message(command: String, params: Array = [], trailing: String = "") -> void:
	_ensure_init()
	var line: String = _wire.call("format_with_max_bytes", command, params, trailing, 510)
	if line.strip_edges() == "":
		return
	send_raw_line(line)

func join(channel: String) -> void:
	send_message("JOIN", [channel])

func part(channel: String, reason: String = "") -> void:
	if reason.strip_edges() == "":
		send_message("PART", [channel])
	else:
		send_message("PART", [channel], reason)

func privmsg(target: String, text: String) -> void:
	send_message("PRIVMSG", [target], text)

func notice(target: String, text: String) -> void:
	send_message("NOTICE", [target], text)

func ctcp_action(target: String, text: String) -> void:
	_ensure_init()
	_ctcp.call("send_action", target, text, func(out: String) -> void: send_raw_line(out))

func _send_registration_if_ready() -> void:
	_ensure_init()
	if bool(_cap.call("is_in_progress")):
		return
	_reg.call("send_if_ready", func(cmd: String, params: Array, trailing: String) -> void:
		send_message(cmd, params, trailing)
	)

func _read_available() -> void:
	var lines: Array[String] = _transport.call("read_lines")
	var read_err: String = String(_transport.call("take_last_error"))
	if read_err.strip_edges() != "":
		error.emit(read_err)
		# Transport may have closed itself (e.g. safety overflow). Mirror that as a disconnect event.
		if _was_connected and not bool(_transport.call("has_peer")):
			_was_connected = false
			disconnected.emit()
			return
	for line in lines:
		raw_line_received.emit(line)
		var msg = _parser.call("parse_line", line)
		message_received.emit(msg)

		var cmd := String((msg as Object).get("command"))
		if cmd == "ERROR":
			var reason := String((msg as Object).get("trailing"))
			if reason.strip_edges() == "":
				var params = (msg as Object).get("params")
				if params is Array and params.size() > 0:
					reason = String(params[0])
			if reason.strip_edges() == "":
				reason = "server ERROR"
			error.emit(reason)
			close_connection()
			return

		if bool(_cap.call("on_message", msg, func(out: String) -> void: send_raw_line(out))):
			_send_registration_if_ready()
		_ctcp.call("handle_message", msg, func(prefix: String, target: String, text: String) -> void: ctcp_action_received.emit(prefix, target, text))
		_ping.call("maybe_reply", msg, func(out: String) -> void: send_raw_line(out))
