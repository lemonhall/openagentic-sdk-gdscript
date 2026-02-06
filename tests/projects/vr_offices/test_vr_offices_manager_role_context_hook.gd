extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var BridgeScript := load("res://vr_offices/core/agent/VrOfficesAgentBridge.gd")
	if BridgeScript == null:
		T.fail_and_quit(self, "Missing VrOfficesAgentBridge.gd")
		return

	var owner := Node.new()
	owner.name = "Owner"
	get_root().add_child(owner)
	await process_frame

	var bridge := (BridgeScript as Script).new(owner, Callable(self, "_fake_find_npc")) as RefCounted
	if bridge == null:
		T.fail_and_quit(self, "Failed to instantiate VrOfficesAgentBridge")
		return

	var payload := {
		"npc_id": "workspace_manager__ws_1",
		"user_text": "你好",
		"context": {
			"workspace_id": "ws_1",
			"active_workspace_npcs": ["npc_1", "npc_2"],
		}
	}

	if not bridge.has_method("_before_turn_hook"):
		T.fail_and_quit(self, "VrOfficesAgentBridge missing _before_turn_hook")
		return
	var out0: Variant = await bridge.call("_before_turn_hook", payload)
	if typeof(out0) != TYPE_DICTIONARY:
		T.fail_and_quit(self, "_before_turn_hook should return Dictionary")
		return
	var out := out0 as Dictionary

	if not T.require_true(self, out.has("override_user_text"), "Expected manager hook to override user text with manager context"):
		return
	var merged := String(out.get("override_user_text", ""))
	if not T.require_true(self, merged.find("workspace manager") != -1 or merged.find("经理") != -1, "Expected manager role text in override_user_text"):
		return
	if not T.require_true(self, merged.find("npc_1") != -1 and merged.find("npc_2") != -1, "Expected active npc roster in override_user_text"):
		return

	T.pass_and_quit(self)

func _fake_find_npc(_npc_id: String) -> Node:
	return null
