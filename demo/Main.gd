extends Control

@onready var _chat_log: RichTextLabel = $"Root/ChatLog"
@onready var _live: RichTextLabel = $"Root/LiveOutput"
@onready var _input: LineEdit = $"Root/InputRow/Input"
@onready var _send: Button = $"Root/InputRow/Send"

var _busy: bool = false
var _assistant_buf: String = ""

var _save_id: String = "slot1"
var _npc_id: String = "npc_1"
var _proxy_base_url: String = "http://127.0.0.1:8787/v1"
var _model: String = "gpt-5.2"

func _ready() -> void:
	_load_env_defaults()
	_wire_ui()
	_configure_openagentic()
	_append_chat("[i]Ready.[/i] Proxy: %s | Model: %s | Save: %s | NPC: %s" % [_proxy_base_url, _model, _save_id, _npc_id])

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
	v = OS.get_environment("OPENAGENTIC_NPC_ID")
	if v.strip_edges() != "":
		_npc_id = v.strip_edges()

func _wire_ui() -> void:
	_send.pressed.connect(_on_send_pressed)
	_input.text_submitted.connect(func(_t: String) -> void:
		_on_send_pressed()
	)
	_input.grab_focus()

func _configure_openagentic() -> void:
	OpenAgentic.set_save_id(_save_id)
	# Proxy holds the real API key; the client sends no auth token by default.
	OpenAgentic.configure_proxy_openai_responses(_proxy_base_url, _model)
	OpenAgentic.set_approver(func(_q: Dictionary, _ctx: Dictionary) -> bool:
		return true
	)

func _append_chat(line: String) -> void:
	_chat_log.append_text(line + "\n")

func _set_busy(b: bool) -> void:
	_busy = b
	_input.editable = not b
	_send.disabled = b

func _on_send_pressed() -> void:
	if _busy:
		return
	var text := _input.text.strip_edges()
	if text == "":
		return
	_input.text = ""
	_set_busy(true)
	_live.clear()
	_assistant_buf = ""

	_append_chat("[b]You:[/b] " + text)

	await OpenAgentic.run_npc_turn(_npc_id, text, Callable(self, "_on_agent_event"))
	_set_busy(false)
	_input.grab_focus()

func _on_agent_event(ev: Dictionary) -> void:
	var t := String(ev.get("type", ""))
	if t == "assistant.delta":
		_assistant_buf += String(ev.get("text_delta", ""))
		_live.text = "[b]%s:[/b] %s" % [_npc_id, _assistant_buf]
		return
	if t == "tool.use" or t == "tool.result":
		_append_chat("[color=gray]%s[/color]" % JSON.stringify(ev))
		return
	if t == "result":
		if _assistant_buf.strip_edges() != "":
			_append_chat("[b]%s:[/b] %s" % [_npc_id, _assistant_buf])
		_live.clear()
		return
