extends SceneTree

const T := preload("res://tests/_test_util.gd")

class FakeDeskIrcLink:
	extends Node
	signal status_changed(status: String)
	signal ready_changed(ready: bool)
	signal error(msg: String)

	var _status := "idle"
	var _ready := false

	func get_status() -> String:
		return _status

	func is_ready() -> bool:
		return _ready

	func set_status(s: String) -> void:
		_status = s
		status_changed.emit(_status)

	func set_ready(v: bool) -> void:
		_ready = v
		ready_changed.emit(_ready)

	func boom(msg: String) -> void:
		error.emit(msg)

func _init() -> void:
	var scene := load("res://vr_offices/furniture/StandingDesk.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing res://vr_offices/furniture/StandingDesk.tscn")
		return

	var desk := (scene as PackedScene).instantiate() as Node3D
	if desk == null:
		T.fail_and_quit(self, "Failed to instantiate StandingDesk.tscn")
		return
	get_root().add_child(desk)
	await process_frame

	var indicator := desk.get_node_or_null("IrcIndicator") as Node3D
	if not T.require_true(self, indicator != null, "Missing IrcIndicator"):
		return
	if not T.require_true(self, float(indicator.position.y) >= 2.0, "IrcIndicator must sit above the desk (y >= 2.0), got %s" % [str(indicator.position.y)]):
		return
	if not T.require_true(self, float(indicator.scale.x) >= 0.8, "IrcIndicator must be readable (scale.x >= 0.8), got %s" % [str(indicator.scale)]):
		return

	# Indicator should feel "alive": its Y should change over time while visible.
	var y0 := float(indicator.position.y)
	for _i in range(12):
		await process_frame
	var y1 := float(indicator.position.y)
	if not T.require_true(self, absf(y1 - y0) >= 0.001, "IrcIndicator Y must animate (bob), got y0=%s y1=%s" % [str(y0), str(y1)]):
		return

	var top := desk.get_node_or_null("IrcIndicator/Top") as MeshInstance3D
	if not T.require_true(self, top != null, "Missing IrcIndicator/Top"):
		return
	var mat := top.material_override as StandardMaterial3D
	if not T.require_true(self, mat != null, "IrcIndicator Top must have StandardMaterial3D material_override"):
		return

	# Default/disabled should still be visible (avoid near-invisible alpha).
	var a0 := float(mat.albedo_color.a)
	if not T.require_true(self, a0 >= 0.65, "Default indicator alpha too low: %s" % [str(a0)]):
		return

	# Inject fake link after the desk is already in-tree (matches real spawn order).
	var link := FakeDeskIrcLink.new()
	link.name = "DeskIrcLink"
	desk.add_child(link)
	await process_frame

	# Connecting should be yellow-ish (R ~= G > B).
	link.set_status("connecting")
	await process_frame
	var c1 := mat.emission
	if not T.require_true(self, c1.r >= c1.b and c1.g >= c1.b, "Connecting emission should be warm"):
		return

	# Ready should be green-ish (G > R).
	link.set_ready(true)
	await process_frame
	var c2 := mat.emission
	if not T.require_true(self, c2.g > c2.r, "Ready emission should be green"):
		return

	# Error should flash red-ish (R > G).
	link.boom("oops")
	await process_frame
	var c3 := mat.emission
	if not T.require_true(self, c3.r > c3.g, "Error emission should be red"):
		return

	get_root().remove_child(desk)
	desk.free()
	await process_frame
	T.pass_and_quit(self)
