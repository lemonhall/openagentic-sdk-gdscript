extends Node3D

const _OAData := preload("res://vr_offices/core/VrOfficesData.gd")
const _ProfilesScript := preload("res://vr_offices/core/VrOfficesNpcProfiles.gd")
const _ChatHistoryScript := preload("res://vr_offices/core/VrOfficesChatHistory.gd")
const _WorldStateScript := preload("res://vr_offices/core/VrOfficesWorldState.gd")
const _DialogueControllerScript := preload("res://vr_offices/core/VrOfficesDialogueController.gd")
const _InputControllerScript := preload("res://vr_offices/core/VrOfficesInputController.gd")
const _MoveControllerScript := preload("res://vr_offices/core/VrOfficesMoveController.gd")
const _BgmScript := preload("res://vr_offices/core/VrOfficesBgm.gd")
const _MoveIndicatorScene := preload("res://vr_offices/fx/MoveIndicator.tscn")

@export var npc_scene: PackedScene
@export var npc_spawn_y := 2.0
@export var spawn_extent := Vector2(6.0, 4.0) # X,Z half extents
@export var culture_code := "zh-CN"

@onready var floor: StaticBody3D = $Floor
@onready var npc_root: Node3D = $NpcRoot
@onready var move_indicators: Node3D = $MoveIndicators
@onready var camera_rig: Node3D = $CameraRig
@onready var ui: Control = $UI/VrOfficesUi
@onready var dialogue: Control = $UI/DialogueOverlay
@onready var saving_overlay: Control = $UI/SavingOverlay
@onready var bgm: AudioStreamPlayer = $Bgm

var _npc_counter := 0
var _selected_npc: Node = null

var _profiles: RefCounted = null
var _chat_history: RefCounted = null
var _world_state: RefCounted = null
var _dialogue_ctrl: RefCounted = null
var _input_ctrl: RefCounted = null
var _move_ctrl: RefCounted = null

var _save_id: String = "slot1"
var _proxy_base_url: String = "http://127.0.0.1:8787/v1"
var _model: String = "gpt-5.2"
var _oa: Node = null
var _quitting := false

func _ready() -> void:
	randomize()
	if get_tree() != null:
		# Give ourselves a chance to autosave before quitting.
		get_tree().auto_accept_quit = false
	_move_ctrl = _MoveControllerScript.new(self, floor, move_indicators, camera_rig, _MoveIndicatorScene)
	_load_env_defaults()
	_configure_openagentic()
	if npc_scene == null:
		npc_scene = preload("res://vr_offices/npc/Npc.tscn")

	ui.add_npc_pressed.connect(add_npc)
	ui.remove_selected_pressed.connect(remove_selected)
	if ui.has_signal("culture_changed"):
		ui.connect("culture_changed", Callable(self, "set_culture"))

	_BgmScript.configure(bgm, _OAData.BGM_PATH, _is_headless())
	_profiles = _ProfilesScript.new(_OAData.MODEL_PATHS, _OAData.CULTURE_NAMES, culture_code)
	_chat_history = _ChatHistoryScript.new()
	_world_state = _WorldStateScript.new()
	_dialogue_ctrl = _DialogueControllerScript.new(
		self,
		camera_rig,
		dialogue,
		_oa,
		_chat_history,
		Callable(self, "_is_headless"),
		Callable(self, "_effective_save_id")
	)
	if dialogue != null and _dialogue_ctrl != null:
		if dialogue.has_signal("message_submitted"):
			dialogue.connect("message_submitted", Callable(_dialogue_ctrl, "on_message_submitted"))
		if dialogue.has_signal("closed"):
			dialogue.connect("closed", Callable(_dialogue_ctrl, "exit_talk"))

	_input_ctrl = _InputControllerScript.new(
		self,
		dialogue,
		camera_rig,
		_dialogue_ctrl,
		Callable(self, "_command_selected_move_to_click"),
		Callable(self, "select_npc")
	)
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
			_oa.set("system_prompt", _OAData.SYSTEM_PROMPT_ZH)
	_oa.set_approver(func(_q: Dictionary, _ctx: Dictionary) -> bool:
		return true
	)
	_install_openagentic_turn_hooks()

func _effective_save_id() -> String:
	var sid := ""
	if _oa != null and _oa.has_method("get"):
		var v: Variant = _oa.get("save_id")
		if v != null:
			sid = String(v)
	if sid.strip_edges() == "":
		sid = _save_id
	return sid

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

