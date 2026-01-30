extends SceneTree

const T := preload("res://tests/_test_util.gd")

static func _is_safe_irc_token(s: String) -> bool:
	# Conservative: allow alnum + underscore only (no spaces).
	for i in s.length():
		var c := s.unicode_at(i)
		var ok := (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95
		if not ok:
			return false
	return true

func _init() -> void:
	var NamesScript := load("res://vr_offices/core/irc/VrOfficesIrcNames.gd")
	if NamesScript == null or not (NamesScript is Script) or not (NamesScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing or invalid res://vr_offices/core/irc/VrOfficesIrcNames.gd")
		return

	var names = (NamesScript as Script).new()
	if not T.require_true(self, names != null, "Failed to instantiate VrOfficesIrcNames"):
		return

	var save_id := "slot1-with-a-very-very-long-save-id-1234567890-abcdef"
	var desk_id := "desk_1234567890_with_extra_suffix_beyond_reasonable_length"

	if not names.has_method("derive_nick"):
		T.fail_and_quit(self, "VrOfficesIrcNames must implement derive_nick(save_id, desk_id, nicklen)")
		return
	if not names.has_method("derive_channel_for_workspace"):
		T.fail_and_quit(self, "VrOfficesIrcNames must implement derive_channel_for_workspace(save_id, workspace_id, desk_id, channellen)")
		return

	var nick := String(names.call("derive_nick", save_id, desk_id, 9))
	var ch := String(names.call("derive_channel_for_workspace", save_id, "ws_1", desk_id, 50))

	if not T.require_true(self, nick.begins_with("oa"), "Nick should start with 'oa'"):
		return
	if not T.require_true(self, nick.length() <= 9, "Nick should respect nicklen cap"):
		return
	if not T.require_true(self, _is_safe_irc_token(nick), "Nick should be conservative-safe token"):
		return

	if not T.require_true(self, ch.begins_with("#"), "Channel should start with #"):
		return
	if not T.require_true(self, ch.length() <= 50, "Channel should respect channellen cap"):
		return
	if not T.require_true(self, _is_safe_irc_token(ch.substr(1)), "Channel body should be conservative-safe token"):
		return
	if not T.require_true(self, ch.find("ws_1") != -1, "Channel should include workspace_id for meaning"):
		return
	if not T.require_true(self, ch.find("desk") != -1, "Channel should include desk_id hint for meaning"):
		return

	# Deterministic.
	var nick2 := String(names.call("derive_nick", save_id, desk_id, 9))
	var ch2 := String(names.call("derive_channel_for_workspace", save_id, "ws_1", desk_id, 50))
	if not T.require_eq(self, nick2, nick, "Nick must be deterministic"):
		return
	if not T.require_eq(self, ch2, ch, "Channel must be deterministic"):
		return

	T.pass_and_quit(self)
