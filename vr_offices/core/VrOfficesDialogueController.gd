extends RefCounted

var owner: Node = null
var camera_rig: Node = null
var dialogue: Control = null
var oa: Node = null
var chat_history: RefCounted = null
var is_headless: Callable
var get_save_id: Callable

var busy := false

var _camera_state_before_talk: Dictionary = {}
var _talk_npc: Node = null

func _init(
	owner_in: Node,
	camera_rig_in: Node,
	dialogue_in: Control,
	oa_in: Node,
	chat_history_in: RefCounted,
	is_headless_in: Callable,
	get_save_id_in: Callable
) -> void:
	owner = owner_in
	camera_rig = camera_rig_in
	dialogue = dialogue_in
	oa = oa_in
	chat_history = chat_history_in
	is_headless = is_headless_in
	get_save_id = get_save_id_in

func enter_talk(npc: Node) -> void:
	if dialogue == null or not dialogue.has_method("open"):
		return
	if npc == null or not is_instance_valid(npc):
		return

	_talk_npc = npc

	var npc_id := ""
	var npc_name := ""
	if npc.has_method("get"):
		npc_id = String(npc.get("npc_id"))
	if npc.has_method("get_display_name"):
		npc_name = String(npc.call("get_display_name"))
	if npc_id.strip_edges() == "":
		npc_id = npc.name

	if camera_rig != null and camera_rig.has_method("set_controls_enabled"):
		camera_rig.call("set_controls_enabled", false)
	_start_dialogue_camera_focus(npc)
	_lock_npc_for_dialogue(npc)

	dialogue.open(npc_id, npc_name)
	if dialogue.has_method("set_history") and chat_history != null and get_save_id.is_valid():
		var sid: String = String(get_save_id.call())
		var hist0: Variant = chat_history.call("read_ui_history", sid, npc_id)
		var hist: Array = hist0 as Array if typeof(hist0) == TYPE_ARRAY else []
		dialogue.call("set_history", hist)

func exit_talk() -> void:
	_unlock_npc_after_dialogue()
	_restore_dialogue_camera()
	if camera_rig != null and camera_rig.has_method("set_controls_enabled"):
		camera_rig.call("set_controls_enabled", true)
	if busy:
		return
	if dialogue != null and dialogue.visible and dialogue.has_method("close"):
		dialogue.close()

func on_message_submitted(text: String) -> void:
	if dialogue == null or busy:
		return
	var npc_id := ""
	if dialogue.has_method("get_npc_id"):
		npc_id = String(dialogue.call("get_npc_id"))
	if npc_id.strip_edges() == "":
		return
	_start_turn(npc_id, text)

func _start_turn(npc_id: String, text: String) -> void:
	busy = true
	if dialogue != null and dialogue.has_method("set_busy"):
		dialogue.call("set_busy", true)
	if dialogue != null and dialogue.has_method("begin_assistant"):
		dialogue.call("begin_assistant")

	if oa == null:
		push_warning("OpenAgentic not configured")
		busy = false
		if dialogue != null and dialogue.has_method("set_busy"):
			dialogue.call("set_busy", false)
		return

	await oa.run_npc_turn(npc_id, text, Callable(self, "_on_agent_event"))

	busy = false
	if dialogue != null and dialogue.has_method("set_busy"):
		dialogue.call("set_busy", false)

func _on_agent_event(ev: Dictionary) -> void:
	if dialogue == null:
		return
	var t := String(ev.get("type", ""))
	if t == "assistant.delta":
		if dialogue.has_method("append_assistant_delta"):
			dialogue.call("append_assistant_delta", String(ev.get("text_delta", "")))
		return
	if t == "result":
		if dialogue.has_method("end_assistant"):
			dialogue.call("end_assistant")
		return

func _start_dialogue_camera_focus(npc: Node) -> void:
	if camera_rig == null:
		return
	if not camera_rig.has_method("get_state") or not camera_rig.has_method("focus_on"):
		return
	_camera_state_before_talk = camera_rig.call("get_state")

	var npc3d: Node3D = npc as Node3D
	if npc3d == null:
		return
	var head: Vector3 = npc3d.global_position + Vector3(0.0, 1.35, 0.0)

	# Keep current orbit angles (prevents disorienting camera flips),
	# but zoom in and move pivot to the NPC head.
	var yaw := float(_camera_state_before_talk.get("yaw", deg_to_rad(45.0)))
	var pitch := float(_camera_state_before_talk.get("pitch", deg_to_rad(-35.0)))
	var dist := 4.0

	var duration := 0.28
	if is_headless.is_valid() and bool(is_headless.call()):
		duration = 0.0
	camera_rig.call("focus_on", head, yaw, pitch, dist, duration)

func _restore_dialogue_camera() -> void:
	if camera_rig == null or _camera_state_before_talk.is_empty():
		return
	if not camera_rig.has_method("tween_to_state"):
		return
	var duration := 0.22
	if is_headless.is_valid() and bool(is_headless.call()):
		duration = 0.0
	camera_rig.call("tween_to_state", _camera_state_before_talk, duration)
	_camera_state_before_talk = {}

func _lock_npc_for_dialogue(npc: Node) -> void:
	if npc == null or not is_instance_valid(npc):
		return
	# Face the camera (more natural than keeping the NPC walking away).
	var cam: Camera3D = null
	if camera_rig != null and camera_rig.has_method("get_camera"):
		var cam0: Variant = camera_rig.call("get_camera")
		if cam0 is Camera3D:
			cam = cam0 as Camera3D
	if npc.has_method("enter_dialogue"):
		if cam != null:
			npc.call("enter_dialogue", cam)
		else:
			npc.call("enter_dialogue", Vector3.ZERO)

func _unlock_npc_after_dialogue() -> void:
	if _talk_npc == null or not is_instance_valid(_talk_npc):
		_talk_npc = null
		return
	if _talk_npc.has_method("exit_dialogue"):
		_talk_npc.call("exit_dialogue")
	_talk_npc = null

