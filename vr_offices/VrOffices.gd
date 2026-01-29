extends Node3D

const MAX_NPCS := 12
const BGM_PATH := "res://assets/audio/pixel_coffee_break.mp3"
const _SessionStoreScript := preload("res://addons/openagentic/core/OAJsonlNpcSessionStore.gd")
const _OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")

const MODEL_PATHS: Array[String] = [
	"res://assets/kenney/mini-characters-1/character-female-a.glb",
	"res://assets/kenney/mini-characters-1/character-female-b.glb",
	"res://assets/kenney/mini-characters-1/character-female-c.glb",
	"res://assets/kenney/mini-characters-1/character-female-d.glb",
	"res://assets/kenney/mini-characters-1/character-female-e.glb",
	"res://assets/kenney/mini-characters-1/character-female-f.glb",
	"res://assets/kenney/mini-characters-1/character-male-a.glb",
	"res://assets/kenney/mini-characters-1/character-male-b.glb",
	"res://assets/kenney/mini-characters-1/character-male-c.glb",
	"res://assets/kenney/mini-characters-1/character-male-d.glb",
	"res://assets/kenney/mini-characters-1/character-male-e.glb",
	"res://assets/kenney/mini-characters-1/character-male-f.glb",
]

const CULTURE_NAMES := {
	# Default: Chinese culture (12 unique names).
	"zh-CN": [
		"林晓", "苏雨晴", "周若雪", "陈思妍", "唐婉儿", "叶清歌",
		"王子轩", "李泽言", "张昊然", "赵景行", "孙亦辰", "郭承宇",
	],
	# US culture: intentionally diverse.
	"en-US": [
		"Emily Carter", "Maya Patel", "Sofia Garcia", "Hannah Kim", "Aaliyah Johnson", "Olivia Nguyen",
		"Alex Johnson", "Daniel Smith", "Ethan Chen", "Noah Williams", "Liam O'Connor", "Jayden Martinez",
	],
	# Japan culture.
	"ja-JP": [
		"佐藤 美咲", "鈴木 陽菜", "高橋 さくら", "田中 結衣", "伊藤 彩花", "渡辺 りん",
		"佐藤 蓮", "鈴木 悠真", "高橋 大輝", "田中 海斗", "伊藤 陽向", "渡辺 颯太",
	],
}

@export var npc_scene: PackedScene
@export var npc_spawn_y := 2.0
@export var spawn_extent := Vector2(6.0, 4.0) # X,Z half extents
@export var culture_code := "zh-CN"

@onready var floor: StaticBody3D = $Floor
@onready var npc_root: Node3D = $NpcRoot
@onready var camera_rig: Node3D = $CameraRig
@onready var ui: Control = $UI/VrOfficesUi
@onready var dialogue: Control = $UI/DialogueOverlay
@onready var saving_overlay: Control = $UI/SavingOverlay
@onready var bgm: AudioStreamPlayer = $Bgm

var _npc_counter := 0
var _selected_npc: Node = null

var _available_profile_indices: Array[int] = []
var _profile_index_by_model_path: Dictionary = {}

var _busy := false
var _save_id: String = "slot1"
var _proxy_base_url: String = "http://127.0.0.1:8787/v1"
var _model: String = "gpt-5.2"
var _oa: Node = null
var _quitting := false
var _camera_state_before_talk: Dictionary = {}
var _talk_npc: Node = null
var _floor_bounds_xz := Rect2(Vector2(-10.0, -10.0), Vector2(20.0, 20.0))

var _rmb_down := false
var _rmb_dragged := false
var _rmb_down_pos := Vector2.ZERO

const _OA_VR_OFFICES_SYSTEM_PROMPT: String = """
你是一个虚拟办公室里的 NPC。

你可用的能力仅来自：
- 工具：Read / Write / Edit / ListFiles / Mkdir / Glob / Grep / WebFetch / WebSearch / TodoWrite / Skill
- 系统消息里提供的“World summary / NPC summary / NPC skills”等信息。

当玩家问“你有哪些技能/你能做什么工具/你有什么能力”时：
1) 先列出工具名；
2) 再列出你已安装的 NPC skills（如果没有就明确说没有）。
不要编造不存在的工具或能力。
"""

