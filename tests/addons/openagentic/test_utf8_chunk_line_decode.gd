extends SceneTree

const T := preload("res://tests/_test_util.gd")
const Provider := preload("res://addons/openagentic/providers/OAOpenAIResponsesProvider.gd")

func _init() -> void:
	# Regression: streaming HTTP chunks can split UTF-8 sequences (e.g. "你" = E4 BD A0)
	# If we decode each chunk to String immediately, Godot logs "Unicode parsing error"
	# and replaces bytes with U+FFFD. Provider must buffer bytes and decode per-line.
	var p := Provider.new("https://example.com") as RefCounted
	if not T.require_true(self, p != null, "Failed to instantiate OAOpenAIResponsesProvider"):
		return

	if not T.require_true(self, p.has_method("_test_decode_lines_from_chunks"), "Provider missing _test_decode_lines_from_chunks()"):
		return

	var ni_bytes := "你".to_utf8_buffer()
	var chunk1 := PackedByteArray([ni_bytes[0]]) # E4
	var chunk2 := PackedByteArray([ni_bytes[1], ni_bytes[2], 10]) # BD A0 + '\n'

	var lines: PackedStringArray = p.call("_test_decode_lines_from_chunks", [chunk1, chunk2])
	if not T.require_eq(self, lines.size(), 1, "Expected 1 decoded line"):
		return
	if not T.require_eq(self, lines[0], "你\n", "Expected UTF-8 to survive chunk split"):
		return

	T.pass_and_quit(self)
