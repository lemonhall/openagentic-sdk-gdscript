extends RefCounted

const _ClickPicker := preload("res://vr_offices/core/input/VrOfficesClickPicker.gd")

var owner: Node = null
var dialogue: Control = null
var camera_rig: Node = null
var dialogue_ctrl: RefCounted = null

var command_move_to_click: Callable
var select_npc: Callable
var workspace_ctrl: RefCounted = null

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
	workspace_ctrl_in: RefCounted = null
) -> void:
	owner = owner_in
	dialogue = dialogue_in
	camera_rig = camera_rig_in
	dialogue_ctrl = dialogue_ctrl_in
	command_move_to_click = command_move_to_click_in
	select_npc = select_npc_in
	workspace_ctrl = workspace_ctrl_in

func handle_unhandled_input(event: InputEvent, selected_npc: Node) -> void:
	if owner == null:
		return

	if event is InputEventKey:
		var k0 := event as InputEventKey
		if k0.pressed and not k0.echo and k0.ctrl_pressed and k0.physical_keycode == KEY_I:
			if owner.has_method("toggle_irc_overlay"):
				owner.call("toggle_irc_overlay")
				owner.get_viewport().set_input_as_handled()
				return

	if dialogue != null and dialogue.visible:
		# In dialogue: Esc is a 2-step exit (helps avoid accidental close while typing).
		# 1st Esc: release LineEdit focus (stop typing)
		# 2nd Esc: close the overlay
		if Input.is_action_just_pressed("ui_cancel") and dialogue.has_method("close"):
			var input_node := dialogue.get_node_or_null("Panel/VBox/Footer/Input") as Control
			if input_node != null and input_node.has_focus():
				owner.get_viewport().gui_release_focus()
			else:
				dialogue.close()
		# Prevent camera rig / world from handling mouse input while the dialogue UI is open.
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
					# If an NPC is selected, RMB should keep working as "move to click" even inside a workspace.
					# Use Shift+RMB as an explicit override to open the workspace context menu.
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
					if command_move_to_click.is_valid():
						command_move_to_click.call(mb.position)
				_rmb_down = false
			return

		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var clicked := _try_select_from_click(mb.position)
			if mb.double_click and clicked != null and dialogue_ctrl != null:
				dialogue_ctrl.call("enter_talk", clicked)
				return
			if mb.double_click:
				var desk := _try_find_desk_from_click(mb.position)
				if desk != null and owner.has_method("open_irc_overlay_for_desk"):
					var did: String = ""
					if desk.has_method("get"):
						var v: Variant = desk.get("desk_id")
						if v != null:
							did = String(v).strip_edges()
					if did.strip_edges() == "":
						did = desk.name
					if did.strip_edges() != "":
						owner.call("open_irc_overlay_for_desk", did)
			return

	if selected_npc != null and event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.physical_keycode == KEY_E and dialogue_ctrl != null:
			dialogue_ctrl.call("enter_talk", selected_npc)

func _try_select_from_click(screen_pos: Vector2) -> Node:
	var npc := _ClickPicker.try_pick_npc(owner, camera_rig, screen_pos)
	if select_npc.is_valid():
		select_npc.call(npc)
	return npc

func _try_find_desk_from_click(screen_pos: Vector2) -> Node:
	return _ClickPicker.try_pick_desk(owner, camera_rig, screen_pos)
