extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var DialogueScene := load("res://vr_offices/ui/DialogueOverlay.tscn")
	if DialogueScene == null:
		T.fail_and_quit(self, "Missing DialogueOverlay.tscn")
		return
	var dlg: Control = (DialogueScene as PackedScene).instantiate()
	get_root().add_child(dlg)
	await process_frame

	var MediaRefScript := load("res://addons/openagentic/core/OAMediaRef.gd")
	if MediaRefScript == null:
		T.fail_and_quit(self, "Missing OAMediaRef.gd")
		return

	var save_id: String = "slot_test_dialogue_media_av_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	dlg.call("open", "npc_1", "NPC", save_id)
	await process_frame

	var audio_ref := {
		"id": "aud_1",
		"kind": "audio",
		"mime": "audio/wav",
		"bytes": 123,
		"sha256": _dummy_sha256(),
		"name": "a.wav",
	}
	var video_ref := {
		"id": "vid_1",
		"kind": "video",
		"mime": "video/mp4",
		"bytes": 456,
		"sha256": _dummy_sha256(),
		"name": "v.mp4",
	}

	var audio_line: String = (MediaRefScript as Script).call("encode_v1", audio_ref)
	var video_line: String = (MediaRefScript as Script).call("encode_v1", video_ref)
	if not T.require_true(self, audio_line.begins_with("OAMEDIA1 ") and video_line.begins_with("OAMEDIA1 "), "expected OAMEDIA1 lines"):
		return

	dlg.call("add_user_message", audio_line)
	dlg.call("add_user_message", video_line)
	await process_frame

	var found_audio := _find_label_text(dlg, "Audio message")
	var found_video := _find_label_text(dlg, "Video message")
	if not T.require_true(self, found_audio, "Expected audio placeholder label"):
		return
	if not T.require_true(self, found_video, "Expected video placeholder label"):
		return

	T.pass_and_quit(self)

func _find_label_text(root: Node, needle: String) -> bool:
	if root == null:
		return false
	if root is Label:
		var lbl := root as Label
		if lbl.text.find(needle) != -1:
			return true
	for c0 in root.get_children():
		var c := c0 as Node
		if c == null:
			continue
		if _find_label_text(c, needle):
			return true
	return false

func _dummy_sha256() -> String:
	var s := ""
	for _i in range(64):
		s += "a"
	return s

