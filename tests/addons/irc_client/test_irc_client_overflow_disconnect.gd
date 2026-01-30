extends SceneTree

const T := preload("res://tests/_test_util.gd")

var got_error: bool = false
var got_disconnected: bool = false

func _on_error(_msg: String) -> void:
	got_error = true

func _on_disconnected() -> void:
	got_disconnected = true

class FakeStreamPeerTCP:
	extends RefCounted

	var status: int = StreamPeerTCP.STATUS_CONNECTED
	var inbound: PackedByteArray = PackedByteArray() # server -> client
	var outbound: PackedByteArray = PackedByteArray() # client -> server

	func poll() -> void:
		pass

	func get_status() -> int:
		return status

	func get_available_bytes() -> int:
		return inbound.size()

	func get_data(_n: int) -> Array:
		var bytes := inbound
		inbound = PackedByteArray()
		return [OK, bytes]

	func put_data(bytes: PackedByteArray) -> int:
		outbound.append_array(bytes)
		return OK

	func disconnect_from_host() -> void:
		status = StreamPeerTCP.STATUS_NONE

	func server_push_bytes(bytes: PackedByteArray) -> void:
		inbound.append_array(bytes)

func _init() -> void:
	var ClientScript := load("res://addons/irc_client/IrcClient.gd")
	if ClientScript == null or not (ClientScript is Script) or not (ClientScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing or invalid res://addons/irc_client/IrcClient.gd")
		return

	var client := (ClientScript as Script).new() as Node
	if not T.require_true(self, client != null, "Failed to instantiate IrcClient"):
		return
	get_root().add_child(client)
	await process_frame

	var fake := FakeStreamPeerTCP.new()
	client.call("set_peer", fake)

	got_error = false
	got_disconnected = false
	client.call("set_nick", "nick_test")
	client.call("set_user", "user_test")

	var err1: int = int(client.connect("error", Callable(self, "_on_error")))
	if not T.require_eq(self, err1, OK, "connect(error)"):
		return
	var err2: int = int(client.connect("disconnected", Callable(self, "_on_disconnected")))
	if not T.require_eq(self, err2, OK, "connect(disconnected)"):
		return

	# First poll: mark connected.
	client.call("poll")
	await process_frame

	# Push a never-terminating oversized line (> default 64 KiB) to force overflow.
	var big: PackedByteArray = PackedByteArray()
	big.resize(80 * 1024) # contents irrelevant; size triggers the safety limit
	fake.server_push_bytes(big)
	if not T.require_true(self, fake.get_available_bytes() > 64 * 1024, "precondition: inbound must exceed default buffer limit"):
		return

	var deadline_ms: int = Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < deadline_ms:
		client.call("poll")
		if got_error and got_disconnected:
			T.pass_and_quit(self)
			return
		await process_frame

	var tr = client.get("_transport")
	var has_peer: bool = tr != null and bool((tr as Object).call("has_peer"))
	var tr_err: String = ""
	if tr != null:
		tr_err = String((tr as Object).call("take_last_error"))
	T.fail_and_quit(self, "expected overflow to emit error+disconnected (got_error=%s got_disconnected=%s has_peer=%s tr_err=%s)" % [str(got_error), str(got_disconnected), str(has_peer), tr_err])
