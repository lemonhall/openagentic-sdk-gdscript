extends Object

static func from_environment() -> Dictionary:
	# Opt-in: keep disabled by default to avoid unexpected background sockets.
	var enabled := false
	var v := OS.get_environment("VR_OFFICES_IRC_ENABLED").strip_edges()
	if v != "" and v != "0" and v.to_lower() != "false":
		enabled = true

	var host := OS.get_environment("VR_OFFICES_IRC_HOST").strip_edges()
	var port_s := OS.get_environment("VR_OFFICES_IRC_PORT").strip_edges()
	var port := 6667
	if port_s.is_valid_int():
		port = int(port_s)

	var tls := false
	v = OS.get_environment("VR_OFFICES_IRC_TLS").strip_edges()
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
		"enabled": enabled and host != "",
		"host": host,
		"port": port,
		"tls": tls,
		"server_name": server_name,
		"password": password,
		# Conservative defaults (many networks are strict; your server reports NICKLEN=9).
		"nicklen_default": nicklen,
		"channellen_default": channellen,
	}

