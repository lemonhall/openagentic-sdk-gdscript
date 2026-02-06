extends RefCounted

const _Props := preload("res://vr_offices/core/props/VrOfficesPropUtils.gd")
const _PickBodies := preload("res://vr_offices/core/props/VrOfficesPickBodyUtils.gd")
const _OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")

const MANAGER_DESK_SCENE := "res://assets/office_pack_glb/Desk-ISpMh81QGq.glb"
const MANAGER_NPC_SCENE := preload("res://vr_offices/npc/Npc.tscn")
const MANAGER_NPC_MODEL := "res://assets/kenney/mini-characters-1/character-male-d.glb"

const _MANAGER_DESK_WALL_INSET := 1.65
const _MANAGER_CHAIR_PULLBACK := 0.55
const _MANAGER_SEAT_Y := -1.05
const _MANAGER_SEAT_FORWARD := -0.2
const _MANAGER_NPC_EXTRA_FORWARD := 0.3

static func ensure_manager_defaults(decor: Node3D, workspace_id: String, hz: float) -> void:
	if decor == null:
		return

	var desk_wrapper := _ensure_child_node3d(decor, "ManagerDesk")
	_place_manager_desk(desk_wrapper, hz)

	var desk_model := _Props.spawn_floor_model(desk_wrapper, MANAGER_DESK_SCENE)
	_PickBodies.ensure_box_pick_body(desk_wrapper, "vr_offices_manager_desk", 32, Vector3(2.0, 1.3, 1.0), Vector3(0.0, 0.65, 0.0))
	var chair := _find_node_name_contains(desk_model, "chair") as Node3D if desk_model != null else null
	if chair != null:
		_pull_back_chair(desk_wrapper, chair)

	_ensure_manager_npc(decor, workspace_id, desk_wrapper, chair)

static func _ensure_child_node3d(parent: Node, name: String) -> Node3D:
	if parent == null:
		return null
	var existing := parent.get_node_or_null(name) as Node3D
	if existing != null:
		return existing
	var n := Node3D.new()
	n.name = name
	parent.add_child(n)
	return n

static func _place_manager_desk(n: Node3D, hz: float) -> void:
	if n == null:
		return
	var z := -maxf(0.0, hz - _MANAGER_DESK_WALL_INSET)
	n.position = Vector3(0.0, 0.0, z)
	n.rotation = Vector3.ZERO
	var xz := Vector2(float(n.position.x), float(n.position.z))
	if xz.length() >= 0.01:
		# Face the workspace center (no jitter for the default manager setup).
		n.rotation.y = atan2(xz.x, xz.y)

static func _dir_to_center_global(desk_wrapper: Node3D) -> Vector3:
	if desk_wrapper == null:
		return Vector3(0.0, 0.0, 1.0)
	var to_center_local := Vector3(-desk_wrapper.position.x, 0.0, -desk_wrapper.position.z)
	if to_center_local.length() <= 0.001:
		return Vector3(0.0, 0.0, 1.0)
	var parent := desk_wrapper.get_parent() as Node3D
	if parent != null:
		return (parent.global_transform.basis * to_center_local.normalized()).normalized()
	return to_center_local.normalized()

static func _pull_back_chair(desk_wrapper: Node3D, chair: Node3D) -> void:
	if desk_wrapper == null or chair == null:
		return
	var to_center := _dir_to_center_global(desk_wrapper)
	# Pull chair "back" relative to the desk: move away from the desk surface (typically toward the wall).
	var desk_to_chair := chair.global_position - desk_wrapper.global_position
	var dotv := float(desk_to_chair.dot(to_center))
	var s := -1.0 if dotv < 0.0 else 1.0
	chair.global_position += to_center * s * _MANAGER_CHAIR_PULLBACK

static func _ensure_manager_npc(decor: Node3D, workspace_id: String, desk_wrapper: Node3D, chair: Node3D) -> void:
	if decor == null or desk_wrapper == null:
		return
	var existing := decor.get_node_or_null("ManagerNpc") as Node
	if existing != null and is_instance_valid(existing):
		return
	if MANAGER_NPC_SCENE == null:
		return

	var npc0 := MANAGER_NPC_SCENE.instantiate()
	var npc := npc0 as Node
	if npc == null:
		return
	npc.name = "ManagerNpc"

	# Important: set exported properties BEFORE adding to the scene tree.
	# If we add first, `_ready()` may run with empty `model_path` and the NPC will keep the fallback capsule.
	if npc.has_method("set"):
		npc.set("npc_id", _OAPaths.workspace_manager_npc_id(workspace_id))
		npc.set("display_name", "经理")
		npc.set("model_path", MANAGER_NPC_MODEL)
		npc.set("stationary", true)
		npc.set("stationary_animation", "sit")
		if _Props.is_headless():
			npc.set("load_model_on_ready", false)
		else:
			npc.set("load_model_on_ready", true)

	decor.add_child(npc)
	# Safety: in case some external code toggles `load_model_on_ready`, try to load now.
	if npc.has_method("_load_model") and npc.has_method("get"):
		var l0: Variant = npc.get("load_model_on_ready")
		if l0 != null and bool(l0):
			npc.call("_load_model")

	var to_center := _dir_to_center_global(desk_wrapper)
	var seat := desk_wrapper.global_position + to_center * _MANAGER_SEAT_FORWARD + Vector3(0.0, _MANAGER_SEAT_Y, 0.0)
	if chair != null:
		seat = chair.global_position + to_center * _MANAGER_SEAT_FORWARD + Vector3(0.0, _MANAGER_SEAT_Y, 0.0)
	seat += to_center * _MANAGER_NPC_EXTRA_FORWARD

	if npc is Node3D:
		var n3 := npc as Node3D
		n3.global_position = seat
		var yaw := atan2(-to_center.x, -to_center.z) + PI
		n3.rotation.y = yaw

static func _find_node_name_contains(root: Node, needle: String) -> Node:
	if root == null:
		return null
	var want := needle.to_lower()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var cur := stack.pop_back() as Node
		if cur == null:
			continue
		if String(cur.name).to_lower().find(want) != -1:
			return cur
		for c0 in cur.get_children():
			var c := c0 as Node
			if c != null:
				stack.append(c)
	return null
