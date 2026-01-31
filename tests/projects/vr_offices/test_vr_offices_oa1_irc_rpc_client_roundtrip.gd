extends SceneTree

const T := preload("res://tests/_test_util.gd")
const IrcMessage := preload("res://addons/irc_client/IrcMessage.gd")

class FakeDeskIrcLink:
	extends Node

	signal message_received(msg: RefCounted)

	var desired_channel := "#oa-test"
	var nick := "oa_desk_test"
	var sent: Array[String] = []

	func get_desired_channel() -> String:
		return desired_channel

	func get_nick() -> String:
		return nick

	func send_channel_message(text: String) -> void:
		sent.append(text)

func _init() -> void:
	var root := get_root()

	var link := FakeDeskIrcLink.new()
	link.name = "DeskIrcLink"
	root.add_child(link)

	var ClientScript := load("res://vr_offices/core/irc/OA1IrcRpcClient.gd")
	if ClientScript == null:
		T.fail_and_quit(self, "Missing OA1IrcRpcClient.gd")
		return
	var client := (ClientScript as Script).new() as Node
	if client == null:
		T.fail_and_quit(self, "Failed to instantiate OA1IrcRpcClient")
		return
	link.add_child(client)

	# Force small payloads to exercise chunking.
	if client.has_method("set"):
		client.set("max_frame_payload_bytes", 4)

	# Start a request without awaiting so we can inject responses.
	var st: Variant = client.call("request_text", "echo hello", 5)
	if not T.require_true(self, T.is_function_state(st), "request_text must be async"):
		return

	# Wait until at least one REQ frame is sent.
	for _i in range(30):
		await process_frame
		if not link.sent.is_empty():
			break
	if not T.require_true(self, not link.sent.is_empty(), "Client must send OA1 REQ frames"):
		return

	# Parse req_id from first frame: OA1 REQ <id> <seq> <more> ...
	var first := String(link.sent[0])
	var parts := first.split(" ", false, 6)
	if not T.require_true(self, parts.size() >= 5 and parts[0] == "OA1" and parts[1] == "REQ", "Invalid OA1 REQ frame: " + first):
		return
	var req_id := String(parts[2]).strip_edges()
	if not T.require_true(self, req_id != "", "REQ_ID must be non-empty"):
		return

	# Ensure request chunking happened (because max_frame_payload_bytes is tiny).
	if not T.require_true(self, link.sent.size() >= 2, "Expected request to be chunked into 2+ frames, got: " + str(link.sent)):
		return

	# Inject a streamed response in two parts, with more=1 then more=0.
	var msg1 := IrcMessage.new()
	msg1.prefix = "remote!u@h"
	msg1.command = "PRIVMSG"
	msg1.params = [link.desired_channel]
	msg1.trailing = "OA1 RES %s 1 1 hello " % req_id
	link.message_received.emit(msg1)

	var msg2 := IrcMessage.new()
	msg2.prefix = "remote!u@h"
	msg2.command = "PRIVMSG"
	msg2.params = [link.desired_channel]
	msg2.trailing = "OA1 RES %s 2 0 world" % req_id
	link.message_received.emit(msg2)

	var out: Variant = await st
	if not T.require_eq(self, String(out), "hello world", "Client must reassemble streamed RES payloads"):
		return

	T.pass_and_quit(self)
