extends RefCounted

const IrcMessage := preload("res://addons/irc_client/IrcMessage.gd")

func parse_line(line: String) -> RefCounted:
	# Accept lines with or without CRLF, but parse the content only.
	var s := line.strip_edges(false, true)
	if s.ends_with("\r"):
		s = s.substr(0, s.length() - 1)

	var msg: RefCounted = IrcMessage.new()

	var i: int = 0
	if s.begins_with(":"):
		var space: int = s.find(" ")
		if space == -1:
			# Degenerate line like ":prefix" (treat as command-less).
			msg.prefix = s.substr(1)
			return msg
		msg.prefix = s.substr(1, space - 1)
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
