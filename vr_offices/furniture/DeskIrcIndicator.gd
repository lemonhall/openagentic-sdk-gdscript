extends Node3D

var _link: Node = null
var _status: String = ""
var _link_ready := false
var _error_flash_until_ms := 0

var _mat: StandardMaterial3D = null

@onready var _top: MeshInstance3D = get_node_or_null("Top") as MeshInstance3D
@onready var _bottom: MeshInstance3D = get_node_or_null("Bottom") as MeshInstance3D

func _ready() -> void:
	_setup_material()
	var p := get_parent()
	if p != null and p is Node:
		var pn := p as Node
		pn.child_entered_tree.connect(_on_parent_child_entered_tree)
		pn.child_exiting_tree.connect(_on_parent_child_exiting_tree)
	_try_bind()
	_update(false)

func set_suspended(suspended: bool) -> void:
	visible = not suspended

func _process(_dt: float) -> void:
	if _error_flash_until_ms == 0:
		return
	if Time.get_ticks_msec() >= _error_flash_until_ms:
		_error_flash_until_ms = 0
		_update(false)

func _on_parent_child_entered_tree(child: Node) -> void:
	if child != null and child.name == "DeskIrcLink":
		_try_bind()

func _on_parent_child_exiting_tree(child: Node) -> void:
	if _link != null and child == _link:
		_unbind()
		_update(false)

func _try_bind() -> void:
	var p := get_parent()
	if p == null or not (p is Node):
		return
	var link := (p as Node).get_node_or_null("DeskIrcLink") as Node
	if link == null or not is_instance_valid(link):
		return
	if _link == link:
		return
	_unbind()
	_link = link

	var on_status := Callable(self, "_on_status_changed")
	var on_ready := Callable(self, "_on_ready_changed")
	var on_err := Callable(self, "_on_error")
	if _link.has_signal("status_changed"):
		_link.connect("status_changed", on_status)
	if _link.has_signal("ready_changed"):
		_link.connect("ready_changed", on_ready)
	if _link.has_signal("error"):
		_link.connect("error", on_err)

	if _link.has_method("get_status"):
		_status = String(_link.call("get_status"))
	if _link.has_method("is_ready"):
		_link_ready = bool(_link.call("is_ready"))
	_update(false)

func _unbind() -> void:
	if _link == null or not is_instance_valid(_link):
		_link = null
		_status = ""
		_link_ready = false
		return
	var on_status := Callable(self, "_on_status_changed")
	var on_ready := Callable(self, "_on_ready_changed")
	var on_err := Callable(self, "_on_error")
	if _link.has_signal("status_changed") and _link.is_connected("status_changed", on_status):
		_link.disconnect("status_changed", on_status)
	if _link.has_signal("ready_changed") and _link.is_connected("ready_changed", on_ready):
		_link.disconnect("ready_changed", on_ready)
	if _link.has_signal("error") and _link.is_connected("error", on_err):
		_link.disconnect("error", on_err)
	_link = null
	_status = ""
	_link_ready = false

func _on_status_changed(status: String) -> void:
	_status = status
	_update(false)

func _on_ready_changed(ready: bool) -> void:
	_link_ready = ready
	_update(false)

func _on_error(_msg: String) -> void:
	_error_flash_until_ms = Time.get_ticks_msec() + 2500
	_update(true)

func _setup_material() -> void:
	if _top == null or _bottom == null:
		return
	var m0 := _top.material_override as StandardMaterial3D
	_mat = m0.duplicate() if m0 != null else StandardMaterial3D.new()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.emission_enabled = true
	_mat.emission_energy_multiplier = 1.35
	_top.material_override = _mat
	_bottom.material_override = _mat

func _update(force_error: bool) -> void:
	if _mat == null:
		return
	var c := Color(0.85, 0.85, 0.85, 0.85) # default: disabled/unknown (still visible)
	if _link != null and is_instance_valid(_link):
		c = Color(1.0, 0.85, 0.20, 0.85) # connecting-ish
		if _link_ready:
			c = Color(0.15, 1.0, 0.25, 0.85)
		elif _status.find("disconnected") != -1:
			c = Color(1.0, 0.20, 0.20, 0.85)

	var flash := force_error or (_error_flash_until_ms != 0 and Time.get_ticks_msec() < _error_flash_until_ms)
	if flash:
		c = Color(1.0, 0.15, 0.20, 0.95)

	_mat.albedo_color = c
	_mat.emission = Color(c.r, c.g, c.b, 1.0)
