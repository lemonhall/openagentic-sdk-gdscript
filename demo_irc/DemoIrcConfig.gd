extends RefCounted

const USER_CONFIG_PATH := "user://demo_irc/config.json"

var host: String = ""
var port: int = 6667
var tls_enabled: bool = false
var nick: String = ""
var user: String = ""
var realname: String = ""
var channel: String = ""

func normalize() -> void:
	if nick.strip_edges() != "":
		if user.strip_edges() == "":
			user = nick
		if realname.strip_edges() == "":
			realname = nick

	if channel.strip_edges() != "":
		var c := channel.strip_edges()
		var prefix := c.substr(0, 1)
		if prefix != "#" and prefix != "&" and prefix != "+" and prefix != "!":
			c = "#" + c
		channel = c

func to_dict() -> Dictionary:
	return {
		"host": host,
		"port": port,
		"tls_enabled": tls_enabled,
		"nick": nick,
		"user": user,
		"realname": realname,
		"channel": channel,
	}

func from_dict(d: Dictionary) -> void:
	host = String(d.get("host", host))
	port = int(d.get("port", port))
	tls_enabled = bool(d.get("tls_enabled", tls_enabled))
	nick = String(d.get("nick", nick))
	user = String(d.get("user", user))
	realname = String(d.get("realname", realname))
	channel = String(d.get("channel", channel))

func save_to_user() -> void:
	var abs_dir := ProjectSettings.globalize_path("user://demo_irc")
	DirAccess.make_dir_recursive_absolute(abs_dir)

	var f := FileAccess.open(USER_CONFIG_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(to_dict(), "\t"))

func load_from_user() -> void:
	if not FileAccess.file_exists(USER_CONFIG_PATH):
		return
	var f := FileAccess.open(USER_CONFIG_PATH, FileAccess.READ)
	if f == null:
		return
	var raw := f.get_as_text()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	from_dict(parsed as Dictionary)
