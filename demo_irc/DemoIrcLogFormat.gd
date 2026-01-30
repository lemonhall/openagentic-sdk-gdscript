extends RefCounted

static func format_prefix(time_str: String) -> String:
	return "[color=gray][lb]%s[rb][/color]" % time_str

static func prepend(time_str: String, line: String) -> String:
	if line.strip_edges() == "":
		return line
	return "%s %s" % [format_prefix(time_str), line]
