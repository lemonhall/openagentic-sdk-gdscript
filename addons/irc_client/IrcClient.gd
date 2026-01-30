extends Node

signal connected
signal disconnected
signal raw_line_received(line: String)
signal message_received(msg: RefCounted)
signal ctcp_action_received(prefix: String, target: String, text: String)
signal error(msg: String)

const IrcLineBuffer := preload("res://addons/irc_client/IrcLineBuffer.gd")
const IrcParser := preload("res://addons/irc_client/IrcParser.gd")
const IrcClientCap := preload("res://addons/irc_client/IrcClientCap.gd")
const IrcClientTls := preload("res://addons/irc_client/IrcClientTls.gd")
const IrcClientPing := preload("res://addons/irc_client/IrcClientPing.gd")
const IrcClientCtcp := preload("res://addons/irc_client/IrcClientCtcp.gd")

var _peer: Object = null # StreamPeerTCP or test double implementing the same methods.
var _tls = null
var _buf = null
var _parser = null
var _cap = null
var _ping = null
var _ctcp = null
var _was_connected: bool = false

var _nick: String = ""
var _user_user: String = ""
var _user_mode: String = "0"
var _user_unused: String = "*"
var _user_realname: String = ""

func _ensure_init() -> void:
	if _buf == null: _buf = IrcLineBuffer.new()
	if _parser == null: _parser = IrcParser.new()
	if _cap == null: _cap = IrcClientCap.new()
	if _tls == null: _tls = IrcClientTls.new()
	if _ping == null: _ping = IrcClientPing.new()
	if _ctcp == null: _ctcp = IrcClientCtcp.new()

func set_peer(peer: Object) -> void:
	_ensure_init()
	_peer = peer
	_tls.call("reset")
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

func set_nick(nick: String) -> void:
	_nick = nick

func set_user(user: String, mode: String = "0", unused: String = "*", realname: String = "") -> void:
	_user_user = user
	_user_mode = mode
	_user_unused = unused
	_user_realname = realname

func connect_to(host: String, port: int) -> void:
	_ensure_init()
	var tcp := StreamPeerTCP.new()
	var err := tcp.connect_to_host(host, port)
	if err != OK:
		error.emit("connect_to_host failed: %s" % str(err))
	_peer = tcp
	_tls.call("reset")

func connect_to_tls_over_stream(stream: StreamPeerTCP, server_name: String) -> void:
	_ensure_init()
	_peer = _tls.call("configure_over_stream", stream, server_name)

func connect_to_tls(host: String, port: int, server_name: String = "") -> void:
	var sn := server_name
	if sn.strip_edges() == "":
		sn = host
	var tcp := StreamPeerTCP.new()
	var err := tcp.connect_to_host(host, port)
	if err != OK:
		error.emit("connect_to_host failed: %s" % str(err))
	connect_to_tls_over_stream(tcp, sn)

func poll() -> void:
	_ensure_init()
	if _peer == null:
		return

	if not bool(_tls.call("poll_pre")):
		var tls_err: int = int(_tls.call("take_last_err"))
		if tls_err != OK:
			error.emit("tls.connect_to_stream failed: %s" % str(tls_err))
		return

	if _peer.has_method("poll"):
		_peer.call("poll")
	var status: int = StreamPeerTCP.STATUS_ERROR
	if _peer.has_method("get_status"):
		status = int(_peer.call("get_status"))

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
	if _peer == null:
		return
	if not _peer.has_method("get_status") or int(_peer.call("get_status")) != StreamPeerTCP.STATUS_CONNECTED:
		return
	if not _peer.has_method("put_data"):
		return
	var s := line
	if s.ends_with("\r\n"):
		pass
	elif s.ends_with("\n"):
		s = s.substr(0, s.length() - 1) + "\r\n"
	else:
		s += "\r\n"
	_peer.call("put_data", s.to_utf8_buffer())

func join(channel: String) -> void:
	send_raw_line("JOIN %s" % channel)

func part(channel: String, reason: String = "") -> void:
	if reason.strip_edges() == "":
		send_raw_line("PART %s" % channel)
	else:
		send_raw_line("PART %s :%s" % [channel, reason])

func privmsg(target: String, text: String) -> void:
	send_raw_line("PRIVMSG %s :%s" % [target, text])

func notice(target: String, text: String) -> void:
	send_raw_line("NOTICE %s :%s" % [target, text])

func ctcp_action(target: String, text: String) -> void:
	_ensure_init()
	_ctcp.call("send_action", target, text, func(out: String) -> void: send_raw_line(out))

func _send_registration_if_ready() -> void:
	_ensure_init()
	if bool(_cap.call("is_in_progress")):
		return
	if _nick.strip_edges() != "":
		send_raw_line("NICK %s" % _nick)
	if _user_user.strip_edges() != "":
		var rn := _user_realname
		if rn.strip_edges() == "":
			rn = _user_user
		send_raw_line("USER %s %s %s :%s" % [_user_user, _user_mode, _user_unused, rn])

func _read_available() -> void:
	if not _peer.has_method("get_available_bytes") or not _peer.has_method("get_data"):
		return
	var avail: int = int(_peer.call("get_available_bytes"))
	if avail <= 0:
		return
	var got = _peer.call("get_data", avail)
	if int(got[0]) != OK:
		error.emit("get_data failed")
		return
	var bytes: PackedByteArray = got[1]
	var chunk: String = bytes.get_string_from_utf8()
	var lines: Array[String] = _buf.call("push_chunk", chunk)
	for line in lines:
		raw_line_received.emit(line)
		var msg = _parser.call("parse_line", line)
		message_received.emit(msg)
		if bool(_cap.call("on_message", msg, func(out: String) -> void: send_raw_line(out))):
			_send_registration_if_ready()
		_ctcp.call("handle_message", msg, func(prefix: String, target: String, text: String) -> void: ctcp_action_received.emit(prefix, target, text))
		_ping.call("maybe_reply", msg, func(out: String) -> void: send_raw_line(out))
