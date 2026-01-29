extends Node3D

const MAX_NPCS := 12

const MODEL_PATHS: Array[String] = [
	"res://assets/kenney/mini-characters-1/character-female-a.glb",
	"res://assets/kenney/mini-characters-1/character-female-b.glb",
	"res://assets/kenney/mini-characters-1/character-female-c.glb",
	"res://assets/kenney/mini-characters-1/character-female-d.glb",
	"res://assets/kenney/mini-characters-1/character-female-e.glb",
	"res://assets/kenney/mini-characters-1/character-female-f.glb",
	"res://assets/kenney/mini-characters-1/character-male-a.glb",
	"res://assets/kenney/mini-characters-1/character-male-b.glb",
	"res://assets/kenney/mini-characters-1/character-male-c.glb",
	"res://assets/kenney/mini-characters-1/character-male-d.glb",
	"res://assets/kenney/mini-characters-1/character-male-e.glb",
	"res://assets/kenney/mini-characters-1/character-male-f.glb",
]

const CULTURE_NAMES := {
	# Default: Chinese culture (12 unique names).
	"zh-CN": [
		"林晓", "苏雨晴", "周若雪", "陈思妍", "唐婉儿", "叶清歌",
		"王子轩", "李泽言", "张昊然", "赵景行", "孙亦辰", "郭承宇",
	],
	# US culture: intentionally diverse.
	"en-US": [
		"Emily Carter", "Maya Patel", "Sofia Garcia", "Hannah Kim", "Aaliyah Johnson", "Olivia Nguyen",
		"Alex Johnson", "Daniel Smith", "Ethan Chen", "Noah Williams", "Liam O'Connor", "Jayden Martinez",
	],
	# Japan culture.
	"ja-JP": [
		"佐藤 美咲", "鈴木 陽菜", "高橋 さくら", "田中 結衣", "伊藤 彩花", "渡辺 りん",
		"佐藤 蓮", "鈴木 悠真", "高橋 大輝", "田中 海斗", "伊藤 陽向", "渡辺 颯太",
	],
}

@export var npc_scene: PackedScene
@export var npc_spawn_y := 2.0
@export var spawn_extent := Vector2(6.0, 4.0) # X,Z half extents
@export var culture_code := "zh-CN"

@onready var npc_root: Node3D = $NpcRoot
@onready var camera_rig: Node3D = $CameraRig
@onready var ui: Control = $UI/VrOfficesUi
@onready var bgm: AudioStreamPlayer = $Bgm

var _npc_counter := 0
var _selected_npc: Node = null

var _available_profile_indices: Array[int] = []
var _profile_index_by_model_path: Dictionary = {}

func _ready() -> void:
	randomize()
	if npc_scene == null:
		npc_scene = preload("res://vr_offices/npc/Npc.tscn")

	ui.add_npc_pressed.connect(add_npc)
	ui.remove_selected_pressed.connect(remove_selected)
	if ui.has_signal("culture_changed"):
		ui.connect("culture_changed", Callable(self, "set_culture"))

	_configure_bgm()
	_init_profiles()
	_apply_ui_state()
	if ui.has_method("set_culture"):
		ui.call("set_culture", culture_code)

func _configure_bgm() -> void:
	if bgm == null or bgm.stream == null:
		return

	# Ensure loop for BGM even if import settings change.
	if _object_has_property(bgm.stream, "loop"):
		bgm.stream.set("loop", true)
	else:
		bgm.finished.connect(func() -> void:
			bgm.play()
		)

func _object_has_property(obj: Object, property_name: String) -> bool:
	for p in obj.get_property_list():
		if p.has("name") and String(p["name"]) == property_name:
			return true
	return false

func _init_profiles() -> void:
	_available_profile_indices.clear()
	_profile_index_by_model_path.clear()
	for i in range(MODEL_PATHS.size()):
		_available_profile_indices.append(i)
		_profile_index_by_model_path[MODEL_PATHS[i]] = i

func _apply_ui_state() -> void:
	if ui == null:
		return
	if ui.has_method("set_can_add"):
		ui.call("set_can_add", _available_profile_indices.size() > 0)
	if ui.has_method("set_status_text"):
		ui.call("set_status_text", "")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_try_select_from_click(mb.position)

