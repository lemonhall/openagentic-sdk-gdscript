extends Control

const _SkillsMpConfig := preload("res://addons/openagentic/core/OASkillsMpConfig.gd")
const _SkillsMpConfigStore := preload("res://addons/openagentic/core/OASkillsMpConfigStore.gd")
const _SkillsMpClient := preload("res://vr_offices/core/skillsmp/VrOfficesSkillsMpClient.gd")
const _SkillsMpHealth := preload("res://vr_offices/core/skillsmp/VrOfficesSkillsMpHealth.gd")

@onready var backdrop: ColorRect = $Backdrop
@onready var close_button: Button = %CloseButton
@onready var query_edit: LineEdit = %QueryEdit
@onready var search_button: Button = %SearchButton
@onready var sort_option: OptionButton = %SortOption
@onready var settings_button: Button = %SettingsButton
@onready var results_list: ItemList = %ResultsList
@onready var details_text: RichTextLabel = %DetailsText
@onready var status_label: Label = %StatusLabel
@onready var prev_page_button: Button = %PrevPageButton
@onready var next_page_button: Button = %NextPageButton
@onready var page_label: Label = %PageLabel

@onready var settings_popup: PopupPanel = %SkillsMpSettingsPopup
@onready var settings_base_url_edit: LineEdit = %SettingsBaseUrlEdit
@onready var settings_api_key_edit: LineEdit = %SettingsApiKeyEdit
@onready var settings_save_button: Button = %SettingsSaveButton
@onready var settings_test_button: Button = %SettingsTestButton
@onready var settings_close_button: Button = %SettingsCloseButton
@onready var settings_status_label: Label = %SettingsStatusLabel

var _client: RefCounted = _SkillsMpClient.new()
var _skillsmp_transport_override: Callable = Callable()

var _items: Array = []
var _current_query := ""
var _current_page := 1
var _limit := 20
var _total_pages := 0

const SETTINGS_POPUP_SIZE := Vector2i(620, 280)
const _DEBUG_LAST_SEARCH_PATH := "user://openagentic/saves/%s/vr_offices/skillsmp_last_search.json"

func _ready() -> void:
	visible = false
	if close_button != null:
		close_button.pressed.connect(close)
	if search_button != null:
		search_button.pressed.connect(_on_search_pressed)
	if query_edit != null:
		query_edit.text_submitted.connect(func(_t: String) -> void:
			_on_search_pressed()
		)
	if settings_button != null:
		settings_button.pressed.connect(_open_settings_popup)
	if prev_page_button != null:
		prev_page_button.pressed.connect(_on_prev_page_pressed)
	if next_page_button != null:
		next_page_button.pressed.connect(_on_next_page_pressed)
	if results_list != null:
		results_list.item_selected.connect(_on_result_selected)
	if settings_save_button != null:
		settings_save_button.pressed.connect(_on_settings_save_pressed)
	if settings_test_button != null:
		settings_test_button.pressed.connect(_on_settings_test_pressed)
	if settings_close_button != null:
		settings_close_button.pressed.connect(func() -> void:
			if settings_popup != null:
				settings_popup.hide()
		)
	_setup_sort_option()
	if backdrop != null:
		backdrop.gui_input.connect(_on_backdrop_gui_input)
	_update_status("")
	_update_page_label()

func open() -> void:
	visible = true
	call_deferred("_grab_focus")
	# Preload config into the settings UI so it's ready when opened.
	_load_settings_fields()
	var cfg: Dictionary = _effective_skillsmp_cfg()
	var key := str(cfg.get("api_key", "")).strip_edges()
	if key == "":
		_update_status("Missing API key. Open Settings to configure.")
	else:
		_update_status("")

func close() -> void:
	visible = false
	if settings_popup != null and settings_popup.visible:
		settings_popup.hide()

func _grab_focus() -> void:
	if query_edit != null:
		query_edit.grab_focus()
	elif close_button != null:
		close_button.grab_focus()

func _on_backdrop_gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if backdrop != null and (event is InputEventMouseButton or event is InputEventMouseMotion):
		backdrop.accept_event()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			close()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click:
			close()
			return

func set_skillsmp_transport_override(transport: Callable) -> void:
	_skillsmp_transport_override = transport

func search_skills(query: String) -> Dictionary:
	if query_edit != null:
		query_edit.text = query
	_current_query = query.strip_edges()
	_current_page = 1
	return await _run_search()

func _on_search_pressed() -> void:
	_current_query = query_edit.text.strip_edges() if query_edit != null else ""
	_current_page = 1
	await _run_search()

func _on_prev_page_pressed() -> void:
	if _current_page <= 1:
		return
	_current_page -= 1
	await _run_search()

func _on_next_page_pressed() -> void:
	if _total_pages > 0 and _current_page >= _total_pages:
		return
	_current_page += 1
	await _run_search()

