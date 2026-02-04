extends Control

const IrcTestClient := preload("res://vr_offices/ui/IrcTestClient.gd")
const _IrcNames := preload("res://vr_offices/core/irc/VrOfficesIrcNames.gd")
const _MediaConfig := preload("res://vr_offices/core/media/VrOfficesMediaConfig.gd")
const _MediaConfigStore := preload("res://vr_offices/core/media/VrOfficesMediaConfigStore.gd")
const _MediaHealth := preload("res://vr_offices/core/media/VrOfficesMediaHealth.gd")
const _MediaCache := preload("res://vr_offices/ui/VrOfficesMediaCache.gd")
const _MediaSendLog := preload("res://vr_offices/core/media/VrOfficesMediaSendLog.gd")

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
@onready var copy_desk_info_button: Button = %CopyDeskInfoButton
@onready var desk_log: RichTextLabel = %DeskLog

@onready var media_base_url_edit: LineEdit = %MediaBaseUrlEdit
@onready var media_token_edit: LineEdit = %MediaTokenEdit
@onready var media_save_button: Button = %MediaSaveButton
@onready var media_reload_button: Button = %MediaReloadButton
@onready var media_health_button: Button = %MediaHealthButton
@onready var media_health_label: Label = %MediaHealthLabel
@onready var media_open_folder_button: Button = %MediaOpenFolderButton
@onready var send_log_refresh_button: Button = %SendLogRefreshButton
@onready var send_log_list: ItemList = %SendLogList

var _world: Node = null
var _desk_manager: RefCounted = null
var _config: Dictionary = {}

var _test_client: Node = null
var _selected_desk_id: String = ""
var _desk_snapshots: Array[Dictionary] = []

var _media_transport_override: Callable = Callable()

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
	if copy_desk_info_button != null:
		copy_desk_info_button.pressed.connect(_on_copy_desk_info_pressed)

	if media_save_button != null:
		media_save_button.pressed.connect(_on_media_save_pressed)
	if media_reload_button != null:
		media_reload_button.pressed.connect(_on_media_reload_pressed)
	if media_health_button != null:
		media_health_button.pressed.connect(_on_media_health_pressed)
	if media_open_folder_button != null:
		media_open_folder_button.pressed.connect(_on_media_open_folder_pressed)
	if send_log_refresh_button != null:
		send_log_refresh_button.pressed.connect(_refresh_send_log)

	if backdrop != null:
		backdrop.gui_input.connect(_on_backdrop_gui_input)

	_update_test_status("")
	_ensure_test_client()
	_update_media_health("")

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
	_load_media_fields()
	_refresh_send_log()
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

func _resolve_save_id() -> String:
	var oa := get_node_or_null("/root/OpenAgentic") as Node
	if oa == null:
		return ""
	var v: Variant = oa.get("save_id") if oa.has_method("get") else null
	return String(v).strip_edges() if v != null else ""

func _effective_media_cfg() -> Dictionary:
	var env: Dictionary = _MediaConfig.from_environment()
	var sid := _resolve_save_id()
	if sid != "":
		var rd: Dictionary = _MediaConfigStore.load_config(sid)
		if bool(rd.get("ok", false)) and typeof(rd.get("config", null)) == TYPE_DICTIONARY:
			var cfg: Dictionary = rd.get("config", {})
			var base := String(cfg.get("base_url", "")).strip_edges()
			var tok := String(cfg.get("bearer_token", "")).strip_edges()
			var base2 := base if base != "" else String(env.get("base_url", "")).strip_edges()
			var tok2 := tok if tok != "" else String(env.get("bearer_token", "")).strip_edges()
			return {"base_url": base2, "bearer_token": tok2}
	return env

func _load_media_fields() -> void:
	var cfg: Dictionary = _effective_media_cfg()
	if media_base_url_edit != null:
		media_base_url_edit.text = String(cfg.get("base_url", "")).strip_edges()
	if media_token_edit != null:
		media_token_edit.text = String(cfg.get("bearer_token", "")).strip_edges()
	_update_media_health("")

func _on_media_save_pressed() -> void:
	var sid := _resolve_save_id()
	if sid == "":
		_update_media_health("Missing save_id")
		return
	var base := media_base_url_edit.text.strip_edges() if media_base_url_edit != null else ""
	var tok := media_token_edit.text.strip_edges() if media_token_edit != null else ""
	var wr: Dictionary = _MediaConfigStore.save_config(sid, {"base_url": base, "bearer_token": tok})
	if bool(wr.get("ok", false)):
		_update_media_health("Saved")
	else:
		_update_media_health("Save failed: %s" % String(wr.get("error", "WriteFailed")))
	_refresh_send_log()

func _on_media_reload_pressed() -> void:
	_load_media_fields()
	_refresh_send_log()

