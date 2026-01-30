extends Control

const IrcClient := preload("res://addons/irc_client/IrcClient.gd")
const DemoIrcConfig := preload("res://demo_irc/DemoIrcConfig.gd")
const DemoIrcInbound := preload("res://demo_irc/DemoIrcInbound.gd")
const DemoIrcLogFormat := preload("res://demo_irc/DemoIrcLogFormat.gd")

@onready var _host: LineEdit = $"Root/ConnectionPanel/VBox/Fields/Host"
@onready var _port: SpinBox = $"Root/ConnectionPanel/VBox/Fields/Port"
@onready var _tls: CheckBox = $"Root/ConnectionPanel/VBox/Fields/Tls"
@onready var _nick: LineEdit = $"Root/ConnectionPanel/VBox/Fields/Nick"
@onready var _user: LineEdit = $"Root/ConnectionPanel/VBox/Fields/User"
@onready var _realname: LineEdit = $"Root/ConnectionPanel/VBox/Fields/Realname"
@onready var _channel: LineEdit = $"Root/ConnectionPanel/VBox/Fields/Channel"
@onready var _connect: Button = $"Root/ConnectionPanel/VBox/Buttons/Connect"
@onready var _disconnect: Button = $"Root/ConnectionPanel/VBox/Buttons/Disconnect"
@onready var _join: Button = $"Root/ConnectionPanel/VBox/Buttons/Join"
@onready var _chat_log: RichTextLabel = $"Root/ChatLog"
@onready var _input: LineEdit = $"Root/InputRow/Input"
@onready var _send: Button = $"Root/InputRow/Send"

var _irc: Node = null
var _connected: bool = false
var _active_target: String = ""
var _cfg := DemoIrcConfig.new()
var _inbound := DemoIrcInbound.new()

func _ready() -> void:
	_irc = IrcClient.new()
	add_child(_irc)

	_irc.connected.connect(_on_irc_connected)
	_irc.disconnected.connect(_on_irc_disconnected)
	_irc.error.connect(_on_irc_error)
	_irc.message_received.connect(_on_irc_message_received)
	_irc.ctcp_action_received.connect(_on_irc_ctcp_action_received)

	_inbound.configure(Callable(self, "_append_chat"), Callable(self, "_append_status"))

	_cfg.load_from_user()
	_apply_config_to_ui(_cfg)

	_connect.pressed.connect(_on_connect_pressed)
	_disconnect.pressed.connect(_on_disconnect_pressed)
	_join.pressed.connect(_on_join_pressed)
	_send.pressed.connect(_on_send_pressed)
	_input.text_submitted.connect(func(_t: String) -> void:
		_on_send_pressed()
	)

	_append_status("Ready. (Fields restored; no auto-connect.)")
	_update_buttons()
	_input.grab_focus()

func _process(dt: float) -> void:
	if _irc != null:
		_irc.call("poll", dt)

func _apply_config_to_ui(cfg: DemoIrcConfig) -> void:
	_host.text = cfg.host
	_port.value = float(cfg.port)
	_tls.button_pressed = cfg.tls_enabled
	_nick.text = cfg.nick
	_user.text = cfg.user
	_realname.text = cfg.realname
	_channel.text = cfg.channel

func _read_ui_to_config(cfg: DemoIrcConfig) -> void:
	cfg.host = _host.text.strip_edges()
	cfg.port = int(_port.value)
	cfg.tls_enabled = _tls.button_pressed
	cfg.nick = _nick.text.strip_edges()
	cfg.user = _user.text.strip_edges()
	cfg.realname = _realname.text.strip_edges()
	cfg.channel = _channel.text.strip_edges()

func _on_connect_pressed() -> void:
	_read_ui_to_config(_cfg)
	_cfg.normalize()
	_apply_config_to_ui(_cfg)
	_cfg.save_to_user()

	_active_target = _cfg.channel
	_connected = false
	_update_buttons()

	_irc.call("close_connection")
	if _cfg.nick.strip_edges() == "":
		_append_status("Missing nick.")
		return
	_irc.call("set_nick", _cfg.nick)
	_irc.call("set_user", _cfg.user, "0", "*", _cfg.realname)

	if _cfg.host.strip_edges() == "" or _cfg.port <= 0:
		_append_status("Missing host/port.")
		return

	_append_status("Connecting to %s:%d (%s)..." % [_cfg.host, _cfg.port, "TLS" if _cfg.tls_enabled else "TCP"])
	if _cfg.tls_enabled:
		_irc.call("connect_to_tls", _cfg.host, _cfg.port)
	else:
		_irc.call("connect_to", _cfg.host, _cfg.port)

func _on_disconnect_pressed() -> void:
	_irc.call("close_connection")
	_connected = false
	_update_buttons()
	_append_status("Disconnected.")

func _on_join_pressed() -> void:
	_read_ui_to_config(_cfg)
	_cfg.normalize()
	_apply_config_to_ui(_cfg)
	_cfg.save_to_user()

	var ch := _cfg.channel.strip_edges()
	if ch == "":
		_append_status("Missing channel.")
		return
	_active_target = ch
	_irc.call("join", ch)
	_append_status("JOIN " + ch)

func _on_send_pressed() -> void:
	var text := _input.text.strip_edges()
	if text == "":
		return
	if _active_target.strip_edges() == "":
		_append_status("No active channel/target.")
		return
	_input.text = ""

	if text.begins_with("/me "):
		var action := text.substr(4).strip_edges()
		if action != "":
			_irc.call("ctcp_action", _active_target, action)
			_append_chat("* %s %s" % [_cfg.nick if _cfg.nick.strip_edges() != "" else "me", action])
		return

	_irc.call("privmsg", _active_target, text)
	_append_chat("<%s> %s" % [_cfg.nick if _cfg.nick.strip_edges() != "" else "me", text])

func _on_irc_connected() -> void:
	_connected = true
	_update_buttons()
	_append_status("Connected.")

func _on_irc_disconnected() -> void:
	_connected = false
	_update_buttons()
	_append_status("Disconnected.")

func _on_irc_error(msg: String) -> void:
	_append_status("[error] " + msg)

func _on_irc_ctcp_action_received(prefix: String, _target: String, text: String) -> void:
	_append_chat("* %s %s" % [_nick_from_prefix(prefix), text])

func _on_irc_message_received(msg: RefCounted) -> void:
	_inbound.on_message(msg, _cfg.nick)

func _nick_from_prefix(prefix: String) -> String:
	var p := prefix
	if p.begins_with(":"):
		p = p.substr(1)
	var bang := p.find("!")
	if bang >= 0:
		return p.substr(0, bang)
	return p

func _append_status(line: String) -> void:
	_append_chat("[i]%s[/i]" % line)

func _append_chat(line: String) -> void:
	if _chat_log == null:
		return
	var stamped := String(DemoIrcLogFormat.prepend(Time.get_time_string_from_system(), line))
	_chat_log.append_text(stamped + "\n")

func _update_buttons() -> void:
	_connect.disabled = _connected
	_disconnect.disabled = not _connected
	_join.disabled = not _connected
	_send.disabled = not _connected
	_input.editable = _connected
