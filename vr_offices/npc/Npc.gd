extends CharacterBody3D

signal move_target_reached(npc_id: String, target: Vector3)

@export var npc_id: String = ""
@export var display_name: String = ""
@export_file("*.glb") var model_path: String = ""
@export var load_model_on_ready := true

@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float

@export var wander_enabled := true
@export_range(0.0, 5.0, 0.05) var wander_speed := 0.9
@export_range(0.0, 10.0, 0.05) var command_speed := 2.2
@export_range(0.1, 5.0, 0.1) var wander_target_radius := 0.35
@export var wander_pause_range := Vector2(0.5, 2.0) # seconds
@export_range(1.0, 600.0, 1.0) var waiting_for_work_seconds := 60.0
@export_range(0.0, 20.0, 0.1) var turn_speed := 8.0
@export_range(-PI, PI, 0.01) var model_yaw_offset := PI

# Stationary pose (used by workspace default “manager” NPCs).
@export var stationary := false
@export var stationary_animation: String = ""

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
var _anim_sprint: StringName = &""
var _anim_work: StringName = &""
var _anim_current: StringName = &""
var _override_anim: StringName = &""
var _override_left := 0.0
var _wander_enabled_before_override := true
var _in_dialogue := false
var _wander_enabled_before_dialogue := true
var _dialogue_face_node: Node3D = null
var _dialogue_face_pos: Vector3 = Vector3.ZERO

var _stationary_anim: StringName = &""

# Desk binding / work state.
var _desk_bound_id: String = ""
var _skip_wait_after_goto := false
var _meeting_bound_room_id: String = ""

# Right-click move command:
var _goto_target_xz := Vector2.ZERO
var _goto_active := false
var _waiting_for_work_left := 0.0 # “等待工作中倒计时”

func _ready() -> void:
	add_to_group("vr_offices_npc")
	if load_model_on_ready:
		_load_model()
	else:
		_load_placeholder()
	_pick_new_wander_target()
	if stationary:
		_apply_stationary_pose()
	if selection_plumbob != null:
		_plumbob_base_y = selection_plumbob.position.y
		_plumbob_base_rot_y = selection_plumbob.rotation.y

