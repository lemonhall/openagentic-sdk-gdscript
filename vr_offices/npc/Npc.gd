extends CharacterBody3D

@export var npc_id: String = ""
@export var display_name: String = ""
@export_file("*.glb") var model_path: String = ""
@export var load_model_on_ready := true

@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float

@export var wander_enabled := true
@export_range(0.0, 5.0, 0.05) var wander_speed := 0.9
@export_range(0.1, 5.0, 0.1) var wander_target_radius := 0.35
@export var wander_pause_range := Vector2(0.5, 2.0) # seconds
@export_range(0.0, 20.0, 0.1) var turn_speed := 8.0
@export_range(-PI, PI, 0.01) var model_yaw_offset := PI

# X = world X, Y = world Z.
@export var wander_bounds := Rect2(Vector2(-6.0, -4.0), Vector2(12.0, 8.0))

@onready var model_root: Node3D = $ModelRoot
@onready var selection_plumbob: Node3D = $SelectionPlumbob

var _wander_target_xz := Vector2.ZERO
var _wander_pause_left := 0.0

var _select_time := 0.0
var _plumbob_base_y := 0.0
var _plumbob_base_rot_y := 0.0

var _anim_player: AnimationPlayer = null
var _anim_idle: StringName = &""
var _anim_walk: StringName = &""
var _anim_current: StringName = &""
var _override_anim: StringName = &""
var _override_left := 0.0
var _wander_enabled_before_override := true
var _in_dialogue := false
var _wander_enabled_before_dialogue := true

func _ready() -> void:
	add_to_group("vr_offices_npc")
	if load_model_on_ready:
		_load_model()
	else:
		_load_placeholder()
	_pick_new_wander_target()
	if selection_plumbob != null:
		_plumbob_base_y = selection_plumbob.position.y
		_plumbob_base_rot_y = selection_plumbob.rotation.y

func _physics_process(delta: float) -> void:
	_update_wander(delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = minf(0.0, velocity.y)
	move_and_slide()

func _process(delta: float) -> void:
	if selection_plumbob == null or not selection_plumbob.visible:
		return
	_select_time += delta
	selection_plumbob.position.y = _plumbob_base_y + sin(_select_time * 2.0) * 0.08
	selection_plumbob.rotation.y = _plumbob_base_rot_y + _select_time * 1.2

func set_selected(is_selected: bool) -> void:
	selection_plumbob.visible = is_selected
	if is_selected:
		_select_time = 0.0

func get_display_name() -> String:
	if display_name.strip_edges() != "":
		return display_name
	return npc_id if npc_id.strip_edges() != "" else name

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

func _load_placeholder() -> void:
	for child in model_root.get_children():
		child.queue_free()
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
	_ensure_loop(_anim_idle)
	_ensure_loop(_anim_walk)

	var chosen := _anim_idle if _anim_idle != &"" else _pick_animation(anims)
	_play_anim(chosen)

func play_animation_once(name: String, duration: float = 0.7, lock_wander: bool = true) -> void:
	if name.strip_edges() == "":
		return
	if duration <= 0.0:
		duration = 0.1
	var anim_name := _pick_named_animation(_anim_player.get_animation_list(), name.to_lower()) if _anim_player != null else &""
	if anim_name == &"":
		# Fallback: the caller may have passed an exact name with different casing.
		anim_name = StringName(name)
	_start_override_animation(anim_name, duration, lock_wander)

func stop_override_animation() -> void:
	if _override_left <= 0.0 and _override_anim == &"":
		return
	_override_left = 0.0
	_override_anim = &""
	wander_enabled = _wander_enabled_before_override
	_play_anim(_anim_idle)

func play_turn_start_animation() -> void:
	# A simple default "talk" gesture for the office prototype.
	play_animation_once("interact-right", 0.7, true)

func play_turn_end_animation() -> void:
	stop_override_animation()

func _start_override_animation(anim: StringName, duration: float, lock_wander: bool) -> void:
	if _anim_player == null:
		return
	if lock_wander and _override_left <= 0.0:
		_wander_enabled_before_override = wander_enabled
		wander_enabled = false
	_override_anim = anim
	_override_left = duration
	_play_anim(_override_anim if _override_anim != &"" else _anim_idle)

func enter_dialogue(face_target: Vector3) -> void:
	if _in_dialogue:
		return
	_in_dialogue = true
	_wander_enabled_before_dialogue = wander_enabled
	wander_enabled = false
	_wander_pause_left = 0.0
	stop_override_animation()
	_face_towards(face_target)
	_play_anim(_anim_idle)

func exit_dialogue() -> void:
	if not _in_dialogue:
		return
	_in_dialogue = false
	stop_override_animation()
	wander_enabled = _wander_enabled_before_dialogue
	if wander_enabled:
		_wander_pause_left = 0.0
		_pick_new_wander_target()
	_play_anim(_anim_idle)

func _face_towards(target: Vector3) -> void:
	var dx := target.x - global_position.x
	var dz := target.z - global_position.z
	var to_target := Vector2(dx, dz)
	if to_target.length() < 0.001:
		return
	var dir := to_target.normalized()
	var target_yaw := atan2(-dir.x, -dir.y) + model_yaw_offset
	rotation.y = target_yaw

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
	_ensure_loop(name)
	if _anim_current == name:
		return
	_anim_current = name
	_anim_player.play(name)

func _ensure_loop(name: StringName) -> void:
	if _anim_player == null or name == &"":
		return
	var anim := _anim_player.get_animation(name)
	if anim == null:
		return
	# Imported Kenney animations may not be set to loop by default; ensure idle/walk loop.
	if anim.loop_mode == Animation.LOOP_NONE:
		anim.loop_mode = Animation.LOOP_LINEAR

func _update_wander(delta: float) -> void:
	# Override animation: keep the NPC still and play the requested clip.
	if _override_left > 0.0:
		_override_left = maxf(0.0, _override_left - delta)
		velocity.x = move_toward(velocity.x, 0.0, wander_speed * 3.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, wander_speed * 3.0 * delta)
		_play_anim(_override_anim if _override_anim != &"" else _anim_idle)
		if _override_left <= 0.0:
			stop_override_animation()
		return

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
		# Godot faces -Z by default, but many imported models visually face +Z.
		# `model_yaw_offset` corrects that (Kenney Mini Characters look correct with PI).
		var target_yaw := atan2(-dir.x, -dir.y) + model_yaw_offset
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))

func _pick_new_wander_target() -> void:
	# Stay inside bounds to avoid walking off the floor.
	var x := randf_range(wander_bounds.position.x, wander_bounds.position.x + wander_bounds.size.x)
	var z := randf_range(wander_bounds.position.y, wander_bounds.position.y + wander_bounds.size.y)
	_wander_target_xz = Vector2(x, z)
