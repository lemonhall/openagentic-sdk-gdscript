extends Object

static func for_desks(cfg: Dictionary) -> Dictionary:
	var c := cfg if cfg != null else {}

	var host := String(c.get("host", "")).strip_edges()
	var port := int(c.get("port", 6667))
	if port <= 0:
		port = 6667

	var tls := bool(c.get("tls", false))
	var server_name := String(c.get("server_name", "")).strip_edges()
	var password := String(c.get("password", "")).strip_edges()

	var nicklen := int(c.get("nicklen_default", 9))
	if nicklen < 1:
		nicklen = 1
	var channellen := int(c.get("channellen_default", 50))
	if channellen < 1:
		channellen = 1

	return {
		"host": host,
		"port": port,
		"tls": tls,
		"server_name": server_name,
		"password": password,
		"nicklen_default": nicklen,
		"channellen_default": channellen,
	}

static func from_environment() -> Dictionary:
	var host := OS.get_environment("VR_OFFICES_IRC_HOST").strip_edges()
	var port_s := OS.get_environment("VR_OFFICES_IRC_PORT").strip_edges()
	var port := 6667
	if port_s.is_valid_int():
		port = int(port_s)

	var tls := false
	var v := OS.get_environment("VR_OFFICES_IRC_TLS").strip_edges()
	if v != "" and v != "0" and v.to_lower() != "false":
		tls = true

	var server_name := OS.get_environment("VR_OFFICES_IRC_SERVER_NAME").strip_edges()
	var password := OS.get_environment("VR_OFFICES_IRC_PASSWORD").strip_edges()

	var nicklen := 9
	v = OS.get_environment("VR_OFFICES_IRC_NICKLEN").strip_edges()
	if v.is_valid_int():
		nicklen = int(v)

	var channellen := 50
	v = OS.get_environment("VR_OFFICES_IRC_CHANNELLEN").strip_edges()
	if v.is_valid_int():
		channellen = int(v)

	return {
		"host": host,
		"port": port,
		"tls": tls,
		"server_name": server_name,
		"password": password,
		# Conservative defaults (many networks are strict; your server reports NICKLEN=9).
		"nicklen_default": nicklen,
		"channellen_default": channellen,
	}