func _ready() -> void:
	randomize()
	if get_tree() != null:
		# Give ourselves a chance to autosave before quitting.
		get_tree().auto_accept_quit = false
	_floor_bounds_xz = _compute_floor_bounds_xz()
	_load_env_defaults()
	_configure_openagentic()
	if npc_scene == null:
		npc_scene = preload("res://vr_offices/npc/Npc.tscn")

	ui.add_npc_pressed.connect(add_npc)
	ui.remove_selected_pressed.connect(remove_selected)
	if ui.has_signal("culture_changed"):
		ui.connect("culture_changed", Callable(self, "set_culture"))

	if dialogue != null:
		if dialogue.has_signal("message_submitted"):
			dialogue.connect("message_submitted", Callable(self, "_on_dialogue_message_submitted"))
		if dialogue.has_signal("closed"):
			dialogue.connect("closed", Callable(self, "_exit_talk"))

	_configure_bgm()
	_init_profiles()
	_load_world_state()
	_apply_ui_state()
	if ui.has_method("set_culture"):
		ui.call("set_culture", culture_code)
	if get_tree() != null and get_tree().has_signal("about_to_quit"):
		get_tree().about_to_quit.connect(func() -> void:
			autosave()
		)

func _load_env_defaults() -> void:
	var v := OS.get_environment("OPENAGENTIC_PROXY_BASE_URL")
	if v.strip_edges() != "":
		_proxy_base_url = v.strip_edges()
	v = OS.get_environment("OPENAGENTIC_MODEL")
	if v.strip_edges() != "":
		_model = v.strip_edges()
	v = OS.get_environment("OPENAGENTIC_SAVE_ID")
	if v.strip_edges() != "":
		_save_id = v.strip_edges()

func _configure_openagentic() -> void:
	_oa = get_node_or_null("/root/OpenAgentic")
	if _oa == null:
		push_warning("Missing autoload: OpenAgentic (dialogue will not work)")
		return

	# Respect a save_id already set on the OpenAgentic autoload, unless an explicit
	# environment override is provided. This makes tests and host games able to
	# control save isolation without scenes clobbering it.
	var env_save: String = OS.get_environment("OPENAGENTIC_SAVE_ID").strip_edges()
	if env_save != "":
		_save_id = env_save
		_oa.set_save_id(_save_id)
	else:
		var existing: String = ""
		if _oa.has_method("get"):
			var v: Variant = _oa.get("save_id")
			if v != null:
				existing = String(v).strip_edges()
		if existing != "":
			_save_id = existing
		else:
			_oa.set_save_id(_save_id)

	_oa.configure_proxy_openai_responses(_proxy_base_url, _model)
	# Ensure tools are registered and set a sensible NPC system prompt for this demo.
	if _oa.has_method("enable_default_tools"):
		_oa.call("enable_default_tools")
	if _oa.has_method("get"):
		var sp0: Variant = _oa.get("system_prompt")
		var sp: String = String(sp0) if sp0 != null else ""
		if sp.strip_edges() == "":
			_oa.set("system_prompt", _OA_VR_OFFICES_SYSTEM_PROMPT)
	_oa.set_approver(func(_q: Dictionary, _ctx: Dictionary) -> bool:
		return true
	)
	_install_openagentic_turn_hooks()

func _install_openagentic_turn_hooks() -> void:
	if _oa == null:
		return
	if _oa.has_meta("vr_offices_turn_hooks_installed"):
		return
	if not _oa.has_method("add_before_turn_hook") or not _oa.has_method("add_after_turn_hook"):
		return
	_oa.call("add_before_turn_hook", "vr_offices.before_turn", "*", Callable(self, "_oa_before_turn_hook"))
	_oa.call("add_after_turn_hook", "vr_offices.after_turn", "*", Callable(self, "_oa_after_turn_hook"))
	_oa.set_meta("vr_offices_turn_hooks_installed", true)

func _find_npc_by_id(npc_id: String) -> Node:
	if npc_id.strip_edges() == "" or get_tree() == null:
		return null
	var nodes: Array = get_tree().get_nodes_in_group("vr_offices_npc")
	for n0 in nodes:
		if typeof(n0) != TYPE_OBJECT:
			continue
		var n: Node = n0 as Node
		if n == null:
			continue
		if n.has_method("get"):
			var id0: Variant = n.get("npc_id")
			if id0 != null and String(id0) == npc_id:
				return n
	return null

