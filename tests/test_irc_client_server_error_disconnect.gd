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
	var inbound: PackedByteArray = PackedByteArray()

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

	func put_data(_bytes: PackedByteArray) -> int:
		return OK

	func disconnect_from_host() -> void:
		status = StreamPeerTCP.STATUS_NONE

	func server_push_raw(text: String) -> void:
		inbound.append_array(text.to_utf8_buffer())

func _init() -> void:
	var ClientScript := load("res://addons/irc_client/IrcClient.gd")
	if ClientScript == null or not (ClientScript is Script) or not (ClientScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing or invalid res://addons/irc_client/IrcClient.gd")
		return

	var client := (ClientScript as Script).new() as Node
	get_root().add_child(client)
	await process_frame

	var fake := FakeStreamPeerTCP.new()
	client.call("set_peer", fake)
	client.call("set_nick", "nick_test")
	client.call("set_user", "user_test")

	got_error = false
	got_disconnected = false
	var err1: int = int(client.connect("error", Callable(self, "_on_error")))
	if not T.require_eq(self, err1, OK, "connect(error)"):
		return
	var err2: int = int(client.connect("disconnected", Callable(self, "_on_disconnected")))
	if not T.require_eq(self, err2, OK, "connect(disconnected)"):
		return

	# Establish connected state.
	client.call("poll")
	await process_frame

	fake.server_push_raw("ERROR :Closing Link\r\n")

	var deadline_ms: int = Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < deadline_ms:
		client.call("poll")
		if got_error and got_disconnected:
			T.pass_and_quit(self)
			return
		await process_frame

	T.fail_and_quit(self, "expected ERROR to emit error+disconnected (got_error=%s got_disconnected=%s)" % [str(got_error), str(got_disconnected)])

