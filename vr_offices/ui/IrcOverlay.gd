extends Control

const IrcTestClient := preload("res://vr_offices/ui/IrcTestClient.gd")

@onready var backdrop: ColorRect = $Backdrop
@onready var close_button: Button = %CloseButton
@onready var tabs: TabContainer = %Tabs

@onready var host_edit: LineEdit = %HostEdit
@onready var port_spin: SpinBox = %PortSpin
@onready var tls_check: CheckBox = %TlsCheck
@onready var server_name_edit: LineEdit = %ServerNameEdit
@onready var password_edit: LineEdit = %PasswordEdit
@onready var nicklen_spin: SpinBox = %NickLenSpin
@onready var channellen_spin: SpinBox = %ChannelLenSpin
@onready var test_nick_edit: LineEdit = %TestNickEdit
@onready var test_channel_edit: LineEdit = %TestChannelEdit
@onready var apply_button: Button = %ApplyButton
@onready var reload_button: Button = %ReloadButton

@onready var connect_button: Button = %ConnectButton
@onready var disconnect_button: Button = %DisconnectButton
@onready var join_button: Button = %JoinButton
@onready var test_status_label: Label = %StatusLabel
@onready var test_log: RichTextLabel = %Log
@onready var send_edit: LineEdit = %SendEdit
@onready var send_button: Button = %SendButton

@onready var refresh_button: Button = %RefreshButton
@onready var reconnect_all_button: Button = %ReconnectAllButton
@onready var desk_status_label: Label = %DeskStatusLabel
@onready var desk_list: ItemList = %DeskList
@onready var desk_info_label: Label = %DeskInfoLabel
@onready var desk_log: RichTextLabel = %DeskLog

var _world: Node = null
var _desk_manager: RefCounted = null
var _config: Dictionary = {}

var _test_client: Node = null
var _selected_desk_id: String = ""
var _desk_snapshots: Array[Dictionary] = []

func _ready() -> void:
	visible = false
	if close_button != null:
		close_button.pressed.connect(close)
	if apply_button != null:
		apply_button.pressed.connect(_on_apply_pressed)
	if reload_button != null:
		reload_button.pressed.connect(_on_reload_pressed)
	if connect_button != null:
		connect_button.pressed.connect(_on_test_connect_pressed)
	if disconnect_button != null:
		disconnect_button.pressed.connect(_on_test_disconnect_pressed)
	if join_button != null:
		join_button.pressed.connect(_on_test_join_pressed)
	if send_button != null:
		send_button.pressed.connect(_on_test_send_pressed)
	if send_edit != null:
		send_edit.text_submitted.connect(func(_t: String) -> void:
			_on_test_send_pressed()
		)
	if refresh_button != null:
		refresh_button.pressed.connect(_refresh_desks)
	if reconnect_all_button != null:
		reconnect_all_button.pressed.connect(_on_reconnect_all_pressed)
	if desk_list != null:
		desk_list.item_selected.connect(_on_desk_selected)

	if backdrop != null:
		backdrop.gui_input.connect(_on_backdrop_gui_input)

	_update_test_status("")
	_ensure_test_client()

func bind(world: Node, desk_manager: RefCounted) -> void:
	_world = world
	_desk_manager = desk_manager
	if _world != null and _world.has_method("get_irc_config"):
		set_config(_world.call("get_irc_config"))

func set_config(cfg: Dictionary) -> void:
	_config = cfg if cfg != null else {}
	if visible:
		_load_fields_from_config()

func open() -> void:
	visible = true
	_load_fields_from_config()
	_refresh_desks()
	call_deferred("_grab_focus")

func open_for_desk(desk_id: String) -> void:
	open()
	if tabs != null:
		tabs.current_tab = 2 # Desks
	call_deferred("_focus_desk_id", desk_id)

func close() -> void:
	if not visible:
		return
	_persist_config_to_world()
	visible = false
	if _test_client != null:
		_test_client.call("disconnect_now")

func _grab_focus() -> void:
	if host_edit != null:
		host_edit.grab_focus()

func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		accept_event()
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.physical_keycode == KEY_ESCAPE:
			close()
			accept_event()

func _on_backdrop_gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if backdrop != null and (event is InputEventMouseButton or event is InputEventMouseMotion):
		backdrop.accept_event()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			close()

func _load_fields_from_config() -> void:
	host_edit.text = String(_config.get("host", ""))
	port_spin.value = float(_config.get("port", 6667))
	tls_check.button_pressed = bool(_config.get("tls", false))
	server_name_edit.text = String(_config.get("server_name", ""))
	password_edit.text = String(_config.get("password", ""))
	nicklen_spin.value = float(_config.get("nicklen_default", 9))
	channellen_spin.value = float(_config.get("channellen_default", 50))
	test_nick_edit.text = String(_config.get("test_nick", "tester"))
	test_channel_edit.text = String(_config.get("test_channel", "#test"))

