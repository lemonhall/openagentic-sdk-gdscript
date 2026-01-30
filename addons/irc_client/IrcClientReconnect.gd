extends RefCounted

var _enabled: bool = false
var _auto_reconnect_backoff: Array[float] = [0.0, 1.0, 2.0, 5.0, 10.0]

var _attempt: int = 0
var _pending: bool = false
var _time_to_next: float = 0.0

var _user_initiated_close: bool = false

var _last_connect: Dictionary = {} # {kind, host, port, server_name}

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not _enabled:
		_pending = false
		_time_to_next = 0.0
		_attempt = 0

func set_backoff_seconds(backoff: Array) -> void:
	var out: Array[float] = []
	for v in backoff:
		var f := float(v)
		if f < 0.0:
			f = 0.0
		out.append(f)
	if out.is_empty():
		return
	_auto_reconnect_backoff = out

func remember_tcp(host: String, port: int) -> void:
	_last_connect = {"kind": "tcp", "host": host, "port": port}

func remember_tls(host: String, port: int, server_name: String) -> void:
	_last_connect = {"kind": "tls", "host": host, "port": port, "server_name": server_name}

func take_last_connect() -> Dictionary:
	return _last_connect.duplicate()

func note_user_initiated_close() -> void:
	_user_initiated_close = true
	_pending = false
	_time_to_next = 0.0

func on_connected() -> void:
	_user_initiated_close = false
	_pending = false
	_time_to_next = 0.0
	_attempt = 0

func on_disconnected() -> void:
	if not _enabled:
		return
	if _user_initiated_close:
		return
	if _last_connect.is_empty():
		return
	_schedule_next()

func _schedule_next() -> void:
	_pending = true
	var idx: int = _attempt
	if idx >= _auto_reconnect_backoff.size():
		idx = _auto_reconnect_backoff.size() - 1
	if idx < 0:
		idx = 0
	_time_to_next = _auto_reconnect_backoff[idx]
	_attempt += 1

func tick(dt_sec: float, do_connect: Callable) -> void:
	if not _pending:
		return
	var dt := dt_sec
	if dt < 0.0:
		dt = 0.0
	_time_to_next -= dt
	if _time_to_next > 0.0:
		return

	var err: int = int(do_connect.call(take_last_connect()))
	if err == OK:
		_pending = false
		_time_to_next = 0.0
		return
	_schedule_next()

