extends CharacterBody2D

@export var speed: float = 140.0

var _enabled: bool = true

func set_enabled(b: bool) -> void:
	_enabled = b
	if not _enabled:
		velocity = Vector2.ZERO

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
