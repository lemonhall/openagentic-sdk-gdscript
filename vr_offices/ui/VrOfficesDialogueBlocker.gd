extends Control

@export var overlays: Array[NodePath] = []

var _targets: Array[Control] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_targets = []
	for p in overlays:
		var c := get_node_or_null(p) as Control
		if c != null:
			_targets.append(c)
			if c.has_signal("visibility_changed"):
				c.visibility_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	visible = _active_overlay() != null

func close() -> void:
	var a := _active_overlay()
	if a == null:
		return
	if a.has_method("close"):
		a.call("close")
	else:
		a.visible = false
	_refresh()

func get_embedded_dialogue() -> Control:
	var a := _active_overlay()
	if a == null:
		return null
	if a.has_method("get_embedded_dialogue"):
		return a.call("get_embedded_dialogue") as Control
	return a

func _active_overlay() -> Control:
	for c0 in _targets:
		var c := c0 as Control
		if c != null and c.visible:
			return c
	return null
