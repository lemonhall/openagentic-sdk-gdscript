extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var CodecScript := load("res://vr_offices/core/irc/OA1IrcRpcCodec.gd")
	if CodecScript == null:
		T.fail_and_quit(self, "Failed to load OA1IrcRpcCodec.gd")
		return

	# Basic escape/unescape roundtrip.
	var raw := "a\\b\nc\rd\t"
	var enc: String = (CodecScript as Script).call("escape_payload", raw)
	var dec: String = (CodecScript as Script).call("unescape_payload", enc)
	if not T.require_eq(self, dec, raw, "escape/unescape must roundtrip"):
		return

	# Chunking must not drop data.
	var chunks: Array = (CodecScript as Script).call("chunk_utf8_by_bytes", enc, 4)
	var joined := ""
	for c0 in chunks:
		joined += String(c0)
	if not T.require_eq(self, joined, enc, "chunking must preserve data"):
		return

	T.pass_and_quit(self)

