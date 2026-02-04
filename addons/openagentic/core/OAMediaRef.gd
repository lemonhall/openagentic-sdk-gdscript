extends RefCounted
class_name OAMediaRef

const _PREFIX_V1 := "OAMEDIA1 "
const _MAX_LINE_LEN := 512
const _MAX_NAME_LEN := 128

const _FRAG_PREFIX := "OAMEDIA1F "
const _MAX_FRAG_PARTS := 64

const _KIND_IMAGE := "image"
const _KIND_AUDIO := "audio"
const _KIND_VIDEO := "video"

const _MIME_IMAGE_PNG := "image/png"
const _MIME_IMAGE_JPEG := "image/jpeg"
const _MIME_AUDIO_MPEG := "audio/mpeg" # mp3
const _MIME_AUDIO_WAV := "audio/wav"
const _MIME_VIDEO_MP4 := "video/mp4"

const _MAX_IMAGE_BYTES := 8 * 1024 * 1024
const _MAX_AUDIO_BYTES := 20 * 1024 * 1024
const _MAX_VIDEO_BYTES := 64 * 1024 * 1024

static func encode_v1(ref: Dictionary) -> String:
	var chk := _validate_ref(ref)
	if not bool(chk.get("ok", false)):
		return ""
	var clean: Dictionary = chk.get("ref", {})
	var json_txt := JSON.stringify(clean)
	if typeof(json_txt) != TYPE_STRING:
		return ""
	var payload := _base64url_encode(String(json_txt).to_utf8_buffer())
	var line := _PREFIX_V1 + payload
	if line.length() > _MAX_LINE_LEN:
		return ""
	return line

static func decode_v1(line: String) -> Dictionary:
	var s := line.strip_edges()
	if s == "" or s.length() > _MAX_LINE_LEN:
		return _err("InvalidLine", "line empty or too long")
	if not s.begins_with(_PREFIX_V1):
		return _err("InvalidPrefix", "expected " + _PREFIX_V1.strip_edges())

	var payload := s.substr(_PREFIX_V1.length()).strip_edges()
	if payload == "":
		return _err("InvalidPayload", "missing payload")

	var raw := _base64url_decode(payload)
	if raw.is_empty():
		return _err("InvalidBase64Url", "payload is not valid base64url")

	var json_txt := raw.get_string_from_utf8()
	var parsed := JSON.new()
	var perr := parsed.parse(json_txt)
	if perr != OK:
		return _err("InvalidJSON", "payload is not valid JSON")
	var data: Variant = parsed.data
	if typeof(data) != TYPE_DICTIONARY:
		return _err("InvalidJSON", "payload must be an object")

	var chk := _validate_ref(data as Dictionary)
	if not bool(chk.get("ok", false)):
		return chk
	return {"ok": true, "ref": chk.get("ref", {})}

static func irc_encode_lines(media_line: String, max_len: int) -> Array[String]:
	var line := media_line.strip_edges()
	if line == "":
		return []
	if max_len < 24:
		return []
	if not line.begins_with(_PREFIX_V1):
		return []
	if line.length() <= max_len:
		return [line]

	# Split payload into explicitly-indexed fragments to avoid corrupting base64url/JSON.
	var payload := line.substr(_PREFIX_V1.length()).strip_edges()
	if payload == "":
		return []

	var mid := _message_id_from_line(line)
	# Conservative overhead using worst-case part counters.
	var overhead := _FRAG_PREFIX.length() + mid.length() + 1 + "64/64".length() + 1
	var max_payload := max_len - overhead
	if max_payload < 8:
		return []

	var parts: Array[String] = []
	var cur := payload
	while cur != "":
		parts.append(cur.substr(0, max_payload))
		cur = cur.substr(max_payload)
		if parts.size() > _MAX_FRAG_PARTS:
			return []

	var total := parts.size()
	var out: Array[String] = []
	for i in range(total):
		out.append("%s%s %d/%d %s" % [_FRAG_PREFIX, mid, i + 1, total, parts[i]])
	return out

