extends RefCounted

var _append_chat: Callable = Callable()
var _append_status: Callable = Callable()

func configure(append_chat: Callable, append_status: Callable) -> void:
	_append_chat = append_chat
	_append_status = append_status

func on_message(msg: RefCounted, my_nick: String) -> void:
	var cmd := String(msg.command)
	if cmd == "ERROR":
		_append_raw("ERROR: " + String(msg.trailing))
		return
	if cmd.is_valid_int():
		var code := int(cmd)
		# Show only key numerics + errors to avoid MOTD spam.
		if code == 1:
			_append_status.call("Logged in: " + String(msg.trailing))
		elif code == 376 or code == 422:
			_append_status.call("MOTD done.")
		elif code >= 400:
			_append_raw("[%s] %s" % [cmd, String(msg.trailing)])
		return
	if cmd == "PRIVMSG":
		var target := ""
		if msg.params.size() >= 1:
			target = String(msg.params[0])
		var nick := _nick_from_prefix(String(msg.prefix))
		var line := "<%s> %s" % [nick, String(msg.trailing)]
		if target.strip_edges() != "" and target != my_nick and not target.begins_with("#"):
			line = "[PM %s] %s" % [target, line]
		_append_chat.call(line)
		return
	if cmd == "NOTICE":
		var nick2 := _nick_from_prefix(String(msg.prefix))
		_append_chat.call("-notice- %s: %s" % [nick2, String(msg.trailing)])
		return
	if cmd == "JOIN":
		var nick3 := _nick_from_prefix(String(msg.prefix))
		var ch := String(msg.trailing)
		if ch.strip_edges() == "" and msg.params.size() >= 1:
			ch = String(msg.params[0])
		_append_chat.call("%s joined %s" % [nick3, ch])
		return
	if cmd == "PART":
		var nick4 := _nick_from_prefix(String(msg.prefix))
		var ch2: String = String(msg.params[0]) if msg.params.size() >= 1 else ""
		_append_chat.call("%s left %s" % [nick4, String(ch2)])
		return

func _append_raw(line: String) -> void:
	_append_chat.call("[color=gray]%s[/color]" % _escape_bbcode(line))

func _nick_from_prefix(prefix: String) -> String:
	var p := prefix
	if p.begins_with(":"):
		p = p.substr(1)
	var bang := p.find("!")
	if bang >= 0:
		return p.substr(0, bang)
	return p

func _escape_bbcode(s: String) -> String:
	# `RichTextLabel` escapes use BBCode tags `[lb]` and `[rb]`. Do NOT naively
	# `replace("[", "[lb]")` because it introduces a `]` that then gets replaced,
	# corrupting the escape tokens (e.g. "[lb[rb]").
	const L := "\uE000"
	const R := "\uE001"
	var out := s.replace("[", L).replace("]", R)
	return out.replace(L, "[lb]").replace(R, "[rb]")
