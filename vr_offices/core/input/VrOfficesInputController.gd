extends RefCounted
const _ClickPicker := preload("res://vr_offices/core/input/VrOfficesClickPicker.gd")
var owner: Node = null
var dialogue: Control = null
var camera_rig: Node = null
var dialogue_ctrl: RefCounted = null
var command_move_to_click: Callable
var select_npc: Callable
var workspace_ctrl: RefCounted = null
var meeting_room_ctrl: RefCounted = null
var open_manager_dialogue_for_workspace: Callable = Callable()
var _rmb_down := false
var _rmb_dragged := false
var _rmb_down_pos := Vector2.ZERO

func _init(
	owner_in: Node,
	dialogue_in: Control,
	camera_rig_in: Node,
	dialogue_ctrl_in: RefCounted,
	command_move_to_click_in: Callable,
	select_npc_in: Callable,
	workspace_ctrl_in: RefCounted = null,
	meeting_room_ctrl_in: RefCounted = null,
	open_manager_dialogue_for_workspace_in: Callable = Callable()
) -> void:
	owner = owner_in
	dialogue = dialogue_in
	camera_rig = camera_rig_in
	dialogue_ctrl = dialogue_ctrl_in
	command_move_to_click = command_move_to_click_in
	select_npc = select_npc_in
	workspace_ctrl = workspace_ctrl_in
	meeting_room_ctrl = meeting_room_ctrl_in
	open_manager_dialogue_for_workspace = open_manager_dialogue_for_workspace_in
