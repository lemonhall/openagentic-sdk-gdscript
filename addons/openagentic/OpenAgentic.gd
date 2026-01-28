extends Node
class_name OpenAgentic

const _ToolRegistryScript := preload("res://addons/openagentic/core/OAToolRegistry.gd")
const _PermissionGateScript := preload("res://addons/openagentic/core/OAAskOncePermissionGate.gd")
const _SessionStoreScript := preload("res://addons/openagentic/core/OAJsonlNpcSessionStore.gd")
const _ToolRunnerScript := preload("res://addons/openagentic/core/OAToolRunner.gd")
const _AgentRuntimeScript := preload("res://addons/openagentic/runtime/OAAgentRuntime.gd")
const _OpenAIProviderScript := preload("res://addons/openagentic/providers/OAOpenAIResponsesProvider.gd")

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

	var store = _SessionStoreScript.new(save_id)
	var runner = _ToolRunnerScript.new(tools, permission_gate, store)
	var rt = _AgentRuntimeScript.new(store, runner, tools, provider, model)
	rt.set_system_prompt(system_prompt)
	await rt.run_turn(npc_id, user_text, on_event, save_id)
