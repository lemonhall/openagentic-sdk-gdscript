extends RefCounted

var _root: Node3D = null
var _model: Node3D = null

func ensure(owner: Node, standing_desk_scene: PackedScene) -> void:
	if owner == null:
		return
	if _root != null and is_instance_valid(_root):
		return
	_root = Node3D.new()
	_root.name = "DeskPreview"
	_root.position = Vector3(0, 0.0, 0)
	owner.add_child(_root)

	if standing_desk_scene == null:
		return
	var ghost0 := standing_desk_scene.instantiate()
	var ghost := ghost0 as Node3D
	if ghost == null:
		return
	ghost.name = "GhostStandingDesk"
	ghost.process_mode = Node.PROCESS_MODE_DISABLED
	_root.add_child(ghost)
	if ghost.has_method("ensure_centered"):
		ghost.call("ensure_centered")
	if ghost.has_method("set_preview"):
		ghost.call("set_preview", true)
	_model = ghost

func free() -> void:
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null
	_model = null

func set_state(center_xz: Vector2, yaw: float, valid: bool) -> void:
	if _root == null or not is_instance_valid(_root):
		return
	_root.position = Vector3(center_xz.x, 0.0, center_xz.y)
	if _model != null and is_instance_valid(_model):
		_model.rotation = Vector3(0.0, yaw, 0.0)
		if _model.has_method("set_preview_valid"):
			_model.call("set_preview_valid", valid)

