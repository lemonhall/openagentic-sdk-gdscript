extends SceneTree

const T := preload("res://tests/_test_util.gd")

class FakeActionHintOverlay:
	extends Control

	var shown: Array[String] = []

	func show_hint(text: String) -> void:
		shown.append(text)
		visible = true

	func hide_hint() -> void:
		visible = false

func _init() -> void:
	var owner := Node3D.new()
	get_root().add_child(owner)
	await process_frame

	var WorkspaceManagerScript := load("res://vr_offices/core/VrOfficesWorkspaceManager.gd")
	if WorkspaceManagerScript == null or not (WorkspaceManagerScript is Script):
		T.fail_and_quit(self, "Missing VrOfficesWorkspaceManager.gd")
		return
	var bounds := Rect2(Vector2(-10, -10), Vector2(20, 20))
	var ws_mgr := (WorkspaceManagerScript as Script).new(bounds) as RefCounted
	if ws_mgr == null:
		T.fail_and_quit(self, "Failed to instantiate workspace manager")
		return

	var WorkspaceCtrlScript := load("res://vr_offices/core/VrOfficesWorkspaceController.gd")
	if WorkspaceCtrlScript == null or not (WorkspaceCtrlScript is Script):
		T.fail_and_quit(self, "Missing VrOfficesWorkspaceController.gd")
		return

	var hint := FakeActionHintOverlay.new()
	owner.add_child(hint)

	var ctrl := (WorkspaceCtrlScript as Script).new(
		owner,
		null,
		ws_mgr,
		null,
		null,
		hint,
		Callable()
	) as RefCounted
	if ctrl == null:
		T.fail_and_quit(self, "Failed to instantiate workspace controller")
		return

	# Simulate a pending create rect and confirm creation.
	var rect := Rect2(Vector2(-2, -2), Vector2(4, 4))
	ctrl.set("_pending_rect", rect)
	ctrl.call("_on_create_confirmed", "Test Workspace")
	await process_frame

	if not T.require_true(self, hint.shown.size() >= 1, "Expected onboarding action hint after workspace creation"):
		return

	get_root().remove_child(owner)
	owner.free()
	await process_frame
	T.pass_and_quit(self)