func _collect_config_from_fields() -> Dictionary:
	var host := host_edit.text.strip_edges()
	var test_channel := test_channel_edit.text.strip_edges()
	if test_channel != "" and not test_channel.begins_with("#"):
		test_channel = "#" + test_channel
	return {
		"host": host,
		"port": int(port_spin.value),
		"tls": tls_check.button_pressed,
		"server_name": server_name_edit.text.strip_edges(),
		"password": password_edit.text,
		"nicklen_default": int(nicklen_spin.value),
		"channellen_default": int(channellen_spin.value),
		"test_nick": test_nick_edit.text.strip_edges(),
		"test_channel": test_channel,
	}

func _on_apply_pressed() -> void:
	_persist_config_to_world()

func _on_reload_pressed() -> void:
	if _world == null or not _world.has_method("get_irc_config"):
		return
	set_config(_world.call("get_irc_config"))
	_load_fields_from_config()

func _persist_config_to_world() -> void:
	var cfg := _collect_config_from_fields()
	_config = cfg
	if _world != null and _world.has_method("set_irc_config"):
		_world.call("set_irc_config", cfg)
	if _test_client != null:
		_test_client.call("set_config", cfg)

func _ensure_test_client() -> void:
	if _test_client != null and is_instance_valid(_test_client):
		return
	_test_client = IrcTestClient.new()
	add_child(_test_client)
	_test_client.call("set_config", _collect_config_from_fields())
	_test_client.log_line.connect(func(line: String) -> void:
		_log_test(line)
	)
	_test_client.status_changed.connect(func(s: String) -> void:
		_update_test_status(s)
	)

func _on_test_connect_pressed() -> void:
	_ensure_test_client()
	_persist_config_to_world()
	var cfg := _collect_config_from_fields()
	_test_client.call("set_config", cfg)
	_test_client.call("connect_now")

func _on_test_disconnect_pressed() -> void:
	if _test_client != null:
		_test_client.call("disconnect_now")

func _on_test_join_pressed() -> void:
	if _test_client != null:
		_persist_config_to_world()
		_test_client.call("set_config", _collect_config_from_fields())
		_test_client.call("join_test_channel")

func _on_test_send_pressed() -> void:
	if _test_client == null:
		return
	var msg := send_edit.text.strip_edges()
	if msg == "":
		return
	send_edit.text = ""
	_persist_config_to_world()
	_test_client.call("set_config", _collect_config_from_fields())
	_test_client.call("send_test_message", msg)

func _log_test(line: String) -> void:
	var t := line.strip_edges()
	if t == "":
		return
	var ts := Time.get_time_string_from_system()
	test_log.text += "[%s] %s\n" % [ts, t]

func _update_test_status(s: String) -> void:
	if test_status_label != null:
		test_status_label.text = s

func _refresh_desks() -> void:
	_desk_snapshots = []
	desk_list.clear()
	desk_info_label.text = ""
	desk_log.text = ""
	desk_status_label.text = ""
	if _desk_manager == null or not _desk_manager.has_method("list_desk_irc_snapshots"):
		desk_status_label.text = "Desk manager not ready."
		return
	var snaps0: Variant = _desk_manager.call("list_desk_irc_snapshots")
	if not (snaps0 is Array):
		desk_status_label.text = "No desks."
		return
	for it0 in snaps0 as Array:
		if typeof(it0) != TYPE_DICTIONARY:
			continue
		var it := it0 as Dictionary
		_desk_snapshots.append(it)
		var did := String(it.get("desk_id", ""))
		var status := String(it.get("status", ""))
		var ready := bool(it.get("ready", false))
		desk_list.add_item("%s  [%s]%s" % [did, status, " ready" if ready else ""])
	desk_status_label.text = "Desks: %d" % _desk_snapshots.size()

func _on_reconnect_all_pressed() -> void:
	_persist_config_to_world()
	if _desk_manager != null and _desk_manager.has_method("reconnect_all_irc_links"):
		_desk_manager.call("reconnect_all_irc_links")
	_refresh_desks()

func _on_desk_selected(idx: int) -> void:
	if idx < 0 or idx >= _desk_snapshots.size():
		return
	var snap := _desk_snapshots[idx]
	_selected_desk_id = String(snap.get("desk_id", ""))
	var ws := String(snap.get("workspace_id", ""))
	var ch := String(snap.get("desired_channel", ""))
	var status := String(snap.get("status", ""))
	var ready := bool(snap.get("ready", false))
	desk_info_label.text = "desk=%s  ws=%s\nchannel=%s\nstatus=%s  ready=%s" % [_selected_desk_id, ws, ch, status, "true" if ready else "false"]
	desk_log.text = ""
	var lines0: Variant = snap.get("log_lines", [])
	if lines0 is Array:
		for l0 in lines0 as Array:
			desk_log.text += String(l0) + "\n"

func _focus_desk_id(desk_id: String) -> void:
	var did := desk_id.strip_edges()
	if did == "":
		return
	_refresh_desks()
	for i in range(_desk_snapshots.size()):
		var it := _desk_snapshots[i]
		if String(it.get("desk_id", "")).strip_edges() == did:
			desk_list.select(i)
			_on_desk_selected(i)
			return
