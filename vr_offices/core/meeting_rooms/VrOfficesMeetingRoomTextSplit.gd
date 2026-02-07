extends RefCounted

static func split_text(text: String, max_chars: int) -> Array[String]:
	var t := text
	var n: int = max(32, max_chars)
	var out: Array[String] = []
	if t.strip_edges() == "":
		return out
	var i := 0
	while i < t.length():
		out.append(t.substr(i, n))
		i += n
	return out
