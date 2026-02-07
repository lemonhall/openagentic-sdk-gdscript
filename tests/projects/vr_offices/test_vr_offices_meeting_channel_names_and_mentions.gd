extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var IrcNames := load("res://vr_offices/core/irc/VrOfficesIrcNames.gd")
	if IrcNames == null:
		T.fail_and_quit(self, "Missing VrOfficesIrcNames.gd")
		return
	if not IrcNames.has_method("derive_channel_for_meeting_room"):
		T.fail_and_quit(self, "VrOfficesIrcNames.gd missing derive_channel_for_meeting_room()")
		return

	# Channel names must be stable, safe, and length-limited.
	var sid := "slot_test_irc_names"
	var rid := "meeting_room:Alpha/01"
	var ch1: String = String(IrcNames.call("derive_channel_for_meeting_room", sid, rid, 50))
	var ch2: String = String(IrcNames.call("derive_channel_for_meeting_room", sid, rid, 50))
	if not T.require_true(self, ch1.strip_edges() != "" and ch1 == ch2, "Channel must be stable and non-empty"):
		return
	if not T.require_true(self, ch1.begins_with("#oa_"), "Channel must use #oa_ prefix, got=%s" % ch1):
		return
	if not T.require_true(self, ch1.length() <= 50, "Channel must respect channellen (<=50), got len=%d" % ch1.length()):
		return
	for i in range(ch1.length()):
		var c := ch1.unicode_at(i)
		var ok := (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 35 or c == 95 # 0-9 A-Z a-z # _
		if not ok:
			T.fail_and_quit(self, "Channel contains invalid char: %s in %s" % [String.chr(c), ch1])
			return

	var Mentions := load("res://vr_offices/core/meeting_rooms/VrOfficesMeetingMentions.gd")
	if Mentions == null:
		T.fail_and_quit(self, "Missing VrOfficesMeetingMentions.gd")
		return
	if not Mentions.has_method("parse_mentioned_npc_ids"):
		T.fail_and_quit(self, "VrOfficesMeetingMentions.gd missing parse_mentioned_npc_ids()")
		return

	var roster := [
		{"npc_id": "npc_01", "display_name": "Alice"},
		{"npc_id": "npc_02", "display_name": "Bob Lee"},
		{"npc_id": "npc_03", "display_name": "小明"},
	]

	var m1: Array = Mentions.call("parse_mentioned_npc_ids", "hi @Alice please reply", roster) as Array
	if not T.require_true(self, m1.has("npc_01"), "Expected @Alice -> npc_01"):
		return

	# Colon-at-line-start supports spaces in display name.
	var m2: Array = Mentions.call("parse_mentioned_npc_ids", "Bob Lee: can you summarize?", roster) as Array
	if not T.require_true(self, m2.has("npc_02"), "Expected 'Bob Lee:' -> npc_02"):
		return

	var m3: Array = Mentions.call("parse_mentioned_npc_ids", "@小明 你怎么看？", roster) as Array
	if not T.require_true(self, m3.has("npc_03"), "Expected @小明 -> npc_03"):
		return

	# npc_id mention always works.
	var m4: Array = Mentions.call("parse_mentioned_npc_ids", "@npc_02 hello", roster) as Array
	if not T.require_true(self, m4.has("npc_02"), "Expected @npc_02 -> npc_02"):
		return

	T.pass_and_quit(self)
