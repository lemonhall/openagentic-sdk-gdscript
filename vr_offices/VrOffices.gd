extends Node3D

@export var npc_scene: PackedScene
@export var npc_spawn_y := 2.0
@export var spawn_extent := Vector2(6.0, 4.0) # X,Z half extents

@onready var npc_root: Node3D = $NpcRoot
@onready var camera_rig: Node3D = $CameraRig
@onready var ui: Control = $UI/VrOfficesUi

var _npc_counter := 0
var _selected_npc: Node = null

var _model_paths: Array[String] = [
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

func _ready() -> void:
	if npc_scene == null:
		npc_scene = preload("res://vr_offices/npc/Npc.tscn")

	ui.add_npc_pressed.connect(add_npc)
	ui.remove_selected_pressed.connect(remove_selected)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_try_select_from_click(mb.position)

func add_npc() -> Node:
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

	# Default NPC scene supports these properties.
	npc.set("npc_id", npc_id)
	npc.set("model_path", _model_paths[(_npc_counter - 1) % _model_paths.size()])

	npc_root.add_child(npc)
	select_npc(npc)
	return npc

func remove_selected() -> void:
	if _selected_npc == null or not is_instance_valid(_selected_npc):
		return
	var to_remove := _selected_npc
	select_npc(null)
	to_remove.queue_free()

func select_npc(npc: Node) -> void:
	if _selected_npc != null and is_instance_valid(_selected_npc) and _selected_npc.has_method("set_selected"):
		_selected_npc.call("set_selected", false)

	_selected_npc = npc

	if _selected_npc != null and is_instance_valid(_selected_npc) and _selected_npc.has_method("set_selected"):
		_selected_npc.call("set_selected", true)

	if _selected_npc == null:
		ui.call("set_selected_text", "")
	else:
		ui.call("set_selected_text", _selected_npc.name)

func _try_select_from_click(screen_pos: Vector2) -> void:
	var cam: Camera3D = null
	if camera_rig != null and camera_rig.has_method("get_camera"):
		cam = camera_rig.call("get_camera")
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

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		select_npc(null)
		return

	var collider := hit.get("collider")
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
