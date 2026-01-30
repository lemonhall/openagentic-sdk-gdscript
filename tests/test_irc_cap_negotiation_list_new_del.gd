extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var NegScript := load("res://addons/irc_client/IrcCapNegotiation.gd")
	if NegScript == null or not (NegScript is Script) or not (NegScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing or invalid res://addons/irc_client/IrcCapNegotiation.gd")
		return

	var ParserScript := load("res://addons/irc_client/IrcParser.gd")
	if ParserScript == null or not (ParserScript is Script) or not (ParserScript as Script).can_instantiate():
		T.fail_and_quit(self, "Missing or invalid res://addons/irc_client/IrcParser.gd")
		return

	var neg = (NegScript as Script).new()
	var parser = (ParserScript as Script).new()
	if not T.require_true(self, neg != null and parser != null, "Failed to instantiate negotiation/parser"):
		return

	neg.call("set_requested_caps", ["foo"])
	neg.call("start")

	# LS establishes supported caps.
	var msg_ls = parser.call("parse_line", ":srv CAP * LS :foo bar")
	var out_ls: Array[String] = neg.call("handle_message", msg_ls)
	if not T.require_true(self, out_ls.size() == 1 and out_ls[0].begins_with("CAP REQ"), "Expected CAP REQ after LS"):
		return

	# ACK should mark negotiation done.
	var msg_ack = parser.call("parse_line", ":srv CAP * ACK :foo")
	var out_ack: Array[String] = neg.call("handle_message", msg_ack)
	if not T.require_true(self, out_ack.is_empty(), "ACK should not emit further lines"):
		return
	if not T.require_true(self, bool(neg.call("is_done")), "Expected negotiation done after ACK"):
		return

	# NEW adds capability (param-form, no ':').
	var msg_new = parser.call("parse_line", ":srv CAP * NEW baz")
	neg.call("handle_message", msg_new)
	var supported: Array[String] = neg.call("get_supported_caps")
	if not T.require_true(self, supported.has("baz"), "Expected NEW to add 'baz' to supported caps"):
		return

	# DEL removes from supported and acked.
	var msg_del = parser.call("parse_line", ":srv CAP * DEL :foo")
	neg.call("handle_message", msg_del)
	supported = neg.call("get_supported_caps")
	var acked: Array[String] = neg.call("get_acked_caps")
	if not T.require_true(self, not supported.has("foo"), "Expected DEL to remove 'foo' from supported caps"):
		return
	if not T.require_true(self, not acked.has("foo"), "Expected DEL to remove 'foo' from acked caps"):
		return

	# LIST replaces enabled caps (multiline list uses '*').
	var msg_list1 = parser.call("parse_line", ":srv CAP * LIST * :bar")
	var msg_list2 = parser.call("parse_line", ":srv CAP * LIST :baz")
	neg.call("handle_message", msg_list1)
	neg.call("handle_message", msg_list2)
	acked = neg.call("get_acked_caps")
	if not T.require_true(self, acked.size() == 2 and acked.has("bar") and acked.has("baz"), "Expected LIST to set acked caps to {bar,baz}"):
		return

	T.pass_and_quit(self)

