extends RefCounted

var _under: Object = null
var _peer: StreamPeerTLS = null
var _server_name: String = ""
var _handshake_started: bool = false
var _last_err: int = OK

func reset() -> void:
	_under = null
	_peer = null
	_server_name = ""
	_handshake_started = false
	_last_err = OK

func configure_over_stream(stream: StreamPeerTCP, server_name: String) -> StreamPeerTLS:
	reset()
	_under = stream
	_peer = StreamPeerTLS.new()
	_server_name = server_name
	return _peer

func poll_pre() -> bool:
	# Returns true if caller should proceed with polling `_peer`.
	if _peer == null:
		return true

	if _under != null and _under.has_method("poll"):
		_under.call("poll")

	if not _handshake_started:
		if _under != null and _under.has_method("get_status"):
			var under_status: int = int(_under.call("get_status"))
			if under_status == StreamPeerTCP.STATUS_CONNECTED:
				_last_err = _peer.connect_to_stream(_under as StreamPeer, _server_name)
				_handshake_started = true
		return false

	return true

func take_last_err() -> int:
	var e := _last_err
	_last_err = OK
	return e

func disconnect_underlying() -> void:
	if _under != null and _under.has_method("disconnect_from_host"):
		_under.call("disconnect_from_host")
