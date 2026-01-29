extends Node

const _ToolRegistryScript := preload("res://addons/openagentic/core/OAToolRegistry.gd")
const _PermissionGateScript := preload("res://addons/openagentic/core/OAAskOncePermissionGate.gd")
const _SessionStoreScript := preload("res://addons/openagentic/core/OAJsonlNpcSessionStore.gd")
const _ToolRunnerScript := preload("res://addons/openagentic/core/OAToolRunner.gd")
const _AgentRuntimeScript := preload("res://addons/openagentic/runtime/OAAgentRuntime.gd")
const _OpenAIProviderScript := preload("res://addons/openagentic/providers/OAOpenAIResponsesProvider.gd")
const _OAPaths := preload("res://addons/openagentic/core/OAPaths.gd")

var save_id: String = ""

var provider = null
var model: String = ""
var system_prompt: String = ""
var tools = _ToolRegistryScript.new()
var permission_gate = _PermissionGateScript.new()

func set_save_id(id: String) -> void:
	save_id = id

func configure_proxy_openai_responses(base_url: String, model_name: String, auth_header: String = "", auth_token: String = "", is_bearer: bool = true) -> void:
	provider = _OpenAIProviderScript.new(base_url, auth_header, auth_token, is_bearer)
	model = model_name

func register_tool(tool) -> void:
	tools.register(tool)

func enable_default_tools() -> void:
	# Registers the standard OpenCode-style toolset (no Bash):
	# - Read/Write/Edit
	# - Glob/Grep
	# - WebFetch/WebSearch
	# - TodoWrite
	# - Skill
	# All filesystem tools are scoped to the per-NPC workspace.
	OAStandardTools.register_into(self)

func enable_npc_workspace_tools() -> void:
	# Back-compat alias.
	enable_default_tools()

func set_approver(approver: Callable) -> void:
	permission_gate = _PermissionGateScript.new(approver)

func run_npc_turn(npc_id: String, user_text: String, on_event: Callable) -> void:
	if save_id.strip_edges() == "":
		push_error("OpenAgentic.save_id is required")
		return
	if provider == null:
		push_error("OpenAgentic.provider is not configured")
		return
	if model.strip_edges() == "":
		push_error("OpenAgentic.model is required")
		return
	# Make the default tool suite available unless the host game overrides it.
	# This keeps NPCs consistent across scenes and avoids "tools are missing" surprises.
	if typeof(tools) == TYPE_OBJECT and tools != null and tools.has_method("names"):
		var names0: Array = tools.names()
		if names0.is_empty():
			enable_default_tools()

	var store = _SessionStoreScript.new(save_id)
	var tavily_key := OS.get_environment("TAVILY_API_KEY").strip_edges()
	var runner = _ToolRunnerScript.new(tools, permission_gate, store, func(session_id: String, _tool_call: Dictionary) -> Dictionary:
		var sid := save_id
		var nid := session_id
		return {
			"save_id": sid,
			"npc_id": nid,
			"workspace_root": _OAPaths.npc_workspace_dir(sid, nid),
			"tavily_api_key": tavily_key,
			"allow_private_networks": false,
		}
	)
	var rt = _AgentRuntimeScript.new(store, runner, tools, provider, model)
	rt.set_system_prompt(system_prompt)
	await rt.run_turn(npc_id, user_text, on_event, save_id)
