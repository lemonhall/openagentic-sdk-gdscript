extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var MediaRefScript := load("res://addons/openagentic/core/OAMediaRef.gd")
	if MediaRefScript == null:
		T.fail_and_quit(self, "Missing OAMediaRef.gd")
		return

	var MediaRef = MediaRefScript as Script

	var ref := {
		"id": "img_abc123",
		"kind": "image",
		"mime": "image/png",
		"bytes": 123,
		"sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
		"name": "x.png",
		"caption": "hello",
	}

	var line: String = MediaRef.call("encode_v1", ref)
	if not T.require_true(self, line.begins_with("OAMEDIA1 "), "encode_v1 should return OAMEDIA1 line"):
		return
	if not T.require_true(self, line.length() <= 512, "encoded line must be <= 512 chars"):
		return

	var dec0: Variant = MediaRef.call("decode_v1", line)
	if not T.require_true(self, typeof(dec0) == TYPE_DICTIONARY, "decode_v1 should return Dictionary"):
		return
	var dec: Dictionary = dec0 as Dictionary
	if not T.require_true(self, bool(dec.get("ok", false)), "decode_v1 should succeed"):
		return
	if not T.require_true(self, typeof(dec.get("ref", null)) == TYPE_DICTIONARY, "decode_v1 should return ref"):
		return
	var got: Dictionary = dec.get("ref", {})

	if not T.require_eq(self, String(got.get("id", "")), "img_abc123", "id"):
		return
	if not T.require_eq(self, String(got.get("kind", "")), "image", "kind"):
		return
	if not T.require_eq(self, String(got.get("mime", "")), "image/png", "mime"):
		return
	if not T.require_eq(self, int(got.get("bytes", -1)), 123, "bytes"):
		return
	if not T.require_eq(self, String(got.get("sha256", "")), ref.sha256, "sha256"):
		return

	# Invalid: prefix
	var bad1: Dictionary = MediaRef.call("decode_v1", "OAMEDIA0 AAA")
	if not T.require_true(self, not bool(bad1.get("ok", true)), "wrong version must fail"):
		return

	# Invalid: too long
	var long_line := "OAMEDIA1 " + "A".repeat(600)
	var bad2: Dictionary = MediaRef.call("decode_v1", long_line)
	if not T.require_true(self, not bool(bad2.get("ok", true)), "overlong line must fail"):
		return

	# Invalid: mime allowlist
	var ref2 := ref.duplicate(true)
	ref2["mime"] = "image/gif"
	var line2: String = MediaRef.call("encode_v1", ref2)
	if not T.require_true(self, line2 == "", "encode_v1 should reject disallowed mime"):
		return

	# Invalid: sha256 format
	var ref3 := ref.duplicate(true)
	ref3["sha256"] = "not-hex"
	var line3: String = MediaRef.call("encode_v1", ref3)
	if not T.require_true(self, line3 == "", "encode_v1 should reject invalid sha256"):
		return

	T.pass_and_quit(self)