func _oa_before_turn_hook(payload: Dictionary) -> Dictionary:
	var npc_id := String(payload.get("npc_id", "")).strip_edges()
	var npc := _find_npc_by_id(npc_id)
	if npc != null and npc.has_method("play_turn_start_animation"):
		npc.call("play_turn_start_animation")
		return {"action": "npc_turn_start_anim"}
	if npc != null and npc.has_method("play_animation_once"):
		npc.call("play_animation_once", "interact-right", 0.7)
		return {"action": "npc_anim:interact-right"}
	return {}

func _oa_after_turn_hook(payload: Dictionary) -> Dictionary:
	var npc_id := String(payload.get("npc_id", "")).strip_edges()
	var npc := _find_npc_by_id(npc_id)
	if npc != null and npc.has_method("play_turn_end_animation"):
		npc.call("play_turn_end_animation")
		return {"action": "npc_turn_end_anim"}
	if npc != null and npc.has_method("stop_override_animation"):
		npc.call("stop_override_animation")
		return {"action": "npc_anim:stop_override"}
	return {}

func _configure_bgm() -> void:
	if bgm == null:
		return
	if _is_headless():
		bgm.stop()
		bgm.stream = null
		return

	if bgm.stream == null:
		var s := load(BGM_PATH)
		if s is AudioStream:
			bgm.stream = s as AudioStream

	# Ensure loop for BGM even if import settings change.
	if bgm.stream == null:
		return
	if _object_has_property(bgm.stream, "loop"):
		bgm.stream.set("loop", true)
	else:
		bgm.finished.connect(func() -> void:
			bgm.play()
		)

	if not bgm.playing:
		bgm.play()

func _is_headless() -> bool:
	# `OS.has_feature("headless")` is not reliable across Godot builds; prefer DisplayServer.
	# When launched with `--headless`, DisplayServer name is typically "headless".
	return DisplayServer.get_name() == "headless" or OS.has_feature("server") or OS.has_feature("headless")

func _object_has_property(obj: Object, property_name: String) -> bool:
	for p in obj.get_property_list():
		if p.has("name") and String(p["name"]) == property_name:
			return true
	return false

func _init_profiles() -> void:
	_available_profile_indices.clear()
	_profile_index_by_model_path.clear()
	for i in range(MODEL_PATHS.size()):
		_available_profile_indices.append(i)
		_profile_index_by_model_path[MODEL_PATHS[i]] = i

func _apply_ui_state() -> void:
	if ui == null:
		return
	if ui.has_method("set_can_add"):
		ui.call("set_can_add", _available_profile_indices.size() > 0)
	if ui.has_method("set_status_text"):
		ui.call("set_status_text", "")

func _unhandled_input(event: InputEvent) -> void:
	if dialogue != null and dialogue.visible:
		# In dialogue: Esc is a 2-step exit (helps avoid accidental close while typing).
		# 1st Esc: release LineEdit focus (stop typing)
		# 2nd Esc: close the overlay
		if Input.is_action_just_pressed("ui_cancel") and dialogue.has_method("close"):
			var input_node := dialogue.get_node_or_null("Panel/VBox/Footer/Input") as Control
			if input_node != null and input_node.has_focus():
				get_viewport().gui_release_focus()
			else:
				dialogue.close()
		# Prevent camera rig / world from handling mouse input while the dialogue UI is open.
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and _rmb_down:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_RIGHT != 0:
			if (mm.position - _rmb_down_pos).length() > 6.0:
				_rmb_dragged = true

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_rmb_down = true
				_rmb_dragged = false
				_rmb_down_pos = mb.position
			else:
				if _rmb_down and not _rmb_dragged:
					_command_selected_move_to_click(mb.position)
				_rmb_down = false
			return

		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var clicked := _try_select_from_click(mb.position)
			if mb.double_click and clicked != null:
				_enter_talk(clicked)
			return

	if _selected_npc != null and event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.physical_keycode == KEY_E:
			_enter_talk(_selected_npc)

func _compute_floor_bounds_xz() -> Rect2:
	# Prefer collider dimensions to avoid depending on mesh settings.
	if floor != null:
		var cs := floor.get_node_or_null("FloorCollider") as CollisionShape3D
		if cs != null and cs.shape is BoxShape3D:
			var box := cs.shape as BoxShape3D
			var sx := float(box.size.x)
			var sz := float(box.size.z)
			var hx := sx * 0.5
			var hz := sz * 0.5
			return Rect2(Vector2(-hx, -hz), Vector2(sx, sz))
	# Fallback: match the default scene values.
	return Rect2(Vector2(-10.0, -10.0), Vector2(20.0, 20.0))

