extends RefCounted

var _transport: Object = null
var _parser: Object = null
var _cap: Object = null
var _ping: Object = null
var _ctcp: Object = null
var _inbound: Object = null
var _channels: Object = null
var _reconnect: Object = null
var _cmd: Object = null
var _server_info: Object = null

var _emit_connected: Callable = Callable()
var _emit_disconnected: Callable = Callable()
var _emit_raw_line: Callable = Callable()
var _emit_message: Callable = Callable()
var _emit_ctcp_action: Callable = Callable()
var _emit_error: Callable = Callable()

var _was_connected: bool = false

func configure(
	transport: Object,
	parser: Object,
	cap: Object,
	ping: Object,
	ctcp: Object,
	inbound: Object,
	channels: Object,
	reconnect: Object,
	cmd: Object,
	server_info: Object,
	emit_connected: Callable,
	emit_disconnected: Callable,
	emit_raw_line: Callable,
	emit_message: Callable,
	emit_ctcp_action: Callable,
	emit_error: Callable,
) -> void:
	_transport = transport
	_parser = parser
	_cap = cap
	_ping = ping
	_ctcp = ctcp
	_inbound = inbound
	_channels = channels
	_reconnect = reconnect
	_cmd = cmd
	_server_info = server_info

	_emit_connected = emit_connected
	_emit_disconnected = emit_disconnected
	_emit_raw_line = emit_raw_line
	_emit_message = emit_message
	_emit_ctcp_action = emit_ctcp_action
	_emit_error = emit_error

func set_peer(peer: Object) -> void:
	_transport.call("set_peer", peer)
	_cmd.call("reset_registration_flags")
	_was_connected = false
	if _server_info != null and _server_info.has_method("reset"):
		_server_info.call("reset")

func connect_to(host: String, port: int) -> void:
	_reconnect.call("remember_tcp", host, port)
	_cmd.call("reset_registration_flags")
	var err: int = int(_transport.call("connect_to", host, port))
	if err != OK and _emit_error.is_valid():
		_emit_error.call("connect_to_host failed: %s" % str(err))

func connect_to_tls_over_stream(stream: StreamPeerTCP, server_name: String) -> void:
	_cmd.call("reset_registration_flags")
	_transport.call("connect_to_tls_over_stream", stream, server_name)

func connect_to_tls(host: String, port: int, server_name: String = "") -> void:
	_reconnect.call("remember_tls", host, port, server_name)
	_cmd.call("reset_registration_flags")
	var err: int = int(_transport.call("connect_to_tls", host, port, server_name))
	if err != OK and _emit_error.is_valid():
		_emit_error.call("connect_to_host failed: %s" % str(err))

func _attempt_reconnect(last_connect: Dictionary) -> int:
	if last_connect.is_empty():
		return ERR_CANT_CONNECT
	var kind := String(last_connect.get("kind", "tcp"))
	var host := String(last_connect.get("host", ""))
	var port := int(last_connect.get("port", 0))
	var server_name := String(last_connect.get("server_name", ""))
	_cmd.call("reset_registration_flags")
	_was_connected = false
	_transport.call("close")
	if kind == "tls":
		return int(_transport.call("connect_to_tls", host, port, server_name))
	return int(_transport.call("connect_to", host, port))