func _run_search() -> Dictionary:
	var cfg: Dictionary = _effective_skillsmp_cfg()
	var base := str(cfg.get("base_url", "")).strip_edges()
	var key := str(cfg.get("api_key", "")).strip_edges()
	if base == "" or key == "":
		_update_status("Missing API key. Open Settings to configure.")
		_write_last_search_debug({"q": _current_query, "page": _current_page, "limit": _limit, "sort_by": _current_sort_by(), "base_url": base}, {"ok": false, "error": "MissingConfig", "status": 0})
		return {"ok": false, "error": "MissingConfig"}
	if _current_query == "":
		_update_status("Enter a query.")
		_write_last_search_debug({"q": _current_query, "page": _current_page, "limit": _limit, "sort_by": _current_sort_by(), "base_url": base}, {"ok": false, "error": "MissingQuery", "status": 0})
		return {"ok": false, "error": "MissingQuery"}

	_set_loading(true)
	_update_status("Searching…")

	var sort_by := _current_sort_by()
	var rr: Dictionary = await _client.call("search", base, key, _current_query, _current_page, _limit, sort_by, _skillsmp_transport_override)
	_set_loading(false)
	_write_last_search_debug({"q": _current_query, "page": _current_page, "limit": _limit, "sort_by": sort_by, "base_url": base}, rr)

	if not bool(rr.get("ok", false)):
		var code := str(rr.get("error_code", "")).strip_edges()
		var msg := str(rr.get("message", "")).strip_edges()
		var status := int(rr.get("status", 0))
		var parts := PackedStringArray()
		parts.append("Search failed")
		if status != 0:
			parts.append("(HTTP %d)" % status)
		if code != "":
			parts.append(code)
		if msg != "":
			parts.append(msg)
		_update_status(" ".join(parts))
		_render_items([])
		_total_pages = 0
		_update_page_label()
		return rr

	_items = rr.get("items", [])
	var pg: Dictionary = rr.get("pagination", {})
	_current_page = int(pg.get("page", _current_page))
	_total_pages = int(pg.get("total_pages", 0))
	_render_items(_items)
	_update_status("Loaded %d result(s)." % int(_items.size()))
	_update_page_label()
	return rr

func _write_last_search_debug(req: Dictionary, rr: Dictionary) -> void:
	var sid := _resolve_save_id()
	if sid == "":
		return
	var p := _DEBUG_LAST_SEARCH_PATH % sid
	var out := {
		"ts_unix": int(Time.get_unix_time_from_system()),
		"ts_ms": int(Time.get_ticks_msec()),
		"request": req,
		"ui": {
			"current_page": _current_page,
			"total_pages": _total_pages,
			"prev_disabled": prev_page_button != null and prev_page_button.disabled,
			"next_disabled": next_page_button != null and next_page_button.disabled,
			"page_label": page_label.text if page_label != null else "",
		},
		"response": {
			"ok": bool(rr.get("ok", false)),
			"status": int(rr.get("status", 0)),
			"error": str(rr.get("error", "")).strip_edges(),
			"error_code": str(rr.get("error_code", "")).strip_edges(),
			"message": str(rr.get("message", "")).strip_edges(),
			"url": str(rr.get("url", "")).strip_edges(),
			"pagination": rr.get("pagination", {}),
			"raw": rr.get("raw", null),
		},
	}

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(p.get_base_dir()))
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(out, "  ") + "\n")
	f.close()

func _render_items(items: Array) -> void:
	if results_list == null:
		return
	results_list.clear()
	if details_text != null:
		details_text.text = ""
	for i in range(items.size()):
		var item0: Variant = items[i]
		var d: Dictionary = item0 as Dictionary if typeof(item0) == TYPE_DICTIONARY else {}
		var title := str(d.get("name", d.get("title", "Untitled"))).strip_edges()
		var stars = d.get("stars", null)
		var label := title
		if stars != null and str(stars) != "":
			label = "%s  ★%s" % [title, str(stars)]
		results_list.add_item(label)
	if items.size() > 0:
		results_list.select(0)
		_on_result_selected(0)

func _on_result_selected(idx: int) -> void:
	if details_text == null:
		return
	if idx < 0 or idx >= _items.size():
		details_text.text = ""
		return
	var d0: Variant = _items[idx]
	var d: Dictionary = d0 as Dictionary if typeof(d0) == TYPE_DICTIONARY else {}
	var title := str(d.get("name", d.get("title", ""))).strip_edges()
	var desc := str(d.get("description", d.get("summary", ""))).strip_edges()
	var url := str(d.get("url", d.get("link", ""))).strip_edges()
	var stars := str(d.get("stars", "")).strip_edges()

	var lines := PackedStringArray()
	if title != "":
		lines.append("[b]%s[/b]" % title)
	if stars != "":
		lines.append("Stars: %s" % stars)
	if desc != "":
		lines.append(desc)
	if url != "":
		lines.append("")
		lines.append(url)
	details_text.text = "\n".join(lines)

