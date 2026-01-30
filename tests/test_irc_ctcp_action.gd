extends SceneTree

const T := preload("res://tests/_test_util.gd")

class FakeStreamPeerTCP:
	extends RefCounted

	var status: int = StreamPeerTCP.STATUS_CONNECTED
	var inbound: PackedByteArray = PackedByteArray()
	var outbound: PackedByteArray = PackedByteArray()

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

	func server_push_line(line: String) -> void:
		inbound.append_array((line + "\r\n").to_utf8_buffer())

	func server_take_outbound_text() -> String:
		var s := outbound.get_string_from_utf8()
		outbound = PackedByteArray()
		return s

func _init() -> void:
	var ClientScript := load("res://addons/irc_client/IrcClient.gd")
	if ClientScript == null or not (ClientScript is Script) or not (ClientScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing or invalid res://addons/irc_client/IrcClient.gd")
		return

	var BufScript := load("res://addons/irc_client/IrcLineBuffer.gd")
	if BufScript == null or not (BufScript is Script) or not (BufScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing or invalid res://addons/irc_client/IrcLineBuffer.gd")
		return

	var client := (ClientScript as Script).new() as Node
	if not T.require_true(self, client != null, "Failed to instantiate IrcClient"):
		return
	get_root().add_child(client)
	await process_frame

	if not T.require_true(self, client.has_method("ctcp_action"), "IrcClient must implement ctcp_action(target, text)"):
		return
	if not T.require_true(self, client.has_signal("ctcp_action_received"), "IrcClient must emit ctcp_action_received(prefix, target, text)"):
		return

	var fake := FakeStreamPeerTCP.new()
	client.call("set_peer", fake)

	# Sending ACTION should encode CTCP framing.
	client.call("ctcp_action", "#c", "waves")
	var buf = (BufScript as Script).new()
	var out_lines: Array[String] = buf.call("push_chunk", fake.server_take_outbound_text())
	if not T.require_eq(self, out_lines.size(), 1, "expected one outbound line"):
		return

	var soh := "\u0001"
	if not T.require_eq(self, out_lines[0], "PRIVMSG #c :%sACTION waves%s" % [soh, soh], "CTCP ACTION encoding"):
		return

	# Receiving ACTION should emit ctcp_action_received.
	var got := {"ok": false}
	client.connect("ctcp_action_received", func(prefix: String, target: String, text: String) -> void:
		got["ok"] = (prefix == "nick" and target == "#c" and text == "hello")
	)
	fake.server_push_line(":nick PRIVMSG #c :%sACTION hello%s" % [soh, soh])

	client.call("poll")
	await process_frame

	if not T.require_true(self, bool(got.get("ok", false)), "Expected ctcp_action_received payload"):
		return

	T.pass_and_quit(self)

