extends CharacterBody2D

@export var speed: float = 140.0

var _enabled: bool = true
@onready var _visual: Node = get_node_or_null("Visual")

func set_enabled(b: bool) -> void:
	_enabled = b
	if not _enabled:
		velocity = Vector2.ZERO
		if _visual != null and _visual.has_method("set_walking"):
			_visual.set_walking(false)

func _ready() -> void:
	add_to_group("openagentic_player")

func _physics_process(_dt: float) -> void:
	if not _enabled:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = dir * speed
	move_and_slide()

	if _visual != null:
		if _visual.has_method("set_move_dir"):
			_visual.set_move_dir(dir)
		if _visual.has_method("set_walking"):
			_visual.set_walking(dir.length() > 0.01)