func _setup_sort_option() -> void:
	if sort_option == null:
		return
	sort_option.clear()
	sort_option.add_item("Stars")
	sort_option.set_item_metadata(0, "stars")
	sort_option.add_item("Recent")
	sort_option.set_item_metadata(1, "recent")
	sort_option.select(0)

func _current_sort_by() -> String:
	if sort_option == null:
		return ""
	var idx := sort_option.selected
	var meta: Variant = sort_option.get_item_metadata(idx)
	return str(meta).strip_edges() if meta != null else ""

func _update_status(text: String) -> void:
	if status_label != null:
		status_label.text = text

func _update_page_label() -> void:
	if page_label != null:
		if _total_pages > 0:
			page_label.text = "Page %d / %d" % [_current_page, _total_pages]
		else:
			page_label.text = "Page %d" % _current_page
	if prev_page_button != null:
		prev_page_button.disabled = _current_page <= 1
	if next_page_button != null:
		next_page_button.disabled = _total_pages > 0 and _current_page >= _total_pages

func _set_loading(is_loading: bool) -> void:
	if search_button != null:
		search_button.disabled = is_loading
	if prev_page_button != null:
		prev_page_button.disabled = is_loading or _current_page <= 1
	if next_page_button != null:
		next_page_button.disabled = is_loading or (_total_pages > 0 and _current_page >= _total_pages)
	if query_edit != null:
		query_edit.editable = not is_loading
	if settings_button != null:
		settings_button.disabled = is_loading

func _resolve_save_id() -> String:
	var oa := get_node_or_null("/root/OpenAgentic") as Node
	if oa == null:
		return ""
	var v: Variant = oa.get("save_id") if oa.has_method("get") else null
	return str(v).strip_edges() if v != null else ""

func _effective_skillsmp_cfg() -> Dictionary:
	var env: Dictionary = _SkillsMpConfig.from_environment()
	var sid := _resolve_save_id()
	if sid != "":
		var rd: Dictionary = _SkillsMpConfigStore.load_config(sid)
		if bool(rd.get("ok", false)) and typeof(rd.get("config", null)) == TYPE_DICTIONARY:
			var cfg: Dictionary = rd.get("config", {})
			var base := str(cfg.get("base_url", "")).strip_edges()
			var key := str(cfg.get("api_key", "")).strip_edges()
			var base2 := base if base != "" else str(env.get("base_url", "")).strip_edges()
			var key2 := key if key != "" else str(env.get("api_key", "")).strip_edges()
			return {"base_url": base2, "api_key": key2}
	return env

func _open_settings_popup() -> void:
	_load_settings_fields()
	_update_settings_status("")
	if settings_popup != null:
		settings_popup.popup_centered(SETTINGS_POPUP_SIZE)
		if settings_api_key_edit != null:
			settings_api_key_edit.grab_focus()

func _load_settings_fields() -> void:
	var cfg: Dictionary = _effective_skillsmp_cfg()
	if settings_base_url_edit != null:
		settings_base_url_edit.text = str(cfg.get("base_url", "")).strip_edges()
	if settings_api_key_edit != null:
		settings_api_key_edit.text = str(cfg.get("api_key", "")).strip_edges()

func _update_settings_status(text: String) -> void:
	if settings_status_label != null:
		settings_status_label.text = text

func _on_settings_save_pressed() -> void:
	var sid := _resolve_save_id()
	if sid == "":
		_update_settings_status("Missing save_id")
		return
	var base := settings_base_url_edit.text.strip_edges() if settings_base_url_edit != null else ""
	var key := settings_api_key_edit.text.strip_edges() if settings_api_key_edit != null else ""
	var wr: Dictionary = _SkillsMpConfigStore.save_config(sid, {"base_url": base, "api_key": key})
	if bool(wr.get("ok", false)):
		_update_settings_status("Saved")
	else:
		_update_settings_status("Save failed: %s" % str(wr.get("error", "WriteFailed")))

func _on_settings_test_pressed() -> void:
	var base := settings_base_url_edit.text.strip_edges() if settings_base_url_edit != null else ""
	var key := settings_api_key_edit.text.strip_edges() if settings_api_key_edit != null else ""
	if base == "" or key == "":
		_update_settings_status("Missing config")
		return
	_update_settings_status("Checking…")
	var rr: Dictionary = await _SkillsMpHealth.check_health(base, key, _skillsmp_transport_override)
	if bool(rr.get("ok", false)):
		_update_settings_status("OK")
	else:
		var status := int(rr.get("status", 0))
		var code := str(rr.get("error_code", "")).strip_edges()
		var msg := str(rr.get("message", "")).strip_edges()
		var parts := PackedStringArray()
		parts.append("Failed")
		if status != 0:
			parts.append("(HTTP %d)" % status)
		if code != "":
			parts.append(code)
		if msg != "":
			parts.append(msg)
		_update_settings_status(" ".join(parts))
