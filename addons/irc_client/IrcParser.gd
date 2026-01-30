extends RefCounted

const IrcMessage := preload("res://addons/irc_client/IrcMessage.gd")

func parse_line(line: String) -> RefCounted:
	# Accept lines with or without CRLF, but only strip line terminators.
	# Do NOT use strip_edges() here: IRC payloads may contain CTCP delimiter (SOH, \u0001),
	# which Godot treats as whitespace and would strip from the right side.
	var s := line
	if s.ends_with("\n"):
		s = s.substr(0, s.length() - 1)
	if s.ends_with("\r"):
		s = s.substr(0, s.length() - 1)

	var msg: RefCounted = IrcMessage.new()

	var i: int = 0

	# IRCv3 message tags (optional): "@a=b;c :prefix CMD ..."
	if s.begins_with("@"):
		var tag_end: int = s.find(" ")
		if tag_end == -1:
			msg.tags = _parse_tags(s.substr(1))
			return msg
		msg.tags = _parse_tags(s.substr(1, tag_end - 1))
		i = tag_end + 1

	# Skip extra spaces (after tags).
	while i < s.length() and s.substr(i, 1) == " ":
		i += 1

	# Prefix (optional).
	if i < s.length() and s.substr(i, 1) == ":":
		var space: int = s.find(" ", i)
		if space == -1:
			# Degenerate line like ":prefix" (treat as command-less).
			msg.prefix = s.substr(i + 1)
			return msg
		msg.prefix = s.substr(i + 1, space - (i + 1))
		i = space + 1

	# Skip extra spaces.
	while i < s.length() and s.substr(i, 1) == " ":
		i += 1

	# Command token.
	var cmd_end: int = s.find(" ", i)
	if cmd_end == -1:
		msg.command = s.substr(i)
		return msg
	msg.command = s.substr(i, cmd_end - i)
	i = cmd_end + 1

	# Params until trailing (":" token) or end.
	while i < s.length():
		while i < s.length() and s.substr(i, 1) == " ":
			i += 1
		if i >= s.length():
			break
		if s.substr(i, 1) == ":":
			msg.trailing = s.substr(i + 1)
			break
		var next_space: int = s.find(" ", i)
		if next_space == -1:
			msg.params.append(s.substr(i))
			break
		msg.params.append(s.substr(i, next_space - i))
		i = next_space + 1

	return msg

func _parse_tags(s: String) -> Dictionary:
	var out: Dictionary = {}
	if s.strip_edges() == "":
		return out
	var parts: PackedStringArray = s.split(";", false)
	for p in parts:
		var entry: String = String(p)
		if entry == "":
			continue
		var eq: int = entry.find("=")
		if eq == -1:
			out[entry] = ""
			continue
		var key: String = entry.substr(0, eq)
		var val: String = entry.substr(eq + 1)
		out[key] = _unescape_tag_value(val)
	return out

func _unescape_tag_value(s: String) -> String:
	# IRCv3 tag value escapes:
	# \: -> ';'   \s -> ' '   \r -> CR   \n -> LF   \\ -> '\'
	var out := ""
	var i: int = 0
	while i < s.length():
		var ch := s.substr(i, 1)
		if ch != "\\":
			out += ch
			i += 1
			continue
		i += 1
		if i >= s.length():
			break
		var e := s.substr(i, 1)
		i += 1
		if e == ":":
			out += ";"
		elif e == "s":
			out += " "
		elif e == "r":
			out += "\r"
		elif e == "n":
			out += "\n"
		elif e == "\\":
			out += "\\"
		else:
			# Unknown escape: keep the character (best-effort).
			out += e
	return out
