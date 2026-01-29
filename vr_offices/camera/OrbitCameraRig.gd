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
var _tween: Tween = null

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

func get_state() -> Dictionary:
	return {
		"position": global_position,
		"yaw": _yaw,
		"pitch": _pitch,
		"distance": _distance,
	}

func apply_state(state: Dictionary) -> void:
	if state.has("position"):
		global_position = state.get("position", global_position)
	if state.has("yaw"):
		_yaw = float(state.get("yaw", _yaw))
	if state.has("pitch"):
		_pitch = float(state.get("pitch", _pitch))
		_pitch = clampf(_pitch, min_pitch, max_pitch)
	if state.has("distance"):
		_distance = float(state.get("distance", _distance))
		_distance = clampf(_distance, min_distance, max_distance)
	_apply_transform()

func tween_to_state(state: Dictionary, duration: float = 0.25) -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	if duration <= 0.0:
		apply_state(state)
		return

	var target_pos := global_position
	var target_yaw := _yaw
	var target_pitch := _pitch
	var target_dist := _distance
	if state.has("position"):
		target_pos = state.get("position", target_pos)
	if state.has("yaw"):
		target_yaw = float(state.get("yaw", target_yaw))
	if state.has("pitch"):
		target_pitch = float(state.get("pitch", target_pitch))
		target_pitch = clampf(target_pitch, min_pitch, max_pitch)
	if state.has("distance"):
		target_dist = float(state.get("distance", target_dist))
		target_dist = clampf(target_dist, min_distance, max_distance)

	target_yaw = _short_angle_target(_yaw, target_yaw)

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_parallel(true)

	_tween.tween_property(self, "global_position", target_pos, duration)
	_tween.tween_method(Callable(self, "_set_yaw"), _yaw, target_yaw, duration)
	_tween.tween_method(Callable(self, "_set_pitch"), _pitch, target_pitch, duration)
	_tween.tween_method(Callable(self, "_set_distance"), _distance, target_dist, duration)

func focus_on(target_pos: Vector3, yaw: float, pitch: float, distance: float, duration: float = 0.25) -> void:
	tween_to_state({
		"position": target_pos,
		"yaw": yaw,
		"pitch": pitch,
		"distance": distance,
	}, duration)

func _short_angle_target(current: float, target: float) -> float:
	return current + wrapf(target - current, -PI, PI)

func _set_yaw(v: float) -> void:
	_yaw = v
	_apply_transform()

func _set_pitch(v: float) -> void:
	_pitch = clampf(v, min_pitch, max_pitch)
	_apply_transform()

func _set_distance(v: float) -> void:
	_distance = clampf(v, min_distance, max_distance)
	_apply_transform()
