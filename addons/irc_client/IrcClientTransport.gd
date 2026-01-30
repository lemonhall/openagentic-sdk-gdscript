extends RefCounted

const IrcLineBuffer := preload("res://addons/irc_client/IrcLineBuffer.gd")
const IrcClientTls := preload("res://addons/irc_client/IrcClientTls.gd")

var _peer: Object = null # StreamPeerTCP/StreamPeerTLS or test double.
var _buf = null
var _tls = null
var _last_error: String = ""

func _ensure_init() -> void:
	if _buf == null: _buf = IrcLineBuffer.new()
	if _tls == null: _tls = IrcClientTls.new()

func has_peer() -> bool:
	return _peer != null

func set_peer(peer: Object) -> void:
	_ensure_init()
	_peer = peer
	_tls.call("reset")

func connect_to(host: String, port: int) -> int:
	_ensure_init()
	var tcp := StreamPeerTCP.new()
	var err := tcp.connect_to_host(host, port)
	if err != OK:
		return err
	_peer = tcp
	_tls.call("reset")
	return OK

func connect_to_tls_over_stream(stream: StreamPeerTCP, server_name: String) -> void:
	_ensure_init()
	_peer = _tls.call("configure_over_stream", stream, server_name)

func connect_to_tls(host: String, port: int, server_name: String = "") -> int:
	var sn := server_name
	if sn.strip_edges() == "":
		sn = host
	var tcp := StreamPeerTCP.new()
	var err := tcp.connect_to_host(host, port)
	if err != OK:
		return err
	connect_to_tls_over_stream(tcp, sn)
	return OK

func poll_pre() -> bool:
	_ensure_init()
	if _peer == null:
		return false
	return bool(_tls.call("poll_pre"))

func take_tls_last_err() -> int:
	_ensure_init()
	return int(_tls.call("take_last_err"))

func poll_peer() -> void:
	if _peer != null and _peer.has_method("poll"):
		_peer.call("poll")

func get_status() -> int:
	if _peer == null:
		return StreamPeerTCP.STATUS_NONE
	if _peer.has_method("get_status"):
		return int(_peer.call("get_status"))
	return StreamPeerTCP.STATUS_ERROR

func send_line(line: String) -> void:
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

func read_lines() -> Array[String]:
	_last_error = ""
	if _peer == null:
		return []
	if not _peer.has_method("get_available_bytes") or not _peer.has_method("get_data"):
		return []
	var avail: int = int(_peer.call("get_available_bytes"))
	if avail <= 0:
		return []
	var got = _peer.call("get_data", avail)
	if int(got[0]) != OK:
		_last_error = "get_data failed"
		return []
	var bytes: PackedByteArray = got[1]
	return _buf.call("push_bytes", bytes)

func take_last_error() -> String:
	var e := _last_error
	_last_error = ""
	return e

func close() -> int:
	_ensure_init()
	var status := get_status()
	if _peer == null:
		return status

	if _peer.has_method("disconnect_from_host"):
		_peer.call("disconnect_from_host")
	else:
		_tls.call("disconnect_underlying")

	_peer = null
	_tls.call("reset")
	return status