func _raycast_floor_point(screen_pos: Vector2) -> Dictionary:
	if camera_rig == null or not camera_rig.has_method("get_camera"):
		return {"ok": false}
	var cam0: Variant = camera_rig.call("get_camera")
	if not (cam0 is Camera3D):
		return {"ok": false}
	var cam := cam0 as Camera3D
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var to := from + dir * 200.0
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1 # floor default layer
	q.collide_with_areas = false
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty() or not hit.has("position"):
		return {"ok": false}
	return {"ok": true, "pos": hit.get("position")}

func _command_selected_move_to_click(screen_pos: Vector2) -> void:
	if _selected_npc == null or not is_instance_valid(_selected_npc):
		return
	if not _selected_npc.has_method("command_move_to"):
		return
	var hit := _raycast_floor_point(screen_pos)
	if not bool(hit.get("ok", false)):
		return
	var p0: Variant = hit.get("pos")
	if not (p0 is Vector3):
		return
	var p := p0 as Vector3
	var min_x := _floor_bounds_xz.position.x
	var max_x := _floor_bounds_xz.position.x + _floor_bounds_xz.size.x
	var min_z := _floor_bounds_xz.position.y
	var max_z := _floor_bounds_xz.position.y + _floor_bounds_xz.size.y
	p.x = clampf(p.x, min_x, max_x)
	p.z = clampf(p.z, min_z, max_z)
	_selected_npc.call("command_move_to", p)

func add_npc() -> Node:
	if _available_profile_indices.is_empty():
		if ui != null and ui.has_method("set_status_text"):
			ui.call("set_status_text", "Reached max NPCs (%d). Remove one to add more." % MAX_NPCS)
		return null

	_npc_counter += 1
	var npc := npc_scene.instantiate()
	if npc == null:
		return null

	var npc_id := "npc_%d" % _npc_counter
	npc.name = npc_id

	# Spawn within a rectangle on XZ.
	var x := randf_range(-spawn_extent.x, spawn_extent.x)
	var z := randf_range(-spawn_extent.y, spawn_extent.y)
	npc.position = Vector3(x, npc_spawn_y, z)

	var profile_index := _take_random_profile_index()
	if profile_index < 0:
		return null

	# Default NPC scene supports these properties.
	npc.set("npc_id", npc_id)
	npc.set("model_path", MODEL_PATHS[profile_index])
	npc.set("display_name", _name_for_profile(profile_index))
	npc.set("wander_bounds", Rect2(Vector2(-spawn_extent.x, -spawn_extent.y), Vector2(spawn_extent.x * 2.0, spawn_extent.y * 2.0)))
	npc.set("load_model_on_ready", not _is_headless())

	npc_root.add_child(npc)
	select_npc(npc)
	_apply_ui_state()
	autosave()
	return npc

func remove_selected() -> void:
	if _selected_npc == null or not is_instance_valid(_selected_npc):
		return

	var to_remove := _selected_npc
	var model_path := ""
	if to_remove.has_method("get") and to_remove.get("model_path") != null:
		model_path = String(to_remove.get("model_path"))
	_return_profile_for_model(model_path)

	select_npc(null)
	to_remove.queue_free()
	_apply_ui_state()
	autosave()

func select_npc(npc: Node) -> void:
	if _selected_npc != null and is_instance_valid(_selected_npc) and _selected_npc.has_method("set_selected"):
		_selected_npc.call("set_selected", false)

	_selected_npc = npc

	if _selected_npc != null and is_instance_valid(_selected_npc) and _selected_npc.has_method("set_selected"):
		_selected_npc.call("set_selected", true)

	if _selected_npc == null:
		ui.call("set_selected_text", "")
	else:
		var label := _selected_npc.name
		if _selected_npc.has_method("get_display_name"):
			label = _selected_npc.call("get_display_name")
		ui.call("set_selected_text", label)
	if ui.has_method("set_status_text"):
		ui.call("set_status_text", "")