func add_npc() -> Node:
	if _available_profile_indices.is_empty():
		if ui != null and ui.has_method("set_status_text"):
			ui.call("set_status_text", "Reached max NPCs (%d). Remove one to add more." % MAX_NPCS)
		return null

	_npc_counter += 1
	var npc := npc_scene.instantiate()
	if npc == null:
		return null

	var npc_id := "npc_%d" % _npc_counter
	npc.name = npc_id

	# Spawn within a rectangle on XZ.
	var x := randf_range(-spawn_extent.x, spawn_extent.x)
	var z := randf_range(-spawn_extent.y, spawn_extent.y)
	npc.position = Vector3(x, npc_spawn_y, z)

	var profile_index := _take_random_profile_index()
	if profile_index < 0:
		return null

	# Default NPC scene supports these properties.
	npc.set("npc_id", npc_id)
	npc.set("model_path", MODEL_PATHS[profile_index])
	npc.set("display_name", _name_for_profile(profile_index))
	npc.set("wander_bounds", Rect2(Vector2(-spawn_extent.x, -spawn_extent.y), Vector2(spawn_extent.x * 2.0, spawn_extent.y * 2.0)))

	npc_root.add_child(npc)
	select_npc(npc)
	_apply_ui_state()
	return npc

func remove_selected() -> void:
	if _selected_npc == null or not is_instance_valid(_selected_npc):
		return

	var to_remove := _selected_npc
	var model_path := ""
	if to_remove.has_method("get") and to_remove.get("model_path") != null:
		model_path = String(to_remove.get("model_path"))
	_return_profile_for_model(model_path)

	select_npc(null)
	to_remove.queue_free()
	_apply_ui_state()

func select_npc(npc: Node) -> void:
	if _selected_npc != null and is_instance_valid(_selected_npc) and _selected_npc.has_method("set_selected"):
		_selected_npc.call("set_selected", false)

	_selected_npc = npc

	if _selected_npc != null and is_instance_valid(_selected_npc) and _selected_npc.has_method("set_selected"):
		_selected_npc.call("set_selected", true)

	if _selected_npc == null:
		ui.call("set_selected_text", "")
	else:
		var label := _selected_npc.name
		if _selected_npc.has_method("get_display_name"):
			label = _selected_npc.call("get_display_name")
		ui.call("set_selected_text", label)
	if ui.has_method("set_status_text"):
		ui.call("set_status_text", "")

func set_culture(code: String) -> void:
	if not CULTURE_NAMES.has(code):
		return
	culture_code = code
	_update_all_npc_names()
	if ui.has_method("set_status_text"):
		ui.call("set_status_text", "")

func _update_all_npc_names() -> void:
	for n in get_tree().get_nodes_in_group("vr_offices_npc"):
		if n == null or not (n is Node):
			continue
		var node := n as Node
		if not node.has_method("get"):
			continue
		var mp := String(node.get("model_path"))
		var idx := _profile_index_for_model(mp)
		if idx >= 0:
			node.set("display_name", _name_for_profile(idx))
	# Refresh selected label.
	if _selected_npc != null and is_instance_valid(_selected_npc):
		select_npc(_selected_npc)

func _try_select_from_click(screen_pos: Vector2) -> void:
	var cam: Camera3D = null
	if camera_rig != null and camera_rig.has_method("get_camera"):
		cam = camera_rig.call("get_camera") as Camera3D
	else:
		cam = get_viewport().get_camera_3d()

	if cam == null:
		return

	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * 200.0

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = 2

	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		select_npc(null)
		return

	var collider: Object = hit.get("collider") as Object
	var npc := _find_npc_owner(collider)
	select_npc(npc)

func _find_npc_owner(node: Object) -> Node:
	var cur := node
	while cur != null and cur is Node:
		var n := cur as Node
		if n.is_in_group("vr_offices_npc"):
			return n
		cur = n.get_parent()
	return null

func _take_random_profile_index() -> int:
	if _available_profile_indices.is_empty():
		return -1
	var k := randi_range(0, _available_profile_indices.size() - 1)
	var idx := _available_profile_indices[k]
	_available_profile_indices.remove_at(k)
	return idx

func _return_profile_for_model(model_path: String) -> void:
	var idx := _profile_index_for_model(model_path)
	if idx < 0:
		return
	if _available_profile_indices.has(idx):
		return
	_available_profile_indices.append(idx)

func _profile_index_for_model(model_path: String) -> int:
	if _profile_index_by_model_path.has(model_path):
		return int(_profile_index_by_model_path[model_path])
	return -1

func _name_for_profile(profile_index: int) -> String:
	var names: Array = CULTURE_NAMES.get(culture_code, CULTURE_NAMES.get("en-US", []))
	if profile_index >= 0 and profile_index < names.size():
		return String(names[profile_index])
	return "NPC %d" % (profile_index + 1)
