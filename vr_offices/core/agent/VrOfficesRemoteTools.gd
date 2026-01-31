extends RefCounted

const _OATool := preload("res://addons/openagentic/core/OATool.gd")
const _RpcClientScript := preload("res://vr_offices/core/irc/OA1IrcRpcClient.gd")
const _IrcNames := preload("res://vr_offices/core/irc/VrOfficesIrcNames.gd")

static func register_into(openagentic: Node, find_npc_by_id: Callable) -> void:
	if openagentic == null or not openagentic.has_method("register_tool"):
		return
	if openagentic.has_meta("vr_offices_remote_tools_registered"):
		return
	openagentic.call("register_tool", _make_remote_bash_tool(find_npc_by_id))
	openagentic.set_meta("vr_offices_remote_tools_registered", true)

static func _make_remote_bash_tool(find_npc_by_id: Callable):
	var schema: Dictionary = {
		"type": "object",
		"properties": {
			"command": {"type": "string", "description": "Shell command to run on the remote machine."},
			"timeout_sec": {"type": "integer", "description": "Optional timeout in seconds."},
		},
		"required": ["command"],
	}

	var description := (
		"在你当前绑定的桌子所连接的远程机器上运行 shell 命令（无状态 one-shot）。"
		+ "像本地 Bash 一样使用：提供 command，返回远端执行的文本输出。"
		+ "注意：输出可能因为 IRC 传输限制而分块/截断；优先使用 head/tail/rg/sed 等控制输出规模。"
	)

	var availability: Callable = func(ctx: Dictionary) -> bool:
		var npc_id := String(ctx.get("npc_id", "")).strip_edges()
		if npc_id == "" or find_npc_by_id == null or find_npc_by_id.is_null():
			return false
		var npc0: Variant = find_npc_by_id.call(npc_id)
		var npc := npc0 as Node
		if npc == null:
			return false
		if not npc.has_method("get_bound_desk_id"):
			return false
		var desk_id := String(npc.call("get_bound_desk_id")).strip_edges()
		if desk_id == "":
			return false
		var desk := _find_desk_by_id(desk_id)
		if desk == null:
			return false
		return _desk_is_paired(desk)

	var run_fn: Callable = func(input: Dictionary, ctx: Dictionary) -> Variant:
		var cmd := String(input.get("command", "")).strip_edges()
		if cmd == "":
			return "ERROR: RemoteBash.command must be a non-empty string"

		var npc_id := String(ctx.get("npc_id", "")).strip_edges()
		if npc_id == "" or find_npc_by_id == null or find_npc_by_id.is_null():
			return "ERROR: MissingNpc"
		var npc0: Variant = find_npc_by_id.call(npc_id)
		var npc := npc0 as Node
		if npc == null:
			return "ERROR: NpcNotFound"

		var desk_id := ""
		if npc.has_method("get_bound_desk_id"):
			desk_id = String(npc.call("get_bound_desk_id")).strip_edges()
		if desk_id == "":
			return "ERROR: NotDeskBound"

		var desk := _find_desk_by_id(desk_id)
		if desk == null:
			return "ERROR: DeskNotFound: %s" % desk_id
		if not _desk_is_paired(desk):
			return "ERROR: DeskNotPaired (RMB desk → Bind Device Code…)"

		var link := (desk as Node).get_node_or_null("DeskIrcLink") as Node
		if link == null or not is_instance_valid(link):
			return "ERROR: DeskHasNoIrcLink"

		var client := _ensure_rpc_client(link)
		if client == null:
			return "ERROR: MissingRpcClient"

		var timeout_sec := float(input.get("timeout_sec", 30))
		if timeout_sec <= 0.0:
			timeout_sec = 30.0
		var res: Variant = await client.call("request_text", cmd, timeout_sec)
		return String(res)

	return _OATool.new("RemoteBash", description, run_fn, schema, true, availability)

static func _desk_is_paired(desk: Node) -> bool:
	if desk == null or not is_instance_valid(desk):
		return false
	var raw := ""
	var v: Variant = desk.get("device_code") if desk.has_method("get") else null
	if v != null:
		raw = String(v)
	var canonical := _IrcNames.canonicalize_device_code(raw)
	return _IrcNames.is_valid_device_code_canonical(canonical)

static func _ensure_rpc_client(link: Node) -> Node:
	if link == null or not is_instance_valid(link):
		return null
	var client := link.get_node_or_null("OA1IrcRpcClient") as Node
	if client != null and is_instance_valid(client):
		if client.has_method("bind_link"):
			client.call("bind_link", link)
		return client

	client = (_RpcClientScript as Script).new() as Node
	if client == null:
		return null
	client.name = "OA1IrcRpcClient"
	link.add_child(client)
	if client.has_method("bind_link"):
		client.call("bind_link", link)
	return client

static func _find_desk_by_id(desk_id: String) -> Node:
	var did := desk_id.strip_edges()
	if did == "":
		return null
	var ml := Engine.get_main_loop()
	var tree := ml as SceneTree if (ml is SceneTree) else null
	if tree == null:
		return null
	for n0 in tree.get_nodes_in_group("vr_offices_desk"):
		var n := n0 as Node
		if n == null:
			continue
		if n.has_method("get"):
			var v: Variant = n.get("desk_id")
			if v != null and String(v).strip_edges() == did:
				return n
		if String(n.name) == did:
			return n
	return null
