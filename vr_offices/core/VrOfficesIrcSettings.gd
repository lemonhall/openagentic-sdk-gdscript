extends RefCounted

const _Defaults := preload("res://vr_offices/core/VrOfficesIrcConfig.gd")

var _config: Dictionary = {}

func _init() -> void:
	_config = _normalize_config(_Defaults.from_environment())

func get_config() -> Dictionary:
	return _config.duplicate(true)

func set_config(cfg: Dictionary) -> void:
	_config = _normalize_config(cfg)

func to_state_dict() -> Dictionary:
	return get_config()

func load_from_state_dict(state: Dictionary) -> void:
	if state == null:
		return
	var irc0: Variant = state.get("irc")
	if typeof(irc0) != TYPE_DICTIONARY:
		return
	_config = _normalize_config(irc0 as Dictionary)

static func _normalize_config(cfg: Dictionary) -> Dictionary:
	var c := cfg if cfg != null else {}

	var host := String(c.get("host", "")).strip_edges()
	var port := int(c.get("port", 6667))
	if port <= 0:
		port = 6667

	var tls := bool(c.get("tls", false))
	var server_name := String(c.get("server_name", "")).strip_edges()
	var password := String(c.get("password", "")).strip_edges()

	var nicklen_default := int(c.get("nicklen_default", 9))
	if nicklen_default < 1:
		nicklen_default = 1
	var channellen_default := int(c.get("channellen_default", 50))
	if channellen_default < 1:
		channellen_default = 1

	var test_nick := String(c.get("test_nick", "tester")).strip_edges()
	if test_nick == "":
		test_nick = "tester"
	var test_channel := String(c.get("test_channel", "#test")).strip_edges()
	if test_channel != "" and not test_channel.begins_with("#"):
		test_channel = "#" + test_channel

	return {
		"host": host,
		"port": port,
		"tls": tls,
		"server_name": server_name,
		"password": password,
		"nicklen_default": nicklen_default,
		"channellen_default": channellen_default,
		"test_nick": test_nick,
		"test_channel": test_channel,
	}
