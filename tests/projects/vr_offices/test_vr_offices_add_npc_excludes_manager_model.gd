extends SceneTree

const T := preload("res://tests/_test_util.gd")
const _OAData := preload("res://vr_offices/core/data/VrOfficesData.gd")

func _init() -> void:
	var save_id: String = "slot_test_vr_offices_no_manager_model_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
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
	var world := (scene as PackedScene).instantiate()
	if world == null:
		T.fail_and_quit(self, "Failed to instantiate VrOffices.tscn")
		return
	get_root().add_child(world)
	await process_frame

	var npc_root := world.get_node_or_null("NpcRoot") as Node
	if not T.require_true(self, npc_root != null, "Missing NpcRoot"):
		return

	var seen: Array[String] = []
	while true:
		var npc := world.call("add_npc") as Node
		if npc == null:
			break
		if npc.has_method("get"):
			var mp0: Variant = npc.get("model_path")
			if mp0 != null:
				seen.append(String(mp0).strip_edges())

	var expected_max := _OAData.MODEL_PATHS.size() - 1
	if not T.require_eq(self, npc_root.get_child_count(), expected_max, "Expected max add_npc count excludes manager model"):
		return
	if not T.require_true(self, not seen.has(String(_OAData.MANAGER_MODEL_PATH)), "add_npc must not allocate manager model path"):
		return

	T.pass_and_quit(self)
