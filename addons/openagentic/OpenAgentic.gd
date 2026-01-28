extends Node
class_name OpenAgentic

var save_id: String = ""

var provider = null
var model: String = ""
var system_prompt: String = ""
var tools := OAToolRegistry.new()
var permission_gate := OAAskOncePermissionGate.new()

func set_save_id(id: String) -> void:
	save_id = id

func configure_proxy_openai_responses(base_url: String, model_name: String, auth_header: String = "", auth_token: String = "", is_bearer: bool = true) -> void:
	var ProviderScript := load("res://addons/openagentic/providers/OAOpenAIResponsesProvider.gd")
	if ProviderScript == null:
		push_error("Missing OAOpenAIResponsesProvider.gd")
		return
	provider = ProviderScript.new(base_url, auth_header, auth_token, is_bearer)
	model = model_name

func register_tool(tool: OATool) -> void:
	tools.register(tool)

func set_approver(approver: Callable) -> void:
	permission_gate = OAAskOncePermissionGate.new(approver)

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

	var store := OAJsonlNpcSessionStore.new(save_id)
	var runner := OAToolRunner.new(tools, permission_gate, store)
	var RuntimeScript := load("res://addons/openagentic/runtime/OAAgentRuntime.gd")
	if RuntimeScript == null:
		push_error("Missing OAAgentRuntime.gd")
		return
	var rt = RuntimeScript.new(store, runner, tools, provider, model)
	rt.set_system_prompt(system_prompt)
	await rt.run_turn(npc_id, user_text, on_event, save_id)

