extends RefCounted

const _OAData := preload("res://vr_offices/core/data/VrOfficesData.gd")

var _owner: Node = null
var _npc_scene: PackedScene = null
var _npc_root: Node3D = null
var _profiles: RefCounted = null
var _move_ctrl: RefCounted = null
var _is_headless: Callable = Callable()

var _npc_spawn_y: float = 2.0
var _spawn_extent: Vector2 = Vector2(6.0, 4.0) # X,Z half extents

func _init(
	owner: Node,
	npc_scene: PackedScene,
	npc_root: Node3D,
	profiles: RefCounted,
	move_ctrl: RefCounted,
	is_headless: Callable,
	npc_spawn_y: float,
	spawn_extent: Vector2
) -> void:
	_owner = owner
	_npc_scene = npc_scene
	_npc_root = npc_root
	_profiles = profiles
	_move_ctrl = move_ctrl
	_is_headless = is_headless
	_npc_spawn_y = npc_spawn_y
	_spawn_extent = spawn_extent

func set_spawn_params(npc_spawn_y: float, spawn_extent: Vector2) -> void:
	_npc_spawn_y = npc_spawn_y
	_spawn_extent = spawn_extent

func apply_profile_to_npc(npc: Node, npc_id: String, profile_index: int, forced_model_path: String = "") -> void:
	if npc == null:
		return
	var model_path := forced_model_path
	if model_path.strip_edges() == "":
		model_path = String(_OAData.MODEL_PATHS[profile_index])
	npc.name = npc_id
	npc.set("npc_id", npc_id)
	npc.set("model_path", model_path)
	if _profiles != null:
		npc.set("display_name", String(_profiles.call("name_for_profile", profile_index)))
	npc.set(
		"wander_bounds",
		Rect2(Vector2(-_spawn_extent.x, -_spawn_extent.y), Vector2(_spawn_extent.x * 2.0, _spawn_extent.y * 2.0))
	)
	npc.set("load_model_on_ready", not _is_headless.is_valid() or not bool(_is_headless.call()))

func load_npcs_from_state_list(list: Array, npc_counter: int) -> int:
	if _npc_root == null or _npc_scene == null:
		return npc_counter

	# Reserve any profiles used by saved NPCs.
	var seen_models: Dictionary = {}
	var max_num := npc_counter
	for it0 in list:
		if typeof(it0) != TYPE_DICTIONARY:
			continue
		var it: Dictionary = it0 as Dictionary
		var model_path := String(it.get("model_path", "")).strip_edges()
		if model_path == "" or seen_models.has(model_path):
			continue
		seen_models[model_path] = true

		var idx := -1
		if _profiles != null:
			_profiles.call("reserve_model", model_path)
			idx = int(_profiles.call("profile_index_for_model", model_path))
		if idx < 0:
			continue

		var npc0 := _npc_scene.instantiate()
		var npc := npc0 as Node
		if npc == null:
			continue

		var npc_id := String(it.get("npc_id", "")).strip_edges()
		if npc_id == "":
			npc_counter += 1
			npc_id = "npc_%d" % npc_counter

		# Track numeric suffix for future ids.
		if npc_id.begins_with("npc_"):
			var suffix := npc_id.substr(4)
			var maybe := int(suffix)
			if maybe > max_num:
				max_num = maybe

		apply_profile_to_npc(npc, npc_id, idx, model_path)

		var pos0: Variant = it.get("pos", [])
		var yaw := float(it.get("yaw", 0.0))
		if npc is Node3D:
			var n3 := npc as Node3D
			if typeof(pos0) == TYPE_ARRAY and (pos0 as Array).size() >= 3:
				var arr := pos0 as Array
				n3.position = Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
			else:
				n3.position = Vector3(randf_range(-_spawn_extent.x, _spawn_extent.x), _npc_spawn_y, randf_range(-_spawn_extent.y, _spawn_extent.y))
			n3.rotation.y = yaw

			_npc_root.add_child(npc)
			if _move_ctrl != null:
				_move_ctrl.call("connect_npc_signals", npc)

	return max(npc_counter, max_num)

func update_all_npc_names() -> void:
	if _owner == null or _owner.get_tree() == null:
		return
	for n in _owner.get_tree().get_nodes_in_group("vr_offices_npc"):
		if n == null or not (n is Node):
			continue
		var node := n as Node
		if not node.has_method("get"):
			continue
		var mp := String(node.get("model_path"))
		var idx := -1
		if _profiles != null:
			idx = int(_profiles.call("profile_index_for_model", mp))
		if idx >= 0 and _profiles != null:
			node.set("display_name", String(_profiles.call("name_for_profile", idx)))

func find_npc_by_id(npc_id: String) -> Node:
	var id := npc_id.strip_edges()
	if id == "" or _owner == null or _owner.get_tree() == null:
		return null
	var nodes: Array = _owner.get_tree().get_nodes_in_group("vr_offices_npc")
	for n0 in nodes:
		if typeof(n0) != TYPE_OBJECT:
			continue
		var n: Node = n0 as Node
		if n == null:
			continue
		if n.has_method("get"):
			var id0: Variant = n.get("npc_id")
			if id0 != null and String(id0) == id:
				return n
	return null
