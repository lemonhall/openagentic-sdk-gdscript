extends CharacterBody3D

@export var npc_id: String = ""
@export_file("*.glb") var model_path: String = ""

@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float

@export var wander_enabled := true
@export_range(0.0, 5.0, 0.05) var wander_speed := 0.9
@export_range(0.1, 5.0, 0.1) var wander_target_radius := 0.35
@export var wander_pause_range := Vector2(0.5, 2.0) # seconds
@export_range(0.0, 20.0, 0.1) var turn_speed := 8.0

# X = world X, Y = world Z.
@export var wander_bounds := Rect2(Vector2(-6.0, -4.0), Vector2(12.0, 8.0))

@onready var model_root: Node3D = $ModelRoot
@onready var selection_ring: Node3D = $SelectionRing

var _wander_target_xz := Vector2.ZERO
var _wander_pause_left := 0.0

var _anim_player: AnimationPlayer = null
var _anim_idle: StringName = &""
var _anim_walk: StringName = &""
var _anim_current: StringName = &""

func _ready() -> void:
	add_to_group("vr_offices_npc")
	_load_model()
	_pick_new_wander_target()

func _physics_process(delta: float) -> void:
	_update_wander(delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = minf(0.0, velocity.y)
	move_and_slide()

func set_selected(is_selected: bool) -> void:
	selection_ring.visible = is_selected

func set_wander_bounds(bounds: Rect2) -> void:
	wander_bounds = bounds
	_pick_new_wander_target()

func _load_model() -> void:
	for child in model_root.get_children():
		child.queue_free()

	if model_path.strip_edges() != "":
		var res := load(model_path)
		if res is PackedScene:
			var inst := (res as PackedScene).instantiate()
			if inst != null:
				model_root.add_child(inst)
				_autoplay_animation(inst)
				return

	# Fallback: a simple capsule mesh so the scene still works without imported assets.
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.25
	mesh.height = 1.1
	mi.mesh = mesh
	model_root.add_child(mi)

func _autoplay_animation(root: Node) -> void:
	# Kenney Mini Characters 1 includes animations embedded in the model files.
	# Imported scenes usually contain an AnimationPlayer, but nothing plays by default.
	var players := root.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return

	_anim_player = players[0] as AnimationPlayer
	var anims := _anim_player.get_animation_list()
	if anims.is_empty():
		return

	_anim_idle = _pick_named_animation(anims, "idle")
	_anim_walk = _pick_named_animation(anims, "walk")

	var chosen := _anim_idle if _anim_idle != &"" else _pick_animation(anims)
	_play_anim(chosen)

func _pick_animation(names: PackedStringArray) -> StringName:
	var best_idle := ""
	var best_walk := ""
	for n in names:
		var lower := String(n).to_lower()
		if best_idle == "" and lower.find("idle") != -1:
			best_idle = String(n)
		if best_walk == "" and lower.find("walk") != -1:
			best_walk = String(n)
	if best_idle != "":
		return StringName(best_idle)
	if best_walk != "":
		return StringName(best_walk)
	return StringName(names[0])

func _pick_named_animation(names: PackedStringArray, contains: String) -> StringName:
	for n in names:
		if String(n).to_lower().find(contains) != -1:
			return StringName(n)
	return &""

func _play_anim(name: StringName) -> void:
	if _anim_player == null or name == &"":
		return
	if _anim_current == name:
		return
	_anim_current = name
	_anim_player.play(name)

func _update_wander(delta: float) -> void:
	if not wander_enabled:
		velocity.x = 0.0
		velocity.z = 0.0
		_play_anim(_anim_idle)
		return

	# Only wander when standing on the floor (keeps behavior predictable with gravity).
	if not is_on_floor():
		return

	if _wander_pause_left > 0.0:
		_wander_pause_left = maxf(0.0, _wander_pause_left - delta)
		velocity.x = move_toward(velocity.x, 0.0, wander_speed * 3.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, wander_speed * 3.0 * delta)
		_play_anim(_anim_idle)
		return

	var pos_xz := Vector2(global_position.x, global_position.z)
	var to_target := _wander_target_xz - pos_xz
	if to_target.length() <= wander_target_radius:
		_wander_pause_left = randf_range(wander_pause_range.x, wander_pause_range.y)
		_pick_new_wander_target()
		return

	var dir := to_target.normalized()
	velocity.x = dir.x * wander_speed
	velocity.z = dir.y * wander_speed
	_play_anim(_anim_walk if _anim_walk != &"" else _anim_idle)

	if turn_speed > 0.0:
		var target_yaw := atan2(-dir.x, -dir.y) # faces -Z by default
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))

func _pick_new_wander_target() -> void:
	# Stay inside bounds to avoid walking off the floor.
	var x := randf_range(wander_bounds.position.x, wander_bounds.position.x + wander_bounds.size.x)
	var z := randf_range(wander_bounds.position.y, wander_bounds.position.y + wander_bounds.size.y)
	_wander_target_xz = Vector2(x, z)
