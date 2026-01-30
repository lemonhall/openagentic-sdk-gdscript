extends Object

static func configure(player: AudioStreamPlayer, bgm_path: String, headless: bool) -> void:
	if player == null:
		return
	if headless:
		player.stop()
		player.stream = null
		return

	if player.stream == null:
		var s := load(bgm_path)
		if s is AudioStream:
			player.stream = s as AudioStream

	# Ensure loop for BGM even if import settings change.
	if player.stream == null:
		return
	if _object_has_property(player.stream, "loop"):
		player.stream.set("loop", true)
	else:
		player.finished.connect(func() -> void:
			player.play()
		)

	if not player.playing:
		player.play()

static func _object_has_property(obj: Object, property_name: String) -> bool:
	for p in obj.get_property_list():
		if p.has("name") and String(p["name"]) == property_name:
			return true
	return false

