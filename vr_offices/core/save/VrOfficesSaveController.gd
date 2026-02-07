extends RefCounted

var _world_state: RefCounted
var _npc_manager: RefCounted
var _workspace_manager: RefCounted = null
var _meeting_room_manager: RefCounted = null
var _desk_manager: RefCounted = null
var _irc_settings: RefCounted = null
var _get_save_id: Callable

func _init(
	world_state: RefCounted,
	manager: RefCounted,
	get_save_id: Callable,
	workspace_manager: RefCounted = null,
	meeting_room_manager: RefCounted = null,
	desk_manager: RefCounted = null,
	irc_settings: RefCounted = null
) -> void:
	_world_state = world_state
	_npc_manager = manager
	_workspace_manager = workspace_manager
	_meeting_room_manager = meeting_room_manager
	_desk_manager = desk_manager
	_irc_settings = irc_settings
	_get_save_id = get_save_id

func load_world() -> void:
	if _world_state == null or _npc_manager == null or not _get_save_id.is_valid():
		return
	var save_id := String(_get_save_id.call()).strip_edges()
	if save_id == "":
		return
	var st: Dictionary = _world_state.call("read_state", save_id)
	if st.is_empty():
		return
	_npc_manager.call("load_from_state_dict", st)
	if _irc_settings != null and _irc_settings.has_method("load_from_state_dict"):
		_irc_settings.call("load_from_state_dict", st)
	if _workspace_manager != null:
		_workspace_manager.call("load_from_state_dict", st)
	if _meeting_room_manager != null:
		_meeting_room_manager.call("load_from_state_dict", st)
	if _desk_manager != null:
		if _irc_settings != null and _irc_settings.has_method("get_config") and _desk_manager.has_method("set_irc_config"):
			_desk_manager.call("set_irc_config", _irc_settings.call("get_config"))
		_desk_manager.call("load_from_state_dict", st)

func save_world(npc_root: Node3D) -> void:
	if _world_state == null or _npc_manager == null or not _get_save_id.is_valid():
		return
	var save_id := String(_get_save_id.call()).strip_edges()
	if save_id == "":
		return
	if npc_root == null:
		return
	var culture := String(_npc_manager.call("get_culture_code"))
	var counter := int(_npc_manager.call("get_npc_counter"))
	var workspaces: Array = []
	var ws_counter := 0
	if _workspace_manager != null:
		workspaces = _workspace_manager.call("to_state_array")
		ws_counter = int(_workspace_manager.call("get_workspace_counter"))
	var meeting_rooms: Array = []
	var meeting_room_counter := 0
	if _meeting_room_manager != null:
		meeting_rooms = _meeting_room_manager.call("to_state_array")
		meeting_room_counter = int(_meeting_room_manager.call("get_meeting_room_counter"))
	var desks: Array = []
	var desk_counter := 0
	if _desk_manager != null:
		desks = _desk_manager.call("to_state_array")
		desk_counter = int(_desk_manager.call("get_desk_counter"))
	var irc: Dictionary = {}
	if _irc_settings != null and _irc_settings.has_method("to_state_dict"):
		var irc0: Variant = _irc_settings.call("to_state_dict")
		if typeof(irc0) == TYPE_DICTIONARY:
			irc = irc0 as Dictionary
	var st: Dictionary = _world_state.call("build_state", save_id, culture, counter, npc_root, workspaces, ws_counter, desks, desk_counter, irc, meeting_rooms, meeting_room_counter)
	_world_state.call("write_state", save_id, st)