func _enter_talk(npc: Node) -> void:
	if dialogue == null or not dialogue.has_method("open"):
		return
	_talk_npc = npc
	var npc_id := ""
	var npc_name := ""
	if npc.has_method("get"):
		npc_id = String(npc.get("npc_id"))
	if npc.has_method("get_display_name"):
		npc_name = String(npc.call("get_display_name"))
	if npc_id.strip_edges() == "":
		npc_id = npc.name
	if camera_rig != null and camera_rig.has_method("set_controls_enabled"):
		camera_rig.call("set_controls_enabled", false)
	_start_dialogue_camera_focus(npc)
	_lock_npc_for_dialogue(npc)
	dialogue.open(npc_id, npc_name)
	if dialogue.has_method("set_history"):
		dialogue.call("set_history", _read_chat_history(npc_id))

func _exit_talk() -> void:
	_unlock_npc_after_dialogue()
	_restore_dialogue_camera()
	if camera_rig != null and camera_rig.has_method("set_controls_enabled"):
		camera_rig.call("set_controls_enabled", true)
	if _busy:
		return
	if dialogue != null and dialogue.visible and dialogue.has_method("close"):
		dialogue.close()

func _start_dialogue_camera_focus(npc: Node) -> void:
	if camera_rig == null:
		return
	if not camera_rig.has_method("get_state") or not camera_rig.has_method("focus_on"):
		return
	_camera_state_before_talk = camera_rig.call("get_state")

	var npc3d: Node3D = npc as Node3D
	if npc3d == null:
		return
	var head: Vector3 = npc3d.global_position + Vector3(0.0, 1.35, 0.0)

	# Keep current orbit angles (prevents disorienting camera flips),
	# but zoom in and move pivot to the NPC head.
	var yaw := float(_camera_state_before_talk.get("yaw", deg_to_rad(45.0)))
	var pitch := float(_camera_state_before_talk.get("pitch", deg_to_rad(-35.0)))
	var dist := 4.0

	var duration := 0.28
	if _is_headless():
		duration = 0.0
	camera_rig.call("focus_on", head, yaw, pitch, dist, duration)

func _restore_dialogue_camera() -> void:
	if camera_rig == null or _camera_state_before_talk.is_empty():
		return
	if not camera_rig.has_method("tween_to_state"):
		return
	var duration := 0.22
	if _is_headless():
		duration = 0.0
	camera_rig.call("tween_to_state", _camera_state_before_talk, duration)
	_camera_state_before_talk = {}

func _lock_npc_for_dialogue(npc: Node) -> void:
	if npc == null or not is_instance_valid(npc):
		return
	# Face the camera (more natural than keeping the NPC walking away).
	var cam: Camera3D = null
	if camera_rig != null and camera_rig.has_method("get_camera"):
		var cam0: Variant = camera_rig.call("get_camera")
		if cam0 is Camera3D:
			cam = cam0 as Camera3D
	if npc.has_method("enter_dialogue"):
		if cam != null:
			npc.call("enter_dialogue", cam)
		else:
			npc.call("enter_dialogue", Vector3.ZERO)

func _unlock_npc_after_dialogue() -> void:
	if _talk_npc == null or not is_instance_valid(_talk_npc):
		_talk_npc = null
		return
	if _talk_npc.has_method("exit_dialogue"):
		_talk_npc.call("exit_dialogue")
	_talk_npc = null

func _on_dialogue_message_submitted(text: String) -> void:
	if dialogue == null or _busy:
		return
	var npc_id := ""
	if dialogue.has_method("get_npc_id"):
		npc_id = String(dialogue.call("get_npc_id"))
	if npc_id.strip_edges() == "":
		return
	_start_turn(npc_id, text)

func _start_turn(npc_id: String, text: String) -> void:
	_busy = true
	if dialogue != null and dialogue.has_method("set_busy"):
		dialogue.call("set_busy", true)
	if dialogue != null and dialogue.has_method("begin_assistant"):
		dialogue.call("begin_assistant")

	if _oa == null:
		push_warning("OpenAgentic not configured")
		_busy = false
		if dialogue != null and dialogue.has_method("set_busy"):
			dialogue.call("set_busy", false)
		return

	await _oa.run_npc_turn(npc_id, text, Callable(self, "_on_agent_event"))

	_busy = false
	if dialogue != null and dialogue.has_method("set_busy"):
		dialogue.call("set_busy", false)

