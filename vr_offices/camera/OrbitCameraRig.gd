extends Node3D

@export var rotate_button: MouseButton = MOUSE_BUTTON_RIGHT
@export var pan_button: MouseButton = MOUSE_BUTTON_MIDDLE
@export var controls_enabled := true

@export_range(0.001, 0.05, 0.001) var rotate_sensitivity := 0.01
@export_range(0.1, 5.0, 0.1) var zoom_step := 0.75
@export_range(2.0, 50.0, 0.5) var min_distance := 4.0
@export_range(2.0, 80.0, 0.5) var max_distance := 25.0

@export_range(-1.55, -0.01, 0.01) var min_pitch := deg_to_rad(-85.0)
@export_range(-1.55, -0.01, 0.01) var max_pitch := deg_to_rad(-20.0)

@onready var pivot: Node3D = $Pivot
@onready var camera: Camera3D = $Pivot/Camera3D

var _yaw := deg_to_rad(45.0)
var _pitch := deg_to_rad(-45.0)
var _distance := 12.0

var _rotating := false
var _panning := false

func _ready() -> void:
	_apply_transform()
	camera.current = true

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		_rotating = false
		_panning = false
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == rotate_button:
			_rotating = mb.pressed
		elif mb.button_index == pan_button:
			_panning = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = clampf(_distance - zoom_step, min_distance, max_distance)
			_apply_transform()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = clampf(_distance + zoom_step, min_distance, max_distance)
			_apply_transform()

	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _rotating:
			_yaw -= mm.relative.x * rotate_sensitivity
			_pitch -= mm.relative.y * rotate_sensitivity
			_pitch = clampf(_pitch, min_pitch, max_pitch)
			_apply_transform()
		elif _panning:
			_pan(mm.relative)

func _pan(delta_pixels: Vector2) -> void:
	# Screen-space pan mapped onto XZ plane.
	var scale := _distance * 0.002
	var right := -pivot.global_transform.basis.x
	var forward := -pivot.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	global_position += (right * delta_pixels.x + forward * delta_pixels.y) * scale

func _apply_transform() -> void:
	pivot.rotation = Vector3(_pitch, _yaw, 0.0)
	camera.position = Vector3(0.0, 0.0, _distance)

func get_camera() -> Camera3D:
	return camera

func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if not enabled:
		_rotating = false
		_panning = false
