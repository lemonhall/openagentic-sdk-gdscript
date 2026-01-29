extends RefCounted

var _world_state: RefCounted
var _manager: RefCounted
var _get_save_id: Callable

func _init(world_state: RefCounted, manager: RefCounted, get_save_id: Callable) -> void:
	_world_state = world_state
	_manager = manager
	_get_save_id = get_save_id

func load_world() -> void:
	if _world_state == null or _manager == null or not _get_save_id.is_valid():
		return
	var save_id := String(_get_save_id.call()).strip_edges()
	if save_id == "":
		return
	var st: Dictionary = _world_state.call("read_state", save_id)
	if st.is_empty():
		return
	_manager.call("load_from_state_dict", st)

func save_world(npc_root: Node3D) -> void:
	if _world_state == null or _manager == null or not _get_save_id.is_valid():
		return
	var save_id := String(_get_save_id.call()).strip_edges()
	if save_id == "":
		return
	if npc_root == null:
		return
	var culture := String(_manager.call("get_culture_code"))
	var counter := int(_manager.call("get_npc_counter"))
	var st: Dictionary = _world_state.call("build_state", save_id, culture, counter, npc_root)
	_world_state.call("write_state", save_id, st)