static func irc_parse_fragment(line: String) -> Dictionary:
	var s := line.strip_edges()
	if not s.begins_with(_FRAG_PREFIX):
		return {"ok": false, "error": "NotAFragment"}
	var rest := s.substr(_FRAG_PREFIX.length()).strip_edges()
	# Expect: <mid> <i>/<n> <payload>
	var sp1 := rest.find(" ")
	if sp1 <= 0:
		return {"ok": false, "error": "InvalidFragment"}
	var mid := rest.substr(0, sp1).strip_edges()
	rest = rest.substr(sp1 + 1).strip_edges()
	var sp2 := rest.find(" ")
	if sp2 <= 0:
		return {"ok": false, "error": "InvalidFragment"}
	var idxspec := rest.substr(0, sp2).strip_edges()
	var payload := rest.substr(sp2 + 1).strip_edges()
	if mid == "" or payload == "":
		return {"ok": false, "error": "InvalidFragment"}
	var slash := idxspec.find("/")
	if slash <= 0:
		return {"ok": false, "error": "InvalidFragment"}
	var a := idxspec.substr(0, slash)
	var b := idxspec.substr(slash + 1)
	if not a.is_valid_int() or not b.is_valid_int():
		return {"ok": false, "error": "InvalidFragment"}
	var idx := int(a)
	var total := int(b)
	if idx < 1 or total < 1 or idx > total or total > _MAX_FRAG_PARTS:
		return {"ok": false, "error": "InvalidFragment"}
	return {"ok": true, "message_id": mid, "index": idx, "total": total, "payload_part": payload}

static func irc_reassemble(message_id: String, total: int, parts: Dictionary) -> Dictionary:
	var mid := message_id.strip_edges()
	if mid == "" or total < 1 or total > _MAX_FRAG_PARTS:
		return {"ok": false, "error": "InvalidFragment"}
	if typeof(parts) != TYPE_DICTIONARY:
		return {"ok": false, "error": "InvalidFragment"}
	var payload := ""
	for i in range(1, total + 1):
		if not parts.has(i):
			return {"ok": false, "error": "MissingPart"}
		payload += String(parts.get(i, ""))
	var line := _PREFIX_V1 + payload
	if line.length() > _MAX_LINE_LEN:
		return {"ok": false, "error": "InvalidLine"}
	# Validate that the reconstructed line parses as a media ref.
	var dec := decode_v1(line)
	if not bool(dec.get("ok", false)):
		return {"ok": false, "error": "InvalidMediaRef"}
	return {"ok": true, "line": line}

static func _message_id_from_line(line: String) -> String:
	# Deterministic and safe: derive from sha256 prefix when possible.
	var d := decode_v1(line)
	if bool(d.get("ok", false)) and typeof(d.get("ref", null)) == TYPE_DICTIONARY:
		var ref: Dictionary = d.get("ref", {})
		var sha := String(ref.get("sha256", "")).strip_edges().to_lower()
		if sha.length() >= 12:
			return sha.substr(0, 12)
	# Fallback: random suffix.
	return ("m%08x" % randi()).to_lower()

