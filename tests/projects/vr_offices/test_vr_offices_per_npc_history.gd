extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var save_id: String = "slot_test_vr_offices_hist_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]

	# Some headless `--script` runs may not instantiate project autoloads before this script starts.
	# Ensure OpenAgentic exists so VrOffices can bind to it in _ready().
	var oa := get_root().get_node_or_null("OpenAgentic") as Node
	if oa == null:
		var OAScript := load("res://addons/openagentic/OpenAgentic.gd")
		if OAScript == null:
			T.fail_and_quit(self, "Missing res://addons/openagentic/OpenAgentic.gd")
			return
		oa = (OAScript as Script).new() as Node
		if oa == null:
			T.fail_and_quit(self, "Failed to instantiate OpenAgentic.gd")
			return
		oa.name = "OpenAgentic"
		get_root().add_child(oa)
		await process_frame
	oa.call("set_save_id", save_id)

	# Prepare per-NPC persisted history.
	var StoreScript := load("res://addons/openagentic/core/OAJsonlNpcSessionStore.gd")
	if StoreScript == null:
		T.fail_and_quit(self, "Missing OAJsonlNpcSessionStore.gd")
		return
	var store = StoreScript.new(save_id)
	store.append_event("npc_1", {"type": "user.message", "text": "hi1"})
	store.append_event("npc_1", {"type": "assistant.message", "text": "hello1"})
	store.append_event("npc_2", {"type": "user.message", "text": "hi2"})
	store.append_event("npc_2", {"type": "assistant.message", "text": "hello2"})

	# Instantiate VR Offices.
	var scene := load("res://vr_offices/VrOffices.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing res://vr_offices/VrOffices.tscn")
		return
	var world := (scene as PackedScene).instantiate()
	if world == null:
		T.fail_and_quit(self, "Failed to instantiate VrOffices.tscn")
		return
	get_root().add_child(world)
	await process_frame

	# Create two NPC nodes (npc_1, npc_2).
	var npc1: Node = world.call("add_npc") as Node
	var npc2: Node = world.call("add_npc") as Node
	if not T.require_true(self, npc1 != null and npc2 != null, "Expected two NPCs"):
		return

	var shell := world.get_node_or_null("UI/VrOfficesManagerDialogueOverlay") as Control
	if not T.require_true(self, shell != null, "Missing node VrOffices/UI/VrOfficesManagerDialogueOverlay"):
		return
	var overlay: Control = null
	if shell != null and shell.has_method("get_embedded_dialogue"):
		overlay = shell.call("get_embedded_dialogue") as Control
	if not T.require_true(self, overlay != null, "Expected embedded dialogue in manager shell"):
		return
	var messages := overlay.get_node_or_null("Panel/VBox/Scroll/Messages") as VBoxContainer
	if not T.require_true(self, messages != null, "Missing Messages container"):
		return

	# Open npc_1 dialogue should load npc_1 history.
	world.call("_enter_talk", npc1)
	await process_frame
	if not T.require_eq(self, messages.get_child_count(), 2, "Expected 2 messages for npc_1"):
		return
	if not _require_message_contains(messages, 0, "hi1"):
		T.fail_and_quit(self, "npc_1 first message mismatch")
		return
	if not _require_message_contains(messages, 1, "hello1"):
		T.fail_and_quit(self, "npc_1 second message mismatch")
		return
	overlay.call("close")
	await process_frame

	# Open npc_2 dialogue should NOT show npc_1 messages.
	world.call("_enter_talk", npc2)
	await process_frame
	if not T.require_eq(self, messages.get_child_count(), 2, "Expected 2 messages for npc_2"):
		return
	if not _require_message_contains(messages, 0, "hi2"):
		T.fail_and_quit(self, "npc_2 first message mismatch")
		return
	if not _require_message_contains(messages, 1, "hello2"):
		T.fail_and_quit(self, "npc_2 second message mismatch")
		return
	overlay.call("close")
	await process_frame

	# Re-open npc_1 should return to npc_1 history.
	world.call("_enter_talk", npc1)
	await process_frame
	if not T.require_eq(self, messages.get_child_count(), 2, "Expected 2 messages for npc_1 (again)"):
		return
	if not _require_message_contains(messages, 0, "hi1"):
		T.fail_and_quit(self, "npc_1 history did not restore")
		return

	# Cleanup.
	var bgm := world.get_node_or_null("Bgm")
	if bgm != null:
		bgm.call("stop")
		bgm.set("stream", null)
	get_root().remove_child(world)
	world.free()
	await process_frame
	T.pass_and_quit(self)

func _require_message_contains(messages: VBoxContainer, idx: int, needle: String) -> bool:
	if messages == null or idx < 0 or idx >= messages.get_child_count():
		return false
	var row := messages.get_child(idx) as Node
	if row == null:
		return false
	var labels := row.find_children("*", "RichTextLabel", true, false)
	if labels.size() < 1:
		return false
	var rtl := labels[0] as RichTextLabel
	if rtl == null:
		return false
	return rtl.text.find(needle) != -1
