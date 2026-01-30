extends RefCounted

var _buf: String = ""

func push_chunk(chunk: String) -> Array[String]:
	_buf += chunk
	var out: Array[String] = []

	while true:
		var nl: int = _buf.find("\n")
		if nl == -1:
			break
		var line: String = _buf.substr(0, nl)
		_buf = _buf.substr(nl + 1)
		if line.ends_with("\r"):
			line = line.substr(0, line.length() - 1)
		out.append(line)

	return out

