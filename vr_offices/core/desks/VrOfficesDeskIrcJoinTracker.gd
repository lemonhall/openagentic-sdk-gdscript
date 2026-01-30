extends RefCounted

var _joined_this_session := false

func reset() -> void:
	_joined_this_session = false

func try_join_after_welcome(client: Node, desired_channel: String) -> void:
	if client == null:
		return
	if _joined_this_session:
		return
	var ch := desired_channel.strip_edges()
	if ch == "":
		return
	_joined_this_session = true
	client.call("join", ch)

func join_matches_desired(msg: Object, desired_channel: String) -> bool:
	if msg == null:
		return false

	var desired := desired_channel.strip_edges()
	if desired == "":
		return false

	var ch := ""
	var params0: Variant = msg.get("params")
	if params0 is Array:
		var params := params0 as Array
		if not params.is_empty():
			ch = String(params[0]).strip_edges()

	# Some servers send `JOIN :#channel` (channel ends up in `trailing` for our parser).
	if ch == "":
		var trailing0: Variant = msg.get("trailing")
		ch = "" if trailing0 == null else String(trailing0).strip_edges()
	if ch == "":
		return false

	for part0 in ch.split(",", false):
		if String(part0).strip_edges() == desired:
			return true
	return false

