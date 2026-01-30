extends SceneTree

const T := preload("res://tests/_test_util.gd")

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

	if not T.require_true(self, client.has_method("connect_to_tls_over_stream"), "IrcClient must implement connect_to_tls_over_stream(stream, server_name)"):
		return
	if not T.require_true(self, client.has_method("connect_to_tls"), "IrcClient must implement connect_to_tls(host, port, server_name=host)"):
		return

	# This test intentionally avoids opening real sockets.
	var tcp := StreamPeerTCP.new()
	client.call("connect_to_tls_over_stream", tcp, "example.com")
	client.call("poll")

	T.pass_and_quit(self)

