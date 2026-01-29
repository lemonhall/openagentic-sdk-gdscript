extends Node3D

const _OAData := preload("res://vr_offices/core/VrOfficesData.gd")
const _AgentBridgeScript := preload("res://vr_offices/core/VrOfficesAgentBridge.gd")
const _NpcManagerScript := preload("res://vr_offices/core/VrOfficesNpcManager.gd")
const _SaveControllerScript := preload("res://vr_offices/core/VrOfficesSaveController.gd")
const _ProfilesScript := preload("res://vr_offices/core/VrOfficesNpcProfiles.gd")
const _ChatHistoryScript := preload("res://vr_offices/core/VrOfficesChatHistory.gd")
const _WorldStateScript := preload("res://vr_offices/core/VrOfficesWorldState.gd")
const _DialogueControllerScript := preload("res://vr_offices/core/VrOfficesDialogueController.gd")
const _InputControllerScript := preload("res://vr_offices/core/VrOfficesInputController.gd")
const _MoveControllerScript := preload("res://vr_offices/core/VrOfficesMoveController.gd")
const _WorkspaceManagerScript := preload("res://vr_offices/core/VrOfficesWorkspaceManager.gd")
const _BgmScript := preload("res://vr_offices/core/VrOfficesBgm.gd")
const _MoveIndicatorScene := preload("res://vr_offices/fx/MoveIndicator.tscn")

@export var npc_scene: PackedScene
@export var npc_spawn_y := 2.0
@export var spawn_extent := Vector2(6.0, 4.0) # X,Z half extents
@export var culture_code := "zh-CN"

@onready var floor_body: StaticBody3D = $Floor
@onready var npc_root: Node3D = $NpcRoot
@onready var move_indicators: Node3D = $MoveIndicators
@onready var camera_rig: Node3D = $CameraRig
@onready var ui: Control = $UI/VrOfficesUi
@onready var dialogue: Control = $UI/DialogueOverlay
@onready var saving_overlay: Control = $UI/SavingOverlay
@onready var bgm: AudioStreamPlayer = $Bgm

var _agent: RefCounted = null
var _profiles: RefCounted = null
var _npc_manager: RefCounted = null
var _chat_history: RefCounted = null
var _world_state: RefCounted = null
var _save_ctrl: RefCounted = null
var _dialogue_ctrl: RefCounted = null
var _input_ctrl: RefCounted = null
var _move_ctrl: RefCounted = null
var _workspace_manager: RefCounted = null
var _quitting := false

func _ready() -> void:
	randomize()
	if get_tree() != null:
		# Give ourselves a chance to autosave before quitting.
		get_tree().auto_accept_quit = false
	_move_ctrl = _MoveControllerScript.new(self, floor_body, move_indicators, camera_rig, _MoveIndicatorScene)
	_agent = _AgentBridgeScript.new(self, Callable(self, "_find_npc_by_id"))
	_agent.call("configure_from_environment")
	var oa: Node = _agent.call("configure_openagentic") as Node
	if npc_scene == null:
		npc_scene = preload("res://vr_offices/npc/Npc.tscn")

	ui.add_npc_pressed.connect(add_npc)
	ui.remove_selected_pressed.connect(remove_selected)
	if ui.has_signal("culture_changed"):
		ui.connect("culture_changed", Callable(self, "set_culture"))

	_BgmScript.configure(bgm, _OAData.BGM_PATH, _is_headless())
	_profiles = _ProfilesScript.new(_OAData.MODEL_PATHS, _OAData.CULTURE_NAMES, culture_code)
	_npc_manager = _NpcManagerScript.new(
		self,
		npc_scene,
		npc_root,
		ui,
		_profiles,
		_move_ctrl,
		Callable(self, "_is_headless"),
		Callable(self, "autosave")
	)
	_npc_manager.call("set_spawn_params", npc_spawn_y, spawn_extent)
	_npc_manager.call("set_culture", culture_code)

	_chat_history = _ChatHistoryScript.new()
	_world_state = _WorldStateScript.new()
	var bounds := Rect2(Vector2(-10.0, -10.0), Vector2(20.0, 20.0))
	if _move_ctrl != null:
		var b0: Variant = _move_ctrl.get("floor_bounds_xz")
		if b0 is Rect2:
			bounds = b0 as Rect2
	_workspace_manager = _WorkspaceManagerScript.new(bounds)
	_save_ctrl = _SaveControllerScript.new(_world_state, _npc_manager, Callable(_agent, "effective_save_id"), _workspace_manager)
	_dialogue_ctrl = _DialogueControllerScript.new(
		self,
		camera_rig,
		dialogue,
		oa,
		_chat_history,
		Callable(self, "_is_headless"),
		Callable(_agent, "effective_save_id")
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
	if _save_ctrl != null:
		_save_ctrl.call("load_world")
	if ui.has_method("set_culture"):
		ui.call("set_culture", culture_code)
	if get_tree() != null and get_tree().has_signal("about_to_quit"):
		get_tree().about_to_quit.connect(func() -> void:
			autosave()
		)

func _is_headless() -> bool:
	# `OS.has_feature("headless")` is not reliable across Godot builds; prefer DisplayServer.
	# When launched with `--headless`, DisplayServer name is typically "headless".
	return DisplayServer.get_name() == "headless" or OS.has_feature("server") or OS.has_feature("headless")

func _unhandled_input(event: InputEvent) -> void:
	if _input_ctrl != null:
		var selected: Node = null
		if _npc_manager != null:
			selected = _npc_manager.call("get_selected_npc") as Node
		_input_ctrl.call("handle_unhandled_input", event, selected)

func _enter_talk(npc: Node) -> void:
	if _dialogue_ctrl != null:
		_dialogue_ctrl.call("enter_talk", npc)
func _exit_talk() -> void:
	if _dialogue_ctrl != null:
		_dialogue_ctrl.call("exit_talk")
func _command_selected_move_to_click(screen_pos: Vector2) -> void:
	if _move_ctrl != null:
		var selected: Node = null
		if _npc_manager != null:
			selected = _npc_manager.call("get_selected_npc") as Node
		_move_ctrl.call("command_selected_move_to_click", selected, screen_pos)

func add_npc() -> Node:
	if _npc_manager == null:
		return null
	return _npc_manager.call("add_npc") as Node

func remove_selected() -> void:
	if _npc_manager != null:
		_npc_manager.call("remove_selected")

func select_npc(npc: Node) -> void:
	if _npc_manager != null:
		_npc_manager.call("select_npc", npc)

func set_culture(code: String) -> void:
	if _npc_manager != null:
		_npc_manager.call("set_culture", code)
func autosave() -> void:
	if _save_ctrl != null:
		_save_ctrl.call("save_world", npc_root)

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

func _find_npc_by_id(npc_id: String) -> Node:
	if _npc_manager == null:
		return null
	return _npc_manager.call("find_npc_by_id", npc_id) as Node