func _is_headless() -> bool:
	# `OS.has_feature("headless")` is not reliable across Godot builds; prefer DisplayServer.
	# When launched with `--headless`, DisplayServer name is typically "headless".
	return DisplayServer.get_name() == "headless" or OS.has_feature("server") or OS.has_feature("headless")

func _apply_ui_state() -> void:
	if ui == null:
		return
	if ui.has_method("set_can_add"):
		ui.call("set_can_add", _profiles != null and _profiles.call("can_add"))
	if ui.has_method("set_status_text"):
		ui.call("set_status_text", "")

func _unhandled_input(event: InputEvent) -> void:
	if _input_ctrl != null:
		_input_ctrl.call("handle_unhandled_input", event, _selected_npc)

func _enter_talk(npc: Node) -> void:
	if _dialogue_ctrl != null:
		_dialogue_ctrl.call("enter_talk", npc)
func _exit_talk() -> void:
	if _dialogue_ctrl != null:
		_dialogue_ctrl.call("exit_talk")
func _command_selected_move_to_click(screen_pos: Vector2) -> void:
	if _move_ctrl != null:
		_move_ctrl.call("command_selected_move_to_click", _selected_npc, screen_pos)

func add_npc() -> Node:
	if _profiles == null or not _profiles.call("can_add"):
		if ui != null and ui.has_method("set_status_text"):
			ui.call("set_status_text", "Reached max NPCs (%d). Remove one to add more." % _OAData.MAX_NPCS)
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

	var profile_index := int(_profiles.call("take_random_index"))
	if profile_index < 0:
		return null

	# Default NPC scene supports these properties.
	npc.set("npc_id", npc_id)
	npc.set("model_path", _OAData.MODEL_PATHS[profile_index])
	npc.set("display_name", String(_profiles.call("name_for_profile", profile_index)))
	npc.set("wander_bounds", Rect2(Vector2(-spawn_extent.x, -spawn_extent.y), Vector2(spawn_extent.x * 2.0, spawn_extent.y * 2.0)))
	npc.set("load_model_on_ready", not _is_headless())

	npc_root.add_child(npc)
	if _move_ctrl != null:
		_move_ctrl.call("connect_npc_signals", npc)
	select_npc(npc)
	_apply_ui_state()
	autosave()
	return npc

func remove_selected() -> void:
	if _selected_npc == null or not is_instance_valid(_selected_npc):
		return

	var to_remove := _selected_npc
	if _move_ctrl != null:
		_move_ctrl.call("clear_move_indicator_for_node", to_remove)
	var model_path := ""
	if to_remove.has_method("get") and to_remove.get("model_path") != null:
		model_path = String(to_remove.get("model_path"))
	if _profiles != null:
		_profiles.call("release_model", model_path)

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

func set_culture(code: String) -> void:
	if not _OAData.has_culture(code):
		return
	culture_code = code
	if _profiles != null:
		_profiles.call("set_culture", culture_code)
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
		var idx := -1
		if _profiles != null:
			idx = int(_profiles.call("profile_index_for_model", mp))
		if idx >= 0 and _profiles != null:
			node.set("display_name", String(_profiles.call("name_for_profile", idx)))
	# Refresh selected label.
	if _selected_npc != null and is_instance_valid(_selected_npc):
		select_npc(_selected_npc)
func autosave() -> void:
	_save_world_state()

func _save_world_state() -> void:
	if _save_id.strip_edges() == "":
		return
	if npc_root == null:
		return
	if _world_state == null:
		return
	var st: Dictionary = _world_state.call("build_state", _save_id, culture_code, _npc_counter, npc_root)
	_world_state.call("write_state", _save_id, st)

func _load_world_state() -> void:
	if _save_id.strip_edges() == "":
		return
	if npc_root == null:
		return
	if _world_state == null:
		return
	var st: Dictionary = _world_state.call("read_state", _save_id)
	if st.is_empty():
		return

	var v := int(st.get("version", 1))
	if v != 1:
		return

	var cc := String(st.get("culture_code", culture_code)).strip_edges()
	if cc != "" and _OAData.has_culture(cc):
		culture_code = cc
		if _profiles != null:
			_profiles.call("set_culture", culture_code)

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

		var idx := -1
		if _profiles != null:
			_profiles.call("reserve_model", model_path)
			idx = int(_profiles.call("profile_index_for_model", model_path))
		if idx < 0:
			continue

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
		if _profiles != null:
			npc.set("display_name", String(_profiles.call("name_for_profile", idx)))
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
			if _move_ctrl != null:
				_move_ctrl.call("connect_npc_signals", npc)

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
