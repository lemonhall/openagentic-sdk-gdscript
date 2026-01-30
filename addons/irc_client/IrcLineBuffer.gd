extends RefCounted

var _buf: PackedByteArray = PackedByteArray()

func push_bytes(chunk: PackedByteArray) -> Array[String]:
	if chunk.size() > 0:
		_buf.append_array(chunk)

	var out: Array[String] = []

	while true:
		var nl: int = _buf.find(0x0A) # '\n'
		if nl == -1:
			break
		var line_bytes: PackedByteArray = _buf.slice(0, nl)
		_buf = _buf.slice(nl + 1)
		if line_bytes.size() > 0 and line_bytes[line_bytes.size() - 1] == 0x0D: # '\r'
			line_bytes = line_bytes.slice(0, line_bytes.size() - 1)
		out.append(line_bytes.get_string_from_utf8())

	return out

func push_chunk(chunk: String) -> Array[String]:
	# Compatibility wrapper (primarily for tests or in-memory transports that operate on Strings).
	return push_bytes(chunk.to_utf8_buffer())
