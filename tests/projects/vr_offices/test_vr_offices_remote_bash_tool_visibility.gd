extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var root: Node = get_root()

	# OpenAgentic node (autoload-like).
	var OAScript := load("res://addons/openagentic/OpenAgentic.gd")
	if OAScript == null:
		T.fail_and_quit(self, "Missing OpenAgentic.gd")
		return
	var oa: Node = (OAScript as Script).new()
	oa.name = "OpenAgentic"
	root.add_child(oa)

	var save_id: String = "slot_test_remote_bash_%s_%s" % [str(OS.get_process_id()), str(Time.get_unix_time_from_system())]
	oa.set("save_id", save_id)
	oa.set("model", "gpt-test")
	oa.set_approver(func(_q: Dictionary, _ctx: Dictionary) -> bool:
		return true
	)

	# Fake provider captures the tool list and does nothing else.
	var captured: Array = []
	var fake_provider := {"name": "fake"}
	fake_provider["stream"] = func(req: Dictionary, on_event: Callable) -> void:
		var names: Array[String] = []
		var tools_v: Variant = req.get("tools", null)
		if typeof(tools_v) == TYPE_ARRAY:
			for t0 in tools_v as Array:
				if typeof(t0) != TYPE_DICTIONARY:
					continue
				var t: Dictionary = t0 as Dictionary
				var n := String(t.get("name", "")).strip_edges()
				if n != "":
					names.append(n)
		names.sort()
		captured.append(names)
		on_event.call({"type": "done"})
	oa.set("provider", fake_provider)

	# Enable default tools, then register VR Offices remote tools.
	if oa.has_method("enable_default_tools"):
		oa.call("enable_default_tools")

	var desk_scene := load("res://vr_offices/furniture/StandingDesk.tscn")
	if desk_scene == null or not (desk_scene is PackedScene):
		T.fail_and_quit(self, "Missing res://vr_offices/furniture/StandingDesk.tscn")
		return
	var desk := (desk_scene as PackedScene).instantiate() as Node3D
	if desk == null:
		T.fail_and_quit(self, "Failed to instantiate StandingDesk.tscn")
		return
	if desk.has_method("configure"):
		desk.call("configure", "desk_1", "ws_1")
	root.add_child(desk)
	await process_frame

	var npc_scene := load("res://vr_offices/npc/Npc.tscn")
	if npc_scene == null or not (npc_scene is PackedScene):
		T.fail_and_quit(self, "Missing res://vr_offices/npc/Npc.tscn")
		return
	var npc := (npc_scene as PackedScene).instantiate() as Node3D
	npc.name = "npc_a"
	if npc.has_method("set"):
		npc.set("npc_id", "npc_a")
	root.add_child(npc)
	await process_frame

	# Register the RemoteBash tool (availability depends on this NPC node).
	var RemoteTools := load("res://vr_offices/core/agent/VrOfficesRemoteTools.gd")
	if RemoteTools == null:
		T.fail_and_quit(self, "Missing VrOfficesRemoteTools.gd")
		return

	var find_npc_by_id: Callable = func(npc_id: String) -> Node:
		return npc if npc_id == "npc_a" else null

	(RemoteTools as Script).call("register_into", oa, find_npc_by_id)

	var indicator := desk.get_node_or_null("NpcBindIndicator") as Node
	if not T.require_true(self, indicator != null, "Missing StandingDesk/NpcBindIndicator"):
		return
	var area := indicator.get_node_or_null("Area") as Area3D
	if not T.require_true(self, area != null, "Missing NpcBindIndicator/Area"):
		return

	# 1) Unbound: RemoteBash must not appear.
	await oa.run_npc_turn("npc_a", "hello", func(_ev: Dictionary) -> void: pass)
	if not T.require_true(self, not captured.is_empty(), "Provider should have been called"):
		return
	var tools_unbound = captured[-1]
	if not T.require_true(self, not tools_unbound.has("RemoteBash"), "RemoteBash must be hidden when unbound. Got: " + str(tools_unbound)):
		return

	# 2) Bound: RemoteBash must appear.
	area.emit_signal("body_entered", npc)
	await process_frame
	await oa.run_npc_turn("npc_a", "hello", func(_ev: Dictionary) -> void: pass)
	var tools_bound = captured[-1]
	if not T.require_true(self, tools_bound.has("RemoteBash"), "RemoteBash must appear when desk-bound. Got: " + str(tools_bound)):
		return

	# 3) Unbound again: RemoteBash must disappear.
	area.emit_signal("body_exited", npc)
	await process_frame
	await oa.run_npc_turn("npc_a", "hello", func(_ev: Dictionary) -> void: pass)
	var tools_unbound2 = captured[-1]
	if not T.require_true(self, not tools_unbound2.has("RemoteBash"), "RemoteBash must disappear after unbind. Got: " + str(tools_unbound2)):
		return

	T.pass_and_quit(self)
