extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var save_id: String = "slot_test_vr_offices_persist_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]

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

	var scene := load("res://vr_offices/VrOffices.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing res://vr_offices/VrOffices.tscn")
		return

	# First run: create NPCs then autosave.
	var world1 := (scene as PackedScene).instantiate() as Node
	if world1 == null:
		T.fail_and_quit(self, "Failed to instantiate VrOffices.tscn")
		return
	get_root().add_child(world1)
	await process_frame

	var npc1: Node = world1.call("add_npc") as Node
	var npc2: Node = world1.call("add_npc") as Node
	if not T.require_true(self, npc1 != null and npc2 != null, "Expected two NPCs"):
		return

	var mp1 := String(npc1.get("model_path"))
	var mp2 := String(npc2.get("model_path"))
	var id1 := String(npc1.get("npc_id"))
	var id2 := String(npc2.get("npc_id"))

	if world1.has_method("autosave"):
		world1.call("autosave")

	var bgm1 := world1.get_node_or_null("Bgm")
	if bgm1 != null:
		bgm1.call("stop")
		bgm1.set("stream", null)
	get_root().remove_child(world1)
	world1.free()
	await process_frame

	# Second run: should load saved NPCs automatically.
	var world2 := (scene as PackedScene).instantiate() as Node
	if world2 == null:
		T.fail_and_quit(self, "Failed to instantiate VrOffices.tscn (second)")
		return
	get_root().add_child(world2)
	await process_frame

	var npc_root := world2.get_node_or_null("NpcRoot") as Node
	if not T.require_true(self, npc_root != null, "Missing node VrOffices/NpcRoot"):
		return
	if not T.require_eq(self, npc_root.get_child_count(), 2, "Expected 2 NPCs after reload"):
		return

	# Validate the exact model paths and ids are present.
	var seen: Dictionary = {}
	for c0 in npc_root.get_children():
		var c := c0 as Node
		if c == null:
			continue
		var mid := String(c.get("model_path"))
		var nid := String(c.get("npc_id"))
		seen["%s|%s" % [nid, mid]] = true

	if not T.require_true(self, seen.has("%s|%s" % [id1, mp1]), "Missing npc_1 record after reload"):
		return
	if not T.require_true(self, seen.has("%s|%s" % [id2, mp2]), "Missing npc_2 record after reload"):
		return

	var bgm2 := world2.get_node_or_null("Bgm")
	if bgm2 != null:
		bgm2.call("stop")
		bgm2.set("stream", null)
	get_root().remove_child(world2)
	world2.free()
	await process_frame
	T.pass_and_quit(self)