func _physics_process(delta: float) -> void:
	if stationary:
		# Stationary NPCs are allowed to float slightly (e.g. seated).
		velocity = Vector3.ZERO
		return
	_update_wander(delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = minf(0.0, velocity.y)
	move_and_slide()

func _process(delta: float) -> void:
	if _in_dialogue:
		var target := _dialogue_face_pos
		if _dialogue_face_node != null and is_instance_valid(_dialogue_face_node):
			target = _dialogue_face_node.global_position
		_face_towards(target)
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
	return npc_id if npc_id.strip_edges() != "" else String(name)

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
		else:
			var tname := "null" if res == null else String(res.get_class())
			push_warning("Npc: failed to load model_path=%s (got %s); using placeholder." % [model_path, tname])

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
	_anim_sprint = _pick_named_animation(anims, "sprint")
	_anim_work = _pick_named_animation(anims, "work")
	if _anim_work == &"":
		_anim_work = _pick_named_animation(anims, "typing")
	if _anim_work == &"":
		_anim_work = _pick_named_animation(anims, "interact-left")
	if _anim_work == &"":
		_anim_work = _pick_named_animation(anims, "interact-right")
	_ensure_loop(_anim_idle)
	_ensure_loop(_anim_walk)
	_ensure_loop(_anim_sprint)
	_ensure_loop(_anim_work)

	var chosen := _anim_idle if _anim_idle != &"" else _pick_animation(anims)
	_play_anim(chosen)

func get_bound_desk_id() -> String:
	return _desk_bound_id

func get_bound_meeting_room_id() -> String:
	return _meeting_bound_room_id

func on_desk_bound(desk_id: String) -> void:
	var did := desk_id.strip_edges()
	if did == "":
		return
	if _desk_bound_id == did:
		return
	_desk_bound_id = did
	_skip_wait_after_goto = false
	_goto_active = false
	_waiting_for_work_left = 0.0
	_wander_pause_left = 0.0
	stop_override_animation()
	wander_enabled = false
	velocity.x = 0.0
	velocity.z = 0.0
	_play_anim(_anim_work if _anim_work != &"" else _anim_idle)

func on_desk_unbound(desk_id: String) -> void:
	var did := desk_id.strip_edges()
	if did != "" and _desk_bound_id != did:
		return
	if _desk_bound_id == "":
		return
	_desk_bound_id = ""
	if _goto_active:
		return
	_waiting_for_work_left = 0.0
	wander_enabled = true
	_wander_pause_left = 0.0
	_pick_new_wander_target()
	_play_anim(_anim_idle)

func on_meeting_bound(meeting_room_id: String) -> void:
	var rid := meeting_room_id.strip_edges()
	if rid == "":
		return
	if _meeting_bound_room_id == rid:
		return
	# Meeting state is for "standing by" near the table; keep NPC in place.
	_meeting_bound_room_id = rid
	_skip_wait_after_goto = false
	_goto_active = false
	_waiting_for_work_left = 0.0
	_wander_pause_left = 0.0
	stop_override_animation()
	wander_enabled = false
	velocity.x = 0.0
	velocity.z = 0.0
	_play_anim(_anim_idle)

func on_meeting_unbound(meeting_room_id: String) -> void:
	var rid := meeting_room_id.strip_edges()
	if rid != "" and _meeting_bound_room_id != rid:
		return
	if _meeting_bound_room_id == "":
		return
	_meeting_bound_room_id = ""
	if _goto_active:
		return
	_waiting_for_work_left = 0.0
	wander_enabled = true
	_wander_pause_left = 0.0
	_pick_new_wander_target()
	_play_anim(_anim_idle)

func play_animation_once(clip: String, duration: float = 0.7, lock_wander: bool = true) -> void:
	if clip.strip_edges() == "":
		return
	if duration <= 0.0:
		duration = 0.1
	var anim_name := _pick_named_animation(_anim_player.get_animation_list(), clip.to_lower()) if _anim_player != null else &""
	if anim_name == &"":
		# Fallback: the caller may have passed an exact name with different casing.
		anim_name = StringName(clip)
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

func set_stationary_pose(clip: String) -> void:
	stationary = true
	stationary_animation = clip
	_apply_stationary_pose()

func _apply_stationary_pose() -> void:
	wander_enabled = false
	_goto_active = false
	_waiting_for_work_left = 0.0
	_wander_pause_left = 0.0
	stop_override_animation()

	if stationary_animation.strip_edges() == "":
		_stationary_anim = &""
		return
	if _anim_player == null:
		# Model may not be loaded yet (e.g. headless placeholder). We'll retry lazily from _update_wander.
		_stationary_anim = &""
		return
	var anims := _anim_player.get_animation_list()
	var anim_name := _pick_named_animation(anims, stationary_animation.to_lower())
	if anim_name == &"":
		anim_name = StringName(stationary_animation)
	_stationary_anim = anim_name
	_play_anim(_stationary_anim)

func _stationary_fallback_anim() -> StringName:
	if _anim_idle != &"":
		return _anim_idle
	if _anim_player != null:
		var anims := _anim_player.get_animation_list()
		if not anims.is_empty():
			return _pick_animation(anims)
	return &""

func _start_override_animation(anim: StringName, duration: float, lock_wander: bool) -> void:
	if _anim_player == null:
		return
	if lock_wander and _override_left <= 0.0:
		_wander_enabled_before_override = wander_enabled
		wander_enabled = false
	_override_anim = anim
	_override_left = duration
	_play_anim(_override_anim if _override_anim != &"" else _anim_idle)

func enter_dialogue(face_target) -> void:
	if _in_dialogue:
		return
	_in_dialogue = true
	_wander_enabled_before_dialogue = wander_enabled
	wander_enabled = false
	_wander_pause_left = 0.0
	stop_override_animation()
	_dialogue_face_node = null
	_dialogue_face_pos = Vector3.ZERO
	var face_pos: Vector3 = Vector3.ZERO
	if face_target is Node3D:
		_dialogue_face_node = face_target as Node3D
		face_pos = _dialogue_face_node.global_position
	elif typeof(face_target) == TYPE_VECTOR3:
		face_pos = face_target as Vector3
		_dialogue_face_pos = face_pos
	_face_towards(face_pos)
	_play_anim(_anim_idle)

func exit_dialogue() -> void:
	if not _in_dialogue:
		return
	_in_dialogue = false
	_dialogue_face_node = null
	_dialogue_face_pos = Vector3.ZERO
	stop_override_animation()
	wander_enabled = _wander_enabled_before_dialogue
	if wander_enabled:
		_wander_pause_left = 0.0
		_pick_new_wander_target()
	_play_anim(_anim_idle)

func command_move_to(target_world_pos: Vector3) -> void:
	# Move to a specific point on the floor, then wait in idle. If no other actions
	# occur, resume wandering after `waiting_for_work_seconds`.
	if stationary:
		return
	if _in_dialogue:
		return
	if _desk_bound_id != "":
		# If we are leaving a desk binding, do not enter the old "wait for work" mode
		# after reaching the target.
		_skip_wait_after_goto = true
	_goto_target_xz = Vector2(target_world_pos.x, target_world_pos.z)
	_goto_active = true
	_waiting_for_work_left = 0.0
	_wander_pause_left = 0.0
	stop_override_animation()
	wander_enabled = false

func _face_towards(target: Vector3) -> void:
	var flat := Vector3(target.x, global_position.y, target.z)
	if flat.distance_to(global_position) < 0.001:
		return
	look_at(flat, Vector3.UP)
	rotation.y = rotation.y + model_yaw_offset

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

func _play_anim(anim_name: StringName) -> void:
	if _anim_player == null or anim_name == &"":
		return
	_ensure_loop(anim_name)
	if _anim_current == anim_name:
		return
	_anim_current = anim_name
	_anim_player.play(anim_name)

func _ensure_loop(anim_name: StringName) -> void:
	if _anim_player == null or anim_name == &"":
		return
	var anim := _anim_player.get_animation(anim_name)
	if anim == null:
		return
	# Imported Kenney animations may not be set to loop by default; ensure idle/walk loop.
	if anim.loop_mode == Animation.LOOP_NONE:
		anim.loop_mode = Animation.LOOP_LINEAR

func _update_wander(delta: float) -> void:
	if stationary:
		velocity.x = 0.0
		velocity.z = 0.0
		if _stationary_anim == &"" and stationary_animation.strip_edges() != "" and _anim_player != null:
			_apply_stationary_pose()
		_play_anim(_stationary_anim if _stationary_anim != &"" else _stationary_fallback_anim())
		return
	# Override animation: keep the NPC still and play the requested clip.
	if _override_left > 0.0:
		_override_left = maxf(0.0, _override_left - delta)
		velocity.x = move_toward(velocity.x, 0.0, wander_speed * 3.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, wander_speed * 3.0 * delta)
		_play_anim(_override_anim if _override_anim != &"" else _anim_idle)
		if _override_left <= 0.0:
			stop_override_animation()
		return

	# Dialogue: stand still (camera/look-at handled in _process).
	if _in_dialogue:
		velocity.x = 0.0
		velocity.z = 0.0
		_play_anim(_anim_idle)
		return

	# Move-to command: walk toward a clicked point, then idle and "wait for work".
	if _goto_active:
		# Only walk when standing on the floor (keeps behavior predictable with gravity).
		if not is_on_floor():
			return
		var cmd_pos_xz := Vector2(global_position.x, global_position.z)
		var cmd_to_target := _goto_target_xz - cmd_pos_xz
		if cmd_to_target.length() <= maxf(0.05, wander_target_radius * 0.75):
			_goto_active = false
			velocity.x = 0.0
			velocity.z = 0.0
			_play_anim(_anim_idle)
			move_target_reached.emit(npc_id, Vector3(_goto_target_xz.x, 0.0, _goto_target_xz.y))
			if _skip_wait_after_goto:
				_skip_wait_after_goto = false
				_waiting_for_work_left = 0.0
				wander_enabled = true
				_wander_pause_left = 0.0
				_pick_new_wander_target()
			else:
				_waiting_for_work_left = maxf(0.0, waiting_for_work_seconds)
			return

		var cmd_dir := cmd_to_target.normalized()
		velocity.x = cmd_dir.x * command_speed
		velocity.z = cmd_dir.y * command_speed
		if _anim_sprint != &"":
			_play_anim(_anim_sprint)
		else:
			_play_anim(_anim_walk if _anim_walk != &"" else _anim_idle)
		if turn_speed > 0.0:
			var target_yaw := atan2(-cmd_dir.x, -cmd_dir.y) + model_yaw_offset
			rotation.y = lerp_angle(rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))
		return

	# Meeting "stand by" state: stay near the meeting table and do not wander.
	if _meeting_bound_room_id != "":
		velocity.x = move_toward(velocity.x, 0.0, wander_speed * 3.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, wander_speed * 3.0 * delta)
		_play_anim(_anim_idle)
		return

	# Desk-bound work state: stand still and play a working loop.
	if _desk_bound_id != "":
		velocity.x = move_toward(velocity.x, 0.0, wander_speed * 3.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, wander_speed * 3.0 * delta)
		_play_anim(_anim_work if _anim_work != &"" else _anim_idle)
		return

	# Waiting-for-work idle countdown: keep still until the timer completes, then resume wandering.
	if _waiting_for_work_left > 0.0:
		_waiting_for_work_left = maxf(0.0, _waiting_for_work_left - delta)
		velocity.x = move_toward(velocity.x, 0.0, wander_speed * 3.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, wander_speed * 3.0 * delta)
		_play_anim(_anim_idle)
		if _waiting_for_work_left <= 0.0:
			wander_enabled = true
			_pick_new_wander_target()
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
