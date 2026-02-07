extends RefCounted

const _MeetingRoomStore := preload("res://vr_offices/core/meeting_rooms/VrOfficesMeetingRoomStore.gd")
const _SceneBinder := preload("res://vr_offices/core/meeting_rooms/VrOfficesMeetingRoomSceneBinder.gd")

var floor_bounds_xz: Rect2

var _store: RefCounted = null
var _scene: RefCounted = null
var _on_room_created: Callable = Callable()
var _on_room_deleted: Callable = Callable()

func _init(bounds_xz: Rect2, root: Node3D = null, scene: PackedScene = null, is_headless: Callable = Callable()) -> void:
	floor_bounds_xz = bounds_xz
	_store = _MeetingRoomStore.new(bounds_xz)
	_scene = _SceneBinder.new()
	if root != null and scene != null:
		bind_scene(root, scene, is_headless)

func set_lifecycle_callbacks(on_room_created: Callable, on_room_deleted: Callable = Callable()) -> void:
	_on_room_created = on_room_created
	_on_room_deleted = on_room_deleted

func get_meeting_room_counter() -> int:
	return int(_store.call("get_meeting_room_counter"))

func list_meeting_rooms() -> Array:
	return _store.call("list_meeting_rooms")

func get_meeting_room(meeting_room_id: String) -> Dictionary:
	return _store.call("get_meeting_room", meeting_room_id)

func get_meeting_room_rect_xz(meeting_room_id: String) -> Rect2:
	return _store.call("get_meeting_room_rect_xz", meeting_room_id)

func meeting_room_id_from_point_xz(point_xz: Vector2) -> String:
	if _store == null or not _store.has_method("meeting_room_id_from_point_xz"):
		return ""
	return String(_store.call("meeting_room_id_from_point_xz", point_xz)).strip_edges()

func bind_scene(root: Node3D, scene: PackedScene, is_headless: Callable) -> void:
	_scene.call("bind_scene", root, scene, is_headless)
	_scene.call("rebuild_nodes", _store.call("list_meeting_rooms_ref"))
	_notify_rooms_created(_store.call("list_meeting_rooms"))

func clamp_rect_to_floor(r: Rect2) -> Rect2:
	return _store.call("clamp_rect_to_floor", r)

func can_place(rect_xz: Rect2) -> bool:
	return bool(_store.call("can_place", rect_xz))

func create_meeting_room(rect_xz: Rect2, name: String) -> Dictionary:
	var res: Dictionary = _store.call("create_meeting_room", rect_xz, name)
	if bool(res.get("ok", false)):
		var r0: Variant = res.get("meeting_room")
		if typeof(r0) == TYPE_DICTIONARY:
			var room := r0 as Dictionary
			_scene.call("spawn_node_for", room)
			_scene.call("play_spawn_fx_for", String(room.get("id", "")))
			_notify_room_created(String(room.get("id", "")))
	return res

func delete_meeting_room(meeting_room_id: String) -> Dictionary:
	var res: Dictionary = _store.call("delete_meeting_room", meeting_room_id)
	if bool(res.get("ok", false)):
		_notify_room_deleted(meeting_room_id)
		_scene.call("free_node_for_id", meeting_room_id)
	return res

func to_state_array() -> Array:
	return _store.call("to_state_array")

func load_from_state_dict(state: Dictionary) -> void:
	_store.call("load_from_state_dict", state)
	_scene.call("rebuild_nodes", _store.call("list_meeting_rooms_ref"))
	_notify_rooms_created(_store.call("list_meeting_rooms"))

func meeting_room_id_from_collider(obj: Object) -> String:
	var cur := obj
	while cur != null and cur is Node:
		var n := cur as Node
		if n.is_in_group("vr_offices_meeting_room") and n.has_method("get"):
			var v: Variant = n.get("meeting_room_id")
			if v != null:
				return String(v)
			return n.name
		cur = n.get_parent()
	return ""

func get_meeting_room_node(meeting_room_id: String) -> Node:
	if _scene == null:
		return null
	if not _scene.has_method("get_node_for_id"):
		return null
	return _scene.call("get_node_for_id", meeting_room_id) as Node

func _notify_rooms_created(rooms0: Variant) -> void:
	if not _on_room_created.is_valid():
		return
	if typeof(rooms0) != TYPE_ARRAY:
		return
	for r0 in rooms0 as Array:
		if typeof(r0) != TYPE_DICTIONARY:
			continue
		var r := r0 as Dictionary
		_notify_room_created(String(r.get("id", "")))

func _notify_room_created(meeting_room_id: String) -> void:
	if not _on_room_created.is_valid():
		return
	var rid := meeting_room_id.strip_edges()
	if rid == "":
		return
	_on_room_created.call(rid)

func _notify_room_deleted(meeting_room_id: String) -> void:
	if not _on_room_deleted.is_valid():
		return
	var rid := meeting_room_id.strip_edges()
	if rid == "":
		return
	_on_room_deleted.call(rid)