func _on_agent_event(ev: Dictionary) -> void:
	if dialogue == null:
		return
	var t := String(ev.get("type", ""))
	if t == "assistant.delta":
		if dialogue.has_method("append_assistant_delta"):
			dialogue.call("append_assistant_delta", String(ev.get("text_delta", "")))
		return
	if t == "result":
		if dialogue.has_method("end_assistant"):
			dialogue.call("end_assistant")
		return

func _read_chat_history(npc_id: String) -> Array:
	# Translate the persisted per-NPC JSONL event log into a simple UI chat history.
	# Only include final user/assistant messages (ignore deltas/tool events).
	var out: Array = []
	if npc_id.strip_edges() == "":
		return out

	var sid := ""
	if _oa != null and _oa.has_method("get"):
		var v: Variant = _oa.get("save_id")
		if v != null:
			sid = String(v)
	if sid.strip_edges() == "":
		sid = _save_id
	if sid.strip_edges() == "":
		return out

	var store = _SessionStoreScript.new(sid)
	var events: Array = store.read_events(npc_id)
	for e0 in events:
		if typeof(e0) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = e0 as Dictionary
		var typ := String(e.get("type", ""))
		if typ == "user.message":
			var tx0: Variant = e.get("text", null)
			if typeof(tx0) == TYPE_STRING:
				out.append({"role": "user", "text": String(tx0)})
		elif typ == "assistant.message":
			var tx1: Variant = e.get("text", null)
			if typeof(tx1) == TYPE_STRING:
				out.append({"role": "assistant", "text": String(tx1)})
	return out

func set_culture(code: String) -> void:
	if not CULTURE_NAMES.has(code):
		return
	culture_code = code
	_update_all_npc_names()
	if ui.has_method("set_status_text"):
		ui.call("set_status_text", "")
	autosave()

func _update_all_npc_names() -> void:
	for n in get_tree().get_nodes_in_group("vr_offices_npc"):
		if n == null or not (n is Node):
			continue
		var node := n as Node
		if not node.has_method("get"):
			continue
		var mp := String(node.get("model_path"))
		var idx := _profile_index_for_model(mp)
		if idx >= 0:
			node.set("display_name", _name_for_profile(idx))
	# Refresh selected label.
	if _selected_npc != null and is_instance_valid(_selected_npc):
		select_npc(_selected_npc)

func _try_select_from_click(screen_pos: Vector2) -> Node:
	var cam: Camera3D = null
	if camera_rig != null and camera_rig.has_method("get_camera"):
		cam = camera_rig.call("get_camera") as Camera3D
	else:
		cam = get_viewport().get_camera_3d()

	if cam == null:
		return null

	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * 200.0

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = 2

	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		select_npc(null)
		return null

	var collider: Object = hit.get("collider") as Object
	var npc := _find_npc_owner(collider)
	select_npc(npc)
	return npc

func _find_npc_owner(node: Object) -> Node:
	var cur := node
	while cur != null and cur is Node:
		var n := cur as Node
		if n.is_in_group("vr_offices_npc"):
			return n
		cur = n.get_parent()
	return null

func _take_random_profile_index() -> int:
	if _available_profile_indices.is_empty():
		return -1
	var k := randi_range(0, _available_profile_indices.size() - 1)
	var idx := _available_profile_indices[k]
	_available_profile_indices.remove_at(k)
	return idx

func _return_profile_for_model(model_path: String) -> void:
	var idx := _profile_index_for_model(model_path)
	if idx < 0:
		return
	if _available_profile_indices.has(idx):
		return
	_available_profile_indices.append(idx)

func _profile_index_for_model(model_path: String) -> int:
	if _profile_index_by_model_path.has(model_path):
		return int(_profile_index_by_model_path[model_path])
	return -1

func _name_for_profile(profile_index: int) -> String:
	var names: Array = CULTURE_NAMES.get(culture_code, CULTURE_NAMES.get("en-US", []))
	if profile_index >= 0 and profile_index < names.size():
		return String(names[profile_index])
	return "NPC %d" % (profile_index + 1)

func autosave() -> void:
	_save_world_state()

func _state_path(save_id: String) -> String:
	return "%s/vr_offices/state.json" % _OAPaths.save_root(save_id)

func _ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))

