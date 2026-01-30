extends RefCounted

var _nick: String = ""
var _user_user: String = ""
var _user_mode: String = "0"
var _user_unused: String = "*"
var _user_realname: String = ""
var _password: String = ""

var _sent_pass: bool = false
var _sent_nick: bool = false
var _sent_user: bool = false

func reset() -> void:
	_sent_pass = false
	_sent_nick = false
	_sent_user = false

func set_password(password: String) -> void:
	_password = password

func set_nick(nick: String) -> void:
	_nick = nick

func set_user(user: String, mode: String = "0", unused: String = "*", realname: String = "") -> void:
	_user_user = user
	_user_mode = mode
	_user_unused = unused
	_user_realname = realname

func send_if_ready(send_message: Callable) -> void:
	# Callable signature: (command: String, params: Array, trailing: String) -> void
	if _password.strip_edges() != "" and not _sent_pass:
		if _password.find(" ") != -1:
			send_message.call("PASS", [], _password)
		else:
			send_message.call("PASS", [_password], "")
		_sent_pass = true

	if _nick.strip_edges() != "" and not _sent_nick:
		send_message.call("NICK", [_nick], "")
		_sent_nick = true

	if _user_user.strip_edges() != "" and not _sent_user:
		var rn := _user_realname
		if rn.strip_edges() == "":
			rn = _user_user
		send_message.call("USER", [_user_user, _user_mode, _user_unused], rn)
		_sent_user = true

