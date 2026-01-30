extends RefCounted

var _wire: Object = null
var _transport: Object = null
var _cap: Object = null
var _ctcp: Object = null
var _channels: Object = null
var _reg: Object = null

func configure(wire: Object, transport: Object, cap: Object, ctcp: Object, channels: Object, reg: Object) -> void:
	_wire = wire
	_transport = transport
	_cap = cap
	_ctcp = ctcp
	_channels = channels
	_reg = reg

func reset_registration_flags() -> void:
	_reg.call("reset")

func send_raw_line(line: String) -> void:
	_transport.call("send_line", line)

func send_message(command: String, params: Array = [], trailing: String = "") -> void:
	var line: String = _wire.call("format_with_max_bytes", command, params, trailing, 510)
	if line.strip_edges() == "":
		return
	send_raw_line(line)

func privmsg(target: String, text: String) -> void:
	var line: String = _wire.call("format_with_max_bytes", "PRIVMSG", [target], text, 510, true)
	if line.strip_edges() == "":
		return
	send_raw_line(line)

func notice(target: String, text: String) -> void:
	var line: String = _wire.call("format_with_max_bytes", "NOTICE", [target], text, 510, true)
	if line.strip_edges() == "":
		return
	send_raw_line(line)

func ctcp_action(target: String, text: String) -> void:
	_ctcp.call("send_action", target, text, func(out: String) -> void: send_raw_line(out))

func join(channel: String) -> void:
	_channels.call("record_join_request", channel)
	send_message("JOIN", [channel])
	_channels.call("note_join_sent", channel)

func part(channel: String, reason: String = "") -> void:
	_channels.call("record_part_request", channel)
	if reason.strip_edges() == "":
		send_message("PART", [channel])
	else:
		send_message("PART", [channel], reason)

func send_registration_if_ready() -> void:
	if bool(_cap.call("is_in_progress")):
		return
	_reg.call("send_if_ready", func(cmd: String, params: Array, trailing: String) -> void:
		send_message(cmd, params, trailing)
	)

