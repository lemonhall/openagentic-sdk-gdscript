extends RefCounted

var _isupport: Dictionary = {}

func reset() -> void:
	_isupport = {}

func get_isupport() -> Dictionary:
	return _isupport.duplicate(true)

func get_str(key: String, default_value: String = "") -> String:
	var k := key.strip_edges()
	if k == "":
		return default_value
	if not _isupport.has(k):
		return default_value
	var v: Variant = _isupport.get(k)
	if v == null:
		return default_value
	return String(v)

func get_int(key: String, default_value: int = 0) -> int:
	var s := get_str(key, "")
	if s.strip_edges() == "":
		return default_value
	if not s.is_valid_int():
		return default_value
	return int(s)

func on_isupport(msg: Object) -> void:
	# Numeric 005 (RPL_ISUPPORT): tokens are typically in params[1..].
	# Example:
	# :irc.example.net 005 nick CHANNELLEN=50 NICKLEN=9 NETWORK=ExampleNet :are supported by this server
	if msg == null:
		return
	var params0: Variant = msg.get("params")
	if not (params0 is Array):
		return
	var params := params0 as Array
	if params.size() < 2:
		return

	for i in range(1, params.size()):
		var tok := String(params[i]).strip_edges()
		if tok == "":
			continue

		# Negative tokens (e.g. -FOO) remove a previous key.
		if tok.begins_with("-") and tok.length() > 1:
			_isupport.erase(tok.substr(1))
			continue

		var eq := tok.find("=")
		if eq == -1:
			_isupport[tok] = true
			continue

		var k := tok.substr(0, eq).strip_edges()
		var v := tok.substr(eq + 1).strip_edges()
		if k == "":
			continue
		_isupport[k] = v