func _write_text(path: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(text)
	f.close()

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _save_world_state() -> void:
	if _save_id.strip_edges() == "":
		return
	if npc_root == null:
		return

	var npcs: Array = []
	for child0 in npc_root.get_children():
		var child := child0 as Node
		if child == null:
			continue
		if not child.has_method("get"):
			continue
		var npc_id := String(child.get("npc_id")).strip_edges()
		if npc_id == "":
			npc_id = child.name
		var model_path := String(child.get("model_path")).strip_edges()
		var pos := Vector3.ZERO
		var yaw := 0.0
		if child is Node3D:
			var n3 := child as Node3D
			pos = n3.position
			yaw = n3.rotation.y
		npcs.append({
			"npc_id": npc_id,
			"model_path": model_path,
			"pos": [pos.x, pos.y, pos.z],
			"yaw": yaw,
		})

	var state := {
		"version": 1,
		"save_id": _save_id,
		"culture_code": culture_code,
		"npc_counter": _npc_counter,
		"npcs": npcs,
	}
	var path := _state_path(_save_id)
	_ensure_dir(path.get_base_dir())
	_write_text(path, JSON.stringify(state) + "\n")

func _load_world_state() -> void:
	if _save_id.strip_edges() == "":
		return
	if npc_root == null:
		return
	var path := _state_path(_save_id)
	var st := _read_json(path)
	if st.is_empty():
		return

	var v := int(st.get("version", 1))
	if v != 1:
		return

	var cc := String(st.get("culture_code", culture_code)).strip_edges()
	if cc != "" and CULTURE_NAMES.has(cc):
		culture_code = cc

	var counter := int(st.get("npc_counter", _npc_counter))
	_npc_counter = max(_npc_counter, counter)

	var list0: Variant = st.get("npcs", [])
	if typeof(list0) != TYPE_ARRAY:
		return
	var list: Array = list0 as Array

	# Reserve any profiles used by saved NPCs.
	var seen_models: Dictionary = {}
	var max_num := _npc_counter
	for it0 in list:
		if typeof(it0) != TYPE_DICTIONARY:
			continue
		var it: Dictionary = it0 as Dictionary
		var model_path := String(it.get("model_path", "")).strip_edges()
		if model_path == "":
			continue
		if seen_models.has(model_path):
			continue
		seen_models[model_path] = true

		var idx := _profile_index_for_model(model_path)
		if idx < 0:
			continue
		if _available_profile_indices.has(idx):
			_available_profile_indices.erase(idx)

		var npc := npc_scene.instantiate()
		if npc == null:
			continue

		var npc_id := String(it.get("npc_id", "")).strip_edges()
		if npc_id == "":
			_npc_counter += 1
			npc_id = "npc_%d" % _npc_counter

		# Track numeric suffix for future ids.
		if npc_id.begins_with("npc_"):
			var suffix := npc_id.substr(4)
			var maybe := int(suffix)
			if maybe > max_num:
				max_num = maybe

		npc.name = npc_id
		npc.set("npc_id", npc_id)
		npc.set("model_path", model_path)
		npc.set("display_name", _name_for_profile(idx))
		npc.set("wander_bounds", Rect2(Vector2(-spawn_extent.x, -spawn_extent.y), Vector2(spawn_extent.x * 2.0, spawn_extent.y * 2.0)))
		npc.set("load_model_on_ready", not _is_headless())

		var pos0: Variant = it.get("pos", [])
		var yaw := float(it.get("yaw", 0.0))
		if npc is Node3D:
			var n3 := npc as Node3D
			if typeof(pos0) == TYPE_ARRAY and (pos0 as Array).size() >= 3:
				var arr := pos0 as Array
				n3.position = Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
			else:
				n3.position = Vector3(randf_range(-spawn_extent.x, spawn_extent.x), npc_spawn_y, randf_range(-spawn_extent.y, spawn_extent.y))
			n3.rotation.y = yaw

		npc_root.add_child(npc)

	_npc_counter = max(_npc_counter, max_num)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not _quitting:
			_quitting = true
			call_deferred("_autosave_and_quit")

func _autosave_and_quit() -> void:
	if saving_overlay != null and saving_overlay.has_method("show_saving"):
		saving_overlay.call("show_saving", "Saving…")
	if get_tree() != null:
		await get_tree().process_frame
	autosave()
	if get_tree() != null:
		await get_tree().process_frame
	get_tree().quit()
