extends Object

static func _sha256_hex(s: String) -> String:
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	hc.update(s.to_utf8_buffer())
	return hc.finish().hex_encode()

static func derive_nick(save_id: String, desk_id: String, nicklen: int) -> String:
	var nlen := nicklen
	if nlen < 1:
		nlen = 1
	var prefix := "oa"
	var digest := _sha256_hex("%s:%s" % [save_id, desk_id])
	var need := nlen - prefix.length()
	if need <= 0:
		return prefix.substr(0, nlen)
	return (prefix + digest.substr(0, need)).substr(0, nlen)

static func derive_channel(save_id: String, desk_id: String, channellen: int) -> String:
	var clen := channellen
	if clen < 1:
		clen = 1
	var prefix := "#oa_"
	if clen <= prefix.length():
		return prefix.substr(0, clen)
	var digest := _sha256_hex("%s:%s" % [save_id, desk_id])
	var need := clen - prefix.length()
	return (prefix + digest.substr(0, need)).substr(0, clen)