func handle_unhandled_input(event: InputEvent, selected_npc: Node) -> void:
	if owner == null:
		return
	if event is InputEventKey:
		var k0 := event as InputEventKey
		if k0.pressed and not k0.echo and k0.ctrl_pressed and k0.physical_keycode == KEY_I:
			if owner.has_method("toggle_settings_overlay"):
				owner.call("toggle_settings_overlay")
				owner.get_viewport().set_input_as_handled()
				return
	if dialogue != null and dialogue.visible:
		if Input.is_action_just_pressed("ui_cancel") and dialogue.has_method("close"):
			var input_node: Control = null
			if dialogue.has_method("get_embedded_dialogue"):
				var embedded := dialogue.call("get_embedded_dialogue") as Control
				if embedded != null:
					input_node = embedded.get_node_or_null("Panel/VBox/Footer/Input") as Control
			if input_node == null:
				input_node = dialogue.get_node_or_null("Panel/VBox/Footer/Input") as Control
			if input_node != null and input_node.has_focus():
				owner.get_viewport().gui_release_focus()
			else:
				dialogue.close()
		owner.get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb0 := event as InputEventMouseButton
		if mb0.button_index == MOUSE_BUTTON_LEFT and mb0.pressed and mb0.double_click:
			var picked_prop := _ClickPicker.try_pick_double_click_prop(owner, camera_rig, mb0.position)
			if typeof(picked_prop) == TYPE_DICTIONARY:
				var pp := picked_prop as Dictionary
				var typ := String(pp.get("type", "")).strip_edges()
				if typ == "vending" and owner.has_method("open_vending_machine_overlay"):
					owner.call("open_vending_machine_overlay")
					owner.get_viewport().set_input_as_handled()
					return
				if typ == "meeting_mic" and owner.has_method("open_meeting_room_chat_for_mic"):
					owner.call("open_meeting_room_chat_for_mic", pp.get("node", null))
					owner.get_viewport().set_input_as_handled()
					return
				if typ == "manager_desk" and open_manager_dialogue_for_workspace.is_valid():
					var manager_desk0 := pp.get("node", null) as Node
					var workspace_id0 := _workspace_id_for_manager_desk(manager_desk0)
					if workspace_id0 != "":
						open_manager_dialogue_for_workspace.call(workspace_id0)
						owner.get_viewport().set_input_as_handled()
						return
	if workspace_ctrl != null and workspace_ctrl.has_method("handle_lmb_event"):
		var consumed := bool(workspace_ctrl.call("handle_lmb_event", event, select_npc))
		if consumed:
			return
	if event is InputEventKey and workspace_ctrl != null and workspace_ctrl.has_method("handle_key_event"):
		var consumed_key := bool(workspace_ctrl.call("handle_key_event", event))
		if consumed_key:
			return
	if event is InputEventMouseMotion and _rmb_down:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_RIGHT != 0:
			if (mm.position - _rmb_down_pos).length() > 6.0:
				_rmb_dragged = true

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_rmb_down = true
				_rmb_dragged = false
				_rmb_down_pos = mb.position
			else:
				if _rmb_down and not _rmb_dragged:
					if workspace_ctrl != null and workspace_ctrl.has_method("handle_rmb_release"):
						if bool(workspace_ctrl.call("handle_rmb_release", mb.position)):
							_rmb_down = false
							return
					var desk := _try_find_desk_from_click(mb.position)
					if desk != null and owner.has_method("open_desk_context_menu"):
						var did: String = ""
						if desk.has_method("get"):
							var v: Variant = desk.get("desk_id")
							if v != null:
								did = String(v).strip_edges()
						if did.strip_edges() == "":
							did = desk.name
						if did.strip_edges() != "":
							owner.call("open_desk_context_menu", did, mb.position)
							_rmb_down = false
							return
					var has_selected := selected_npc != null and is_instance_valid(selected_npc)
					var want_menu := mb.shift_pressed
					if has_selected and not want_menu:
						if command_move_to_click.is_valid():
							command_move_to_click.call(mb.position)
						_rmb_down = false
						return
					if workspace_ctrl != null and workspace_ctrl.has_method("try_open_context_menu"):
						if bool(workspace_ctrl.call("try_open_context_menu", mb.position)):
							_rmb_down = false
							return
					if meeting_room_ctrl != null and meeting_room_ctrl.has_method("try_open_context_menu"):
						if bool(meeting_room_ctrl.call("try_open_context_menu", mb.position)):
							_rmb_down = false
							return
					if command_move_to_click.is_valid():
						command_move_to_click.call(mb.position)
				_rmb_down = false
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var clicked := _try_select_from_click(mb.position)
			if mb.double_click and clicked != null:
				if owner.has_method("_enter_talk"):
					owner.call("_enter_talk", clicked)
				elif dialogue_ctrl != null:
					dialogue_ctrl.call("enter_talk", clicked)
				return
			if mb.double_click:
				var vending := _try_find_vending_machine_from_click(mb.position)
				if vending != null and owner.has_method("open_vending_machine_overlay"):
					owner.call("open_vending_machine_overlay")
					return
				var desk := _try_find_desk_from_click(mb.position)
				if desk != null and owner.has_method("open_settings_overlay_for_desk"):
					var did: String = ""
					if desk.has_method("get"):
						var v: Variant = desk.get("desk_id")
						if v != null:
							did = String(v).strip_edges()
					if did.strip_edges() == "":
						did = desk.name
					if did.strip_edges() != "":
						owner.call("open_settings_overlay_for_desk", did)
			return
	if selected_npc != null and event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.physical_keycode == KEY_E:
			if owner.has_method("_enter_talk"):
				owner.call("_enter_talk", selected_npc)
			elif dialogue_ctrl != null:
				dialogue_ctrl.call("enter_talk", selected_npc)

func _try_select_from_click(screen_pos: Vector2) -> Node:
	var npc := _ClickPicker.try_pick_npc(owner, camera_rig, screen_pos)
	if select_npc.is_valid():
		select_npc.call(npc)
	return npc

func _try_find_desk_from_click(screen_pos: Vector2) -> Node:
	return _ClickPicker.try_pick_desk(owner, camera_rig, screen_pos)

func _try_find_vending_machine_from_click(screen_pos: Vector2) -> Node:
	return _ClickPicker.try_pick_vending_machine(owner, camera_rig, screen_pos)

func _workspace_id_for_manager_desk(manager_desk: Node) -> String:
	if manager_desk == null:
		return ""
	var cur: Node = manager_desk
	while cur != null:
		if cur.has_method("get"):
			var wid0: Variant = cur.get("workspace_id")
			if wid0 != null:
				var wid := String(wid0).strip_edges()
				if wid != "":
					return wid
		cur = cur.get_parent()
	return ""
