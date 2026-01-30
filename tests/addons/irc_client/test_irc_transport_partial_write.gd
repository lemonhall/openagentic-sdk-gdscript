extends SceneTree

const T := preload("res://tests/_test_util.gd")

class FakePartialPeer:
	extends RefCounted

	var status: int = StreamPeerTCP.STATUS_CONNECTED
	var max_per_write: int = 3
	var outbound: PackedByteArray = PackedByteArray()

	func poll() -> void:
		pass

	func get_status() -> int:
		return status

	func put_partial_data(bytes: PackedByteArray) -> Array:
		if status != StreamPeerTCP.STATUS_CONNECTED:
			return [ERR_UNAVAILABLE, 0]
		var n: int = int(min(max_per_write, bytes.size()))
		if n > 0:
			outbound.append_array(bytes.slice(0, n))
		return [OK, n]

	func get_available_bytes() -> int:
		return 0

	func get_data(_n: int) -> Array:
		return [OK, PackedByteArray()]

func _init() -> void:
	var TransportScript := load("res://addons/irc_client/IrcClientTransport.gd")
	if TransportScript == null or not (TransportScript is Script) or not (TransportScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing or invalid res://addons/irc_client/IrcClientTransport.gd")
		return

	var transport = (TransportScript as Script).new()
	if transport == null or not transport.has_method("set_peer") or not transport.has_method("send_line") or not transport.has_method("poll_peer"):
		T.fail_and_quit(self, "IrcClientTransport must implement set_peer/send_line/poll_peer")
		return

	var peer := FakePartialPeer.new()
	peer.max_per_write = 1
	transport.call("set_peer", peer)

	transport.call("send_line", "PING :abc")
	transport.call("send_line", "PONG :def")
	var expected := "PING :abc\r\nPONG :def\r\n".to_utf8_buffer()

	var deadline_ms: int = Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < deadline_ms:
		transport.call("poll_peer")
		if peer.outbound.size() == expected.size():
			break
		await process_frame

	if not T.require_eq(self, peer.outbound.size(), expected.size(), "should eventually flush all bytes with partial writes"):
		return
	if not T.require_eq(self, peer.outbound.get_string_from_utf8(), expected.get_string_from_utf8(), "wire bytes must match exactly"):
		return

	T.pass_and_quit(self)
