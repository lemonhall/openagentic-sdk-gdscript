extends RefCounted

const DESK_KIND_STANDING := "standing_desk"

const _DeskModel := preload("res://vr_offices/core/desks/VrOfficesDeskModel.gd")
const _DeskSceneBinder := preload("res://vr_offices/core/desks/VrOfficesDeskSceneBinder.gd")
const _IrcConfig := preload("res://vr_offices/core/irc/VrOfficesIrcConfig.gd")
const _IrcNames := preload("res://vr_offices/core/irc/VrOfficesIrcNames.gd")

var _model := _DeskModel.new()
var _scene := _DeskSceneBinder.new()

var _irc_config: Dictionary = {}

func get_desk_counter() -> int:
	return int(_model.get_desk_counter())

func get_max_desks_per_workspace() -> int:
	return int(_model.get_max_desks_per_workspace())

func get_standing_desk_footprint_size_xz(yaw: float) -> Vector2:
	return _model.get_standing_desk_footprint_size_xz(yaw)

func list_desks() -> Array:
	return _model.list_desks()

func list_desks_for_workspace(workspace_id: String) -> Array:
	return _model.list_desks_for_workspace(workspace_id)

func list_desk_irc_snapshots() -> Array:
	return _scene.list_desk_irc_snapshots(_model.list_desks_ref())

func set_desk_device_code(desk_id: String, code: String) -> Dictionary:
	var did := desk_id.strip_edges()
	if did == "":
		return {"ok": false, "reason": "empty_desk_id"}

	var input := code.strip_edges()
	var canonical := _IrcNames.canonicalize_device_code(input)
	if canonical == "" and input == "":
		var changed_clear := _model.set_device_code(did, "")
		if changed_clear:
			_scene.refresh_irc_links(_model.list_desks_ref(), _irc_config)
		return {"ok": true, "device_code": "", "changed": changed_clear}

	if canonical == "" or not _IrcNames.is_valid_device_code_canonical(canonical):
		return {"ok": false, "reason": "invalid_device_code", "device_code": canonical}

	var changed := _model.set_device_code(did, canonical)
	if changed:
		_scene.refresh_irc_links(_model.list_desks_ref(), _irc_config)
	return {"ok": true, "device_code": canonical, "changed": changed}

func get_desk_device_code(desk_id: String) -> String:
	return _model.get_device_code(desk_id)

func bind_scene(root: Node3D, desk_scene: PackedScene, is_headless: Callable, get_save_id: Callable = Callable()) -> void:
	_scene.bind_scene(root, desk_scene, is_headless, get_save_id)
	_scene.rebuild_nodes(_model.list_desks_ref(), _irc_config)

func set_irc_config(config: Dictionary) -> void:
	var cfg := _IrcConfig.for_desks(config)
	if _irc_config == cfg:
		return
	_irc_config = cfg
	_scene.refresh_irc_links(_model.list_desks_ref(), _irc_config)

func reconnect_all_irc_links() -> void:
	_scene.reconnect_all_irc_links(_model.list_desks_ref(), _irc_config)

func can_place_standing_desk(workspace_id: String, workspace_rect_xz: Rect2, center_xz: Vector2, yaw: float) -> Dictionary:
	return _model.can_place_standing_desk(workspace_id, workspace_rect_xz, center_xz, yaw)

func add_standing_desk(workspace_id: String, workspace_rect_xz: Rect2, pos: Vector3, yaw: float) -> Dictionary:
	var res: Dictionary = _model.add_standing_desk(workspace_id, workspace_rect_xz, pos, yaw)
	if bool(res.get("ok", false)):
		var d0: Variant = res.get("desk")
		if typeof(d0) == TYPE_DICTIONARY:
			_scene.spawn_node_for(d0 as Dictionary, _irc_config)
	return res

func delete_desks_for_workspace(workspace_id: String) -> int:
	var removed_ids := _model.delete_desks_for_workspace(workspace_id)
	_scene.delete_nodes_for_ids(removed_ids)
	return removed_ids.size()

func to_state_array() -> Array:
	return _model.to_state_array()

func load_from_state_dict(state: Dictionary) -> void:
	_model.load_from_state_dict(state)
	_scene.rebuild_nodes(_model.list_desks_ref(), _irc_config)
