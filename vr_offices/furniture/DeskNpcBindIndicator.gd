extends Node3D

@export var unbound_color: Color = Color(1.0, 0.92, 0.45, 0.85)
@export var bound_color: Color = Color(0.15, 1.0, 0.25, 0.85)

var _bound_npc_id: String = ""
var _bound_npc: Node = null

var _suspended := false

@onready var _area: Area3D = get_node_or_null("Area") as Area3D
@onready var _visual: Node = get_node_or_null("Visual") as Node

func _ready() -> void:
	_connect_area()
	_update_visual()

func set_suspended(suspended: bool) -> void:
	_suspended = suspended
	visible = not suspended
	if suspended:
		_bound_npc_id = ""
		_bound_npc = null
	_update_visual()

func get_bound_npc_id() -> String:
	return _bound_npc_id

func get_bound_npc_name() -> String:
	if _bound_npc == null or not is_instance_valid(_bound_npc):
		return ""
	if _bound_npc.has_method("get_display_name"):
		return String(_bound_npc.call("get_display_name")).strip_edges()
	if _bound_npc.has_method("get"):
		var v: Variant = _bound_npc.get("display_name")
		if v != null and String(v).strip_edges() != "":
			return String(v).strip_edges()
		v = _bound_npc.get("npc_id")
		if v != null and String(v).strip_edges() != "":
			return String(v).strip_edges()
	return String(_bound_npc.name).strip_edges()

func is_suspended() -> bool:
	return _suspended

func _connect_area() -> void:
	if _area == null:
		return
	if not _area.body_entered.is_connected(_on_area_body_entered):
		_area.body_entered.connect(_on_area_body_entered)
	if not _area.body_exited.is_connected(_on_area_body_exited):
		_area.body_exited.connect(_on_area_body_exited)

func _on_area_body_entered(body: Node) -> void:
	if _suspended:
		return
	if body == null or not is_instance_valid(body):
		return
	if not body.is_in_group("vr_offices_npc"):
		return

	var nid := _npc_id_for(body)
	if nid == "":
		return

	if _bound_npc_id != "" and _bound_npc_id != nid:
		# Desk already bound to another NPC; do not steal binding.
		return

	_bound_npc_id = nid
	_bound_npc = body
	if body.has_method("on_desk_bound"):
		body.call("on_desk_bound", _desk_id())
	_update_visual()

func _on_area_body_exited(body: Node) -> void:
	if body == null or not is_instance_valid(body):
		return
	var nid := _npc_id_for(body)
	if nid == "" or nid != _bound_npc_id:
		return

	_bound_npc_id = ""
	_bound_npc = null
	if body.has_method("on_desk_unbound"):
		body.call("on_desk_unbound", _desk_id())
	_update_visual()

func _update_visual() -> void:
	if _visual == null:
		return
	var c := unbound_color if _bound_npc_id == "" else bound_color
	if _visual.has_method("set"):
		_visual.set("color", c)

func _desk_id() -> String:
	var p := get_parent() as Node
	if p == null:
		return ""
	if p.has_method("get"):
		var v: Variant = p.get("desk_id")
		if v != null and String(v).strip_edges() != "":
			return String(v).strip_edges()
	return String(p.name)

func _npc_id_for(npc: Node) -> String:
	if npc == null:
		return ""
	if npc.has_method("get"):
		var v: Variant = npc.get("npc_id")
		if v != null and String(v).strip_edges() != "":
			return String(v).strip_edges()
	return String(npc.name)
