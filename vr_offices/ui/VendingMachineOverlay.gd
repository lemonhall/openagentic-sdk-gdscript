extends Control

const _SkillsMpConfig := preload("res://addons/openagentic/core/OASkillsMpConfig.gd")
const _SkillsMpConfigStore := preload("res://addons/openagentic/core/OASkillsMpConfigStore.gd")
const _SkillsMpClient := preload("res://vr_offices/core/skillsmp/VrOfficesSkillsMpClient.gd")
const _SkillsMpHealth := preload("res://vr_offices/core/skillsmp/VrOfficesSkillsMpHealth.gd")
const _GitHubZipSource := preload("res://vr_offices/core/skill_library/VrOfficesGitHubZipSource.gd")
const _SkillPackInstaller := preload("res://vr_offices/core/skill_library/VrOfficesSkillPackInstaller.gd")
const _LibraryStore := preload("res://vr_offices/core/skill_library/VrOfficesSharedSkillLibraryStore.gd")
const _LibraryPaths := preload("res://vr_offices/core/skill_library/VrOfficesSharedSkillLibraryPaths.gd")

@onready var backdrop: ColorRect = $Backdrop
@onready var close_button: Button = %CloseButton
@onready var query_edit: LineEdit = %QueryEdit
@onready var search_button: Button = %SearchButton
@onready var sort_option: OptionButton = %SortOption
@onready var settings_button: Button = %SettingsButton
@onready var results_list: ItemList = %ResultsList
@onready var details_text: RichTextLabel = %DetailsText
@onready var repo_url_label: Label = %RepoUrlLabel
@onready var open_repo_button: Button = %OpenRepoButton
@onready var install_button: Button = %InstallButton
@onready var status_label: Label = %StatusLabel
@onready var prev_page_button: Button = %PrevPageButton
@onready var next_page_button: Button = %NextPageButton
@onready var page_label: Label = %PageLabel

@onready var settings_popup: PopupPanel = %SkillsMpSettingsPopup
@onready var settings_base_url_edit: LineEdit = %SettingsBaseUrlEdit
@onready var settings_api_key_edit: LineEdit = %SettingsApiKeyEdit
@onready var settings_proxy_http_edit: LineEdit = %SettingsHttpProxyEdit
@onready var settings_proxy_https_edit: LineEdit = %SettingsHttpsProxyEdit
@onready var settings_save_button: Button = %SettingsSaveButton
@onready var settings_test_button: Button = %SettingsTestButton
@onready var settings_close_button: Button = %SettingsCloseButton
@onready var settings_status_label: Label = %SettingsStatusLabel

@onready var library_filter_edit: LineEdit = %LibraryFilterEdit
@onready var library_refresh_button: Button = %LibraryRefreshButton
@onready var library_list: ItemList = %LibraryList
@onready var library_details_text: RichTextLabel = %LibraryDetailsText
@onready var library_status_label: Label = %LibraryStatusLabel
@onready var library_uninstall_button: Button = %LibraryUninstallButton

var _client: RefCounted = _SkillsMpClient.new()
var _skillsmp_transport_override: Callable = Callable()
var _github_zip_transport_override: Callable = Callable()
var _installer: RefCounted = _SkillPackInstaller.new()

var _items: Array = []
var _selected_remote_skill: Dictionary = {}
var _current_query := ""
var _current_page := 1
var _limit := 20
var _total_pages := 0
var _selected_repo_url := ""

var _library_all: Array[Dictionary] = []
var _library_filtered: Array[Dictionary] = []

const SETTINGS_POPUP_SIZE := Vector2i(620, 360)
const _DEBUG_LAST_SEARCH_PATH := "user://openagentic/saves/%s/vr_offices/skillsmp_last_search.json"
const DEFAULT_PROXY_HTTP := "http://127.0.0.1:7897"
const DEFAULT_PROXY_HTTPS := "https://127.0.0.1:7897"

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
	if details_text != null and details_text.has_signal("meta_clicked"):
		details_text.meta_clicked.connect(_on_details_meta_clicked)
	if open_repo_button != null:
		open_repo_button.pressed.connect(_on_open_repo_pressed)
	if install_button != null:
		install_button.pressed.connect(_on_install_pressed)
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
	_update_repo_ui("")

	if library_refresh_button != null:
		library_refresh_button.pressed.connect(library_refresh)
	if library_filter_edit != null:
		library_filter_edit.text_changed.connect(func(_t: String) -> void:
			_apply_library_filter_and_render()
		)
	if library_list != null:
		library_list.item_selected.connect(_on_library_selected)
	if library_uninstall_button != null:
		library_uninstall_button.pressed.connect(_on_library_uninstall_pressed)

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
	library_refresh()

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

func set_github_zip_transport_override(transport: Callable) -> void:
	_github_zip_transport_override = transport

