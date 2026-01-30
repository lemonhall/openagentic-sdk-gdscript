extends SceneTree

const T := preload("res://tests/_test_util.gd")

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

	func disconnect_from_host() -> void:
		status = StreamPeerTCP.STATUS_NONE

	func server_push_bytes(bytes: PackedByteArray) -> void:
		inbound.append_array(bytes)

func _init() -> void:
	var TransportScript := load("res://addons/irc_client/IrcClientTransport.gd")
	if TransportScript == null or not (TransportScript is Script) or not (TransportScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing or invalid res://addons/irc_client/IrcClientTransport.gd")
		return

	var t = (TransportScript as Script).new()
	var peer := FakeStreamPeerTCP.new()
	t.call("set_peer", peer)

	var big := PackedByteArray()
	big.resize(80 * 1024)
	peer.server_push_bytes(big)

	var lines: Array[String] = t.call("read_lines")
	if not T.require_eq(self, lines.size(), 0, "overflow read should return no lines"):
		return
	var err: String = String(t.call("take_last_error"))
	if not T.require_true(self, err.strip_edges() != "", "overflow must produce an error"):
		return
	if not T.require_true(self, not bool(t.call("has_peer")), "overflow must close transport"):
		return

	T.pass_and_quit(self)

