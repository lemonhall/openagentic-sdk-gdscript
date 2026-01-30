extends RefCounted

const IrcCapNegotiation := preload("res://addons/irc_client/IrcCapNegotiation.gd")

var _enabled: bool = false
var _requested_caps: Array[String] = []
var _neg = null
var _cap_end_sent: bool = false
var _complete: bool = false

var _sasl_user: String = ""
var _sasl_pass: String = ""
var _sasl_state: int = 0 # 0=off, 1=need_start, 2=wait_plus, 3=wait_result

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not _enabled:
		_neg = null
		_complete = false
		_cap_end_sent = false
		_sasl_state = 0

func set_requested_caps(caps: Array) -> void:
	_requested_caps = []
	for c in caps:
		var s := String(c).strip_edges()
		if s != "":
			_requested_caps.append(s)

func is_in_progress() -> bool:
	if not _enabled or _complete:
		return false
	if _neg == null:
		return false
	return bool(_neg.call("is_started")) and not _cap_end_sent

func set_sasl_plain(user: String, password: String) -> void:
	_sasl_user = user
	_sasl_pass = password

func on_connected(send_line: Callable) -> void:
	if not _enabled:
		return
	if _requested_caps.is_empty():
		return
	if _neg != null and bool(_neg.call("is_started")):
		return
	_neg = IrcCapNegotiation.new()
	_neg.call("set_requested_caps", _requested_caps)
	_cap_end_sent = false
	_complete = false
	_sasl_state = 0
	for l in (_neg.call("start") as Array[String]):
		send_line.call(l)

func on_message(msg: RefCounted, send_line: Callable) -> bool:
	if _neg == null or msg == null:
		return false
	if _complete:
		return true

	var cmd := String((msg as Object).get("command"))

	if cmd == "AUTHENTICATE" and is_in_progress() and _sasl_state == 2:
		var params = (msg as Object).get("params")
		if params is Array and params.size() >= 1 and String(params[0]) == "+":
			var payload := PackedByteArray([0])
			payload.append_array(_sasl_user.to_utf8_buffer())
			payload.append(0)
			payload.append_array(_sasl_pass.to_utf8_buffer())
			var b64 := Marshalls.raw_to_base64(payload)
			send_line.call("AUTHENTICATE %s" % b64)
			_sasl_state = 3
		return false

	if is_in_progress() and _sasl_state == 3:
		# Treat numeric 903 as success; 904+ as failure but still end CAP.
		if cmd == "903" or cmd == "904" or cmd == "905" or cmd == "906" or cmd == "907":
			_cap_end_sent = true
			_complete = true
			send_line.call("CAP END")
			return true

	if cmd == "CAP":
		if is_in_progress() and not bool(_neg.call("is_done")):
			for l in (_neg.call("handle_message", msg) as Array[String]):
				send_line.call(l)

		# CAP negotiation finished (ACK/NAK or empty REQ). Decide next step.
		if is_in_progress() and bool(_neg.call("is_done")) and not _cap_end_sent:
			var acked: Array[String] = _neg.call("get_acked_caps")
			var sasl_acked := acked.has("sasl")
			if sasl_acked and _sasl_user.strip_edges() != "" and _sasl_pass != "":
				# Start SASL once, then wait for AUTHENTICATE/+ and numeric result before ending CAP.
				if _sasl_state == 0:
					_sasl_state = 2
					send_line.call("AUTHENTICATE PLAIN")
				return false
			_cap_end_sent = true
			_complete = true
			send_line.call("CAP END")
			return true
		return false

	return false