func debug_set_selected_skill_for_install(skill: Dictionary) -> void:
	_selected_remote_skill = skill if skill != null else {}
	_selected_repo_url = _extract_repo_url(_selected_remote_skill)
	_update_selected_skill_details(_selected_remote_skill)

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
		_update_repo_ui("")
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
	else:
		_update_repo_ui("")

func _on_result_selected(idx: int) -> void:
	if details_text == null:
		return
	if idx < 0 or idx >= _items.size():
		details_text.text = ""
		return
	var d0: Variant = _items[idx]
	var d: Dictionary = d0 as Dictionary if typeof(d0) == TYPE_DICTIONARY else {}
	_selected_remote_skill = d
	_selected_repo_url = _extract_repo_url(d)
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
	if _selected_repo_url != "":
		lines.append("")
		lines.append("[url=%s]%s[/url]" % [_selected_repo_url, _selected_repo_url])
	details_text.text = "\n".join(lines)
	_update_repo_ui(_selected_repo_url)

func _update_selected_skill_details(skill: Dictionary) -> void:
	if details_text == null:
		return
	var title := str(skill.get("name", skill.get("title", ""))).strip_edges()
	var desc := str(skill.get("description", skill.get("summary", ""))).strip_edges()
	var repo := _extract_repo_url(skill)
	var lines := PackedStringArray()
	if title != "":
		lines.append("[b]%s[/b]" % title)
	if desc != "":
		lines.append(desc)
	if repo != "":
		lines.append("")
		lines.append("[url=%s]%s[/url]" % [repo, repo])
	details_text.text = "\n".join(lines)
	_update_repo_ui(repo)

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
	if install_button != null:
		install_button.disabled = is_loading or _selected_repo_url.strip_edges() == ""
	if open_repo_button != null:
		open_repo_button.disabled = is_loading or _selected_repo_url.strip_edges() == ""

func _update_repo_ui(repo_url: String) -> void:
	_selected_repo_url = repo_url.strip_edges()
	if repo_url_label != null:
		repo_url_label.text = _selected_repo_url
	if install_button != null:
		install_button.disabled = _selected_repo_url == ""
	if open_repo_button != null:
		open_repo_button.disabled = _selected_repo_url == ""

func _extract_repo_url(skill: Dictionary) -> String:
	if skill == null:
		return ""
	var keys := [
		"repo_url", "repoUrl",
		"github_url", "githubUrl",
		"repository", "repo",
		"git_url", "gitUrl",
		"source_url", "sourceUrl",
	]
	for k in keys:
		var v: Variant = skill.get(k, null)
		var s := str(v).strip_edges() if v != null else ""
		if s != "":
			return s
	var u := str(skill.get("url", "")).strip_edges()
	if u.find("github.com/") != -1:
		return u
	return ""

func _on_open_repo_pressed() -> void:
	var u := _selected_repo_url.strip_edges()
	if u == "":
		return
	if _is_headless():
		return
	OS.shell_open(u)

func _on_details_meta_clicked(meta: Variant) -> void:
	if meta == null:
		return
	var u := str(meta).strip_edges()
	if u == "" or _is_headless():
		return
	OS.shell_open(u)

func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless" or OS.has_feature("server") or OS.has_feature("headless")

func _on_install_pressed() -> void:
	var sid := _resolve_save_id()
	if sid == "":
		_update_status("Missing save_id")
		return
	var repo := _selected_repo_url.strip_edges()
	if repo == "":
		_update_status("Missing repo URL")
		return

	_set_loading(true)
	_update_status("Downloading…")
	var cfg: Dictionary = _effective_skillsmp_cfg()
	var proxy_http := str(cfg.get("proxy_http", "")).strip_edges()
	var proxy_https := str(cfg.get("proxy_https", "")).strip_edges()
	var dr: Dictionary = await _GitHubZipSource.download_repo_zip(repo, _github_zip_transport_override, proxy_http, proxy_https)
	if not bool(dr.get("ok", false)):
		_set_loading(false)
		var err := str(dr.get("error", "Error")).strip_edges()
		var msg := str(dr.get("message", "")).strip_edges()
		_update_status("Download failed: %s%s" % [err, (": " + msg) if msg != "" else ""])
		return

	var zip: PackedByteArray = dr.get("zip", PackedByteArray())
	if zip.size() <= 0:
		_set_loading(false)
		_update_status("Download failed: empty zip")
		return

	var stage := _LibraryPaths.staging_root(sid)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(stage))
	var zip_path := stage.rstrip("/") + "/download.zip"
	var f := FileAccess.open(zip_path, FileAccess.WRITE)
	if f == null:
		_set_loading(false)
		_update_status("Install failed: write zip")
		return
	f.store_buffer(zip)
	f.close()

	_update_status("Validating & installing…")
	var source := {"type": "github", "repo_url": String(dr.get("repo_url", repo)), "ref": String(dr.get("ref", "")), "url": String(dr.get("url", ""))}
	var rr: Dictionary = await _installer.call("install_zip_for_save", sid, zip_path, source)
	_set_loading(false)
	if not bool(rr.get("ok", false)):
		_update_status("Install failed")
		return
	var installed: Array = rr.get("installed", [])
	_update_status("Installed %d skill(s)." % installed.size())
	library_refresh()

