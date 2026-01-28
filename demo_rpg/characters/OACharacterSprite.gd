extends Sprite2D

@export var cell_size_px: int = 16
@export var margin_px: int = 1

@export var scale_factor: float = 2.0

# Tile coordinates in the spritesheet grid (16x16 tiles with 1px margin).
@export var base_cell: Vector2i = Vector2i(0, 0)
@export var alt_cell: Vector2i = Vector2i(1, 0)
@export var use_alt_for_walk: bool = true

@export var bob_enabled: bool = false
@export var bob_distance_px: float = 1.0

@export var anim_fps: float = 6.0

var _walking: bool = false
var _frame: int = 0
var _accum: float = 0.0
var _base_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	_base_pos = position
	init_visual()

func init_visual() -> void:
	if texture == null:
		return
	centered = true
	region_enabled = true
	scale = Vector2(scale_factor, scale_factor)
	_apply_cell(base_cell)

func set_move_dir(v: Vector2) -> void:
	if v.length() <= 0.0001:
		return
	# This pack doesn't ship a full 4-dir animated set; we still keep
	# direction semantics for gameplay and future asset swaps.
	if abs(v.x) > abs(v.y):
		flip_h = v.x < 0.0
		return
	# Up/down: keep flip as-is.

func set_walking(b: bool) -> void:
	if _walking == b:
		return
	_walking = b
	_accum = 0.0
	_frame = 0
	position = _base_pos
	_apply_cell(base_cell)

func tick(delta: float) -> void:
	if not _walking:
		return
	if anim_fps <= 0.0:
		return

	_accum += delta
	var step := 1.0 / anim_fps
	if _accum < step:
		return
	_accum = fmod(_accum, step)

	_frame = (_frame + 1) % 2
	if use_alt_for_walk and alt_cell.x >= 0 and alt_cell.y >= 0:
		_apply_cell(alt_cell if _frame == 1 else base_cell)

	if bob_enabled:
		position = _base_pos + Vector2(0.0, (-bob_distance_px if _frame == 1 else 0.0))

func _process(delta: float) -> void:
	tick(delta)

func _apply_cell(cell: Vector2i) -> void:
	var stride := cell_size_px + margin_px
	region_rect = Rect2(cell.x * stride, cell.y * stride, cell_size_px, cell_size_px)