static func _validate_ref(ref: Dictionary) -> Dictionary:
	if ref == null:
		return _err("InvalidRef", "ref is null")

	var id := String(ref.get("id", "")).strip_edges()
	var kind := String(ref.get("kind", "")).strip_edges().to_lower()
	var mime := String(ref.get("mime", "")).strip_edges().to_lower()
	var sha256 := String(ref.get("sha256", "")).strip_edges().to_lower()
	var bytes0: Variant = ref.get("bytes", null)

	if id == "" or id.length() > _MAX_NAME_LEN:
		return _err("InvalidId", "id required and must be <= %d chars" % _MAX_NAME_LEN)
	if not _is_safe_id(id):
		return _err("InvalidId", "id contains invalid characters")

	if kind != _KIND_IMAGE and kind != _KIND_AUDIO and kind != _KIND_VIDEO:
		return _err("InvalidKind", "kind must be image|audio|video")

	if typeof(bytes0) != TYPE_INT and typeof(bytes0) != TYPE_FLOAT:
		return _err("InvalidBytes", "bytes must be a number")
	if typeof(bytes0) == TYPE_FLOAT and float(bytes0) != float(int(bytes0)):
		return _err("InvalidBytes", "bytes must be an integer")
	var bytes := int(bytes0)
	if bytes <= 0:
		return _err("InvalidBytes", "bytes must be > 0")

	var max_bytes := _max_bytes_for_kind(kind)
	if bytes > max_bytes:
		return _err("InvalidBytes", "bytes exceeds limit for kind")

	if not _mime_allowed_for_kind(kind, mime):
		return _err("InvalidMime", "mime not allowed for kind")

	if not _is_sha256_hex(sha256):
		return _err("InvalidSha256", "sha256 must be 64 hex chars")

	var out: Dictionary = {
		"id": id,
		"kind": kind,
		"mime": mime,
		"bytes": bytes,
		"sha256": sha256,
	}

	var name := String(ref.get("name", "")).strip_edges()
	if name != "":
		if name.length() > _MAX_NAME_LEN or name.find("\n") != -1 or name.find("\r") != -1:
			return _err("InvalidName", "name too long or contains newline")
		out["name"] = name

	var caption := String(ref.get("caption", "")).strip_edges()
	if caption != "":
		if caption.length() > _MAX_NAME_LEN or caption.find("\n") != -1 or caption.find("\r") != -1:
			return _err("InvalidCaption", "caption too long or contains newline")
		out["caption"] = caption

	return {"ok": true, "ref": out}

static func _max_bytes_for_kind(kind: String) -> int:
	if kind == _KIND_IMAGE:
		return _MAX_IMAGE_BYTES
	if kind == _KIND_AUDIO:
		return _MAX_AUDIO_BYTES
	if kind == _KIND_VIDEO:
		return _MAX_VIDEO_BYTES
	return 0

static func _mime_allowed_for_kind(kind: String, mime: String) -> bool:
	if kind == _KIND_IMAGE:
		return mime == _MIME_IMAGE_PNG or mime == _MIME_IMAGE_JPEG
	if kind == _KIND_AUDIO:
		return mime == _MIME_AUDIO_MPEG or mime == _MIME_AUDIO_WAV
	if kind == _KIND_VIDEO:
		return mime == _MIME_VIDEO_MP4
	return false

static func _is_sha256_hex(s: String) -> bool:
	if s.length() != 64:
		return false
	for i in range(64):
		var c := s.unicode_at(i)
		var is_num := c >= 48 and c <= 57
		var is_hex := c >= 97 and c <= 102
		if not (is_num or is_hex):
			return false
	return true

static func _is_safe_id(s: String) -> bool:
	# Conservative: allow only [A-Za-z0-9_-].
	for i in range(s.length()):
		var c := s.unicode_at(i)
		var is_num := c >= 48 and c <= 57
		var is_low := c >= 97 and c <= 122
		var is_up := c >= 65 and c <= 90
		if not (is_num or is_low or is_up or c == 95 or c == 45):
			return false
	return true

static func _base64url_encode(raw: PackedByteArray) -> String:
	var b64 := Marshalls.raw_to_base64(raw)
	var s := String(b64)
	s = s.replace("+", "-").replace("/", "_")
	s = s.replace("=", "")
	return s

static func _base64url_decode(s: String) -> PackedByteArray:
	var t := s.strip_edges().replace("-", "+").replace("_", "/")
	# Pad to multiple of 4.
	var mod := t.length() % 4
	if mod == 1:
		return PackedByteArray()
	if mod == 2:
		t += "=="
	elif mod == 3:
		t += "="
	var raw: PackedByteArray = Marshalls.base64_to_raw(t)
	return raw

static func _err(code: String, msg: String) -> Dictionary:
	return {"ok": false, "error": code, "message": msg}