func library_refresh() -> void:
	var sid := _resolve_save_id()
	if sid == "":
		return
	_library_all = _LibraryStore.list_skills(sid)
	_apply_library_filter_and_render()

func _apply_library_filter_and_render() -> void:
	var q := library_filter_edit.text.strip_edges().to_lower() if library_filter_edit != null else ""
	_library_filtered = []
	for it in _library_all:
		var name := str(it.get("name", "")).to_lower()
		var desc := str(it.get("description", "")).to_lower()
		if q == "" or name.find(q) != -1 or desc.find(q) != -1:
			_library_filtered.append(it)
	_render_library_list()

func _render_library_list() -> void:
	if library_list == null:
		return
	library_list.clear()
	for it in _library_filtered:
		var name := str(it.get("name", "")).strip_edges()
		var desc := str(it.get("description", "")).strip_edges()
		var label := name
		if desc != "":
			label = "%s — %s" % [name, desc]
		library_list.add_item(label)
	if _library_filtered.size() > 0:
		library_list.select(0)
		_on_library_selected(0)
	else:
		if library_details_text != null:
			library_details_text.text = ""
		if library_status_label != null:
			library_status_label.text = ""

func _on_library_selected(idx: int) -> void:
	if idx < 0 or idx >= _library_filtered.size():
		return
	var it := _library_filtered[idx]
	if library_details_text != null:
		var lines := PackedStringArray()
		lines.append("[b]%s[/b]" % str(it.get("name", "")).strip_edges())
		var d := str(it.get("description", "")).strip_edges()
		if d != "":
			lines.append(d)
		var src0: Variant = it.get("source", null)
		if typeof(src0) == TYPE_DICTIONARY:
			var src: Dictionary = src0 as Dictionary
			var repo := str(src.get("repo_url", "")).strip_edges()
			if repo != "":
				lines.append("")
				lines.append("[url=%s]%s[/url]" % [repo, repo])
		library_details_text.text = "\n".join(lines)

func _on_library_uninstall_pressed() -> void:
	var sid := _resolve_save_id()
	if sid == "":
		return
	if library_list == null:
		return
	var idx := library_list.get_selected_items()[0] if library_list.get_selected_items().size() > 0 else -1
	if idx < 0 or idx >= _library_filtered.size():
		return
	var it := _library_filtered[idx]
	var name := str(it.get("name", "")).strip_edges()
	if name == "":
		return
	var root := _LibraryPaths.library_root(sid)
	var dir := root.rstrip("/") + "/" + name
	_rm_tree(dir)
	_LibraryStore.remove_skill(sid, name)
	if library_status_label != null:
		library_status_label.text = "Uninstalled %s" % name
	library_refresh()

func _rm_tree(dir_path: String) -> void:
	var abs := ProjectSettings.globalize_path(dir_path)
	if not DirAccess.dir_exists_absolute(abs):
		return
	var d := DirAccess.open(abs)
	if d == null:
		return
	d.list_dir_begin()
	while true:
		var n := d.get_next()
		if n == "":
			break
		if n == "." or n == "..":
			continue
		var p := abs.rstrip("/") + "/" + n
		if d.current_is_dir():
			_rm_tree(p)
			DirAccess.remove_absolute(p)
		else:
			DirAccess.remove_absolute(p)
	d.list_dir_end()

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
			var proxy_http := str(cfg.get("proxy_http", "")).strip_edges()
			var proxy_https := str(cfg.get("proxy_https", "")).strip_edges()
			var base2 := base if base != "" else str(env.get("base_url", "")).strip_edges()
			var key2 := key if key != "" else str(env.get("api_key", "")).strip_edges()
			return {"base_url": base2, "api_key": key2, "proxy_http": proxy_http, "proxy_https": proxy_https}
	return {"base_url": str(env.get("base_url", "")).strip_edges(), "api_key": str(env.get("api_key", "")).strip_edges(), "proxy_http": "", "proxy_https": ""}

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
	if settings_proxy_http_edit != null:
		var v := str(cfg.get("proxy_http", "")).strip_edges()
		settings_proxy_http_edit.text = v if v != "" else DEFAULT_PROXY_HTTP
	if settings_proxy_https_edit != null:
		var v2 := str(cfg.get("proxy_https", "")).strip_edges()
		settings_proxy_https_edit.text = v2 if v2 != "" else DEFAULT_PROXY_HTTPS

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
	var proxy_http := settings_proxy_http_edit.text.strip_edges() if settings_proxy_http_edit != null else ""
	var proxy_https := settings_proxy_https_edit.text.strip_edges() if settings_proxy_https_edit != null else ""
	var wr: Dictionary = _SkillsMpConfigStore.save_config(sid, {"base_url": base, "api_key": key, "proxy_http": proxy_http, "proxy_https": proxy_https})
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
