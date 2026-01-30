extends RefCounted

var _auto_rejoin_enabled: bool = true
var _desired_channels: Array[String] = []
var _join_sent_this_session: Dictionary = {}
var _needs_rejoin_on_welcome: bool = false

func set_auto_rejoin_enabled(enabled: bool) -> void:
	_auto_rejoin_enabled = enabled
	if not _auto_rejoin_enabled:
		_needs_rejoin_on_welcome = false

func record_join_request(channel: String) -> void:
	var ch := channel.strip_edges()
	if ch == "":
		return
	if not _desired_channels.has(ch):
		_desired_channels.append(ch)

func record_part_request(channel: String) -> void:
	var ch := channel.strip_edges()
	if ch == "":
		return
	_desired_channels.erase(ch)
	_join_sent_this_session.erase(ch)

func on_connected_session() -> void:
	_join_sent_this_session = {}

func note_join_sent(channel: String) -> void:
	var ch := channel.strip_edges()
	if ch == "":
		return
	_join_sent_this_session[ch] = true

func note_disconnected_for_rejoin() -> void:
	if not _auto_rejoin_enabled:
		return
	if _desired_channels.is_empty():
		return
	_needs_rejoin_on_welcome = true

func on_welcome(send_join: Callable) -> void:
	if not _needs_rejoin_on_welcome:
		return
	_needs_rejoin_on_welcome = false
	for ch in _desired_channels:
		if _join_sent_this_session.has(ch):
			continue
		send_join.call(ch)
		_join_sent_this_session[ch] = true

