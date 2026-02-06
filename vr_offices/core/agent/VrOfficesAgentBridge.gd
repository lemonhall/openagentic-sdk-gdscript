extends RefCounted

const _OAData := preload("res://vr_offices/core/data/VrOfficesData.gd")
const _RemoteTools := preload("res://vr_offices/core/agent/VrOfficesRemoteTools.gd")
const _OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")

var _owner: Node
var _find_npc_by_id: Callable
var _list_active_workspace_npcs: Callable

var _oa: Node = null
var _save_id: String = "slot1"
var _proxy_base_url: String = "http://127.0.0.1:8787/v1"
var _model: String = "gpt-5.2"

func _init(owner: Node, find_npc_by_id: Callable) -> void:
	_owner = owner
	_find_npc_by_id = find_npc_by_id
	if _owner != null and _owner.has_method("_active_npc_ids_for_workspace"):
		_list_active_workspace_npcs = Callable(_owner, "_active_npc_ids_for_workspace")

func set_defaults(save_id: String, proxy_base_url: String, model: String) -> void:
	if save_id.strip_edges() != "":
		_save_id = save_id.strip_edges()
	if proxy_base_url.strip_edges() != "":
		_proxy_base_url = proxy_base_url.strip_edges()
	if model.strip_edges() != "":
		_model = model.strip_edges()

func configure_from_environment() -> void:
	var v := OS.get_environment("OPENAGENTIC_PROXY_BASE_URL")
	if v.strip_edges() != "":
		_proxy_base_url = v.strip_edges()
	v = OS.get_environment("OPENAGENTIC_MODEL")
	if v.strip_edges() != "":
		_model = v.strip_edges()
	v = OS.get_environment("OPENAGENTIC_SAVE_ID")
	if v.strip_edges() != "":
		_save_id = v.strip_edges()

func configure_openagentic() -> Node:
	if _owner == null:
		return null
	_oa = _owner.get_node_or_null("/root/OpenAgentic")
	if _oa == null:
		push_warning("Missing autoload: OpenAgentic (dialogue will not work)")
		return null

	# Respect a save_id already set on the OpenAgentic autoload, unless an explicit
	# environment override is provided.
	var env_save: String = OS.get_environment("OPENAGENTIC_SAVE_ID").strip_edges()
	if env_save != "":
		_save_id = env_save
		_oa.call("set_save_id", _save_id)
	else:
		var existing: String = ""
		if _oa.has_method("get"):
			var v: Variant = _oa.get("save_id")
			if v != null:
				existing = String(v).strip_edges()
		if existing != "":
			_save_id = existing
		else:
			_oa.call("set_save_id", _save_id)

	_oa.call("configure_proxy_openai_responses", _proxy_base_url, _model)

	if _oa.has_method("enable_default_tools"):
		_oa.call("enable_default_tools")

	# VR Offices-specific tools (desk-bound RemoteBash, etc.).
	_RemoteTools.register_into(_oa, _find_npc_by_id)

	if _oa.has_method("get") and _oa.has_method("set"):
		var sp0: Variant = _oa.get("system_prompt")
		var sp: String = String(sp0) if sp0 != null else ""
		if sp.strip_edges() == "":
			_oa.set("system_prompt", _OAData.SYSTEM_PROMPT_ZH)

	# Demo/dev: always allow file+web tools, no approvals.
	if _oa.has_method("set_approver"):
		_oa.call("set_approver", func(_q: Dictionary, _ctx: Dictionary) -> bool: return true)

	_install_turn_hooks()
	return _oa

func get_openagentic() -> Node:
	return _oa

func effective_save_id() -> String:
	var sid := ""
	if _oa != null and _oa.has_method("get"):
		var v: Variant = _oa.get("save_id")
		if v != null:
			sid = String(v)
	if sid.strip_edges() == "":
		sid = _save_id
	return sid

func _install_turn_hooks() -> void:
	if _oa == null:
		return
	if _oa.has_meta("vr_offices_turn_hooks_installed"):
		return
	if not _oa.has_method("add_before_turn_hook") or not _oa.has_method("add_after_turn_hook"):
		return
	_oa.call("add_before_turn_hook", "vr_offices.before_turn", "*", Callable(self, "_before_turn_hook"))
	_oa.call("add_after_turn_hook", "vr_offices.after_turn", "*", Callable(self, "_after_turn_hook"))
	_oa.set_meta("vr_offices_turn_hooks_installed", true)

func _before_turn_hook(payload: Dictionary) -> Dictionary:
	var npc_id := String(payload.get("npc_id", "")).strip_edges()
	if npc_id == "":
		return {}

	var manager_ctx := _build_manager_context(payload)
	if manager_ctx != "":
		return {"override_user_text": manager_ctx + "\n\n" + String(payload.get("user_text", "")), "action": "manager_context"}

	if not _find_npc_by_id.is_valid():
		return {}
	var npc0: Variant = _find_npc_by_id.call(npc_id)
	var npc := npc0 as Node
	if npc == null:
		return {}
	if npc.has_method("play_turn_start_animation"):
		npc.call("play_turn_start_animation")
		return {"action": "npc_turn_start_anim"}
	if npc.has_method("play_animation_once"):
		npc.call("play_animation_once", "interact-right", 0.7)
		return {"action": "npc_anim:interact-right"}
	return {}

func _build_manager_context(payload: Dictionary) -> String:
	var npc_id := String(payload.get("npc_id", "")).strip_edges()
	if _OAPaths.workspace_id_from_manager_npc_id(npc_id) == "":
		return ""
	var ctx0: Variant = payload.get("context", {})
	var ctx: Dictionary = ctx0 as Dictionary if typeof(ctx0) == TYPE_DICTIONARY else {}
	var workspace_id := String(ctx.get("workspace_id", _OAPaths.workspace_id_from_manager_npc_id(npc_id))).strip_edges()
	if workspace_id != "" and _list_active_workspace_npcs.is_valid() and not ctx.has("active_workspace_npcs"):
		var arr0: Variant = _list_active_workspace_npcs.call(workspace_id)
		ctx["active_workspace_npcs"] = arr0
	var lines: Array[String] = []
	lines.append("[Manager Role Context]")
	lines.append("You are the workspace manager responsible for coordinating active NPCs in workspace %s." % workspace_id)
	var roster0: Variant = ctx.get("active_workspace_npcs", [])
	if typeof(roster0) != TYPE_ARRAY and _list_active_workspace_npcs.is_valid() and workspace_id != "":
		roster0 = _list_active_workspace_npcs.call(workspace_id)
	if typeof(roster0) == TYPE_ARRAY:
		var roster := roster0 as Array
		if roster.size() > 0:
			var names: Array[String] = []
			for n0 in roster:
				names.append(String(n0).strip_edges())
			lines.append("Active NPCs: %s" % ", ".join(PackedStringArray(names)))
		else:
			lines.append("Active NPCs: (none)")
	return "\n".join(PackedStringArray(lines)).strip_edges()

func _after_turn_hook(payload: Dictionary) -> Dictionary:
	var npc_id := String(payload.get("npc_id", "")).strip_edges()
	if npc_id == "" or not _find_npc_by_id.is_valid():
		return {}
	var npc0: Variant = _find_npc_by_id.call(npc_id)
	var npc := npc0 as Node
	if npc == null:
		return {}
	if npc.has_method("play_turn_end_animation"):
		npc.call("play_turn_end_animation")
		return {"action": "npc_turn_end_anim"}
	if npc.has_method("stop_override_animation"):
		npc.call("stop_override_animation")
		return {"action": "npc_anim:stop_override"}
	return {}