func poll(dt_sec: float = 0.0) -> void:
	_reconnect.call("tick", dt_sec, func(last_connect: Dictionary) -> int:
		return _attempt_reconnect(last_connect)
	)
	if not bool(_transport.call("has_peer")):
		return

	if not bool(_transport.call("poll_pre")):
		var tls_err: int = int(_transport.call("take_tls_last_err"))
		if tls_err != OK and _emit_error.is_valid():
			_emit_error.call("tls.connect_to_stream failed: %s" % str(tls_err))
		return

	_transport.call("poll_peer")
	var status: int = int(_transport.call("get_status"))

	if status == StreamPeerTCP.STATUS_CONNECTED and not _was_connected:
		_was_connected = true
		_reconnect.call("on_connected")
		_channels.call("on_connected_session")
		if _emit_connected.is_valid():
			_emit_connected.call()
		_cap.call("on_connected", func(line: String) -> void: _cmd.call("send_raw_line", line))
		if not bool(_cap.call("is_in_progress")):
			_cmd.call("send_registration_if_ready")

	if status == StreamPeerTCP.STATUS_NONE or status == StreamPeerTCP.STATUS_ERROR:
		# Even if we never reached STATUS_CONNECTED, treat this as a disconnect so that
		# auto-reconnect can recover from "failed first connect" scenarios.
		_was_connected = false
		_channels.call("note_disconnected_for_rejoin")
		_reconnect.call("on_disconnected")
		_transport.call("close")
		if _emit_disconnected.is_valid():
			_emit_disconnected.call()
		return

	if status != StreamPeerTCP.STATUS_CONNECTED:
		return

	_read_available()

func close_connection() -> void:
	_close_connection_internal(true)

func close_connection_remote() -> void:
	# Remote-initiated close (server ERROR, socket drop, etc). Eligible for auto-reconnect.
	_close_connection_internal(false)

func _close_connection_internal(user_initiated: bool) -> void:
	if user_initiated:
		_reconnect.call("note_user_initiated_close")
	if not bool(_transport.call("has_peer")):
		return
	var status: int = int(_transport.call("close"))
	if _was_connected or status == StreamPeerTCP.STATUS_CONNECTED:
		_was_connected = false
		_channels.call("note_disconnected_for_rejoin")
		_reconnect.call("on_disconnected")
		if _emit_disconnected.is_valid():
			_emit_disconnected.call()

func quit(reason: String = "") -> void:
	if reason.strip_edges() == "":
		_cmd.call("send_message", "QUIT")
	else:
		_cmd.call("send_message", "QUIT", [], reason)
	close_connection()

func _read_available() -> void:
	var lines: Array[String] = _transport.call("read_lines")
	var read_err: String = String(_transport.call("take_last_error"))
	if read_err.strip_edges() != "" and _emit_error.is_valid():
		_emit_error.call(read_err)
		if _was_connected and not bool(_transport.call("has_peer")):
			_was_connected = false
			_channels.call("note_disconnected_for_rejoin")
			_reconnect.call("on_disconnected")
			if _emit_disconnected.is_valid():
				_emit_disconnected.call()
			return

	var send_raw := func(out: String) -> void: _cmd.call("send_raw_line", out)
	var emit_raw := func(l: String) -> void:
		if _emit_raw_line.is_valid():
			_emit_raw_line.call(l)
	var emit_msg := func(m: RefCounted) -> void:
		if _emit_message.is_valid():
			_emit_message.call(m)
	var emit_err := func(e: String) -> void:
		if _emit_error.is_valid():
			_emit_error.call(e)
	var close_fn := func() -> void: close_connection_remote()
	var on_welcome := func() -> void:
		_channels.call("on_welcome", func(ch: String) -> void: _cmd.call("join", ch))
	var on_isupport := func(m: Object) -> void:
		if _server_info != null and _server_info.has_method("on_isupport"):
			_server_info.call("on_isupport", m)
	var on_cap_complete := func() -> void: _cmd.call("send_registration_if_ready")
	var emit_ctcp := func(prefix: String, target: String, text: String) -> void:
		if _emit_ctcp_action.is_valid():
			_emit_ctcp_action.call(prefix, target, text)

	for line in lines:
		var stop: bool = bool(_inbound.call("handle_line",
			line,
			_parser,
			_cap,
			_ctcp,
			_ping,
			send_raw,
			emit_raw,
			emit_msg,
			emit_err,
			close_fn,
			on_welcome,
			on_isupport,
			on_cap_complete,
			emit_ctcp,
		))
		if stop:
			return