func _on_media_health_pressed() -> void:
	var base := media_base_url_edit.text.strip_edges() if media_base_url_edit != null else ""
	if base == "":
		_update_media_health("Missing base URL")
		return
	_update_media_health("Checking…")
	var rr: Dictionary = await _MediaHealth.check_health(base, _media_transport_override)
	if not bool(rr.get("ok", false)):
		_update_media_health("FAIL %d (%sms)" % [int(rr.get("status", 0)), int(rr.get("ms", 0))])
		return
	_update_media_health("OK %d (%sms)" % [int(rr.get("status", 0)), int(rr.get("ms", 0))])

func _on_media_open_folder_pressed() -> void:
	var sid := _resolve_save_id()
	if sid == "":
		_update_media_health("Missing save_id")
		return
	var dir := String(_MediaCache.media_cache_dir(sid)).strip_edges()
	if dir == "":
		_update_media_health("Bad cache dir")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	if DisplayServer.get_name() == "headless":
		_update_media_health("Headless: cannot open folder")
		return
	OS.shell_open(ProjectSettings.globalize_path(dir))

func _refresh_send_log() -> void:
	if send_log_list == null:
		return
	send_log_list.clear()
	var sid := _resolve_save_id()
	if sid == "":
		send_log_list.add_item("(Missing save_id)")
		return
	var rd: Dictionary = _MediaSendLog.list_recent(sid, 50)
	if not bool(rd.get("ok", false)):
		send_log_list.add_item("(Read failed)")
		return
	var items0: Variant = rd.get("items", [])
	var items: Array = items0 as Array if typeof(items0) == TYPE_ARRAY else []
	for it0 in items:
		if typeof(it0) != TYPE_DICTIONARY:
			continue
		var it: Dictionary = it0 as Dictionary
		var ts := int(it.get("ts", 0))
		var npc := String(it.get("npc_id", ""))
		var ref0: Variant = it.get("ref", {})
		var ref: Dictionary = ref0 as Dictionary if typeof(ref0) == TYPE_DICTIONARY else {}
		var name := String(ref.get("name", ""))
		var mid := String(ref.get("id", ""))
		var mime := String(ref.get("mime", ""))
		send_log_list.add_item("%d %s %s %s %s" % [ts, npc, mid, mime, name])

func _update_media_health(text: String) -> void:
	if media_health_label != null:
		media_health_label.text = text

func _test_set_media_transport(transport: Callable) -> void:
	_media_transport_override = transport

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
	if copy_desk_info_button != null:
		copy_desk_info_button.disabled = true
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
		var is_ready := bool(it.get("ready", false))
		desk_list.add_item("%s  [%s]%s" % [did, status, " ready" if is_ready else ""])
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
	var dc := String(snap.get("device_code", "")).strip_edges()
	var bound_npc_id := String(snap.get("bound_npc_id", "")).strip_edges()
	var bound_npc_name := String(snap.get("bound_npc_name", "")).strip_edges()
	var status := String(snap.get("status", ""))
	var is_ready := bool(snap.get("ready", false))
	var dc_canon := _IrcNames.canonicalize_device_code(dc)
	var remote_bash_should_be := bound_npc_id != "" and _IrcNames.is_valid_device_code_canonical(dc_canon)
	var remote_bash_should_be_s := "true" if remote_bash_should_be else "false"
	var log_abs := String(snap.get("log_file_abs", ""))
	var log_user := String(snap.get("log_file_user", ""))
	var log_line := ""
	if log_abs.strip_edges() != "":
		log_line = "\nlog=%s" % log_abs
	elif log_user.strip_edges() != "":
		log_line = "\nlog=%s" % log_user
	desk_info_label.text = "desk=%s  ws=%s\nchannel=%s\ndevice_code=%s\nbound_npc_id=%s\nbound_npc_name=%s\nremote_bash_visible_should_be=%s\nstatus=%s  ready=%s%s" % [_selected_desk_id, ws, ch, dc, bound_npc_id, bound_npc_name, remote_bash_should_be_s, status, "true" if is_ready else "false", log_line]
	if copy_desk_info_button != null:
		copy_desk_info_button.disabled = desk_info_label.text.strip_edges() == ""
	desk_log.text = ""
	var lines0: Variant = snap.get("log_lines", [])
	if lines0 is Array:
		for l0 in lines0 as Array:
			desk_log.text += String(l0) + "\n"

func _on_copy_desk_info_pressed() -> void:
	if desk_info_label == null:
		return
	var txt := desk_info_label.text.strip_edges()
	if txt == "":
		return
	# Clipboard does not always exist in headless/server runs; avoid noise.
	if DisplayServer.get_name() == "headless" or OS.has_feature("server") or OS.has_feature("headless"):
		return
	DisplayServer.clipboard_set(txt)

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
