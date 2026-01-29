extends RefCounted

const _OAData := preload("res://vr_offices/core/VrOfficesData.gd")

var _owner: Node
var _npc_scene: PackedScene
var _npc_root: Node3D
var _ui: Control
var _profiles: RefCounted
var _move_ctrl: RefCounted
var _is_headless: Callable
var _autosave: Callable

var _npc_counter: int = 0
var _selected_npc: Node = null
var _culture_code: String = "zh-CN"
var _npc_spawn_y: float = 2.0
var _spawn_extent: Vector2 = Vector2(6.0, 4.0) # X,Z half extents

func _init(
	owner: Node,
	npc_scene: PackedScene,
	npc_root: Node3D,
	ui: Control,
	profiles: RefCounted,
	move_ctrl: RefCounted,
	is_headless: Callable,
	autosave: Callable
) -> void:
	_owner = owner
	_npc_scene = npc_scene
	_npc_root = npc_root
	_ui = ui
	_profiles = profiles
	_move_ctrl = move_ctrl
	_is_headless = is_headless
	_autosave = autosave

func set_spawn_params(npc_spawn_y: float, spawn_extent: Vector2) -> void:
	_npc_spawn_y = npc_spawn_y
	_spawn_extent = spawn_extent

func set_culture(code: String) -> void:
	if not _OAData.has_culture(code):
		return
	_culture_code = code
	if _owner != null and _owner.has_method("set"):
		_owner.set("culture_code", _culture_code)
	if _profiles != null:
		_profiles.call("set_culture", _culture_code)
	_update_all_npc_names()
	_apply_ui_state()
	_try_autosave()

func get_culture_code() -> String:
	return _culture_code

func set_npc_counter(v: int) -> void:
	_npc_counter = max(_npc_counter, v)

func get_npc_counter() -> int:
	return _npc_counter

func get_selected_npc() -> Node:
	return _selected_npc

func can_add() -> bool:
	return _profiles != null and bool(_profiles.call("can_add"))

func add_npc() -> Node:
	if not can_add():
		if _ui != null and _ui.has_method("set_status_text"):
			_ui.call("set_status_text", "Reached max NPCs (%d). Remove one to add more." % _OAData.MAX_NPCS)
		return null
	if _npc_scene == null:
		return null

	_npc_counter += 1
	var npc0 := _npc_scene.instantiate()
	var npc := npc0 as Node
	if npc == null:
		return null

	var npc_id := "npc_%d" % _npc_counter
	npc.name = npc_id

	var profile_index := int(_profiles.call("take_random_index"))
	if profile_index < 0:
		return null

	_apply_profile_to_npc(npc, npc_id, profile_index)

	# Spawn within a rectangle on XZ.
	var x := randf_range(-_spawn_extent.x, _spawn_extent.x)
	var z := randf_range(-_spawn_extent.y, _spawn_extent.y)
	if npc is Node3D:
		(npc as Node3D).position = Vector3(x, _npc_spawn_y, z)

	_npc_root.add_child(npc)
	if _move_ctrl != null:
		_move_ctrl.call("connect_npc_signals", npc)
	select_npc(npc)
	_apply_ui_state()
	_try_autosave()
	return npc

func remove_selected() -> void:
	if _selected_npc == null or not is_instance_valid(_selected_npc):
		return

	var to_remove := _selected_npc
	if _move_ctrl != null:
		_move_ctrl.call("clear_move_indicator_for_node", to_remove)

	var model_path := ""
	if to_remove.has_method("get") and to_remove.get("model_path") != null:
		model_path = String(to_remove.get("model_path"))
	if _profiles != null:
		_profiles.call("release_model", model_path)

	select_npc(null)
	to_remove.queue_free()
	_apply_ui_state()
	_try_autosave()

func select_npc(npc: Node) -> void:
	if _selected_npc != null and is_instance_valid(_selected_npc) and _selected_npc.has_method("set_selected"):
		_selected_npc.call("set_selected", false)

	_selected_npc = npc

	if _selected_npc != null and is_instance_valid(_selected_npc) and _selected_npc.has_method("set_selected"):
		_selected_npc.call("set_selected", true)

	if _ui != null:
		if _selected_npc == null:
			if _ui.has_method("set_selected_text"):
				_ui.call("set_selected_text", "")
		else:
			var label := _selected_npc.name
			if _selected_npc.has_method("get_display_name"):
				label = String(_selected_npc.call("get_display_name"))
			if _ui.has_method("set_selected_text"):
				_ui.call("set_selected_text", label)
		if _ui.has_method("set_status_text"):
			_ui.call("set_status_text", "")

func find_npc_by_id(npc_id: String) -> Node:
	if npc_id.strip_edges() == "" or _owner == null or _owner.get_tree() == null:
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
			if id0 != null and String(id0) == npc_id:
				return n
	return null

func load_from_state_dict(st: Dictionary) -> void:
	if st.is_empty() or _npc_root == null or _npc_scene == null:
		return
	var v := int(st.get("version", 1))
	# v2 extends v1 with additional fields (e.g. workspaces). NPC load logic is compatible.
	if v < 1 or v > 2:
		return

	var cc := String(st.get("culture_code", _culture_code)).strip_edges()
	if cc != "" and _OAData.has_culture(cc):
		_culture_code = cc
		if _profiles != null:
			_profiles.call("set_culture", _culture_code)
		if _owner != null and _owner.has_method("set"):
			_owner.set("culture_code", _culture_code)

	var counter := int(st.get("npc_counter", _npc_counter))
	_npc_counter = max(_npc_counter, counter)

	var list0: Variant = st.get("npcs", [])
	if typeof(list0) != TYPE_ARRAY:
		return
	var list: Array = list0 as Array

	# Reserve any profiles used by saved NPCs.
	var seen_models: Dictionary = {}
	var max_num := _npc_counter
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
			_npc_counter += 1
			npc_id = "npc_%d" % _npc_counter

		# Track numeric suffix for future ids.
		if npc_id.begins_with("npc_"):
			var suffix := npc_id.substr(4)
			var maybe := int(suffix)
			if maybe > max_num:
				max_num = maybe

		_apply_profile_to_npc(npc, npc_id, idx, model_path)

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

	_npc_counter = max(_npc_counter, max_num)
	_apply_ui_state()

func _apply_profile_to_npc(npc: Node, npc_id: String, profile_index: int, forced_model_path: String = "") -> void:
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

func _update_all_npc_names() -> void:
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
	if _selected_npc != null and is_instance_valid(_selected_npc):
		select_npc(_selected_npc)

func _apply_ui_state() -> void:
	if _ui == null:
		return
	if _ui.has_method("set_can_add"):
		_ui.call("set_can_add", can_add())
	if _ui.has_method("set_status_text"):
		_ui.call("set_status_text", "")

func _try_autosave() -> void:
	if _autosave.is_valid():
		_autosave.call()
