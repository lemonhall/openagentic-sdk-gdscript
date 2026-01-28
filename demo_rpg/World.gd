extends Node2D

enum Mode { WALK, TALK }

@onready var _player: Node = $Player
@onready var _npcs: Node = $NPCs
@onready var _prompt: Control = $UI/InteractPrompt
@onready var _dialogue: Control = $UI/DialogueBox

var _mode: Mode = Mode.WALK
var _near_npc: Node = null
var _busy: bool = false

var _save_id: String = "slot1"
var _proxy_base_url: String = "http://127.0.0.1:8787/v1"
var _model: String = "gpt-5.2"

var _oa: Node = null

func _ready() -> void:
	_ensure_input_actions()
	_load_env_defaults()
	_configure_openagentic()
	_wire_npcs()
	if _prompt != null:
		_prompt.hide_prompt()
	if _dialogue != null:
		if _dialogue.has_signal("message_submitted"):
			_dialogue.message_submitted.connect(_on_dialogue_message_submitted)
		if _dialogue.has_signal("closed"):
			_dialogue.closed.connect(func() -> void:
				_exit_talk()
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
		push_error("Missing autoload: OpenAgentic")
		return
	_oa.set_save_id(_save_id)
	_oa.configure_proxy_openai_responses(_proxy_base_url, _model)
	_oa.set_approver(func(_q: Dictionary, _ctx: Dictionary) -> bool:
		return true
	)

func _ensure_input_actions() -> void:
	if InputMap.has_action("interact"):
		return
	InputMap.add_action("interact")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	InputMap.action_add_event("interact", ev)

func _wire_npcs() -> void:
	if _npcs == null:
		return
	for c in _npcs.get_children():
		if c != null and c.has_signal("player_in_range"):
			c.player_in_range.connect(_on_player_in_range)

func _unhandled_input(_ev: InputEvent) -> void:
	if _mode == Mode.TALK:
		if Input.is_action_just_pressed("ui_cancel"):
			_exit_talk()
		return

	if _near_npc != null and Input.is_action_just_pressed("interact"):
		_enter_talk(_near_npc)

func _on_player_in_range(npc: Node, in_range: bool) -> void:
	if npc == null:
		return
	if in_range:
		_near_npc = npc
		if _prompt != null:
			var name := String(npc.get("display_name"))
			_prompt.show_for(name if name.strip_edges() != "" else "NPC")
		return

	if _near_npc == npc:
		_near_npc = null
		if _prompt != null:
			_prompt.hide_prompt()

func _enter_talk(_npc: Node) -> void:
	_mode = Mode.TALK
	if _prompt != null:
		_prompt.hide_prompt()
	if _player != null and _player.has_method("set_enabled"):
		_player.set_enabled(false)
	if _dialogue != null and _dialogue.has_method("open"):
		_dialogue.open(String(_npc.get("npc_id")), String(_npc.get("display_name")))

func _exit_talk() -> void:
	if _mode != Mode.TALK:
		return
	if _busy:
		return
	_mode = Mode.WALK
	if _player != null and _player.has_method("set_enabled"):
		_player.set_enabled(true)
	if _dialogue != null and _dialogue.visible:
		_dialogue.close()

func _on_dialogue_message_submitted(text: String) -> void:
	if _mode != Mode.TALK:
		return
	if _busy:
		return
	var npc_id := ""
	if _dialogue != null and _dialogue.has_method("get_npc_id"):
		npc_id = String(_dialogue.get_npc_id())
	if npc_id.strip_edges() == "":
		return
	_start_turn(npc_id, text)

func _start_turn(npc_id: String, text: String) -> void:
	_busy = true
	if _dialogue != null and _dialogue.has_method("set_busy"):
		_dialogue.set_busy(true)
	if _dialogue != null and _dialogue.has_method("begin_assistant"):
		_dialogue.begin_assistant()

	if _oa == null:
		push_error("OpenAgentic not configured")
		_busy = false
		if _dialogue != null and _dialogue.has_method("set_busy"):
			_dialogue.set_busy(false)
		return

	await _oa.run_npc_turn(npc_id, text, Callable(self, "_on_agent_event"))

	_busy = false
	if _dialogue != null and _dialogue.has_method("set_busy"):
		_dialogue.set_busy(false)

func _on_agent_event(ev: Dictionary) -> void:
	var t := String(ev.get("type", ""))
	if t == "assistant.delta":
		if _dialogue != null and _dialogue.has_method("append_assistant_delta"):
			_dialogue.append_assistant_delta(String(ev.get("text_delta", "")))
		return
	if t == "result":
		if _dialogue != null and _dialogue.has_method("end_assistant"):
			_dialogue.end_assistant()
		return
